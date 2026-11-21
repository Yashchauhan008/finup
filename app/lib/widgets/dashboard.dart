import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/stats.dart';
import '../screens/budgets_screen.dart';
import '../screens/goals_screen.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import 'charts.dart';
import 'common.dart';

class _DashData {
  final double income;
  final double expense;
  final List<MonthStat> months;
  final List<(int, double, double)> alerts;
  final int budgetCount;
  final int goalCount;
  const _DashData(this.income, this.expense, this.months, this.alerts,
      this.budgetCount, this.goalCount);
}

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  Future<_DashData>? _future;
  int _version = -1;

  Future<_DashData> _load() async {
    final db = AppDatabase.instance;
    final (start, end) = monthRange(DateTime.now());
    final ie = await db.incomeExpense(start, end);
    final months = await db.monthly(6);
    final budgets = await db.budgets();
    final goals = await db.goals();
    final spent = await db.categoryTotals(start, end, 'expense');
    final alerts = <(int, double, double)>[];
    for (final b in budgets) {
      final s = spent[b.categoryId] ?? 0;
      if (b.amount > 0 && s / b.amount >= 0.8) {
        alerts.add((b.categoryId, s, b.amount));
      }
    }
    alerts.sort((a, b) => (b.$2 / b.$3).compareTo(a.$2 / a.$3));
    return _DashData(
        ie.$1, ie.$2, months, alerts, budgets.length, goals.length);
  }

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));

  Widget _kv(FinColors fin, String label, String value, Color color, IconData icon) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: fin.subtext, fontSize: 12.5)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      color: fin.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _link(FinColors fin, String title, String sub, IconData icon,
      Color color, Widget page) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _open(page),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: fin.card, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: fin.text, fontWeight: FontWeight.w700)),
                  Text(sub,
                      style: TextStyle(color: fin.subtext, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    if (_future == null || _version != txns.version) {
      _version = txns.version;
      _future = _load();
    }
    return FutureBuilder<_DashData>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        if (d == null) return const SizedBox(height: 260);
        final net = d.income - d.expense;
        final ratio = d.income > 0
            ? (d.expense / d.income).clamp(0.0, 1.0).toDouble()
            : (d.expense > 0 ? 1.0 : 0.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: fin.card, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('This month',
                        style: TextStyle(
                            color: fin.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(DateFormat('MMMM').format(DateTime.now()),
                        style: TextStyle(color: fin.subtext)),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: _kv(fin, 'Income', inr(d.income, hide: hide),
                            AppColors.income, Icons.south_west_rounded)),
                    Expanded(
                        child: _kv(fin, 'Spent', inr(d.expense, hide: hide),
                            AppColors.expense, Icons.north_east_rounded)),
                  ]),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 10,
                        backgroundColor: AppColors.income.withValues(alpha: 0.25),
                        color: net < 0 ? AppColors.expense : AppColors.lavender,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hide
                        ? ' '
                        : (net >= 0
                            ? 'You have saved ${inr(net, decimals: 0)} so far'
                            : 'Overspent by ${inr(-net, decimals: 0)}'),
                    style: TextStyle(
                        color: net >= 0 ? AppColors.income : AppColors.expense,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (d.alerts.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final a in d.alerts.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _open(const BudgetsScreen()),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusColor(a.$2 / a.$3).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: statusColor(a.$2 / a.$3)
                                .withValues(alpha: 0.45)),
                      ),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            color: statusColor(a.$2 / a.$3)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${txns.category(a.$1)?.name ?? 'Budget'}: ${(a.$2 / a.$3 * 100).round()}% of ${inr(a.$3, decimals: 0)} used',
                            style: TextStyle(
                                color: fin.text, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: fin.subtext),
                      ]),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              _link(
                  fin,
                  'Budgets',
                  d.budgetCount == 0 ? 'Set limits' : '${d.budgetCount} active',
                  Icons.donut_large_rounded,
                  AppColors.lavender,
                  const BudgetsScreen()),
              const SizedBox(width: 12),
              _link(
                  fin,
                  'Goals',
                  d.goalCount == 0 ? 'Start saving' : '${d.goalCount} goals',
                  Icons.flag_rounded,
                  AppColors.pink,
                  const GoalsScreen()),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: fin.card, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Statistic',
                        style: TextStyle(
                            color: fin.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('Last 6 months',
                        style: TextStyle(color: fin.subtext, fontSize: 12.5)),
                  ]),
                  const SizedBox(height: 12),
                  MonthBars(
                    months: d.months.map((m) => m.month).toList(),
                    values: d.months.map((m) => m.expense).toList(),
                    hide: hide,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
