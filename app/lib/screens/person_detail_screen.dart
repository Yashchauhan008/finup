import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/people_repo.dart';
import '../native.dart';
import '../security/lock.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'ledger_entry_screen.dart';
import 'people_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  final int personId;
  const PersonDetailScreen({super.key, required this.personId});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  Future<(Person?, List<LedgerEntry>)>? _future;
  int _version = -1;

  Future<(Person?, List<LedgerEntry>)> _load() async {
    final db = AppDatabase.instance;
    return (await db.person(widget.personId), await db.entries(widget.personId));
  }

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));

  Future<void> _delete(Person p) async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text(
            'All ledger entries with this person are removed. Linked bank SMS go back to your review inbox.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.deletePerson(p.id);
    await accounts.load();
    await txns.load();
    nav.pop();
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
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
    return FutureBuilder<(Person?, List<LedgerEntry>)>(
      future: _future,
      builder: (context, snap) {
        final p = snap.data?.$1;
        final entries = snap.data?.$2 ?? const <LedgerEntry>[];
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
                child: snap.connectionState == ConnectionState.done
                    ? const Text('Person not found')
                    : const CircularProgressIndicator()),
          );
        }
        final balance = entries.fold<double>(0, (a, e) => a + e.signed);
        final label = balance > 0.009
            ? '${p.name} owes you'
            : (balance < -0.009 ? 'You owe ${p.name}' : 'All settled');
        final now = DateTime.now();
        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              IconButton(
                tooltip: 'Statement',
                onPressed: () => _open(StatementScreen(
                    person: p, entries: entries, balance: balance)),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    final t = context.read<TxnState>();
                    final id = await editPerson(context, person: p);
                    if (id != null) await t.load();
                  } else if (v == 'delete') {
                    await _delete(p);
                  }
                },
                itemBuilder: (c) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit person')),
                  PopupMenuItem(value: 'delete', child: Text('Delete person')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: fin.hero, borderRadius: BorderRadius.circular(26)),
                child: Column(children: [
                  Avatar(name: p.name, id: p.id, size: 64),
                  const SizedBox(height: 10),
                  if (p.upis.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final u in p.upis)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(u,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11.5)),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(label, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(hide ? '₹ ••••' : inr(balance.abs(), decimals: 0),
                      style: AppText.display(
                          size: 32,
                          color: balance > 0.009
                              ? AppColors.income
                              : (balance < -0.009 ? AppColors.pink : Colors.white))),
                  const SizedBox(height: 16),
                  Row(children: [
                    _action(Icons.north_east_rounded, 'You gave', AppColors.pink,
                        () => _open(LedgerEntryScreen(personId: p.id, type: 'gave'))),
                    const SizedBox(width: 8),
                    _action(Icons.south_west_rounded, 'You got', AppColors.income,
                        () => _open(LedgerEntryScreen(personId: p.id, type: 'took'))),
                    if (balance.abs() > 0.009) ...[
                      const SizedBox(width: 8),
                      _action(
                          Icons.handshake_rounded,
                          'Settle up',
                          Colors.white,
                          () => _open(LedgerEntryScreen(
                              personId: p.id,
                              type: balance > 0 ? 'took' : 'gave',
                              amount: balance.abs(),
                              note: 'Settled up'))),
                    ],
                    if (balance > 0.009) ...[
                      const SizedBox(width: 8),
                      _action(
                          Icons.notifications_active_rounded,
                          'Remind',
                          AppColors.lavender,
                          () => AppLockGate.suspendWhile(() => Native.shareText(
                              'Hi ${p.name}, a gentle reminder about ${inr(balance, decimals: 0)} pending. Thanks!'))),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Text('History',
                  style: TextStyle(
                      color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No entries yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fin.subtext)),
                ),
              if (entries.isNotEmpty)
                Material(
                  color: fin.card,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final e in entries)
                      ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: (e.type == 'gave' ? AppColors.expense : AppColors.income)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                              e.type == 'gave'
                                  ? Icons.north_east_rounded
                                  : Icons.south_west_rounded,
                              color: e.type == 'gave'
                                  ? AppColors.expense
                                  : AppColors.income),
                        ),
                        title: Row(children: [
                          Text(e.type == 'gave' ? 'You gave' : 'You got',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (e.txnId != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.link_rounded, size: 16, color: fin.subtext),
                          ],
                        ]),
                        subtitle: Text([
                          DateFormat('d MMM yyyy').format(e.occurredAt),
                          if (e.note != null && e.note!.isNotEmpty) e.note!,
                          if (e.dueAt != null && e.type == 'gave')
                            e.dueAt!.isBefore(now)
                                ? 'Due date passed'
                                : 'Due ${DateFormat('d MMM').format(e.dueAt!)}',
                        ].join(' · ')),
                        trailing: Text(
                          hide ? '••••' : inr(e.amount, decimals: 0),
                          style: TextStyle(
                              color: e.type == 'gave' ? AppColors.expense : AppColors.income,
                              fontWeight: FontWeight.w700),
                        ),
                        onTap: () => _open(
                            LedgerEntryScreen(personId: p.id, editing: e)),
                      ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class StatementScreen extends StatefulWidget {
  final Person person;
  final List<LedgerEntry> entries;
  final double balance;
  const StatementScreen(
      {super.key, required this.person, required this.entries, required this.balance});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  String get _summary {
    final b = widget.balance;
    final n = widget.person.name;
    if (b > 0.009) return '$n owes me ${inr(b, decimals: 0)}';
    if (b < -0.009) return 'I owe $n ${inr(-b, decimals: 0)}';
    return 'All settled with $n';
  }

  String get _text {
    final lines = <String>['Statement with ${widget.person.name}', ''];
    for (final e in widget.entries.reversed) {
      lines.add(
          '${DateFormat('d MMM yyyy').format(e.occurredAt)}  ${e.type == 'gave' ? 'I gave' : 'I got'}  ${inr(e.amount, decimals: 0)}${e.note != null && e.note!.isNotEmpty ? ' (${e.note})' : ''}');
    }
    lines.addAll(['', _summary, '— via FinUp']);
    return lines.join('\n');
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data != null) {
        final bytes = data.buffer.asUint8List();
        await AppLockGate.suspendWhile(() => Native.shareImage(
            bytes,
            'FinUp-statement-${DateTime.now().millisecondsSinceEpoch}.png',
            '$_summary (via FinUp)'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.ink;
    const grey = Color(0xFF7D7D92);
    final b = widget.balance;
    final color = b > 0.009 ? AppColors.income : (b < -0.009 ? AppColors.expense : grey);
    final gave = widget.entries
        .where((e) => e.type == 'gave')
        .fold<double>(0, (a, e) => a + e.amount);
    final got = widget.entries
        .where((e) => e.type == 'took')
        .fold<double>(0, (a, e) => a + e.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Statement')),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RepaintBoundary(
              key: _key,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const FinUpLogo(size: 40),
                      const SizedBox(width: 10),
                      const Text('FinUp',
                          style: TextStyle(
                              color: ink, fontWeight: FontWeight.w800, fontSize: 20)),
                      const Spacer(),
                      Text(DateFormat('d MMM yyyy').format(DateTime.now()),
                          style: const TextStyle(color: grey)),
                    ]),
                    const SizedBox(height: 20),
                    const Text('Statement with', style: TextStyle(color: grey)),
                    Text(widget.person.name,
                        style: const TextStyle(
                            color: ink, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Expanded(
                            child: Text(_summary,
                                style: TextStyle(
                                    color: color, fontWeight: FontWeight.w700))),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    const Row(children: [
                      SizedBox(
                          width: 84,
                          child: Text('Date',
                              style: TextStyle(color: grey, fontSize: 12))),
                      Expanded(
                          child: Text('Details',
                              style: TextStyle(color: grey, fontSize: 12))),
                      Text('Amount', style: TextStyle(color: grey, fontSize: 12)),
                    ]),
                    const Divider(color: Color(0xFFE6E6EE)),
                    for (final e in widget.entries.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SizedBox(
                              width: 84,
                              child: Text(DateFormat('d MMM yy').format(e.occurredAt),
                                  style: const TextStyle(color: ink, fontSize: 13))),
                          Expanded(
                            child: Text(
                              '${e.type == 'gave' ? 'You gave' : 'You got'}${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}',
                              style: const TextStyle(color: ink, fontSize: 13),
                            ),
                          ),
                          Text(
                            '${e.type == 'gave' ? '-' : '+'}${inr(e.amount, decimals: 0)}',
                            style: TextStyle(
                                color: e.type == 'gave'
                                    ? AppColors.expense
                                    : AppColors.income,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ]),
                      ),
                    const Divider(color: Color(0xFFE6E6EE)),
                    Row(children: [
                      const Expanded(
                          child: Text('Total given', style: TextStyle(color: grey))),
                      Text(inr(gave, decimals: 0),
                          style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Expanded(
                          child: Text('Total received', style: TextStyle(color: grey))),
                      Text(inr(got, decimals: 0),
                          style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 18),
                    const Text('Generated by FinUp · private and offline',
                        style: TextStyle(color: grey, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18))),
                  onPressed: () =>
                      AppLockGate.suspendWhile(() => Native.shareText(_text)),
                  icon: const Icon(Icons.text_snippet_rounded),
                  label: const Text('As text'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: _busy ? 'Preparing…' : 'Share image',
                  icon: Icons.image_rounded,
                  onPressed: _busy ? null : _shareImage,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
