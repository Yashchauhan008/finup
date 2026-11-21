import 'db.dart';
import 'repo.dart';

class Person {
  final int id;
  final String name;
  final String? phone;
  final List<String> upis;
  final String? note;
  const Person(
      {required this.id,
      required this.name,
      this.phone,
      this.upis = const [],
      this.note});
}

class LedgerEntry {
  final int id;
  final int personId;
  final String type; // gave | took
  final double amount;
  final String? note;
  final int? txnId;
  final DateTime? dueAt;
  final DateTime occurredAt;

  const LedgerEntry({
    required this.id,
    required this.personId,
    required this.type,
    required this.amount,
    this.note,
    this.txnId,
    this.dueAt,
    required this.occurredAt,
  });

  double get signed => type == 'gave' ? amount : -amount;

  factory LedgerEntry.fromMap(Map<String, Object?> m) => LedgerEntry(
        id: m['id'] as int,
        personId: m['person_id'] as int,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        note: m['note'] as String?,
        txnId: m['txn_id'] as int?,
        dueAt: m['due_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due_at'] as int),
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(m['occurred_at'] as int),
      );
}

class PersonSummary {
  final Person person;
  final double balance;
  final DateTime? lastAt;
  final DateTime? nextDue;
  const PersonSummary(this.person, this.balance, this.lastAt, this.nextDue);
}

extension People on AppDatabase {
  Person _person(Map<String, Object?> r) => Person(
        id: r['id'] as int,
        name: r['name'] as String,
        phone: r['phone'] as String?,
        upis: ((r['upi_ids'] as String?) ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        note: r['note'] as String?,
      );

  Future<List<Person>> people() async {
    final rows = await db.query('people', orderBy: 'name COLLATE NOCASE');
    return rows.map(_person).toList();
  }

  Future<Person?> person(int id) async {
    final rows = await db.query('people', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _person(rows.first);
  }

  Future<int> insertPerson(String name,
      {String? phone, List<String> upis = const []}) {
    return db.insert('people', {
      'name': name,
      'phone': phone,
      'upi_ids': upis.join(','),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updatePerson(Person p) async {
    await db.update(
        'people',
        {'name': p.name, 'phone': p.phone, 'upi_ids': p.upis.join(','), 'note': p.note},
        where: 'id = ?',
        whereArgs: [p.id]);
  }

  Future<void> addUpi(int personId, String upi) async {
    final p = await person(personId);
    if (p == null) return;
    final u = upi.trim().toLowerCase();
    if (u.isEmpty || p.upis.contains(u)) return;
    await updatePerson(Person(
        id: p.id, name: p.name, phone: p.phone, upis: [...p.upis, u], note: p.note));
  }

  Future<List<LedgerEntry>> entries(int personId) async {
    final rows = await db.query('ledger',
        where: 'person_id = ?', whereArgs: [personId], orderBy: 'occurred_at DESC');
    return rows.map(LedgerEntry.fromMap).toList();
  }

  Future<List<PersonSummary>> peopleSummaries() async {
    final list = await people();
    final rows = await db.query('ledger');
    final bal = <int, double>{};
    final last = <int, DateTime>{};
    final due = <int, DateTime>{};
    for (final r in rows) {
      final e = LedgerEntry.fromMap(r);
      final pid = e.personId;
      bal[pid] = (bal[pid] ?? 0) + e.signed;
      final l = last[pid];
      if (l == null || e.occurredAt.isAfter(l)) last[pid] = e.occurredAt;
      final d = e.dueAt;
      final cur = due[pid];
      if (d != null && e.type == 'gave' && (cur == null || d.isBefore(cur))) {
        due[pid] = d;
      }
    }
    return [
      for (final p in list)
        PersonSummary(p, bal[p.id] ?? 0, last[p.id],
            (bal[p.id] ?? 0) > 0.009 ? due[p.id] : null)
    ];
  }

  Future<Txn?> txnById(int id) async {
    final r = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Txn.fromMap(r.first);
  }

  Future<void> addEntry({
    required int personId,
    required String type,
    required double amount,
    String? note,
    DateTime? dueAt,
    required DateTime when,
    int? accountId,
    String? personName,
  }) async {
    int? txnId;
    if (accountId != null) {
      txnId = await this.addTxn(Txn(
        accountId: accountId,
        type: type == 'gave' ? TxnType.expense : TxnType.income,
        amount: amount,
        personId: personId,
        counterparty: personName,
        note: note,
        status: 'done',
        occurredAt: when,
      ));
    }
    await db.insert('ledger', {
      'person_id': personId,
      'type': type,
      'amount': amount,
      'note': note,
      'txn_id': txnId,
      'due_at': dueAt?.millisecondsSinceEpoch,
      'occurred_at': when.millisecondsSinceEpoch,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteEntry(LedgerEntry e) async {
    if (e.txnId != null) {
      final t = await txnById(e.txnId!);
      if (t != null) {
        // Always delete the linked txn and remember its SMS ref so sync cannot
        // re-import it, and autoLinkPeople cannot resurrect it on the person.
        await this.deleteTxn(t);
      }
    }
    await db.delete('ledger', where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> updateEntry(
    LedgerEntry old, {
    required String type,
    required double amount,
    String? note,
    DateTime? dueAt,
    required DateTime when,
    int? accountId,
    String? personName,
  }) async {
    final t = old.txnId == null ? null : await txnById(old.txnId!);
    if (t != null && t.smsBody != null) {
      await db.update('ledger',
          {'note': note, 'due_at': dueAt?.millisecondsSinceEpoch},
          where: 'id = ?', whereArgs: [old.id]);
      return;
    }
    await deleteEntry(old);
    await addEntry(
        personId: old.personId,
        type: type,
        amount: amount,
        note: note,
        dueAt: dueAt,
        when: when,
        accountId: accountId,
        personName: personName);
  }

  Future<void> deletePerson(int id) async {
    for (final e in await entries(id)) {
      await deleteEntry(e);
    }
    await db.update('transactions', {'person_id': null},
        where: 'person_id = ?', whereArgs: [id]);
    await db.delete('people', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> linkTxn(Txn t, int personId) async {
    final type = t.type == TxnType.income ? 'took' : 'gave';
    await db.update('transactions',
        {'person_id': personId, 'category_id': null, 'status': 'done'},
        where: 'id = ?', whereArgs: [t.id]);
    await db.insert('ledger', {
      'person_id': personId,
      'type': type,
      'amount': t.amount,
      'note': t.note,
      'txn_id': t.id,
      'occurred_at': t.occurredAt.millisecondsSinceEpoch,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    final party = t.counterparty?.trim().toLowerCase();
    if (party != null && party.contains('@')) await addUpi(personId, party);
  }

  Future<int> autoLinkPeople() async {
    final map = <String, int>{};
    for (final p in await people()) {
      for (final u in p.upis) {
        map[u] = p.id;
      }
    }
    if (map.isEmpty) return 0;
    final rows = await db.query('transactions',
        where: "status = 'review' AND person_id IS NULL AND counterparty IS NOT NULL");
    var n = 0;
    for (final r in rows) {
      final t = Txn.fromMap(r);
      if (t.type == TxnType.transfer) continue;
      final pid = map[t.counterparty!.trim().toLowerCase()];
      if (pid != null) {
        await linkTxn(t, pid);
        n++;
      }
    }
    return n;
  }
}
