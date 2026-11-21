import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/people_repo.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_txn_screen.dart';
import 'people_screen.dart';

Widget _fieldTile(FinColors fin, IconData icon, Color color, String label,
    String value, VoidCallback? onTap, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: fin.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: fin.subtext, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: fin.text, fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: fin.subtext),
          ]),
        ),
      ),
    ),
  );
}

class LedgerEntryScreen extends StatefulWidget {
  final int? personId;
  final String type;
  final double? amount;
  final String? note;
  final LedgerEntry? editing;

  const LedgerEntryScreen(
      {super.key,
      this.personId,
      this.type = 'gave',
      this.amount,
      this.note,
      this.editing});

  @override
  State<LedgerEntryScreen> createState() => _LedgerEntryScreenState();
}

class _LedgerEntryScreenState extends State<LedgerEntryScreen> {
  int? _personId;
  String? _personName;
  late String _type;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _when;
  DateTime? _due;
  int? _accountId;
  bool _locked = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _personId = e?.personId ?? widget.personId;
    _type = e?.type ?? widget.type;
    _when = e?.occurredAt ?? DateTime.now();
    _due = e?.dueAt;
    final amt = e?.amount ?? widget.amount;
    if (amt != null) {
      _amount.text = amt == amt.roundToDouble()
          ? amt.toStringAsFixed(0)
          : amt.toStringAsFixed(2);
    }
    _note.text = e?.note ?? widget.note ?? '';
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    final db = AppDatabase.instance;
    final pid = _personId;
    if (pid != null) {
      final p = await db.person(pid);
      if (mounted) setState(() => _personName = p?.name);
    }
    final tid = widget.editing?.txnId;
    if (tid != null) {
      final t = await db.txnById(tid);
      if (t != null && mounted) {
        setState(() {
          _accountId = t.accountId;
          _locked = t.smsBody != null;
        });
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
  bool get _valid => !_saving && _personId != null && _value > 0;

  String _accName(int? id) {
    if (id == null) return 'Not linked to an account';
    for (final a in context.read<AccountsState>().accounts) {
      if (a.id == id) return a.name;
    }
    return 'Account';
  }

  Future<void> _pickPerson() async {
    final id = await pickPerson(context);
    if (id == null) return;
    final p = await AppDatabase.instance.person(id);
    if (mounted) {
      setState(() {
        _personId = id;
        _personName = p?.name;
      });
    }
  }

  Future<void> _pickAccount() async {
    final fin = context.fin;
    final accounts = context.read<AccountsState>().accounts;
    final res = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block_rounded),
              title: const Text('Not linked to an account'),
              subtitle: const Text('Only the ledger is updated'),
              onTap: () => Navigator.pop(c, -1),
            ),
            for (final a in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradientAt(a.colorIndex),
                      shape: BoxShape.circle),
                  child: Icon(a.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text(inr(a.balance)),
                onTap: () => Navigator.pop(c, a.id),
              ),
          ],
        ),
      ),
    );
    if (res == null) return;
    setState(() => _accountId = res == -1 ? null : res);
  }

  Future<void> _pickDate({required bool due}) async {
    final init = due ? (_due ?? DateTime.now().add(const Duration(days: 7))) : _when;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d == null) return;
    setState(() {
      if (due) {
        _due = d;
      } else {
        _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute);
      }
    });
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final db = AppDatabase.instance;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final due = _type == 'gave' ? _due : null;
    final e = widget.editing;
    if (e != null) {
      await db.updateEntry(e,
          type: _type,
          amount: _value,
          note: note,
          dueAt: due,
          when: _when,
          accountId: _accountId,
          personName: _personName);
    } else {
      await db.addEntry(
          personId: _personId!,
          type: _type,
          amount: _value,
          note: note,
          dueAt: due,
          when: _when,
          accountId: _accountId,
          personName: _personName);
    }
    await accounts.load();
    await txns.load();
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('Any linked account balance is adjusted back.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.deleteEntry(widget.editing!);
    await accounts.load();
    await txns.load();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final gave = _type == 'gave';
    final color = gave ? AppColors.expense : AppColors.income;

    Widget typeItem(String v, String label, Color c) {
      final sel = _type == v;
      return Expanded(
        child: GestureDetector(
          onTap: _locked ? null : () => setState(() => _type = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: sel ? c : Colors.transparent,
                borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : fin.subtext,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? 'Lend or borrow' : 'Edit entry'),
        actions: [
          if (widget.editing != null)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: fin.card, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              typeItem('gave', 'You gave', AppColors.expense),
              typeItem('took', 'You got', AppColors.income),
            ]),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amount,
            enabled: !_locked,
            autofocus: widget.editing == null && widget.amount == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.display(size: 30, color: color),
            decoration: const InputDecoration(prefixText: '₹ ', hintText: '0'),
            onChanged: (_) => setState(() {}),
          ),
          if (_locked)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Amount comes from a bank SMS and cannot be changed.',
                  style: TextStyle(color: fin.subtext, fontSize: 12)),
            ),
          const SizedBox(height: 14),
          _fieldTile(fin, Icons.person_rounded, AppColors.lavender, 'Person',
              _personName ?? 'Choose person', _locked ? null : _pickPerson),
          _fieldTile(fin, Icons.calendar_month_rounded, AppColors.income, 'Date',
              DateFormat('EEE, d MMM yyyy').format(_when),
              _locked ? null : () => _pickDate(due: false)),
          if (gave)
            _fieldTile(
              fin,
              Icons.event_available_rounded,
              const Color(0xFFF6A23A),
              'Expect it back by (optional)',
              _due == null ? 'No due date' : DateFormat('d MMM yyyy').format(_due!),
              () => _pickDate(due: true),
              trailing: _due == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _due = null),
                      icon: const Icon(Icons.close_rounded)),
            ),
          _fieldTile(
              fin,
              Icons.account_balance_wallet_rounded,
              AppColors.pink,
              gave ? 'Paid from account' : 'Received into account',
              _accName(_accountId),
              _locked ? null : _pickAccount),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                hintText: 'Note (optional)', prefixIcon: Icon(Icons.edit_note_rounded)),
          ),
          const SizedBox(height: 10),
          Text('Lending and borrowing is not counted as spending or income.',
              style: TextStyle(color: fin.subtext, fontSize: 12)),
          const SizedBox(height: 24),
          PrimaryButton(
              label: widget.editing == null ? 'Save entry' : 'Update entry',
              icon: Icons.check_rounded,
              onPressed: _valid ? _save : null),
        ],
      ),
    );
  }
}

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  int? _accountId;
  int? _categoryId;
  bool _includeMe = true;
  final Set<int> _selected = {};
  List<Person> _people = [];
  final DateTime _when = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final accounts = context.read<AccountsState>().accounts;
    if (accounts.isNotEmpty) _accountId = accounts.first.id;
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final list = await AppDatabase.instance.people();
    if (mounted) setState(() => _people = list);
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  double get _total => double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
  int get _parts => _selected.length + (_includeMe ? 1 : 0);
  double get _share => _parts == 0 ? 0 : (_total / _parts * 100).floorToDouble() / 100;
  bool get _valid => !_saving && _total > 0 && _selected.isNotEmpty && _accountId != null;

  String _accName(int? id) {
    for (final a in context.read<AccountsState>().accounts) {
      if (a.id == id) return a.name;
    }
    return 'Choose account';
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final db = AppDatabase.instance;
    final share = _share;
    final rem = double.parse((_total - share * _parts).toStringAsFixed(2));
    final desc = _desc.text.trim().isEmpty ? 'Split bill' : _desc.text.trim();
    var first = true;
    if (_includeMe) {
      await db.addTxn(Txn(
        accountId: _accountId,
        type: TxnType.expense,
        amount: share + rem,
        categoryId: _categoryId,
        counterparty: desc,
        note: 'My share of ${inr(_total)}',
        status: _categoryId == null ? 'review' : 'done',
        occurredAt: _when,
      ));
      first = false;
    }
    for (final id in _selected) {
      Person? p;
      for (final x in _people) {
        if (x.id == id) p = x;
      }
      final amt = first ? share + rem : share;
      first = false;
      await db.addEntry(
          personId: id,
          type: 'gave',
          amount: amt,
          note: 'Split: $desc',
          when: _when,
          accountId: _accountId,
          personName: p?.name);
    }
    await accounts.load();
    await txns.load();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final cat = context.watch<TxnState>().category(_categoryId);
    return Scaffold(
      appBar: AppBar(title: const Text('Split a bill')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.display(size: 30, color: AppColors.expense),
            decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Total bill'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'What was it? e.g. Dinner at Barbeque Nation',
                prefixIcon: Icon(Icons.receipt_rounded)),
          ),
          const SizedBox(height: 12),
          _fieldTile(fin, Icons.account_balance_wallet_rounded, AppColors.pink,
              'You paid from', _accName(_accountId), () async {
            final id = await pickAccount(context);
            if (id != null) setState(() => _accountId = id);
          }),
          _fieldTile(fin, cat?.icon ?? Icons.category_rounded,
              cat?.colorValue ?? AppColors.lavender, 'Category for your share',
              cat?.name ?? 'Choose category', () async {
            final id = await pickCategory(context, 'expense');
            if (id != null) setState(() => _categoryId = id);
          }),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeMe,
            onChanged: (v) => setState(() => _includeMe = v),
            title: const Text('Include my share'),
          ),
          const SizedBox(height: 4),
          Text('Split with',
              style: TextStyle(color: fin.subtext, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _people)
                FilterChip(
                  label: Text(p.name),
                  selected: _selected.contains(p.id),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selected.add(p.id);
                    } else {
                      _selected.remove(p.id);
                    }
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add person'),
                onPressed: () async {
                  final id = await editPerson(context);
                  if (id != null) {
                    await _loadPeople();
                    setState(() => _selected.add(id));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_total > 0 && _parts > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.lavender.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Each share: ${inr(_share)}',
                      style: TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      '${_selected.length} ${_selected.length == 1 ? 'person owes' : 'people owe'} you ${inr(_share * _selected.length)}',
                      style: TextStyle(color: fin.subtext)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          PrimaryButton(
              label: 'Save split', icon: Icons.check_rounded, onPressed: _valid ? _save : null),
        ],
      ),
    );
  }
}
