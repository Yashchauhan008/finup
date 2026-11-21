import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AccountEditor extends StatefulWidget {
  final Account? account;

  const AccountEditor({super.key, this.account});

  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  late final TextEditingController _name;
  late final TextEditingController _last4;
  late final TextEditingController _balance;
  late AccountType _type;
  late int _color;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _last4 = TextEditingController(text: a?.last4 ?? '');
    _balance = TextEditingController(
        text: a == null ? '' : a.balance.toStringAsFixed(2));
    _type = a?.type ?? AccountType.bank;
    _color = a?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _last4.dispose();
    _balance.dispose();
    super.dispose();
  }

  double get _bal =>
      double.tryParse(_balance.text.replaceAll(',', '').trim()) ?? 0;

  bool get _needsDigits =>
      _type == AccountType.bank || _type == AccountType.card;

  Account _build() => Account(
        id: widget.account?.id,
        name: _name.text.trim().isEmpty ? 'Account name' : _name.text.trim(),
        type: _type,
        bank: widget.account?.bank,
        last4: _needsDigits ? _last4.text.trim() : null,
        balance: _bal,
        colorIndex: _color,
        balanceUpdatedAt: DateTime.now(),
      );

  Future<void> _save() async {
    final nav = Navigator.of(context);
    await context.read<AccountsState>().save(_build());
    nav.pop();
  }

  Future<void> _delete() async {
    final state = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'If this account has transactions it will be archived instead, so your history stays correct.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.remove(widget.account!.id!);
      nav.pop();
    }
  }

  Widget _label(String text, FinColors fin) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
        child: Text(text,
            style: TextStyle(
                color: fin.subtext,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit account' : 'New account'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          SizedBox(height: 190, child: AccountCard(account: _build())),
          const SizedBox(height: 8),
          _label('Type', fin),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AccountType.values
                .map((t) => ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(t.icon, size: 18),
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ))
                .toList(),
          ),
          _label('Name', fin),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'e.g. Bank of Baroda'),
            onChanged: (_) => setState(() {}),
          ),
          if (_needsDigits) ...[
            _label('Last 4 digits (used to match bank SMS)', fin),
            TextField(
              controller: _last4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(hintText: '2261', counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
          ],
          _label(
            _type == AccountType.card
                ? 'Outstanding (enter as minus, e.g. -2500)'
                : 'Current balance',
            fin,
          ),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration:
                const InputDecoration(hintText: '0.00', prefixText: '₹ '),
            onChanged: (_) => setState(() {}),
          ),
          _label('Card colour', fin),
          Row(
            children: List.generate(
              AppColors.cardGradients.length,
              (i) => GestureDetector(
                onTap: () => setState(() => _color = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientAt(i),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == i ? primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Save account',
            icon: Icons.check_rounded,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
