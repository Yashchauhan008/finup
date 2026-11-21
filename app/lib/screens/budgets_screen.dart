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
    final messenger = ScaffoldMessenger.of(context);
    if (res == 'delete') {
      await db.deleteBudget(catId);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Budget removed')));
      }
    }
    if (res == 'save') {
      final raw = ctrl.text.replaceAll(',', '').replaceAll('₹', '').trim();
      final v = double.tryParse(raw) ?? 0;
      if (v <= 0) {
        if (mounted) {
          messenger.showSnackBar(
              const SnackBar(content: Text('Enter a budget amount greater than 0')));
        }
      } else {
        await db.setBudget(catId, v);
        if (mounted) {
          messenger.showSnackBar(
              SnackBar(content: Text('Budget saved · ${cat?.name ?? 'category'}')));
        }
      }
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
