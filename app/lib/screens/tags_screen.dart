import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/tags_repo.dart';
import '../native.dart';
import '../security/lock.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_screen.dart';
import 'categories_screen.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  Future<(List<Tag>, Map<int, (double, int)>)>? _future;
  int _version = -1;

  Future<(List<Tag>, Map<int, (double, int)>)> _load() async {
    final db = AppDatabase.instance;
    return (await db.tags(), await db.tagSummaries());
  }

  void _open(Widget p) => Navigator.of(context).push(fadeRoute(p));

  void _new() {
    final fin = context.fin;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.luggage_rounded, color: Color(0xFFD78FD3)),
              title: const Text('New trip'),
              subtitle: const Text('Dates, budget and auto-tagging'),
              onTap: () {
                Navigator.pop(c);
                _open(const TagEditorScreen(trip: true));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sell_rounded, color: AppColors.lavender),
              title: const Text('New tag'),
              subtitle: const Text('For example: Diwali, Office, Wedding'),
              onTap: () {
                Navigator.pop(c);
                _open(const TagEditorScreen());
              },
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
    return Scaffold(
      appBar: AppBar(title: const Text('Trips & tags')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: FutureBuilder<(List<Tag>, Map<int, (double, int)>)>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          final trips = d.$1.where((t) => t.isTrip).toList();
          final tags = d.$1.where((t) => !t.isTrip).toList();
          if (d.$1.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.luggage_rounded, size: 56, color: Color(0xFFD78FD3)),
                  const SizedBox(height: 14),
                  Text('No trips or tags yet', style: AppText.display(size: 20, color: fin.text)),
                  const SizedBox(height: 8),
                  Text(
                    'Create a trip like "Goa 2026" and every transaction during those dates is grouped automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fin.subtext, height: 1.5),
                  ),
                ]),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              if (trips.isNotEmpty) ...[
                Text('Trips',
                    style: TextStyle(color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (final t in trips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TripCard(
                      tag: t,
                      spent: d.$2[t.id]?.$1 ?? 0,
                      count: d.$2[t.id]?.$2 ?? 0,
                      hide: hide,
                      onTap: () => _open(TagDetailScreen(tagId: t.id)),
                    ),
                  ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Tags',
                    style: TextStyle(color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Material(
                  color: fin.card,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final t in tags)
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: Color(t.color).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.sell_rounded, color: Color(t.color), size: 20),
                        ),
                        title: Text(t.name),
                        subtitle: Text('${d.$2[t.id]?.$2 ?? 0} transactions'),
                        trailing: Text(inr(d.$2[t.id]?.$1 ?? 0, hide: hide, decimals: 0),
                            style: TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
                        onTap: () => _open(TagDetailScreen(tagId: t.id)),
                      ),
                  ]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Tag tag;
  final double spent;
  final int count;
  final bool hide;
  final VoidCallback onTap;

  const _TripCard(
      {required this.tag,
      required this.spent,
      required this.count,
      required this.hide,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final pct = (tag.budget != null && tag.budget! > 0) ? spent / tag.budget! : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(tag.color), Color(tag.color).withValues(alpha: 0.65)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: OrbitPainter(0.25,
                    line: Colors.white.withValues(alpha: 0.18),
                    showDots: false,
                    center: const Alignment(0.8, -0.3)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.luggage_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tag.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                    ),
                    if (tag.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Active',
                            style: TextStyle(
                                color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    tag.start != null && tag.end != null
                        ? '${df.format(tag.start!)} – ${df.format(tag.end!)} · $count transactions'
                        : '$count transactions',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(inr(spent, hide: hide, decimals: 0),
                      style: AppText.display(size: 26, color: Colors.white)),
                  if (pct != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0).toDouble(),
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        color: pct >= 1 ? AppColors.expense : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hide ? '' : '${(pct * 100).round()}% of ${inr(tag.budget!, decimals: 0)} budget',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class TagEditorScreen extends StatefulWidget {
  final Tag? tag;
  final bool trip;
  const TagEditorScreen({super.key, this.tag, this.trip = false});

  @override
  State<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends State<TagEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _budget;
  late bool _trip;
  late int _color;
  DateTime? _start;
  DateTime? _end;
  bool _auto = true;

  @override
  void initState() {
    super.initState();
    final t = widget.tag;
    _trip = t?.isTrip ?? widget.trip;
    _name = TextEditingController(text: t?.name ?? '');
    _budget = TextEditingController(
        text: t?.budget == null ? '' : t!.budget!.toStringAsFixed(0));
    _color = t?.color ?? (_trip ? 0xFFD78FD3 : kPalette[2]);
    final today = DateTime.now();
    _start = t?.start ?? (_trip ? DateTime(today.year, today.month, today.day) : null);
    _end = t?.end ?? (_trip ? DateTime(today.year, today.month, today.day).add(const Duration(days: 3)) : null);
    _auto = t?.autoTag ?? _trip;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_name.text.trim().isEmpty) return false;
    if (_trip && (_start == null || _end == null || _end!.isBefore(_start!))) return false;
    return true;
  }

  Future<void> _pickDate(bool start) async {
    final init = (start ? _start : _end) ?? DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: init,
        firstDate: DateTime(2015),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        if (_end != null && _end!.isBefore(d)) _end = d;
      } else {
        _end = d;
      }
    });
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final db = AppDatabase.instance;
    if (!_valid) {
      messenger.showSnackBar(SnackBar(
          content: Text(_name.text.trim().isEmpty
              ? 'Enter a name'
              : 'Check the trip dates')));
      return;
    }
    final budget = double.tryParse(
        _budget.text.replaceAll(',', '').replaceAll('₹', '').trim());
    final t = widget.tag;
    if (t == null) {
      await db.insertTag(
          name: _name.text.trim(),
          color: _color,
          isTrip: _trip,
          start: _trip ? _start : null,
          end: _trip ? _end : null,
          budget: _trip ? budget : null,
          autoTag: _trip && _auto);
    } else {
      await db.updateTag(t.id,
          name: _name.text.trim(),
          color: _color,
          start: _trip ? _start : null,
          end: _trip ? _end : null,
          budget: _trip ? budget : null,
          autoTag: _trip && _auto,
          archived: t.archived);
    }
    await db.autoTagTrips();
    await txns.load();
    messenger.showSnackBar(SnackBar(
        content: Text(t == null
            ? (_trip ? 'Trip created' : 'Tag created')
            : 'Saved')));
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${widget.tag!.name}?'),
        content: const Text('Transactions stay, only this tag is removed from them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.deleteTag(widget.tag!.id);
    await txns.load();
    nav.pop();
  }

  Widget _dateTile(FinColors fin, String label, DateTime? d, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: fin.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: fin.subtext, fontSize: 12)),
              const SizedBox(height: 4),
              Text(d == null ? 'Choose' : DateFormat('d MMM yyyy').format(d),
                  style: TextStyle(color: fin.text, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tag == null ? (_trip ? 'New trip' : 'New tag') : 'Edit'),
        actions: [
          if (widget.tag != null)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          TextField(
            controller: _name,
            autofocus: widget.tag == null,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                hintText: _trip ? 'e.g. Goa 2026' : 'e.g. Diwali',
                prefixIcon: Icon(_trip ? Icons.luggage_rounded : Icons.sell_rounded)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          Text('Colour', style: TextStyle(color: fin.subtext, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in [0xFFD78FD3, ...kPalette])
              GestureDetector(
                onTap: () => setState(() => _color = p),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color(p),
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == p ? primary : Colors.transparent, width: 3),
                  ),
                ),
              ),
          ]),
          if (_trip) ...[
            const SizedBox(height: 20),
            Row(children: [
              _dateTile(fin, 'Starts', _start, () => _pickDate(true)),
              const SizedBox(width: 10),
              _dateTile(fin, 'Ends', _end, () => _pickDate(false)),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Trip budget (optional)'),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _auto,
              onChanged: (v) => setState(() => _auto = v),
              title: const Text('Auto-tag transactions'),
              subtitle: const Text('Everything between these dates joins this trip'),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save', icon: Icons.check_rounded, onPressed: _save),
        ],
      ),
    );
  }
}

class TagDetailScreen extends StatefulWidget {
  final int tagId;
  const TagDetailScreen({super.key, required this.tagId});

  @override
  State<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends State<TagDetailScreen> {
  Future<(Tag?, List<Txn>)>? _future;
  int _version = -1;

  Future<(Tag?, List<Txn>)> _load() async {
    final db = AppDatabase.instance;
    return (await db.tagById(widget.tagId), await db.txnsForTag(widget.tagId));
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
    return FutureBuilder<(Tag?, List<Txn>)>(
      future: _future,
      builder: (context, snap) {
        final tag = snap.data?.$1;
        final list = snap.data?.$2 ?? const <Txn>[];
        if (tag == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final spending = list.where((t) => t.type == TxnType.expense && t.personId == null).toList();
        final spent = spending.fold<double>(0, (a, t) => a + t.amount);
        final byCat = <int?, double>{};
        for (final t in spending) {
          byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
        }
        final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final pct = (tag.budget != null && tag.budget! > 0) ? spent / tag.budget! : null;
        final df = DateFormat('d MMM yyyy');

        String summary() {
          final b = StringBuffer('${tag.name}\n');
          if (tag.start != null && tag.end != null) {
            b.writeln('${df.format(tag.start!)} – ${df.format(tag.end!)}');
          }
          b.writeln('Total spent: ${inr(spent, decimals: 0)}');
          for (final e in cats) {
            b.writeln('• ${txns.category(e.key)?.name ?? 'Other'}: ${inr(e.value, decimals: 0)}');
          }
          b.write('— via FinUp');
          return b.toString();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tag.name),
            actions: [
              IconButton(
                onPressed: () => AppLockGate.suspendWhile(() => Native.shareText(summary())),
                icon: const Icon(Icons.share_rounded),
              ),
              IconButton(
                onPressed: () => Navigator.of(context)
                    .push(fadeRoute(TagEditorScreen(tag: tag))),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(tag.color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Color(tag.color).withValues(alpha: 0.5)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tag.isTrip ? 'Trip spending' : 'Total spent',
                      style: TextStyle(color: fin.subtext)),
                  const SizedBox(height: 4),
                  Text(inr(spent, hide: hide, decimals: 0),
                      style: AppText.display(size: 30, color: fin.text)),
                  if (tag.start != null && tag.end != null)
                    Text('${df.format(tag.start!)} – ${df.format(tag.end!)}',
                        style: TextStyle(color: fin.subtext)),
                  Text('${list.length} transactions', style: TextStyle(color: fin.subtext)),
                  if (pct != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0).toDouble(),
                        minHeight: 10,
                        backgroundColor: fin.divider,
                        color: statusColor(pct),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hide ? '' : '${(pct * 100).round()}% of ${inr(tag.budget!, decimals: 0)} budget',
                      style: TextStyle(color: statusColor(pct), fontWeight: FontWeight.w600),
                    ),
                  ],
                ]),
              ),
              if (cats.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('By category',
                    style: TextStyle(color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final e in cats)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(txns.category(e.key)?.icon ?? Icons.help_outline_rounded,
                          color: txns.category(e.key)?.colorValue ?? fin.subtext, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(txns.category(e.key)?.name ?? 'Needs review',
                              style: TextStyle(color: fin.text))),
                      Text(inr(e.value, hide: hide, decimals: 0),
                          style: TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ],
              const SizedBox(height: 18),
              Text('Transactions',
                  style: TextStyle(color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Text('No transactions yet.', style: TextStyle(color: fin.subtext)),
              for (final t in list)
                TxnTile(
                  txn: t,
                  hide: hide,
                  showDate: true,
                  onTap: () => Navigator.of(context).push(fadeRoute(AddTxnScreen(editing: t))),
                ),
            ],
          ),
        );
      },
    );
  }
}
