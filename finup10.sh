#!/usr/bin/env bash
# FinUp Part 10 — Invest: move money from accounts → goals (not expense/income)
set -euo pipefail
cd app

python3 <<'PY'
from pathlib import Path
from typing import Optional

def must(path: str) -> Path:
    p = Path(path)
    if not p.exists():
        raise SystemExit(f'missing {path}')
    return p

def read(path: str) -> str:
    return must(path).read_text()

def write(path: str, text: str):
    must(path).write_text(text)

def replace_once(path: str, old: str, new: str, *, already: Optional[str] = None):
    text = read(path)
    marker = already or new
    if marker in text and old not in text:
        print(f'skip {path} (already applied)')
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}:\n---\n{old[:220]}\n---')
    write(path, text.replace(old, new, 1))
    print(f'patched {path}')

def ensure_contains(path: str, needle: str, label: str):
    if needle not in read(path):
        raise SystemExit(f'ERROR: missing {label} in {path}')

# ===== db.dart: TxnType + goalId =====
replace_once(
    'lib/data/db.dart',
    'enum TxnType { expense, income, transfer }',
    'enum TxnType { expense, income, transfer, invest }',
    already='TxnType { expense, income, transfer, invest }',
)

replace_once(
    'lib/data/db.dart',
    '  final int? toAccountId;\n  final TxnType type;',
    '  final int? toAccountId;\n  final int? goalId;\n  final TxnType type;',
    already='final int? goalId;',
)

replace_once(
    'lib/data/db.dart',
    '    this.toAccountId,\n    required this.type,',
    '    this.toAccountId,\n    this.goalId,\n    required this.type,',
    already='this.goalId,',
)

replace_once(
    'lib/data/db.dart',
    "        'to_account_id': toAccountId,\n        'type': type.name,",
    "        'to_account_id': toAccountId,\n        'goal_id': goalId,\n        'type': type.name,",
    already="'goal_id': goalId,",
)

replace_once(
    'lib/data/db.dart',
    '        toAccountId: m[\'to_account_id\'] as int?,\n        type: TxnType.values.byName(m[\'type\'] as String),',
    '        toAccountId: m[\'to_account_id\'] as int?,\n        goalId: m[\'goal_id\'] as int?,\n        type: TxnType.values.byName(m[\'type\'] as String),',
    already='goalId: m[\'goal_id\'] as int?,',
)

replace_once(
    'lib/data/db.dart',
    '        to_account_id INTEGER,\n        type TEXT NOT NULL,',
    '        to_account_id INTEGER,\n        goal_id INTEGER,\n        type TEXT NOT NULL,',
    already='goal_id INTEGER,',
)

# ===== repo.dart: migrate + apply + helper =====
replace_once(
    'lib/data/repo.dart',
    '''  Future<void> ensureSchema() async {
    final cols = await db.rawQuery('PRAGMA table_info(transactions)');
    final has = cols.any((c) => c['name'] == 'affects_balance');
    if (!has) {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN affects_balance INTEGER NOT NULL DEFAULT 1');
    }
  }''',
    '''  Future<void> ensureSchema() async {
    final cols = await db.rawQuery('PRAGMA table_info(transactions)');
    final names = cols.map((c) => c['name'] as String).toSet();
    if (!names.contains('affects_balance')) {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN affects_balance INTEGER NOT NULL DEFAULT 1');
    }
    if (!names.contains('goal_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN goal_id INTEGER');
    }
  }''',
    already="!names.contains('goal_id')",
)

replace_once(
    'lib/data/repo.dart',
    '''      case TxnType.transfer:
        if (mode == 1) await bump(t.accountId, -a);
        await bump(t.toAccountId, a);
    }
  }''',
    '''      case TxnType.transfer:
        if (mode == 1) await bump(t.accountId, -a);
        await bump(t.toAccountId, a);
      case TxnType.invest:
        // amount > 0: account → goal; amount < 0: goal → account
        if (mode == 1) {
          await bump(t.accountId, -a);
          if (t.goalId != null) {
            await db.rawUpdate(
                'UPDATE goals SET saved = MAX(0, saved + ?) WHERE id = ?',
                [a, t.goalId]);
          }
        }
    }
  }

  /// Move money between an account and a savings goal. Not expense/income.
  Future<int> investInGoal({
    required int accountId,
    required int goalId,
    required double amount,
    required DateTime when,
    String? note,
    bool withdraw = false,
  }) async {
    final v = amount.abs();
    final t = Txn(
      accountId: accountId,
      goalId: goalId,
      type: TxnType.invest,
      amount: withdraw ? -v : v,
      note: note,
      status: 'done',
      occurredAt: when,
    );
    return addTxn(t);
  }''',
    already='investInGoal',
)

# ===== typeColor =====
replace_once(
    'lib/widgets/txn_tile.dart',
    '''Color typeColor(TxnType t) => switch (t) {
      TxnType.expense => AppColors.expense,
      TxnType.income => AppColors.income,
      TxnType.transfer => AppColors.lavender,
    };''',
    '''Color typeColor(TxnType t) => switch (t) {
      TxnType.expense => AppColors.expense,
      TxnType.income => AppColors.income,
      TxnType.transfer => AppColors.lavender,
      TxnType.invest => const Color(0xFF5B8DEF),
    };''',
    already='TxnType.invest =>',
)

# ===== txn_tile: invest display (post-finup6 person patches) =====
replace_once(
    'lib/widgets/txn_tile.dart',
    '    final isTransfer = txn.type == TxnType.transfer;\n'
    '    final color = txn.personId != null ? const Color(0xFFF4A261) : (cat?.colorValue ?? typeColor(txn.type));\n'
    '    final icon = txn.personId != null ? Icons.people_alt_rounded : isTransfer\n'
    '        ? Icons.swap_horiz_rounded\n'
    '        : (cat?.icon ??\n'
    '            (txn.type == TxnType.income\n'
    '                ? Icons.south_west_rounded\n'
    '                : Icons.north_east_rounded));\n'
    '    final party = prettyParty(txn.counterparty);\n'
    '    final title = isTransfer\n'
    "        ? '${accName(txn.accountId)} → ${accName(txn.toAccountId)}'\n"
    '        : (party.isNotEmpty\n'
    '            ? party\n'
    '            : (cat?.name ??\n'
    "                (txn.type == TxnType.income ? 'Income' : 'Expense')));\n"
    "    final time = DateFormat(showDate ? 'd MMM, h:mm a' : 'h:mm a')\n"
    '        .format(txn.occurredAt);\n'
    '    final label = isTransfer\n'
    "        ? (party.isNotEmpty ? party : 'Transfer')\n"
    "        : (txn.personId != null ? (txn.type == TxnType.expense ? 'Gave to a person' : 'Got from a person') : (cat?.name ?? 'Needs review'));\n"
    '    final sign = txn.type == TxnType.expense\n'
    "        ? '-'\n"
    "        : (txn.type == TxnType.income ? '+' : '');\n"
    '    final amountColor = txn.type == TxnType.income\n'
    '        ? AppColors.income\n'
    '        : (isTransfer ? AppColors.lavender : fin.text);',
    '    final isTransfer = txn.type == TxnType.transfer;\n'
    '    final isInvest = txn.type == TxnType.invest;\n'
    '    final color = txn.personId != null\n'
    '        ? const Color(0xFFF4A261)\n'
    '        : (cat?.colorValue ?? typeColor(txn.type));\n'
    '    final icon = txn.personId != null\n'
    '        ? Icons.people_alt_rounded\n'
    '        : (isInvest\n'
    '            ? (txn.amount < 0\n'
    '                ? Icons.unpublished_rounded\n'
    '                : Icons.savings_rounded)\n'
    '            : (isTransfer\n'
    '                ? Icons.swap_horiz_rounded\n'
    '                : (cat?.icon ??\n'
    '                    (txn.type == TxnType.income\n'
    '                        ? Icons.south_west_rounded\n'
    '                        : Icons.north_east_rounded))));\n'
    '    final party = prettyParty(txn.counterparty);\n'
    '    final title = isInvest\n'
    "        ? (txn.amount < 0\n"
    "            ? 'Goal → ${accName(txn.accountId)}'\n"
    "            : '${accName(txn.accountId)} → Goal')\n"
    '        : (isTransfer\n'
    "            ? '${accName(txn.accountId)} → ${accName(txn.toAccountId)}'\n"
    '            : (party.isNotEmpty\n'
    '                ? party\n'
    '                : (cat?.name ??\n'
    "                    (txn.type == TxnType.income ? 'Income' : 'Expense'))));\n"
    "    final time = DateFormat(showDate ? 'd MMM, h:mm a' : 'h:mm a')\n"
    '        .format(txn.occurredAt);\n'
    '    final label = isInvest\n'
    '        ? (party.isNotEmpty\n'
    '            ? party\n'
    "            : (txn.amount < 0 ? 'Goal withdraw' : 'Invest to goal'))\n"
    '        : (isTransfer\n'
    "            ? (party.isNotEmpty ? party : 'Transfer')\n"
    '            : (txn.personId != null\n'
    '                ? (txn.type == TxnType.expense\n'
    "                    ? 'Gave to a person'\n"
    "                    : 'Got from a person')\n"
    "                : (cat?.name ?? 'Needs review')));\n"
    '    final displayAmount = txn.amount.abs();\n'
    '    final sign = isInvest\n'
    "        ? (txn.amount < 0 ? '+' : '-')\n"
    '        : (txn.type == TxnType.expense\n'
    "            ? '-'\n"
    "            : (txn.type == TxnType.income ? '+' : ''));\n"
    '    final amountColor = txn.type == TxnType.income\n'
    '        ? AppColors.income\n'
    '        : (isTransfer || isInvest ? typeColor(txn.type) : fin.text);',
    already='final isInvest = txn.type == TxnType.invest;',
)

tile = read('lib/widgets/txn_tile.dart')
if 'isInvest ? displayAmount' not in tile:
    old_amt = "hide ? '₹ ••••' : '$sign${inr(txn.amount)}'"
    new_amt = "hide ? '₹ ••••' : '$sign${inr(isInvest ? displayAmount : txn.amount)}'"
    if old_amt not in tile:
        raise SystemExit('txn amount display pattern missing')
    write('lib/widgets/txn_tile.dart', tile.replace(old_amt, new_amt, 1))
    print('patched txn amount display')
else:
    print('skip txn amount display (already applied)')

# ===== add_txn_screen.dart =====
add_path = 'lib/screens/add_txn_screen.dart'
text = read(add_path)

if "import '../data/stats.dart';" not in text:
    text = text.replace(
        "import '../data/repo.dart';",
        "import '../data/repo.dart';\nimport '../data/stats.dart';",
        1,
    )

if 'Future<int?> pickGoal' not in text:
    pick_goal = '''
Future<int?> pickGoal(BuildContext context) async {
  final fin = context.fin;
  final goals = await AppDatabase.instance.goals();
  if (!context.mounted) return null;
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: fin.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text('Choose goal', style: AppText.display(size: 18, color: fin.text)),
            const SizedBox(height: 12),
            for (final g in goals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientAt(g.colorIndex),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.savings_rounded, color: Colors.white, size: 20),
                ),
                title: Text(g.name),
                subtitle: Text('${inr(g.saved)} / ${inr(g.target)}'),
                onTap: () => Navigator.pop(c, g.id),
              ),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No goals yet. Create one from Savings goals.',
                    style: TextStyle(color: fin.subtext)),
              ),
          ],
        ),
      ),
    ),
  );
}

'''
    marker = 'class AddTxnScreen extends StatefulWidget'
    if marker not in text:
        raise SystemExit('AddTxnScreen class not found')
    text = text.replace(marker, pick_goal + marker, 1)

old_fields = '''  final String? receiptPath;
  final String? voiceText;

  const AddTxnScreen({
    super.key,
    this.type = TxnType.expense,
    this.editing,
    this.initialAmount,
    this.initialCategoryId,
    this.initialAccountId,
    this.initialPayee,
    this.initialNote,
    this.initialWhen,
    this.receiptPath,
    this.voiceText,
  });'''
new_fields = '''  final String? receiptPath;
  final String? voiceText;
  final int? initialGoalId;

  const AddTxnScreen({
    super.key,
    this.type = TxnType.expense,
    this.editing,
    this.initialAmount,
    this.initialCategoryId,
    this.initialAccountId,
    this.initialPayee,
    this.initialNote,
    this.initialWhen,
    this.receiptPath,
    this.voiceText,
    this.initialGoalId,
  });'''
if 'initialGoalId' not in text:
    if old_fields not in text:
        raise SystemExit('AddTxnScreen fields block not found')
    text = text.replace(old_fields, new_fields, 1)

if 'int? _goalId;' not in text:
    old_state = '''  int? _categoryId;
  int? _personId;
  String? _personName;'''
    new_state = '''  int? _categoryId;
  int? _goalId;
  String? _goalName;
  int? _personId;
  String? _personName;'''
    if old_state not in text:
        raise SystemExit('state fields not found')
    text = text.replace(old_state, new_state, 1)

if '_loadGoal' not in text:
    old_init = '''    if (e != null) {
      _amount = _fmt(e.amount);
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _categoryId = e.categoryId;
      _note.text = e.note ?? '';
      _payee.text = e.counterparty ?? '';
      if (e.personId != null && e.type != TxnType.transfer) {
        _mode = e.type == TxnType.income ? 'got' : 'gave';
        _type = TxnType.transfer;
        _personId = e.personId;
      }
    } else {'''
    new_init = '''    if (e != null) {
      _amount = _fmt(e.amount.abs());
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _categoryId = e.categoryId;
      _goalId = e.goalId;
      _note.text = e.note ?? '';
      _payee.text = e.counterparty ?? '';
      if (e.goalId != null) _loadGoal(e.goalId!);
      if (e.personId != null && e.type != TxnType.transfer && e.type != TxnType.invest) {
        _mode = e.type == TxnType.income ? 'got' : 'gave';
        _type = TxnType.transfer;
        _personId = e.personId;
      }
    } else {'''
    if old_init not in text:
        raise SystemExit('initState amount block not found')
    text = text.replace(old_init, new_init, 1)

    old_else = '''      _accountId = widget.initialAccountId ?? (bank ?? cash)?.id;
      if (_type == TxnType.transfer) _toAccountId = cash?.id;
      if (widget.initialAmount != null && widget.initialAmount! > 0) _amount = _fmt(widget.initialAmount!);
      _categoryId = widget.initialCategoryId;'''
    new_else = '''      _accountId = widget.initialAccountId ?? (bank ?? cash)?.id;
      if (_type == TxnType.transfer) _toAccountId = cash?.id;
      if (widget.initialAmount != null && widget.initialAmount! > 0) _amount = _fmt(widget.initialAmount!);
      _categoryId = widget.initialCategoryId;
      _goalId = widget.initialGoalId;
      if (_goalId != null) _loadGoal(_goalId!);'''
    if old_else not in text:
        raise SystemExit('else init block not found')
    text = text.replace(old_else, new_else, 1)

    load_goal = '''
  Future<void> _loadGoal(int id) async {
    final goals = await AppDatabase.instance.goals();
    for (final g in goals) {
      if (g.id == id) {
        if (mounted) setState(() => _goalName = g.name);
        return;
      }
    }
  }

'''
    text = text.replace('  Future<void> _save() async {', load_goal + '  Future<void> _save() async {', 1)

# type switch: 4 tabs
if "item(TxnType.invest, 'Invest')" not in text:
    old_items = '''        item(TxnType.expense, 'Expense'),
        item(TxnType.income, 'Income'),
        item(TxnType.transfer, 'Transfer'),
      ]),
    );
  }'''
    new_items = '''        item(TxnType.expense, 'Expense'),
        item(TxnType.income, 'Income'),
        item(TxnType.transfer, 'Move'),
        item(TxnType.invest, 'Invest'),
      ]),
    );
  }'''
    if old_items not in text:
        raise SystemExit('type switch items not found')
    text = text.replace(old_items, new_items, 1)

    old_ontap = '''            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: sel ? typeColor(t) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(label,
                  style: TextStyle(color: sel ? Colors.white : fin.subtext, fontWeight: FontWeight.w700)),
            ),'''
    new_ontap = '''            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: sel ? typeColor(t) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : fin.subtext,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ),'''
    if old_ontap not in text:
        raise SystemExit('type switch style not found')
    text = text.replace(old_ontap, new_ontap, 1)

# _save invest
if 'final isInvest = _type == TxnType.invest;' not in text or 'Choose a goal to invest in' not in text:
    old_save = '''    final isTransfer = _type == TxnType.transfer;
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
    );'''
    new_save = '''    final isTransfer = _type == TxnType.transfer;
    final isInvest = _type == TxnType.invest;
    if (isInvest && _goalId == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a goal to invest in')));
      return;
    }
    final t = Txn(
      id: e?.id,
      accountId: _accountId,
      toAccountId: isTransfer ? _toAccountId : null,
      goalId: isInvest ? _goalId : null,
      type: _type,
      amount: isInvest ? _value.abs() : _value,
      categoryId: (isTransfer || isInvest) ? null : _categoryId,
      personId: null,
      counterparty: payee.isEmpty ? (isInvest ? _goalName : null) : payee,
      note: note,
      ref: e?.ref,
      smsBody: e?.smsBody,
      status: (isTransfer || isInvest || _categoryId != null) ? 'done' : 'review',
      occurredAt: _when,
    );'''
    if old_save not in text:
        raise SystemExit('_save txn block not found')
    text = text.replace(old_save, new_save, 1)

if '!isInvest && _categoryId' not in text:
    text = text.replace(
        'if (_remember && !isTransfer && _categoryId != null && payee.isNotEmpty && e?.smsBody != null)',
        'if (_remember && !isTransfer && !isInvest && _categoryId != null && payee.isNotEmpty && e?.smsBody != null)',
        1,
    )

# build UI
if 'Moves money from an account into a savings goal' not in text:
    old_build = '''    final isTransfer = _type == TxnType.transfer;
    final kind = _type == TxnType.income ? 'income' : 'expense';
    final cat = context.watch<TxnState>().category(_categoryId);
    final color = _personMode ? (_mode == 'gave' ? AppColors.expense : AppColors.income) : typeColor(_type);'''
    new_build = '''    final isTransfer = _type == TxnType.transfer;
    final isInvest = _type == TxnType.invest;
    final kind = _type == TxnType.income ? 'income' : 'expense';
    final cat = context.watch<TxnState>().category(_categoryId);
    final color = _personMode ? (_mode == 'gave' ? AppColors.expense : AppColors.income) : typeColor(_type);'''
    if old_build not in text:
        raise SystemExit('build vars not found')
    text = text.replace(old_build, new_build, 1)

    old_ui = '''              if (!isTransfer) accountField,
              if (isTransfer && _mode == 'accounts') ...[
                accountField,
                _field(fin, Icons.south_rounded, AppColors.pink, 'To account', _accName(_toAccountId), () async {
                  final id = await pickAccount(context, exclude: _accountId, title: 'Move money to');
                  if (id != null) setState(() => _toAccountId = id);
                }),
              ],
              if (isTransfer && _mode == 'gave') ...[accountField, personField],
              if (isTransfer && _mode == 'got') ...[personField, accountField],
              if (!isTransfer)
                _field(fin, cat?.icon ?? Icons.category_rounded, cat?.colorValue ?? AppColors.pink, 'Category',
                    cat?.name ?? 'Choose category', () async {
                  final id = await pickCategory(context, kind);
                  if (id != null) setState(() => _categoryId = id);
                }),'''
    new_ui = '''              if (!isTransfer) accountField,
              if (isTransfer && _mode == 'accounts') ...[
                accountField,
                _field(fin, Icons.south_rounded, AppColors.pink, 'To account', _accName(_toAccountId), () async {
                  final id = await pickAccount(context, exclude: _accountId, title: 'Move money to');
                  if (id != null) setState(() => _toAccountId = id);
                }),
              ],
              if (isTransfer && _mode == 'gave') ...[accountField, personField],
              if (isTransfer && _mode == 'got') ...[personField, accountField],
              if (isInvest)
                _field(fin, Icons.savings_rounded, const Color(0xFF5B8DEF), 'Goal',
                    _goalName ?? 'Choose goal', () async {
                  final id = await pickGoal(context);
                  if (id != null) {
                    setState(() => _goalId = id);
                    await _loadGoal(id);
                  }
                }),
              if (!isTransfer && !isInvest)
                _field(fin, cat?.icon ?? Icons.category_rounded, cat?.colorValue ?? AppColors.pink, 'Category',
                    cat?.name ?? 'Choose category', () async {
                  final id = await pickCategory(context, kind);
                  if (id != null) setState(() => _categoryId = id);
                }),'''
    if old_ui not in text:
        raise SystemExit('fields UI block not found')
    text = text.replace(old_ui, new_ui, 1)

    old_help = '''              if (_personMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                  child: Text(
                    _mode == 'gave'
                        ? 'Lending money or paying someone back. Saved in the People ledger, not counted as spending.'
                        : 'Borrowing money or getting paid back. Saved in the People ledger, not counted as income.',
                    style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.4),
                  ),
                ),'''
    new_help = '''              if (isInvest)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                  child: Text(
                    'Moves money from an account into a savings goal. Not counted as expense or income.',
                    style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.4),
                  ),
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
                ),'''
    if old_help not in text:
        raise SystemExit('person help not found')
    text = text.replace(old_help, new_help, 1)

    text = text.replace(
        '''                  hintText: isTransfer
                      ? 'Label or UPI ID (optional)'
                      : (_type == TxnType.income ? 'Received from (optional)' : 'Paid to (optional)'),''',
        '''                  hintText: isInvest
                      ? 'Label (optional)'
                      : (isTransfer
                          ? 'Label or UPI ID (optional)'
                          : (_type == TxnType.income ? 'Received from (optional)' : 'Paid to (optional)')),''',
        1,
    )

write(add_path, text)
print('patched add_txn_screen.dart')

# ===== goals_screen =====
gs_path = 'lib/screens/goals_screen.dart'
gtext = read(gs_path)

if "import '../data/repo.dart';" not in gtext:
    gtext = gtext.replace(
        "import '../data/stats.dart';",
        "import '../data/stats.dart';\nimport '../data/repo.dart';",
        1,
    )
if "import 'add_txn_screen.dart';" not in gtext:
    gtext = gtext.replace(
        "import '../widgets/common.dart';",
        "import '../widgets/common.dart';\nimport 'add_txn_screen.dart';",
        1,
    )

if 'investInGoal(' not in gtext:
    old_add = '''  Future<void> _addMoney(Goal g) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(g.name),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Amount'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, 'withdraw'),
              child: const Text('Withdraw')),
          FilledButton(
              onPressed: () => Navigator.pop(d, 'add'),
              child: const Text('Add money')),
        ],
      ),
    );
    final v = _parse(ctrl.text);
    if (res == null || v <= 0) return;
    await AppDatabase.instance.addToGoal(g.id, res == 'add' ? v : -v);
    if (res == 'add' && g.saved < g.target && g.saved + v >= g.target) {
      messenger.showSnackBar(
          SnackBar(content: Text('Goal reached: ${g.name}. Well done!')));
    }
    if (mounted) _reload();
  }'''
    new_add = '''  Future<void> _addMoney(Goal g) async {
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
  }'''
    if old_add not in gtext:
        raise SystemExit('goals _addMoney not found')
    gtext = gtext.replace(old_add, new_add, 1)

write(gs_path, gtext)
print('patched goals_screen.dart')

# ===== verify =====
checks = [
    ('lib/data/db.dart', 'invest }', 'TxnType.invest'),
    ('lib/data/db.dart', 'goalId', 'Txn.goalId'),
    ('lib/data/repo.dart', 'investInGoal', 'investInGoal helper'),
    ('lib/data/repo.dart', 'case TxnType.invest:', 'invest balance apply'),
    ('lib/widgets/txn_tile.dart', 'TxnType.invest =>', 'typeColor invest'),
    ('lib/widgets/txn_tile.dart', 'isInvest ? displayAmount', 'invest amount display'),
    ('lib/screens/add_txn_screen.dart', "item(TxnType.invest, 'Invest')", 'Invest type tab'),
    ('lib/screens/add_txn_screen.dart', 'pickGoal', 'pickGoal'),
    ('lib/screens/goals_screen.dart', 'investInGoal(', 'goals invest flow'),
]
for path, needle, label in checks:
    ensure_contains(path, needle, label)
    print(f'ok {label}')

print('finup10 patches complete')
PY

echo "FinUp Part 10 (Invest) applied."
