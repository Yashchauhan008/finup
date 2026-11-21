import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/people_repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'ledger_entry_screen.dart';
import 'person_detail_screen.dart';

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

class Avatar extends StatelessWidget {
  final String name;
  final int id;
  final double size;
  const Avatar({super.key, required this.name, required this.id, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(gradient: AppColors.gradientAt(id), shape: BoxShape.circle),
      child: Center(
        child: Text(initials(name),
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36)),
      ),
    );
  }
}

Future<int?> editPerson(BuildContext context, {Person? person, String? upi}) async {
  final name = TextEditingController(text: person?.name ?? '');
  final phone = TextEditingController(text: person?.phone ?? '');
  final upis = TextEditingController(
      text: person != null ? person.upis.join(', ') : (upi ?? ''));
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(person == null ? 'New person' : 'Edit person'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: name,
            autofocus: person == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'Phone (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: upis,
            decoration: const InputDecoration(
                hintText: 'UPI IDs, comma separated (optional)'),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
      ],
    ),
  );
  final n = name.text.trim();
  if (ok != true || n.isEmpty) return null;
  final ph = phone.text.trim().isEmpty ? null : phone.text.trim();
  final list = upis.text
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList();
  final db = AppDatabase.instance;
  if (person == null) return db.insertPerson(n, phone: ph, upis: list);
  await db.updatePerson(
      Person(id: person.id, name: n, phone: ph, upis: list, note: person.note));
  return person.id;
}

Future<int?> pickPerson(BuildContext context,
    {String? suggestFor, String title = 'Choose person'}) async {
  final fin = context.fin;
  final people = await AppDatabase.instance.people();
  if (!context.mounted) return null;
  final raw = (suggestFor ?? '').trim().toLowerCase();
  final handle = raw.split('@').first;
  Person? found;
  if (handle.isNotEmpty) {
    for (final p in people) {
      final first = p.name.toLowerCase().split(' ').first;
      if (p.upis.contains(raw) || (first.length >= 3 && handle.contains(first))) {
        found = p;
        break;
      }
    }
  }
  final sug = found;
  final picked = await showModalBottomSheet<int>(
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
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(title, style: AppText.display(size: 18, color: fin.text)),
            if (raw.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(prettyParty(suggestFor),
                    style: TextStyle(color: fin.subtext)),
              ),
            const SizedBox(height: 12),
            if (sug != null) ...[
              const Text('Suggested',
                  style: TextStyle(
                      color: AppColors.lavender,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(name: sug.name, id: sug.id, size: 42),
                title: Text('Is this ${sug.name}?'),
                trailing:
                    const Icon(Icons.check_circle_rounded, color: AppColors.income),
                onTap: () => Navigator.pop(c, sug.id),
              ),
              const Divider(),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.18),
                    shape: BoxShape.circle),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: AppColors.lavender),
              ),
              title: const Text('New person'),
              onTap: () => Navigator.pop(c, -1),
            ),
            for (final p in people)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(name: p.name, id: p.id, size: 42),
                title: Text(p.name),
                onTap: () => Navigator.pop(c, p.id),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked == -1) {
    if (!context.mounted) return null;
    return editPerson(context, upi: raw.contains('@') ? raw : null);
  }
  return picked;
}

Future<void> linkTxnToPerson(BuildContext context, Txn txn) async {
  final txns = context.read<TxnState>();
  final messenger = ScaffoldMessenger.of(context);
  final id = await pickPerson(context,
      suggestFor: txn.counterparty,
      title: txn.type == TxnType.income ? 'Who paid you?' : 'Who did you give it to?');
  if (id == null) return;
  await AppDatabase.instance.linkTxn(txn, id);
  await txns.load();
  final hasUpi = (txn.counterparty ?? '').contains('@');
  messenger.showSnackBar(SnackBar(
      content: Text(hasUpi
          ? 'Linked. Future payments to ${prettyParty(txn.counterparty)} will link automatically.'
          : 'Linked to the people ledger.')));
}

void openPeopleEntry(BuildContext context, {int? personId}) {
  Navigator.of(context).push(fadeRoute(LedgerEntryScreen(personId: personId)));
}

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  Future<List<PersonSummary>>? _future;
  int _version = -1;

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));

  Future<void> _add() async {
    final txns = context.read<TxnState>();
    final id = await editPerson(context);
    if (id != null) await txns.load();
  }

  Widget _sum(String label, double v, Color color, bool hide) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(hide ? '₹ ••••' : inr(v, decimals: 0),
            style: AppText.display(size: 22, color: color)),
      ),
    ]);
  }

  Widget _heroBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
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
      _future = AppDatabase.instance.peopleSummaries();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<List<PersonSummary>>(
          future: _future,
          builder: (context, snap) {
            final list = snap.data ?? const <PersonSummary>[];
            double toGet = 0;
            double toPay = 0;
            for (final s in list) {
              if (s.balance > 0) {
                toGet += s.balance;
              } else {
                toPay += -s.balance;
              }
            }
            final soon = DateTime.now().add(const Duration(days: 7));
            final due = list
                .where((s) => s.nextDue != null && s.nextDue!.isBefore(soon))
                .toList()
              ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                Row(children: [
                  Expanded(
                      child: Text('People',
                          style: AppText.display(size: 26, color: fin.text))),
                  IconButton(
                      onPressed: _add,
                      icon: const Icon(Icons.person_add_alt_1_rounded)),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: fin.hero, borderRadius: BorderRadius.circular(26)),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _sum("You'll get", toGet, AppColors.income, hide)),
                      Container(width: 1, height: 44, color: Colors.white24),
                      Expanded(child: _sum('You owe', toPay, AppColors.pink, hide)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _heroBtn(Icons.swap_vert_rounded, 'Gave / Got',
                              () => openPeopleEntry(context))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _heroBtn(Icons.call_split_rounded, 'Split a bill',
                              () => _open(const SplitBillScreen()))),
                    ]),
                  ]),
                ),
                if (due.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Due soon',
                      style: TextStyle(
                          color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final s in due.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: fin.card,
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          leading: Avatar(name: s.person.name, id: s.person.id, size: 38),
                          title: Text(s.person.name),
                          subtitle: Text(hide ? '' : '${inr(s.balance, decimals: 0)} pending'),
                          trailing: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (s.nextDue!.isBefore(DateTime.now())
                                      ? AppColors.expense
                                      : kAmber)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s.nextDue!.isBefore(DateTime.now())
                                  ? 'Overdue'
                                  : 'Due ${DateFormat('d MMM').format(s.nextDue!)}',
                              style: TextStyle(
                                  color: s.nextDue!.isBefore(DateTime.now())
                                      ? AppColors.expense
                                      : kAmber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ),
                          onTap: () => _open(PersonDetailScreen(personId: s.person.id)),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(children: [
                      const Icon(Icons.people_alt_rounded,
                          size: 56, color: AppColors.lavender),
                      const SizedBox(height: 14),
                      Text('No one here yet',
                          style: AppText.display(size: 20, color: fin.text)),
                      const SizedBox(height: 8),
                      Text(
                          'Add the people you lend to or borrow from. Link UPI payments from the review inbox.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: fin.subtext, height: 1.5)),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Add person')),
                    ]),
                  )
                else
                  Material(
                    color: fin.card,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      for (final s in list)
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Avatar(name: s.person.name, id: s.person.id),
                          title: Text(s.person.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(s.lastAt == null
                              ? 'No entries yet'
                              : 'Last entry: ${dayLabel(s.lastAt!)}'),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                s.balance.abs() < 0.01
                                    ? 'Settled'
                                    : (s.balance > 0 ? 'owes you' : 'you owe'),
                                style: TextStyle(color: fin.subtext, fontSize: 11.5),
                              ),
                              Text(
                                hide ? '••••' : inr(s.balance.abs(), decimals: 0),
                                style: TextStyle(
                                    color: s.balance > 0.009
                                        ? AppColors.income
                                        : (s.balance < -0.009
                                            ? AppColors.expense
                                            : fin.subtext),
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          onTap: () => _open(PersonDetailScreen(personId: s.person.id)),
                        ),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
