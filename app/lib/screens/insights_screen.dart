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
  final Map<int, double> daily;
  final double opening;
  final double income;
  final double spending;
  final double invested;
  final double closing;
  const _Insight(
    this.total,
    this.last,
    this.cats,
    this.daily, {
    required this.opening,
    required this.income,
    required this.spending,
    required this.invested,
    required this.closing,
  });
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
    // Full money usage: categories + lent / settle / borrowed.
    final cur = await db.moneyFlow(s, e);
    final prev = await db.moneyFlow(ps, pe);
    final cats = await db.usageBreakdown(s, e, _type);
    final daily = await db.dailyTotals(s, e, _type);
    final analysis = await db.monthMoneyAnalysis(s, e);
    // Show invested under By category on the Spending tab (not counted as expense).
    if (_type == 'expense' && analysis.invested > 0) {
      cats[kUsageInvestId] = analysis.invested;
    }
    final list = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final inc = _type == 'income';
    return _Insight(
      inc ? cur.$1 : cur.$2,
      inc ? prev.$1 : prev.$2,
      list,
      daily,
      opening: analysis.opening,
      income: analysis.income,
      spending: analysis.spending,
      invested: analysis.invested,
      closing: analysis.closing,
    );
  }

  String _bucketLabel(int? id, TxnState txns) {
    if (isUsageBucket(id)) return usageBucketName(id);
    return txns.category(id)?.name ?? 'Needs review';
  }

  IconData _bucketIcon(int? id, TxnState txns) {
    if (isUsageBucket(id)) return usageBucketIcon(id);
    return txns.category(id)?.icon ?? Icons.help_outline_rounded;
  }

  Color _bucketColor(int? id, TxnState txns, FinColors fin) {
    if (isUsageBucket(id)) return usageBucketColor(id);
    return txns.category(id)?.colorValue ?? fin.subtext;
  }

  Future<List<Txn>> _bucketTxns(int id, DateTime s, DateTime e) async {
    final db = AppDatabase.instance;
    if (id == kUsageInvestId) {
      final all = await db.txns(type: 'invest', from: s, to: e);
      return all.where((t) => t.amount > 0).toList();
    }
    if (!isUsageBucket(id)) {
      return db.txns(categoryId: id, type: _type, from: s, to: e);
    }
    final all = await db.txns(type: _type, from: s, to: e);
    return all.where((t) {
      if (t.personId == null) return false;
      final settled = isSettledNote(t.note);
      if (id == kUsageLentId) return _type == 'expense' && !settled;
      if (id == kUsageSettledOutId) return _type == 'expense' && settled;
      if (id == kUsageBorrowedId) return _type == 'income' && !settled;
      if (id == kUsageSettledInId) return _type == 'income' && settled;
      return false;
    }).toList();
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
            future: _bucketTxns(id, s, e),
            builder: (c, snap) {
              final list = snap.data ?? const <Txn>[];
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  Text(name, style: AppText.display(size: 18, color: fin.text)),
                  const SizedBox(height: 8),
                  if (list.isEmpty)
                    Text('No entries in this bucket.',
                        style: TextStyle(color: fin.subtext)),
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


  Widget _kv(FinColors fin, String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: fin.subtext,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ),
        Text(value,
            style: TextStyle(
                color: valueColor ?? fin.text,
                fontWeight: FontWeight.w700,
                fontSize: bold ? 16 : 14)),
      ]),
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
                  for (final e in d.cats)
                    _bucketColor(e.key, txns, fin)
                ];
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
                              : () => _showCategory(
                                  d.cats[i].key!, _bucketLabel(d.cats[i].key, txns)),
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
                                    _bucketIcon(d.cats[i].key, txns),
                                    color: colors[i],
                                    size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _bucketLabel(d.cats[i].key, txns),
                                  style: TextStyle(
                                      color: fin.text, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                  () {
                                    final denom = d.cats.fold<double>(0, (a, e) => a + e.value);
                                    return denom > 0
                                        ? '${(d.cats[i].value / denom * 100).round()}%'
                                        : '';
                                  }(),
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
                        _title(fin, 'Money analysis'),
                        const SizedBox(height: 4),
                        Text(
                          'Spending includes money given to people. Invest moves to goals and is listed separately.',
                          style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        _kv(fin, 'From last month', inr(d.opening, hide: hide, decimals: 0)),
                        _kv(fin, 'Income', inr(d.income, hide: hide, decimals: 0),
                            valueColor: AppColors.income),
                        _kv(fin, 'Spending', inr(d.spending, hide: hide, decimals: 0),
                            valueColor: AppColors.expense),
                        _kv(fin, 'Invested in goals', inr(d.invested, hide: hide, decimals: 0),
                            valueColor: const Color(0xFF5B8DEF)),
                        const Divider(height: 22),
                        _kv(fin, 'In accounts now', inr(d.closing, hide: hide, decimals: 0),
                            bold: true),
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
