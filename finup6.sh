#!/usr/bin/env bash
set -euo pipefail
cd app
mkdir -p lib/data lib/screens

############################ lib/data/person_txn.dart ############################
cat > lib/data/person_txn.dart <<'__END__'
import 'db.dart';
import 'people_repo.dart';

extension PersonTxn on AppDatabase {
  /// Re-links an existing transaction to a person (replaces old ledger rows for it).
  Future<void> relinkTxn(Txn t, int personId) async {
    await db.delete('ledger', where: 'txn_id = ?', whereArgs: [t.id]);
    await this.linkTxn(t, personId);
  }

  /// Removes ledger rows that belonged to a transaction (when it is no longer a person transfer).
  Future<void> unlinkTxnLedger(int txnId) async {
    await db.delete('ledger', where: 'txn_id = ?', whereArgs: [txnId]);
    await db.update('transactions', {'person_id': null},
        where: 'id = ?', whereArgs: [txnId]);
  }
}
__END__

############################ lib/screens/add_txn_screen.dart (Transfer now supports people) ############################
cat > lib/screens/add_txn_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/people_repo.dart';
import '../data/person_txn.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'categories_screen.dart';
import 'people_screen.dart';

Future<int?> pickAccount(BuildContext context,
    {int? exclude, String title = 'Choose account'}) {
  final fin = context.fin;
  final accounts =
      context.read<AccountsState>().accounts.where((a) => a.id != exclude).toList();
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: fin.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(title, style: AppText.display(size: 18, color: fin.text)),
            const SizedBox(height: 12),
            for (final a in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradientAt(a.colorIndex), shape: BoxShape.circle),
                  child: Icon(a.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text(inr(a.balance)),
                onTap: () => Navigator.pop(c, a.id),
              ),
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No other accounts yet. Add one from Home.',
                    style: TextStyle(color: fin.subtext)),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<int?> pickCategory(BuildContext context, String kind) {
  final fin = context.fin;
  final cats = context.read<TxnState>().byKind(kind);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: fin.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Row(children: [
              Expanded(
                  child: Text('Choose category',
                      style: AppText.display(size: 18, color: fin.text))),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.of(context).push(fadeRoute(const CategoriesScreen()));
                },
                child: const Text('Manage'),
              ),
            ]),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.78,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final cat in cats)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(c, cat.id),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cat.colorValue.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(cat.icon, color: cat.colorValue),
                        ),
                        const SizedBox(height: 6),
                        Text(cat.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: fin.text,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class AddTxnScreen extends StatefulWidget {
  final TxnType type;
  final Txn? editing;

  const AddTxnScreen({super.key, this.type = TxnType.expense, this.editing});

  @override
  State<AddTxnScreen> createState() => _AddTxnScreenState();
}

class _AddTxnScreenState extends State<AddTxnScreen> {
  late TxnType _type;
  String _mode = 'accounts'; // accounts | gave | got  (only for Transfer)
  String _amount = '0';
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  int? _personId;
  String? _personName;
  late DateTime _when;
  final _note = TextEditingController();
  final _payee = TextEditingController();
  bool _remember = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _type = e?.type ?? widget.type;
    _when = e?.occurredAt ?? DateTime.now();
    if (e != null) {
      _amount = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toStringAsFixed(2);
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _categoryId = e.categoryId;
      _note.text = e.note ?? '';
      _payee.text = e.counterparty ?? '';
      if (e.personId != null && e.type != TxnType.transfer) {
        _mode = e.type == TxnType.income ? 'got' : 'gave';
        _type = TxnType.transfer;
        _personId = e.personId;
        _loadPerson(e.personId!);
      }
    } else {
      final accounts = context.read<AccountsState>().accounts;
      Account? bank;
      Account? cash;
      for (final a in accounts) {
        if (bank == null && a.type != AccountType.cash) bank = a;
        if (cash == null && a.type == AccountType.cash) cash = a;
      }
      _accountId = (bank ?? cash)?.id;
      if (_type == TxnType.transfer) _toAccountId = cash?.id;
    }
  }

  Future<void> _loadPerson(int id) async {
    final p = await AppDatabase.instance.person(id);
    if (mounted) setState(() => _personName = p?.name);
  }

  @override
  void dispose() {
    _note.dispose();
    _payee.dispose();
    super.dispose();
  }

  bool get _personMode => _type == TxnType.transfer && _mode != 'accounts';

  double get _value => double.tryParse(_amount) ?? 0;

  bool get _valid {
    if (_saving || _value <= 0 || _accountId == null) return false;
    if (_type != TxnType.transfer) return true;
    if (_mode == 'accounts') return _toAccountId != null && _toAccountId != _accountId;
    return _personId != null;
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '<') {
        _amount = _amount.length <= 1 ? '0' : _amount.substring(0, _amount.length - 1);
        return;
      }
      if (k == '.') {
        if (!_amount.contains('.')) _amount = '$_amount.';
        return;
      }
      if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
      if (_amount.replaceAll('.', '').length >= 9) return;
      _amount = _amount == '0' ? k : '$_amount$k';
    });
  }

  String _accName(int? id) {
    for (final a in context.read<AccountsState>().accounts) {
      if (a.id == id) return a.name;
    }
    return 'Choose';
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t?.hour ?? _when.hour, t?.minute ?? _when.minute);
    });
  }

  Future<void> _pickPerson() async {
    final id = await pickPerson(context,
        suggestFor: _payee.text.trim().isEmpty ? null : _payee.text.trim(),
        title: _mode == 'gave' ? 'Who did you give it to?' : 'Who gave you the money?');
    if (id == null) return;
    final p = await AppDatabase.instance.person(id);
    if (mounted) {
      setState(() {
        _personId = id;
        _personName = p?.name;
      });
    }
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final db = AppDatabase.instance;
    setState(() => _saving = true);
    final e = widget.editing;
    final payee = _payee.text.trim();
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();

    if (_personMode) {
      final gave = _mode == 'gave';
      if (e == null) {
        await db.addEntry(
          personId: _personId!,
          type: gave ? 'gave' : 'took',
          amount: _value,
          note: note,
          when: _when,
          accountId: _accountId,
          personName: _personName,
        );
      } else {
        final t = Txn(
          id: e.id,
          accountId: _accountId,
          type: gave ? TxnType.expense : TxnType.income,
          amount: _value,
          personId: _personId,
          counterparty: payee.isEmpty ? _personName : payee,
          note: note,
          ref: e.ref,
          smsBody: e.smsBody,
          status: 'done',
          occurredAt: _when,
        );
        await db.editTxn(e, t);
        await db.relinkTxn(t, _personId!);
      }
      await accounts.load();
      await txns.load();
      nav.pop();
      return;
    }

    final isTransfer = _type == TxnType.transfer;
    final t = Txn(
      id: e?.id,
      accountId: _accountId,
      toAccountId: isTransfer ? _toAccountId : null,
      type: _type,
      amount: _value,
      categoryId: isTransfer ? null : _categoryId,
      personId: null,
      counterparty: payee.isEmpty ? null : payee,
      note: note,
      ref: e?.ref,
      smsBody: e?.smsBody,
      status: (isTransfer || _categoryId != null) ? 'done' : 'review',
      occurredAt: _when,
    );
    await txns.save(accounts, t, old: e);
    if (e != null && e.personId != null) {
      await db.unlinkTxnLedger(e.id!);
      await txns.load();
    }
    if (_remember && !isTransfer && _categoryId != null && payee.isNotEmpty && e?.smsBody != null) {
      await txns.rememberRule(payee, _categoryId!);
    }
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('Account balances will be adjusted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok == true) {
      final e = widget.editing!;
      if (e.personId != null) await AppDatabase.instance.unlinkTxnLedger(e.id!);
      await txns.delete(accounts, e);
      nav.pop();
    }
  }

  Widget _typeSwitch(FinColors fin) {
    Widget item(TxnType t, String label) {
      final sel = _type == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _type = t;
            _categoryId = null;
            if (t == TxnType.transfer && _toAccountId == null) {
              for (final a in context.read<AccountsState>().accounts) {
                if (a.type == AccountType.cash && a.id != _accountId) {
                  _toAccountId = a.id;
                  break;
                }
              }
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: sel ? typeColor(t) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : fin.subtext, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: fin.card, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        item(TxnType.expense, 'Expense'),
        item(TxnType.income, 'Income'),
        item(TxnType.transfer, 'Transfer'),
      ]),
    );
  }

  Widget _modeSwitch(FinColors fin) {
    Widget item(String v, IconData icon, String label, Color color) {
      final sel = _mode == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mode = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: sel ? color.withValues(alpha: 0.16) : fin.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? color : fin.divider, width: sel ? 1.8 : 1),
            ),
            child: Column(children: [
              Icon(icon, color: sel ? color : fin.subtext, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: sel ? fin.text : fin.subtext,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.25)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      item('accounts', Icons.swap_horiz_rounded, 'Between\naccounts', AppColors.lavender),
      item('gave', Icons.north_east_rounded, 'Gave to\na person', AppColors.expense),
      item('got', Icons.south_west_rounded, 'Got from\na person', AppColors.income),
    ]);
  }

  Widget _field(FinColors fin, IconData icon, Color color, String label, String value,
      VoidCallback onTap) {
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
                  borderRadius: BorderRadius.circular(12),
                ),
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
              Icon(Icons.chevron_right_rounded, color: fin.subtext),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _keypad(FinColors fin) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '<'],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: fin.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        for (final r in rows)
          Row(children: [
            for (final k in r)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _key(k),
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: k == '<'
                          ? Icon(Icons.backspace_outlined, color: fin.text)
                          : Text(k,
                              style: TextStyle(
                                  color: fin.text, fontSize: 24, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
          ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final e = widget.editing;
    final isTransfer = _type == TxnType.transfer;
    final kind = _type == TxnType.income ? 'income' : 'expense';
    final cat = context.watch<TxnState>().category(_categoryId);
    final color = _personMode
        ? (_mode == 'gave' ? AppColors.expense : AppColors.income)
        : typeColor(_type);

    final accountField = _field(
      fin,
      Icons.account_balance_wallet_rounded,
      AppColors.lavender,
      isTransfer ? (_mode == 'got' ? 'To account' : 'From account') : 'Account',
      _accName(_accountId),
      () async {
        final id = await pickAccount(context);
        if (id != null) setState(() => _accountId = id);
      },
    );
    final personField = _field(
      fin,
      Icons.person_rounded,
      _mode == 'gave' ? AppColors.expense : AppColors.income,
      _mode == 'gave' ? 'To person' : 'From person',
      _personName ?? 'Choose person',
      _pickPerson,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(e == null ? 'New transaction' : 'Edit transaction'),
        actions: [
          if (e != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              _typeSwitch(fin),
              if (isTransfer) ...[
                const SizedBox(height: 12),
                _modeSwitch(fin),
              ],
              const SizedBox(height: 22),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: FittedBox(
                    key: ValueKey('$_amount$_type$_mode'),
                    fit: BoxFit.scaleDown,
                    child: Text('₹$_amount', style: AppText.display(size: 46, color: color)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (!isTransfer) accountField,
              if (isTransfer && _mode == 'accounts') ...[
                accountField,
                _field(
                  fin,
                  Icons.south_rounded,
                  AppColors.pink,
                  'To account',
                  _accName(_toAccountId),
                  () async {
                    final id = await pickAccount(context, exclude: _accountId, title: 'Move money to');
                    if (id != null) setState(() => _toAccountId = id);
                  },
                ),
              ],
              if (isTransfer && _mode == 'gave') ...[accountField, personField],
              if (isTransfer && _mode == 'got') ...[personField, accountField],
              if (!isTransfer)
                _field(
                  fin,
                  cat?.icon ?? Icons.category_rounded,
                  cat?.colorValue ?? AppColors.pink,
                  'Category',
                  cat?.name ?? 'Choose category',
                  () async {
                    final id = await pickCategory(context, kind);
                    if (id != null) setState(() => _categoryId = id);
                  },
                ),
              _field(
                fin,
                Icons.calendar_month_rounded,
                AppColors.income,
                'Date and time',
                DateFormat('EEE, d MMM yyyy · h:mm a').format(_when),
                _pickWhen,
              ),
              if (_personMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                  child: Text(
                    _mode == 'gave'
                        ? 'Lending money or paying someone back. Saved in the People ledger, not counted as spending.'
                        : 'Borrowing money or getting paid back. Saved in the People ledger, not counted as income.',
                    style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.4),
                  ),
                ),
              TextField(
                controller: _payee,
                decoration: InputDecoration(
                  hintText: isTransfer
                      ? 'Label or UPI ID (optional)'
                      : (_type == TxnType.income ? 'Received from (optional)' : 'Paid to (optional)'),
                  prefixIcon: const Icon(Icons.storefront_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  hintText: 'Note (optional)',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              if (e?.smsBody != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.sms_rounded, size: 16, color: AppColors.lavender),
                        SizedBox(width: 6),
                        Text('From bank SMS',
                            style: TextStyle(
                                color: AppColors.lavender,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ]),
                      const SizedBox(height: 6),
                      Text(e!.smsBody!,
                          style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
                if (!isTransfer && _payee.text.trim().isNotEmpty)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? true),
                    title: Text('Always use this category for ${prettyParty(_payee.text)}',
                        style: TextStyle(color: fin.text, fontSize: 14)),
                  ),
              ],
            ],
          ),
        ),
        _keypad(fin),
        Container(
          color: fin.card,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: e == null ? 'Save' : 'Update',
              icon: Icons.check_rounded,
              onPressed: _valid ? _save : null,
            ),
          ),
        ),
      ]),
    );
  }
}
__END__

############################ Activity list: show person transfers clearly ############################
sed -i "s#final color = cat?.colorValue ?? typeColor(txn.type);#final color = txn.personId != null ? const Color(0xFFF4A261) : (cat?.colorValue ?? typeColor(txn.type));#" lib/widgets/txn_tile.dart
sed -i "s#final icon = isTransfer#final icon = txn.personId != null ? Icons.people_alt_rounded : isTransfer#" lib/widgets/txn_tile.dart
sed -i "s#: (cat?.name ?? 'Needs review');#: (txn.personId != null ? (txn.type == TxnType.expense ? 'Gave to a person' : 'Got from a person') : (cat?.name ?? 'Needs review'));#" lib/widgets/txn_tile.dart

if ! grep -q "Gave to a person" lib/widgets/txn_tile.dart; then
  echo "ERROR: Part 6 patch failed in txn_tile.dart"; exit 1
fi

echo "FinUp Part 6 applied."