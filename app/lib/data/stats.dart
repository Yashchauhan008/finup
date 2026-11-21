import 'package:flutter/material.dart';

import '../theme.dart';
import 'db.dart';

/// Synthetic category ids for people-ledger / invest money in charts.
const int kUsageLentId = -101; // you gave / lent (not a settle note)
const int kUsageSettledOutId = -102; // you paid someone back / settled
const int kUsageBorrowedId = -103; // you got / borrowed
const int kUsageSettledInId = -104; // someone paid you back / settled
const int kUsageInvestId = -105; // account → goal (not expense)

class MonthStat {
  final DateTime month;
  double income = 0;
  double expense = 0;
  MonthStat(this.month);
}

class Budget {
  final int id;
  final int categoryId;
  final double amount;
  const Budget(this.id, this.categoryId, this.amount);
}

class Goal {
  final int id;
  final String name;
  final double target;
  final double saved;
  final int colorIndex;
  const Goal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.colorIndex,
  });
}

(DateTime, DateTime) monthRange(DateTime m) =>
    (DateTime(m.year, m.month, 1), DateTime(m.year, m.month + 1, 1));

bool isSettledNote(String? note) {
  final n = (note ?? '').toLowerCase();
  return n.contains('settled');
}

String usageBucketName(int? id) {
  switch (id) {
    case kUsageLentId:
      return 'Lent to people';
    case kUsageSettledOutId:
      return 'Loan / settle paid';
    case kUsageBorrowedId:
      return 'Borrowed / received';
    case kUsageSettledInId:
      return 'Settlements received';
    case kUsageInvestId:
      return 'Invested in goals';
    default:
      return 'Needs review';
  }
}

IconData usageBucketIcon(int? id) {
  switch (id) {
    case kUsageLentId:
      return Icons.volunteer_activism_rounded;
    case kUsageSettledOutId:
      return Icons.handshake_rounded;
    case kUsageBorrowedId:
      return Icons.south_west_rounded;
    case kUsageSettledInId:
      return Icons.handshake_rounded;
    case kUsageInvestId:
      return Icons.savings_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

Color usageBucketColor(int? id) {
  switch (id) {
    case kUsageLentId:
      return AppColors.pink;
    case kUsageSettledOutId:
      return const Color(0xFFE8A87C);
    case kUsageBorrowedId:
      return AppColors.income;
    case kUsageSettledInId:
      return AppColors.lavender;
    case kUsageInvestId:
      return const Color(0xFF5B8DEF);
    default:
      return AppColors.lavender;
  }
}

bool isUsageBucket(int? id) =>
    id == kUsageLentId ||
    id == kUsageSettledOutId ||
    id == kUsageBorrowedId ||
    id == kUsageSettledInId ||
    id == kUsageInvestId;

extension Stats on AppDatabase {
  Future<List<Map<String, Object?>>> _rows(DateTime from, DateTime to,
      {bool excludePeople = false}) {
    return db.query(
      'transactions',
      columns: [
        'type',
        'amount',
        'category_id',
        'counterparty',
        'occurred_at',
        'person_id',
        'note',
      ],
      where: excludePeople
          ? 'occurred_at >= ? AND occurred_at < ? AND person_id IS NULL'
          : 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
  }

  int? _usageBucket(Map<String, Object?> r, String type) {
    if (r['type'] != type) return null;
    final personId = r['person_id'] as int?;
    if (personId == null) return r['category_id'] as int?;
    final settled = isSettledNote(r['note'] as String?);
    if (type == 'expense') {
      return settled ? kUsageSettledOutId : kUsageLentId;
    }
    if (type == 'income') {
      return settled ? kUsageSettledInId : kUsageBorrowedId;
    }
    return null;
  }

  /// True spending / income only (excludes people ledger). Used for budgets & "saved".
  Future<(double, double)> incomeExpense(DateTime from, DateTime to) async {
    double inc = 0;
    double exp = 0;
    for (final r in await _rows(from, to, excludePeople: true)) {
      final a = (r['amount'] as num).toDouble();
      if (r['type'] == 'income') {
        inc += a;
      } else if (r['type'] == 'expense') {
        exp += a;
      }
    }
    return (inc, exp);
  }

  /// Money in/out including lent, borrowed and settlements (full usage).
  Future<(double, double)> moneyFlow(DateTime from, DateTime to) async {
    double inc = 0;
    double exp = 0;
    for (final r in await _rows(from, to)) {
      final a = (r['amount'] as num).toDouble();
      if (r['type'] == 'income') {
        inc += a;
      } else if (r['type'] == 'expense') {
        exp += a;
      }
    }
    return (inc, exp);
  }

  /// Month cash story for Insights: opening carry, income, spending, invested.
  /// Opening is reconstructed from current account totals rolled back by this month.
  Future<({double opening, double income, double spending, double invested, double closing})>
      monthMoneyAnalysis(DateTime from, DateTime to) async {
    // Include lent / people money in spending & income (same as Insights total).
    final (income, spending) = await moneyFlow(from, to);
    double invested = 0;
    double netAccounts = 0;
    for (final r in await _rows(from, to)) {
      final a = (r['amount'] as num).toDouble();
      final t = r['type'];
      if (t == 'income') {
        netAccounts += a;
      } else if (t == 'expense') {
        netAccounts -= a;
      } else if (t == 'invest') {
        netAccounts -= a; // +invest leaves accounts; -invest returns
        if (a > 0) invested += a;
      }
    }
    double closing = 0;
    final accs = await db.query('accounts',
        columns: ['balance'], where: 'archived = 0');
    for (final a in accs) {
      closing += (a['balance'] as num).toDouble();
    }
    final opening = closing - netAccounts;
    return (
      opening: opening,
      income: income,
      spending: spending,
      invested: invested,
      closing: closing,
    );
  }

  Future<List<MonthStat>> monthly(int months) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final end = DateTime(now.year, now.month + 1, 1);
    final out = List.generate(
        months, (i) => MonthStat(DateTime(start.year, start.month + i, 1)));
    // Include people money so the 6-month chart reflects real cash movement.
    for (final r in await _rows(start, end)) {
      final d = DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int);
      final idx = (d.year - start.year) * 12 + d.month - start.month;
      if (idx < 0 || idx >= months) continue;
      final a = (r['amount'] as num).toDouble();
      if (r['type'] == 'income') {
        out[idx].income += a;
      } else if (r['type'] == 'expense') {
        out[idx].expense += a;
      }
    }
    return out;
  }

  /// Category / people-usage totals. [excludePeople] true for budgets.
  Future<Map<int?, double>> categoryTotals(
      DateTime from, DateTime to, String type,
      {bool excludePeople = true}) async {
    final m = <int?, double>{};
    for (final r in await _rows(from, to, excludePeople: excludePeople)) {
      if (r['type'] != type) continue;
      final id = excludePeople
          ? r['category_id'] as int?
          : _usageBucket(r, type);
      if (id == null && !excludePeople && r['person_id'] != null) continue;
      m[id] = (m[id] ?? 0) + (r['amount'] as num).toDouble();
    }
    return m;
  }

  /// Insights donut: spending/income categories + lent / settle / borrowed buckets.
  Future<Map<int?, double>> usageBreakdown(
      DateTime from, DateTime to, String type) {
    return categoryTotals(from, to, type, excludePeople: false);
  }

  Future<Map<int, double>> dailyTotals(
      DateTime from, DateTime to, String type,
      {bool excludePeople = false}) async {
    final m = <int, double>{};
    for (final r in await _rows(from, to, excludePeople: excludePeople)) {
      if (r['type'] != type) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int).day;
      m[d] = (m[d] ?? 0) + (r['amount'] as num).toDouble();
    }
    return m;
  }

  Future<List<(String, double, int)>> topParties(DateTime from, DateTime to,
      {String type = 'expense', int limit = 5, bool excludePeople = false}) async {
    final totals = <String, double>{};
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final r in await _rows(from, to, excludePeople: excludePeople)) {
      if (r['type'] != type) continue;
      final p = (r['counterparty'] as String?)?.trim();
      if (p == null || p.isEmpty) continue;
      final k = p.toLowerCase();
      names.putIfAbsent(k, () => p);
      totals[k] = (totals[k] ?? 0) + (r['amount'] as num).toDouble();
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final keys = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    return [for (final k in keys.take(limit)) (names[k]!, totals[k]!, counts[k]!)];
  }

  // ----- Budgets -----
  Future<List<Budget>> budgets() async {
    final rows = await db.query('budgets');
    return rows
        .map((r) => Budget(r['id'] as int, r['category_id'] as int,
            (r['amount'] as num).toDouble()))
        .toList();
  }

  Future<void> setBudget(int categoryId, double amount) async {
    await db.delete('budgets', where: 'category_id = ?', whereArgs: [categoryId]);
    await db.insert('budgets', {'category_id': categoryId, 'amount': amount});
  }

  Future<void> deleteBudget(int categoryId) async {
    await db.delete('budgets', where: 'category_id = ?', whereArgs: [categoryId]);
  }

  // ----- Goals -----
  Future<List<Goal>> goals() async {
    final rows = await db.query('goals', orderBy: 'id');
    return rows
        .map((r) => Goal(
              id: r['id'] as int,
              name: r['name'] as String,
              target: (r['target'] as num).toDouble(),
              saved: (r['saved'] as num).toDouble(),
              colorIndex: (r['color_index'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<void> insertGoal(String name, double target, int colorIndex) async {
    await db.insert('goals', {
      'name': name,
      'target': target,
      'saved': 0,
      'color_index': colorIndex,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateGoal(int id, String name, double target, int colorIndex) async {
    await db.update('goals',
        {'name': name, 'target': target, 'color_index': colorIndex},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addToGoal(int id, double delta) async {
    await db.rawUpdate(
        'UPDATE goals SET saved = MAX(0, saved + ?) WHERE id = ?', [delta, id]);
  }

  Future<void> deleteGoal(int id) async {
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }
}
