import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_screen.dart';
import 'people_screen.dart';

class ReviewBanner extends StatelessWidget {
  final int count;
  const ReviewBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(fadeRoute(const ReviewScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [AppColors.lavender, AppColors.pink]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const Icon(Icons.inbox_rounded, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count to review',
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                Text('Tap a category for each one',
                    style: TextStyle(
                        color: AppColors.ink.withValues(alpha: 0.7),
                        fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
        ]),
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  Future<List<Txn>>? _future;
  int _version = -1;

  Future<void> _markAll(TxnState txns) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mark all as reviewed?'),
        content: const Text(
            'They will stay uncategorised. You can still edit them later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Mark all')),
        ],
      ),
    );
    if (ok == true) await txns.markAllReviewed();
  }

  @override
  Widget build(BuildContext context) {
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    if (_future == null || _version != txns.version) {
      _version = txns.version;
      _future = AppDatabase.instance.txns(status: 'review', limit: 500);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          if (txns.reviewCount > 0)
            TextButton(
                onPressed: () => _markAll(txns),
                child: const Text('Mark all done')),
        ],
      ),
      body: FutureBuilder<List<Txn>>(
        future: _future,
        builder: (context, snap) {
          final list = snap.data ?? const <Txn>[];
          if (snap.connectionState != ConnectionState.done && list.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) return const _AllDone();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _ReviewCard(key: ValueKey(list[i].id), txn: list[i], hide: hide),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Txn txn;
  final bool hide;

  const _ReviewCard({super.key, required this.txn, required this.hide});

  Future<void> _pick(BuildContext context, int categoryId) async {
    final txns = context.read<TxnState>();
    final messenger = ScaffoldMessenger.of(context);
    final party = prettyParty(txn.counterparty);
    final catName = txns.category(categoryId)?.name ?? '';
    await txns.categorize(txn, categoryId);
    if (party.isNotEmpty) {
      messenger.showSnackBar(SnackBar(
          content: Text('Saved. FinUp will file $party under $catName next time.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.read<TxnState>();
    final kind = txn.type == TxnType.income ? 'income' : 'expense';
    final cats = txns.byKind(kind);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      decoration: BoxDecoration(
          color: fin.card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TxnTile(
            txn: txn,
            hide: hide,
            showDate: true,
            onTap: () => Navigator.of(context)
                .push(fadeRoute(AddTxnScreen(editing: txn))),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Pick a category',
                style: TextStyle(color: fin.subtext, fontSize: 12)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats.take(8))
                ActionChip(
                  avatar: Icon(c.icon, size: 16, color: c.colorValue),
                  label: Text(c.name),
                  onPressed: () => _pick(context, c.id!),
                ),
              ActionChip(avatar: const Icon(Icons.person_add_alt_1_rounded, size: 16), label: const Text('Lend / Borrow'), onPressed: () => linkTxnToPerson(context, txn)), ActionChip(avatar: const Icon(Icons.more_horiz_rounded, size: 16),
                label: const Text('More'),
                onPressed: () async {
                  final id = await pickCategory(context, kind);
                  if (id != null && context.mounted) await _pick(context, id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Looping(
          duration: const Duration(milliseconds: 2200),
          builder: (context, t) {
            final s = 1 + 0.06 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Transform.scale(
              scale: s,
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                    color: AppColors.income, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 52),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text('All caught up',
            style: AppText.display(size: 22, color: fin.text)),
        const SizedBox(height: 8),
        Text('New bank SMS will show up here.',
            style: TextStyle(color: fin.subtext)),
      ]),
    );
  }
}
