import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/stats.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_txn_screen.dart';

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
    final messenger = ScaffoldMessenger.of(context);
    if (res == 'delete' && g != null) {
      await db.deleteGoal(g.id);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Goal deleted')));
      }
    }
    if (res == 'save') {
      final n = name.text.trim();
      final t = _parse(target.text);
      if (n.isEmpty || t <= 0) {
        if (mounted) {
          messenger.showSnackBar(const SnackBar(
              content: Text('Enter a goal name and target amount')));
        }
      } else {
        if (g == null) {
          await db.insertGoal(n, t, color);
        } else {
          await db.updateGoal(g.id, n, t, color);
        }
        if (mounted) {
          messenger.showSnackBar(SnackBar(
              content: Text(g == null ? 'Goal created · $n' : 'Goal updated · $n')));
        }
      }
    }
    if (mounted) _reload();
  }

  Future<void> _addMoney(Goal g) async {
    final messenger = ScaffoldMessenger.of(context);
    final accounts = context.read<AccountsState>();
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(g.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invest moves money from an account into this goal. It is not an expense or income.',
              style: TextStyle(color: context.fin.subtext, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, 'withdraw'),
              child: const Text('Withdraw')),
          FilledButton(
              onPressed: () => Navigator.pop(d, 'invest'),
              child: const Text('Invest')),
        ],
      ),
    );
    final v = _parse(ctrl.text);
    if (res == null || v <= 0) return;
    final withdraw = res == 'withdraw';
    if (withdraw && v > g.saved + 0.001) {
      messenger.showSnackBar(
          SnackBar(content: Text('Only ${inr(g.saved)} saved in this goal')));
      return;
    }
    final accId = await pickAccount(
      context,
      title: withdraw ? 'Return money to account' : 'Invest from account',
    );
    if (accId == null) return;
    await AppDatabase.instance.investInGoal(
      accountId: accId,
      goalId: g.id,
      amount: v,
      when: DateTime.now(),
      note: withdraw ? 'Withdraw from ${g.name}' : 'Invest in ${g.name}',
      withdraw: withdraw,
    );
    await accounts.load();
    if (!withdraw && g.saved < g.target && g.saved + v >= g.target) {
      messenger.showSnackBar(
          SnackBar(content: Text('Goal reached: ${g.name}. Well done!')));
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text(withdraw
              ? 'Returned ${inr(v)} to account'
              : 'Invested ${inr(v)} in ${g.name}')));
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
                              label: const Text('Invest'),
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
