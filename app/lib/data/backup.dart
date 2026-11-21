import 'dart:convert';

import 'db.dart';

const _tables = [
  'accounts', 'categories', 'transactions', 'people', 'ledger', 'rules', 'budgets', 'goals', 'tags', 'txn_tags', 'receipts'
];

extension Backup on AppDatabase {
  Future<String> exportJson() async {
    final data = <String, Object?>{};
    for (final t in _tables) {
      data[t] = await db.query(t);
    }
    return jsonEncode({
      'app': 'FinUp',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': data,
    });
  }

  Future<bool> importJson(String json) async {
    final root = jsonDecode(json);
    if (root is! Map || root['app'] != 'FinUp' || root['tables'] is! Map) {
      return false;
    }
    final tables = root['tables'] as Map;
    await db.transaction((txn) async {
      for (final t in _tables) {
        await txn.delete(t);
      }
      for (final t in _tables) {
        final rows = tables[t];
        if (rows is! List) continue;
        for (final r in rows) {
          if (r is Map) await txn.insert(t, Map<String, Object?>.from(r));
        }
      }
    });
    return true;
  }

  Future<String> exportCsv() async {
    final cats = {for (final c in await categories()) c.id: c.name};
    final accs = {for (final a in await db.query('accounts')) a['id']: a['name']};
    final ppl = {for (final p in await db.query('people')) p['id']: p['name']};
    final rows = await db.query('transactions', orderBy: 'occurred_at DESC');
    final b = StringBuffer(
        'Date,Type,Amount,Category,Account,To account,Payee,Person,Note,Status\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final r in rows) {
      final d = DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int);
      b.writeln([
        d.toIso8601String().substring(0, 16).replaceAll('T', ' '),
        r['type'],
        r['amount'],
        cats[r['category_id']] ?? '',
        accs[r['account_id']] ?? '',
        accs[r['to_account_id']] ?? '',
        r['counterparty'],
        ppl[r['person_id']] ?? '',
        r['note'],
        r['status'],
      ].map(esc).join(','));
    }
    return b.toString();
  }

  Future<void> wipeAll() async {
    for (final t in ['accounts', 'transactions', 'people', 'ledger', 'rules', 'budgets', 'goals', 'tags', 'txn_tags', 'receipts']) {
      await db.delete(t);
    }
  }
}
