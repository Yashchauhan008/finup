#!/usr/bin/env bash
set -euo pipefail
cd app
mkdir -p lib/data lib/widgets lib/screens

############################ lib/data/stats.dart ############################
cat > lib/data/stats.dart <<'__END__'
import 'db.dart';

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

extension Stats on AppDatabase {
  Future<List<Map<String, Object?>>> _rows(DateTime from, DateTime to) {
    return db.query('transactions',
        columns: ['type', 'amount', 'category_id', 'counterparty', 'occurred_at'],
        where: 'occurred_at >= ? AND occurred_at < ?',
        whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]);
  }

  Future<(double, double)> incomeExpense(DateTime from, DateTime to) async {
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

  Future<List<MonthStat>> monthly(int months) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final end = DateTime(now.year, now.month + 1, 1);
    final out = List.generate(
        months, (i) => MonthStat(DateTime(start.year, start.month + i, 1)));
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

  Future<Map<int?, double>> categoryTotals(
      DateTime from, DateTime to, String type) async {
    final m = <int?, double>{};
    for (final r in await _rows(from, to)) {
      if (r['type'] != type) continue;
      final id = r['category_id'] as int?;
      m[id] = (m[id] ?? 0) + (r['amount'] as num).toDouble();
    }
    return m;
  }

  Future<Map<int, double>> dailyTotals(
      DateTime from, DateTime to, String type) async {
    final m = <int, double>{};
    for (final r in await _rows(from, to)) {
      if (r['type'] != type) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int).day;
      m[d] = (m[d] ?? 0) + (r['amount'] as num).toDouble();
    }
    return m;
  }

  Future<List<(String, double, int)>> topParties(DateTime from, DateTime to,
      {String type = 'expense', int limit = 5}) async {
    final totals = <String, double>{};
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final r in await _rows(from, to)) {
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
__END__

############################ lib/widgets/charts.dart ############################
cat > lib/widgets/charts.dart <<'__END__'
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

const kAmber = Color(0xFFF6A23A);

Color statusColor(double pct) {
  if (pct >= 1) return AppColors.expense;
  if (pct >= 0.8) return kAmber;
  return AppColors.income;
}

String shortInr(double v) {
  if (v >= 100000) {
    final x = v / 100000;
    return '${x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1)}L';
  }
  if (v >= 1000) {
    final x = v / 1000;
    return '${x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1)}k';
  }
  return v.toStringAsFixed(0);
}

double niceMax(double v) {
  if (v <= 0) return 3000;
  final raw = v / 3;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / mag;
  final step = (n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 5 ? 5 : 10))) * mag;
  return step * 3;
}

class MonthBars extends StatefulWidget {
  final List<DateTime> months;
  final List<double> values;
  final bool hide;

  const MonthBars(
      {super.key, required this.months, required this.values, this.hide = false});

  @override
  State<MonthBars> createState() => _MonthBarsState();
}

class _MonthBarsState extends State<MonthBars> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    if (widget.values.isEmpty) return const SizedBox.shrink();
    final maxV = niceMax(widget.values.fold<double>(0, (a, b) => math.max(a, b)));
    const h = 150.0;
    final sel = (_sel ?? widget.values.length - 1)
        .clamp(0, widget.values.length - 1)
        .toInt();
    final accent = context.isDark ? AppColors.lavender : AppColors.indigo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.hide ? '₹ ••••' : inr(widget.values[sel], decimals: 0),
            key: ValueKey(sel),
            style: AppText.display(size: 22, color: fin.text),
          ),
        ),
        Text('Spent in ${DateFormat('MMMM yyyy').format(widget.months[sel])}',
            style: TextStyle(color: fin.subtext, fontSize: 12.5)),
        const SizedBox(height: 16),
        SizedBox(
          height: h + 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                height: h,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var k = 3; k >= 0; k--)
                      Text(shortInr(maxV * k / 3),
                          style: TextStyle(color: fin.subtext, fontSize: 11)),
                  ],
                ),
              ),
              for (var i = 0; i < widget.values.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _sel = i),
                    child: Column(children: [
                      SizedBox(
                        height: h,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 14,
                              height: h,
                              decoration: BoxDecoration(
                                color: fin.divider.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                  begin: 0,
                                  end: (widget.values[i] / maxV)
                                      .clamp(0.0, 1.0)
                                      .toDouble()),
                              duration: Duration(milliseconds: 700 + i * 80),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => Container(
                                width: 14,
                                height: h * v,
                                decoration: BoxDecoration(
                                  color: i == sel ? accent : AppColors.pink,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(DateFormat('MMM').format(widget.months[i]),
                          style: TextStyle(
                              color: i == sel ? fin.text : fin.subtext,
                              fontSize: 11.5,
                              fontWeight:
                                  i == sel ? FontWeight.w700 : FontWeight.w400)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.size = 190,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final track = context.fin.divider;
    return TweenAnimationBuilder<double>(
      key: ValueKey(values.join(',')),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, p, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(values, colors, p, track),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double progress;
  final Color track;

  _DonutPainter(this.values, this.colors, this.progress, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final gap = values.where((v) => v > 0).length > 1 ? 0.035 : 0.0;
    final full = 2 * math.pi * progress;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = full * values[i] / total;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.001),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

class ProgressRing extends StatelessWidget {
  final double value;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 64,
    this.stroke = 7,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final track = context.fin.divider;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, color, track, stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter(this.v, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    if (v <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * v,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.v != v || oldDelegate.color != color;
}
__END__

############################ lib/widgets/dashboard.dart ############################
cat > lib/widgets/dashboard.dart <<'__END__'
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
__END__

############################ lib/screens/budgets_screen.dart ############################
cat > lib/screens/budgets_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/stats.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import 'add_txn_screen.dart';

class _BData {
  final List<Budget> budgets;
  final Map<int?, double> spent;
  const _BData(this.budgets, this.spent);
}

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  Future<_BData>? _future;
  int _version = -1;

  Future<_BData> _load() async {
    final db = AppDatabase.instance;
    final (s, e) = monthRange(DateTime.now());
    return _BData(await db.budgets(), await db.categoryTotals(s, e, 'expense'));
  }

  Future<void> _edit(Budget? b) async {
    final txns = context.read<TxnState>();
    int? catId = b?.categoryId;
    if (catId == null) {
      catId = await pickCategory(context, 'expense');
      if (catId == null || !mounted) return;
    }
    final ctrl = TextEditingController(
        text: b == null ? '' : b.amount.toStringAsFixed(0));
    final cat = txns.category(catId);
    final res = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Monthly budget · ${cat?.name ?? ''}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(prefixText: '₹ ', hintText: 'e.g. 5000'),
        ),
        actions: [
          if (b != null)
            TextButton(
                onPressed: () => Navigator.pop(d, 'delete'),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.expense))),
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(d, 'save'),
              child: const Text('Save')),
        ],
      ),
    );
    final db = AppDatabase.instance;
    if (res == 'delete') await db.deleteBudget(catId);
    if (res == 'save') {
      final v = double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0;
      if (v > 0) await db.setBudget(catId, v);
    }
    if (mounted) setState(() => _future = null);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New budget'),
      ),
      body: FutureBuilder<_BData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          final totalLimit = d.budgets.fold<double>(0, (a, b) => a + b.amount);
          final totalSpent = d.budgets
              .fold<double>(0, (a, b) => a + (d.spent[b.categoryId] ?? 0));
          final pct = totalLimit > 0 ? totalSpent / totalLimit : 0.0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: fin.hero, borderRadius: BorderRadius.circular(26)),
                child: Row(children: [
                  ProgressRing(
                    value: pct,
                    color: statusColor(pct),
                    size: 104,
                    stroke: 10,
                    child: Text('${(pct * 100).round()}%',
                        style: AppText.display(size: 20, color: Colors.white)),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('This month',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(inr(totalSpent, hide: hide, decimals: 0),
                              style: AppText.display(
                                  size: 24, color: Colors.white)),
                        ),
                        Text('of ${inr(totalLimit, hide: hide, decimals: 0)} budget',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text(
                          totalSpent <= totalLimit
                              ? '${inr(totalLimit - totalSpent, hide: hide, decimals: 0)} left'
                              : 'Over by ${inr(totalSpent - totalLimit, hide: hide, decimals: 0)}',
                          style: const TextStyle(
                              color: AppColors.pink, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              if (d.budgets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    'No budgets yet. Tap "New budget" to set a monthly limit for a category. FinUp warns you at 80% and 100%.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fin.subtext, height: 1.5),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                  children: [
                    for (final b in d.budgets)
                      _BudgetCard(
                        category: txns.category(b.categoryId),
                        spent: d.spent[b.categoryId] ?? 0,
                        limit: b.amount,
                        hide: hide,
                        onTap: () => _edit(b),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Category? category;
  final double spent;
  final double limit;
  final bool hide;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.category,
    required this.spent,
    required this.limit,
    required this.hide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final pct = limit > 0 ? spent / limit : 0.0;
    final color = statusColor(pct);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: fin.card, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressRing(
              value: pct,
              color: color,
              size: 64,
              stroke: 7,
              child: Icon(category?.icon ?? Icons.category_rounded,
                  color: category?.colorValue ?? fin.subtext, size: 24),
            ),
            const SizedBox(height: 12),
            Text(category?.name ?? 'Category',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                '${inr(spent, hide: hide, decimals: 0)} of ${inr(limit, hide: hide, decimals: 0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fin.subtext, fontSize: 12.5)),
            const Spacer(),
            Text(
              pct >= 1
                  ? 'Over by ${inr(spent - limit, hide: hide, decimals: 0)}'
                  : '${inr(limit - spent, hide: hide, decimals: 0)} left',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/goals_screen.dart ############################
cat > lib/screens/goals_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/stats.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  Future<List<Goal>>? _future;

  void _reload() => setState(() => _future = null);

  double _parse(String s) => double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

  Future<void> _edit(Goal? g) async {
    final name = TextEditingController(text: g?.name ?? '');
    final target = TextEditingController(
        text: g == null ? '' : g.target.toStringAsFixed(0));
    var color = g?.colorIndex ?? 0;
    final res = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(g == null ? 'New goal' : 'Edit goal'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: g == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. New phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  prefixText: '₹ ', hintText: 'Target amount'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                AppColors.cardGradients.length,
                (i) => GestureDetector(
                  onTap: () => setLocal(() => color = i),
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientAt(i),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color == i
                              ? Theme.of(d).colorScheme.primary
                              : Colors.transparent,
                          width: 3),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          actions: [
            if (g != null)
              TextButton(
                  onPressed: () => Navigator.pop(d, 'delete'),
                  child: const Text('Delete',
                      style: TextStyle(color: AppColors.expense))),
            TextButton(
                onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(d, 'save'),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final db = AppDatabase.instance;
    if (res == 'delete' && g != null) await db.deleteGoal(g.id);
    if (res == 'save') {
      final n = name.text.trim();
      final t = _parse(target.text);
      if (n.isNotEmpty && t > 0) {
        if (g == null) {
          await db.insertGoal(n, t, color);
        } else {
          await db.updateGoal(g.id, n, t, color);
        }
      }
    }
    if (mounted) _reload();
  }

  Future<void> _addMoney(Goal g) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(g.name),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Amount'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, 'withdraw'),
              child: const Text('Withdraw')),
          FilledButton(
              onPressed: () => Navigator.pop(d, 'add'),
              child: const Text('Add money')),
        ],
      ),
    );
    final v = _parse(ctrl.text);
    if (res == null || v <= 0) return;
    await AppDatabase.instance.addToGoal(g.id, res == 'add' ? v : -v);
    if (res == 'add' && g.saved < g.target && g.saved + v >= g.target) {
      messenger.showSnackBar(
          SnackBar(content: Text('Goal reached: ${g.name}. Well done!')));
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final hide = context.watch<SettingsState>().hideAmounts;
    _future ??= AppDatabase.instance.goals();
    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New goal'),
      ),
      body: FutureBuilder<List<Goal>>(
        future: _future,
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.flag_rounded,
                      size: 56, color: AppColors.pink),
                  const SizedBox(height: 16),
                  Text('No goals yet',
                      style: AppText.display(size: 22, color: fin.text)),
                  const SizedBox(height: 8),
                  Text('Save for a phone, a trip or an emergency fund.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fin.subtext)),
                ]),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final g = list[i];
              final pct =
                  g.target > 0 ? (g.saved / g.target).clamp(0.0, 1.0).toDouble() : 0.0;
              return Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientAt(g.colorIndex),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: OrbitPainter(0.3,
                            line: Colors.white.withValues(alpha: 0.16),
                            showDots: false,
                            center: const Alignment(0.8, -0.3)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.flag_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(g.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17)),
                            ),
                            IconButton(
                              onPressed: () => _edit(g),
                              icon: const Icon(Icons.more_horiz_rounded,
                                  color: Colors.white),
                            ),
                          ]),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(inr(g.saved, hide: hide, decimals: 0),
                                style: AppText.display(
                                    size: 28, color: Colors.white)),
                          ),
                          Text('of ${inr(g.target, hide: hide, decimals: 0)}',
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: pct),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, _) =>
                                    LinearProgressIndicator(
                                  value: v,
                                  minHeight: 10,
                                  backgroundColor: Colors.white24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            Text('${(pct * 100).round()}% saved',
                                style: const TextStyle(color: Colors.white70)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _addMoney(g),
                              style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.ink),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add money'),
                            ),
                            const SizedBox(width: 12),
                          ]),
                        ],
                      ),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
__END__

############################ lib/screens/insights_screen.dart ############################
cat > lib/screens/insights_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../data/stats.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_screen.dart';
import 'budgets_screen.dart';
import 'goals_screen.dart';

class _Insight {
  final double total;
  final double last;
  final List<MapEntry<int?, double>> cats;
  final List<(String, double, int)> parties;
  final Map<int, double> daily;
  const _Insight(this.total, this.last, this.cats, this.parties, this.daily);
}

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late DateTime _month;
  String _type = 'expense';
  Future<_Insight>? _future;
  int _version = -1;
  String _key = '';
  int? _selDay;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  bool get _isCurrent {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  Future<_Insight> _load() async {
    final db = AppDatabase.instance;
    final (s, e) = monthRange(_month);
    final (ps, pe) = monthRange(DateTime(_month.year, _month.month - 1));
    final cur = await db.incomeExpense(s, e);
    final prev = await db.incomeExpense(ps, pe);
    final cats = await db.categoryTotals(s, e, _type);
    final parties = await db.topParties(s, e, type: _type);
    final daily = await db.dailyTotals(s, e, _type);
    final list = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final inc = _type == 'income';
    return _Insight(inc ? cur.$1 : cur.$2, inc ? prev.$1 : prev.$2, list,
        parties, daily);
  }

  void _showCategory(int id, String name) {
    final fin = context.fin;
    final hide = context.read<SettingsState>().hideAmounts;
    final (s, e) = monthRange(_month);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
          child: FutureBuilder<List<Txn>>(
            future: AppDatabase.instance
                .txns(categoryId: id, type: _type, from: s, to: e),
            builder: (c, snap) {
              final list = snap.data ?? const <Txn>[];
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  Text(name, style: AppText.display(size: 18, color: fin.text)),
                  const SizedBox(height: 8),
                  for (final t in list)
                    TxnTile(
                      txn: t,
                      hide: hide,
                      showDate: true,
                      onTap: () {
                        Navigator.pop(c);
                        Navigator.of(context)
                            .push(fadeRoute(AddTxnScreen(editing: t)));
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card(FinColors fin, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration:
            BoxDecoration(color: fin.card, borderRadius: BorderRadius.circular(24)),
        child: child,
      );

  Widget _title(FinColors fin, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t,
            style: TextStyle(
                color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
      );

  Widget _link(FinColors fin, String title, IconData icon, Color color, Widget page) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(fadeRoute(page)),
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
                child: Text(title,
                    style: TextStyle(color: fin.text, fontWeight: FontWeight.w700))),
            Icon(Icons.chevron_right_rounded, color: fin.subtext),
          ]),
        ),
      ),
    );
  }

  Widget _typePills(FinColors fin) {
    final dark = context.isDark;
    Widget item(String v, String label) {
      final sel = _type == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _type = v;
            _selDay = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: sel
                  ? (dark ? AppColors.lavender : AppColors.ink)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: sel ? (dark ? AppColors.ink : Colors.white) : fin.text,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration:
          BoxDecoration(color: fin.card, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [item('expense', 'Spending'), item('income', 'Income')]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    final key = '${_month.year}-${_month.month}-$_type';
    if (_future == null || _version != txns.version || key != _key) {
      _version = txns.version;
      _key = key;
      _future = _load();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Text('Insights', style: AppText.display(size: 26, color: fin.text)),
            const SizedBox(height: 14),
            Row(children: [
              _link(fin, 'Budgets', Icons.donut_large_rounded, AppColors.lavender,
                  const BudgetsScreen()),
              const SizedBox(width: 12),
              _link(fin, 'Goals', Icons.flag_rounded, AppColors.pink,
                  const GoalsScreen()),
            ]),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                  color: fin.card, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                IconButton(
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month - 1);
                    _selDay = null;
                  }),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(DateFormat('MMMM yyyy').format(_month),
                        style: TextStyle(
                            color: fin.text, fontWeight: FontWeight.w700)),
                  ),
                ),
                IconButton(
                  onPressed: _isCurrent
                      ? null
                      : () => setState(() {
                            _month = DateTime(_month.year, _month.month + 1);
                            _selDay = null;
                          }),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _typePills(fin),
            const SizedBox(height: 16),
            FutureBuilder<_Insight>(
              future: _future,
              builder: (context, snap) {
                final d = snap.data;
                if (d == null) return const SizedBox(height: 300);
                final isExp = _type == 'expense';
                final change = d.last > 0 ? (d.total - d.last) / d.last * 100 : null;
                final upIsBad = isExp;
                Color changeColor = fin.subtext;
                if (change != null && change != 0) {
                  final up = change > 0;
                  changeColor = (up == upIsBad) ? AppColors.expense : AppColors.income;
                }
                final colors = <Color>[
                  for (final e in d.cats) txns.category(e.key)?.colorValue ?? fin.subtext
                ];
                final maxParty = d.parties.isEmpty ? 1.0 : d.parties.first.$2;
                final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
                final lead = DateTime(_month.year, _month.month, 1).weekday - 1;
                final maxDay = d.daily.values.fold<double>(0, (a, b) => a > b ? a : b);
                final prevName = DateFormat('MMM').format(DateTime(_month.year, _month.month - 1));

                return Column(children: [
                  _card(
                    fin,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isExp ? 'Total spent' : 'Total received',
                            style: TextStyle(color: fin.subtext)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(inr(d.total, hide: hide, decimals: 0),
                              style: AppText.display(size: 32, color: fin.text)),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          if (change != null)
                            Icon(
                                change >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: changeColor,
                                size: 18),
                          const SizedBox(width: 4),
                          Text(
                            change == null
                                ? 'No data for $prevName to compare'
                                : '${change.abs().toStringAsFixed(0)}% ${change >= 0 ? 'more' : 'less'} than $prevName',
                            style: TextStyle(
                                color: changeColor, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    fin,
                    Column(children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: _title(fin, 'By category')),
                      DonutChart(
                        values: d.cats.map((e) => e.value).toList(),
                        colors: colors,
                        center: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${d.cats.length}',
                              style: AppText.display(size: 26, color: fin.text)),
                          Text('categories',
                              style: TextStyle(color: fin.subtext, fontSize: 12)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      if (d.cats.isEmpty)
                        Text('Nothing here yet for this month.',
                            style: TextStyle(color: fin.subtext)),
                      for (var i = 0; i < d.cats.length; i++)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: d.cats[i].key == null
                              ? null
                              : () => _showCategory(d.cats[i].key!,
                                  txns.category(d.cats[i].key)?.name ?? ''),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: colors[i].withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                    txns.category(d.cats[i].key)?.icon ??
                                        Icons.help_outline_rounded,
                                    color: colors[i],
                                    size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  txns.category(d.cats[i].key)?.name ??
                                      'Needs review',
                                  style: TextStyle(
                                      color: fin.text, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                  d.total > 0
                                      ? '${(d.cats[i].value / d.total * 100).round()}%'
                                      : '',
                                  style: TextStyle(color: fin.subtext, fontSize: 12.5)),
                              const SizedBox(width: 10),
                              Text(inr(d.cats[i].value, hide: hide, decimals: 0),
                                  style: TextStyle(
                                      color: fin.text, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    fin,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(fin, isExp ? 'Where it went' : 'Who paid you'),
                        if (d.parties.isEmpty)
                          Text('No payee details this month.',
                              style: TextStyle(color: fin.subtext)),
                        for (final p in d.parties)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(prettyParty(p.$1),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: fin.text,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  Text('${p.$3}x  ',
                                      style: TextStyle(
                                          color: fin.subtext, fontSize: 12)),
                                  Text(inr(p.$2, hide: hide, decimals: 0),
                                      style: TextStyle(
                                          color: fin.text,
                                          fontWeight: FontWeight.w700)),
                                ]),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: maxParty > 0 ? p.$2 / maxParty : 0,
                                    minHeight: 6,
                                    backgroundColor: fin.divider,
                                    color: isExp ? AppColors.pink : AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    fin,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(fin, isExp ? 'Daily spending' : 'Daily income'),
                        Row(children: [
                          for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                            Expanded(
                              child: Center(
                                child: Text(w,
                                    style: TextStyle(
                                        color: fin.subtext,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          children: [
                            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                            for (var day = 1; day <= daysInMonth; day++)
                              Builder(builder: (context) {
                                final v = d.daily[day] ?? 0;
                                final t = maxDay > 0 ? v / maxDay : 0.0;
                                final base = isExp ? AppColors.expense : AppColors.income;
                                final bg = v <= 0
                                    ? fin.bg
                                    : Color.lerp(base.withValues(alpha: 0.18), base, t)!;
                                final sel = _selDay == day;
                                return GestureDetector(
                                  onTap: () => setState(() => _selDay = day),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: sel ? fin.text : Colors.transparent,
                                          width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text('$day',
                                          style: TextStyle(
                                              color: t > 0.55 ? Colors.white : fin.text,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selDay == null
                              ? 'Tap a day to see its total'
                              : '${DateFormat('d MMMM').format(DateTime(_month.year, _month.month, _selDay!))}: ${inr(d.daily[_selDay] ?? 0, hide: hide, decimals: 0)}',
                          style: TextStyle(
                              color: _selDay == null ? fin.subtext : fin.text,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
__END__

############################ Patch Home: replace placeholder with dashboard ############################
perl -0777 -pi -e 's/Container\(\s*width: double\.infinity,\s*padding: const EdgeInsets\.all\(24\),.*?Statistic charts arrive in Part 3.*?\]\),\s*\),/const DashboardSection(),/s' lib/screens/home_screen.dart
sed -i "s#import '../widgets/logo.dart';#import '../widgets/dashboard.dart';\nimport '../widgets/logo.dart';#" lib/screens/home_screen.dart
if ! grep -q "DashboardSection()" lib/screens/home_screen.dart; then
  echo "ERROR: could not patch home_screen.dart for Part 3"; exit 1
fi
sed -i "s#Version 1.1.0 · Part 2#Version 1.2.0 · Part 3#" lib/screens/settings_screen.dart

echo "FinUp Part 3 applied."