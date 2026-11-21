import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../data/stats.dart';
import '../native.dart';
import '../state/txn_state.dart';
import '../theme.dart';

/// Applies categories chosen from SMS notification buttons.
Future<void> applyPendingCategories() async {
  final pending = await Native.pendingCategories();
  if (pending.isEmpty) return;
  final db = AppDatabase.instance;
  final done = <String>[];
  for (final e in pending.entries) {
    List<Map<String, Object?>> rows;
    if (e.key.startsWith('ref:')) {
      rows = await db.db.query('transactions',
          where: 'ref = ?', whereArgs: [e.key], limit: 1);
    } else if (e.key.startsWith('body:')) {
      rows = await db.db.query('transactions',
          where: 'sms_body = ?', whereArgs: [e.key.substring(5)], limit: 1);
    } else {
      done.add(e.key);
      continue;
    }
    if (rows.isEmpty || e.value < 0) continue;
    final t = Txn.fromMap(rows.first);
    await db.markReviewed(t.id!, e.value);
    final k = t.counterparty?.trim().toLowerCase();
    if (k != null && k.isNotEmpty) {
      await db.addRule(k, e.value);
      await db.applyRuleToPending(k, e.value);
    }
    done.add(e.key);
  }
  if (done.isNotEmpty) await Native.clearPendingCategories(done);
}

class BudgetAlerts {
  static bool _running = false;

  static Future<void> check(TxnState s) async {
    if (_running) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('budgetAlerts') ?? true)) return;
      if (!(prefs.getBool('onboarded') ?? false)) return;
      final db = AppDatabase.instance;
      final budgets = await db.budgets();
      if (budgets.isEmpty) return;
      final now = DateTime.now();
      final (start, end) = monthRange(now);
      final spent = await db.categoryTotals(start, end, 'expense');
      final ym = '${now.year}-${now.month}';
      for (final b in budgets) {
        if (b.amount <= 0) continue;
        final used = spent[b.categoryId] ?? 0;
        final pct = used / b.amount;
        final level = pct >= 1 ? 2 : (pct >= 0.8 ? 1 : 0);
        if (level == 0) continue;
        final key = 'budgetAlert:${b.categoryId}:$ym';
        if ((prefs.getInt(key) ?? 0) >= level) continue;
        await prefs.setInt(key, level);
        final name = s.category(b.categoryId)?.name ?? 'A budget';
        final month = DateFormat('MMMM').format(now);
        if (level == 2) {
          await Native.notify(
            '$name budget used up',
            'You have spent ${inr(used, decimals: 0)} of ${inr(b.amount, decimals: 0)} in $month.',
            id: 9000 + b.categoryId,
          );
        } else {
          await Native.notify(
            '$name budget at ${(pct * 100).round()}%',
            '${inr(used, decimals: 0)} of ${inr(b.amount, decimals: 0)} used. ${inr(b.amount - used, decimals: 0)} left for $month.',
            id: 9000 + b.categoryId,
          );
        }
      }
    } catch (_) {
    } finally {
      _running = false;
    }
  }
}
