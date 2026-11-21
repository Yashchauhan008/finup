import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db.dart';

const kFinupSyncTables = [
  'accounts',
  'categories',
  'transactions',
  'people',
  'ledger',
  'rules',
  'budgets',
  'goals',
  'tags',
  'txn_tags',
  'receipts',
  'deleted_refs',
];

extension Backup on AppDatabase {
  Future<String> exportJson() async {
    final data = <String, Object?>{};
    for (final t in kFinupSyncTables) {
      try {
        data[t] = await db.query(t);
      } catch (_) {
        data[t] = <Map<String, Object?>>[];
      }
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
      for (final t in kFinupSyncTables) {
        try {
          await txn.delete(t);
        } catch (_) {}
      }
      for (final t in kFinupSyncTables) {
        final rows = tables[t];
        if (rows is! List) continue;
        for (final r in rows) {
          if (r is! Map) continue;
          final map = <String, Object?>{};
          r.forEach((k, v) {
            if (v == null || v is num || v is String || v is bool) {
              map[k.toString()] = v;
            } else {
              map[k.toString()] = v.toString();
            }
          });
          try {
            await txn.insert(t, map, conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}
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
    for (final t in [
      'accounts',
      'transactions',
      'people',
      'ledger',
      'rules',
      'budgets',
      'goals',
      'tags',
      'txn_tags',
      'receipts',
      'deleted_refs',
    ]) {
      try {
        await db.delete(t);
      } catch (_) {}
    }
  }
}
