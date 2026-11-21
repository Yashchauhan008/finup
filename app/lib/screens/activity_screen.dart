import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_screen.dart';
import 'review_screen.dart';

class _Day {
  final DateTime day;
  final double spent;
  const _Day(this.day, this.spent);
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = 'all';
  final _search = TextEditingController();
  bool _searching = false;
  Future<List<Txn>>? _future;
  int _version = -1;
  String _key = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Object> _group(List<Txn> list) {
    final totals = <DateTime, double>{};
    for (final t in list) {
      final d = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
      if (t.type == TxnType.expense) totals[d] = (totals[d] ?? 0) + t.amount;
    }
    final out = <Object>[];
    DateTime? cur;
    for (final t in list) {
      final d = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
      if (cur == null || d != cur) {
        cur = d;
        out.add(_Day(d, totals[d] ?? 0));
      }
      out.add(t);
    }
    return out;
  }

  Widget _pills(FinColors fin) {
    final dark = context.isDark;
    Widget item(String value, String label) {
      final sel = _filter == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
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
                      color: sel
                          ? (dark ? AppColors.ink : Colors.white)
                          : fin.text,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: fin.card, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        item('all', 'All'),
        item('expense', 'Spend'),
        item('income', 'Income'),
        item('invest', 'Invest'),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    final key = '$_filter|${_search.text}';
    if (_future == null || _version != txns.version || key != _key) {
      _version = txns.version;
      _key = key;
      _future = AppDatabase.instance.txns(
          type: _filter == 'all' ? null : _filter,
          search: _search.text,
          limit: 400);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              Expanded(
                child: _searching
                    ? TextField(
                        controller: _search,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search payee or note',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      )
                    : Text('Activity',
                        style: AppText.display(size: 26, color: fin.text)),
              ),
              if (txns.syncing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              IconButton(
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search.clear();
                }),
                icon: Icon(
                    _searching ? Icons.close_rounded : Icons.search_rounded),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _pills(fin)),
          if (txns.reviewCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ReviewBanner(count: txns.reviewCount),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await txns.sync(context.read<AccountsState>());
              },
              child: FutureBuilder<List<Txn>>(
                future: _future,
                builder: (context, snap) {
                  final list = snap.data ?? const <Txn>[];
                  if (list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 90),
                        Icon(Icons.receipt_long_rounded,
                            size: 48, color: fin.subtext),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            snap.connectionState == ConnectionState.done
                                ? 'No transactions yet'
                                : 'Loading…',
                            style: TextStyle(color: fin.subtext),
                          ),
                        ),
                      ],
                    );
                  }
                  final items = _group(list);
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final it = items[i];
                      if (it is _Day) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                          child: Row(children: [
                            Text(dayLabel(it.day),
                                style: TextStyle(
                                    color: fin.subtext,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            const Spacer(),
                            if (it.spent > 0)
                              Text(hide ? '' : '-${inr(it.spent)}',
                                  style: TextStyle(
                                      color: fin.subtext, fontSize: 12.5)),
                          ]),
                        );
                      }
                      final t = it as Txn;
                      return TxnTile(
                        txn: t,
                        hide: hide,
                        onTap: () => Navigator.of(context)
                            .push(fadeRoute(AddTxnScreen(editing: t))),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
