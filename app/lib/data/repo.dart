import 'package:sqflite/sqflite.dart';

import 'db.dart';

extension Repo on AppDatabase {
  Future<void> ensureSchema() async {
    final cols = await db.rawQuery('PRAGMA table_info(transactions)');
    final names = cols.map((c) => c['name'] as String).toSet();
    if (!names.contains('affects_balance')) {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN affects_balance INTEGER NOT NULL DEFAULT 1');
    }
    if (!names.contains('goal_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN goal_id INTEGER');
    }
    await db.execute(
        'CREATE TABLE IF NOT EXISTS deleted_refs(ref TEXT PRIMARY KEY, deleted_at INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS budgets(id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER NOT NULL, amount REAL NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS goals(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, target REAL NOT NULL, saved REAL NOT NULL DEFAULT 0, color_index INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)');
  }

  Future<void> rememberDeletedRef(String? ref) async {
    final r = (ref ?? '').trim();
    if (r.isEmpty) return;
    await db.insert(
      'deleted_refs',
      {'ref': r, 'deleted_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> isDeletedRef(String ref) async {
    final n = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM deleted_refs WHERE ref = ?', [ref])) ??
        0;
    return n > 0;
  }

  Future<bool> txnExists(String ref) async {
    final n = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM transactions WHERE ref = ?', [ref])) ??
        0;
    return n > 0;
  }

  /// balanceMode: 0 = no balance change, 1 = full, 2 = only the receiving account (transfers)
  Future<int> addTxn(Txn t, {int balanceMode = 1}) async {
    final id = await db.insert('transactions', {
      ...t.toMap(),
      'affects_balance': balanceMode,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _apply(t, 1, balanceMode);
    return id;
  }

  Future<void> editTxn(Txn old, Txn neu) async {
    final mode = await _modeOf(old.id!);
    await _apply(old, -1, mode);
    var newMode = mode;
    if (mode == 2 && neu.type != TxnType.transfer) newMode = 0;
    await db.update('transactions', {...neu.toMap(), 'affects_balance': newMode},
        where: 'id = ?', whereArgs: [old.id]);
    await _apply(neu, 1, newMode);
  }

  Future<void> deleteTxn(Txn t) async {
    final mode = await _modeOf(t.id!);
    await _apply(t, -1, mode);
    await rememberDeletedRef(t.ref);
    await db.delete('ledger', where: 'txn_id = ?', whereArgs: [t.id]);
    await db.delete('transactions', where: 'id = ?', whereArgs: [t.id]);
  }

  Future<int> _modeOf(int id) async {
    final r = await db.query('transactions',
        columns: ['affects_balance'], where: 'id = ?', whereArgs: [id]);
    if (r.isEmpty) return 0;
    return (r.first['affects_balance'] as int?) ?? 1;
  }

  Future<void> _apply(Txn t, int sign, int mode) async {
    if (mode == 0) return;
    final a = t.amount * sign;
    Future<void> bump(int? id, double d) async {
      if (id == null) return;
      await db.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?', [d, id]);
    }

    switch (t.type) {
      case TxnType.expense:
        if (mode == 1) await bump(t.accountId, -a);
      case TxnType.income:
        if (mode == 1) await bump(t.accountId, a);
      case TxnType.transfer:
        if (mode == 1) await bump(t.accountId, -a);
        await bump(t.toAccountId, a);
      case TxnType.invest:
        // amount > 0: account → goal; amount < 0: goal → account
        if (mode == 1) {
          await bump(t.accountId, -a);
          if (t.goalId != null) {
            await db.rawUpdate(
                'UPDATE goals SET saved = MAX(0, saved + ?) WHERE id = ?',
                [a, t.goalId]);
          }
        }
    }
  }

  /// Move money between an account and a savings goal. Not expense/income.
  Future<int> investInGoal({
    required int accountId,
    required int goalId,
    required double amount,
    required DateTime when,
    String? note,
    bool withdraw = false,
  }) async {
    final v = amount.abs();
    final t = Txn(
      accountId: accountId,
      goalId: goalId,
      type: TxnType.invest,
      amount: withdraw ? -v : v,
      note: note,
      status: 'done',
      occurredAt: when,
    );
    return addTxn(t);
  }

  Future<void> setAccountBalance(int id, double balance, DateTime at) async {
    await db.update(
        'accounts',
        {'balance': balance, 'balance_updated_at': at.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<List<Txn>> txns({
    String? type,
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
    int? accountId,
    int? categoryId,
    int? personId,
    int limit = 300,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (from != null) {
      where.add('occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('occurred_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (accountId != null) {
      where.add('(account_id = ? OR to_account_id = ?)');
      args.addAll([accountId, accountId]);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (personId != null) {
      where.add('person_id = ?');
      args.add(personId);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add(
          "(LOWER(COALESCE(counterparty, '')) LIKE ? OR LOWER(COALESCE(note, '')) LIKE ?)");
      final q = '%${search.trim().toLowerCase()}%';
      args.addAll([q, q]);
    }
    final rows = await db.query('transactions',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'occurred_at DESC',
        limit: limit);
    return rows.map(Txn.fromMap).toList();
  }

  Future<void> markReviewed(int id, int? categoryId) async {
    await db.update(
        'transactions',
        {'status': 'done', if (categoryId != null) 'category_id': categoryId},
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> markAllReviewed() async {
    await db.update('transactions', {'status': 'done'},
        where: 'status = ?', whereArgs: ['review']);
  }

  Future<List<(String, int)>> rules() async {
    final rows = await db.query('rules', where: 'category_id IS NOT NULL');
    return rows
        .map((r) => ((r['keyword'] as String), (r['category_id'] as int)))
        .toList();
  }

  Future<void> addRule(String keyword, int categoryId) async {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return;
    await db.delete('rules', where: 'keyword = ?', whereArgs: [k]);
    await db.insert('rules', {
      'keyword': k,
      'category_id': categoryId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> applyRuleToPending(String keyword, int categoryId) async {
    await db.rawUpdate(
        "UPDATE transactions SET category_id = ?, status = 'done' "
        "WHERE status = 'review' AND LOWER(COALESCE(counterparty, '')) = ?",
        [categoryId, keyword.trim().toLowerCase()]);
  }

  Future<void> insertCategory(
      String name, String iconKey, int color, String kind) async {
    final maxSort = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COALESCE(MAX(sort), 0) FROM categories')) ??
        0;
    await db.insert('categories', {
      'name': name,
      'icon': iconKey,
      'color': color,
      'kind': kind,
      'sort': maxSort + 1,
    });
  }

  Future<void> updateCategory(Category c) async {
    await db.update(
        'categories', {'name': c.name, 'icon': c.iconKey, 'color': c.color},
        where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCategory(int id) async {
    await db.update('transactions', {'category_id': null},
        where: 'category_id = ?', whereArgs: [id]);
    await db.delete('rules', where: 'category_id = ?', whereArgs: [id]);
    await db.delete('budgets', where: 'category_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
