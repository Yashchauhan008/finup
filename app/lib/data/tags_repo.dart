import 'package:sqflite/sqflite.dart';

import 'db.dart';

class Tag {
  final int id;
  final String name;
  final int color;
  final bool isTrip;
  final DateTime? start;
  final DateTime? end;
  final double? budget;
  final bool autoTag;
  final bool archived;

  const Tag({
    required this.id,
    required this.name,
    required this.color,
    this.isTrip = false,
    this.start,
    this.end,
    this.budget,
    this.autoTag = false,
    this.archived = false,
  });

  factory Tag.fromMap(Map<String, Object?> m) => Tag(
        id: m['id'] as int,
        name: m['name'] as String,
        color: (m['color'] as int?) ?? 0xFF8E8BEA,
        isTrip: (m['is_trip'] as int? ?? 0) == 1,
        start: m['start_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['start_at'] as int),
        end: m['end_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['end_at'] as int),
        budget: (m['budget'] as num?)?.toDouble(),
        autoTag: (m['auto_tag'] as int? ?? 0) == 1,
        archived: (m['archived'] as int? ?? 0) == 1,
      );

  bool get isActive {
    if (!isTrip || start == null || end == null) return false;
    final now = DateTime.now();
    return !now.isBefore(start!) && now.isBefore(end!.add(const Duration(days: 1)));
  }
}

extension Tags on AppDatabase {
  Future<void> ensureTagSchema() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0,
        is_trip INTEGER NOT NULL DEFAULT 0,
        start_at INTEGER,
        end_at INTEGER,
        budget REAL,
        auto_tag INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS txn_tags(
        txn_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY(txn_id, tag_id)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipts(
        txn_id INTEGER PRIMARY KEY,
        path TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''');
  }

  Future<List<Tag>> tags() async {
    final rows = await db.query('tags', orderBy: 'is_trip DESC, id DESC');
    return rows.map(Tag.fromMap).toList();
  }

  Future<Tag?> tagById(int id) async {
    final r = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Tag.fromMap(r.first);
  }

  Future<int> insertTag({
    required String name,
    required int color,
    bool isTrip = false,
    DateTime? start,
    DateTime? end,
    double? budget,
    bool autoTag = false,
  }) {
    return db.insert('tags', {
      'name': name,
      'color': color,
      'is_trip': isTrip ? 1 : 0,
      'start_at': start?.millisecondsSinceEpoch,
      'end_at': end?.millisecondsSinceEpoch,
      'budget': budget,
      'auto_tag': autoTag ? 1 : 0,
      'archived': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateTag(int id,
      {required String name,
      required int color,
      DateTime? start,
      DateTime? end,
      double? budget,
      bool autoTag = false,
      bool archived = false}) async {
    await db.update(
        'tags',
        {
          'name': name,
          'color': color,
          'start_at': start?.millisecondsSinceEpoch,
          'end_at': end?.millisecondsSinceEpoch,
          'budget': budget,
          'auto_tag': autoTag ? 1 : 0,
          'archived': archived ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> deleteTag(int id) async {
    await db.delete('txn_tags', where: 'tag_id = ?', whereArgs: [id]);
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<int>> tagsOf(int txnId) async {
    final r = await db.query('txn_tags', columns: ['tag_id'], where: 'txn_id = ?', whereArgs: [txnId]);
    return r.map((e) => e['tag_id'] as int).toList();
  }

  Future<void> setTxnTags(int txnId, List<int> tagIds) async {
    await db.delete('txn_tags', where: 'txn_id = ?', whereArgs: [txnId]);
    for (final t in tagIds) {
      await db.insert('txn_tags', {'txn_id': txnId, 'tag_id': t},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<Txn>> txnsForTag(int tagId) async {
    final rows = await db.rawQuery(
        'SELECT t.* FROM transactions t JOIN txn_tags tt ON tt.txn_id = t.id '
        'WHERE tt.tag_id = ? ORDER BY t.occurred_at DESC',
        [tagId]);
    return rows.map(Txn.fromMap).toList();
  }

  Future<Map<int, (double, int)>> tagSummaries() async {
    final rows = await db.rawQuery(
        "SELECT tt.tag_id AS tag_id, "
        "COALESCE(SUM(CASE WHEN t.type = 'expense' AND t.person_id IS NULL THEN t.amount ELSE 0 END), 0) AS spent, "
        "COUNT(*) AS n FROM txn_tags tt JOIN transactions t ON t.id = tt.txn_id GROUP BY tt.tag_id");
    final m = <int, (double, int)>{};
    for (final r in rows) {
      m[r['tag_id'] as int] = ((r['spent'] as num).toDouble(), (r['n'] as num).toInt());
    }
    return m;
  }

  Future<Tag?> activeTrip() async {
    for (final t in await tags()) {
      if (t.isTrip && t.autoTag && !t.archived && t.isActive) return t;
    }
    return null;
  }

  Future<void> autoTagTrips() async {
    for (final t in await tags()) {
      if (!t.isTrip || !t.autoTag || t.archived || t.start == null || t.end == null) continue;
      final from = t.start!.millisecondsSinceEpoch;
      final to = t.end!.add(const Duration(days: 1)).millisecondsSinceEpoch;
      await db.rawInsert(
          "INSERT OR IGNORE INTO txn_tags(txn_id, tag_id) "
          "SELECT id, ? FROM transactions WHERE occurred_at >= ? AND occurred_at < ? AND type != 'transfer'",
          [t.id, from, to]);
    }
  }

  Future<int?> lastTxnId() async {
    return Sqflite.firstIntValue(await db.rawQuery('SELECT MAX(id) FROM transactions'));
  }

  Future<String?> receiptOf(int txnId) async {
    final r = await db.query('receipts', where: 'txn_id = ?', whereArgs: [txnId]);
    return r.isEmpty ? null : r.first['path'] as String;
  }

  Future<void> setReceipt(int txnId, String path) async {
    await db.insert('receipts',
        {'txn_id': txnId, 'path': path, 'created_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeReceipt(int txnId) async {
    await db.delete('receipts', where: 'txn_id = ?', whereArgs: [txnId]);
  }
}
