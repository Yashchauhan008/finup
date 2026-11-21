#!/usr/bin/env bash
# FinUp Part 14 — Delete persistence, SMS balance refresh, Spent-today sheet, create UX
set -euo pipefail
cd app

python3 <<'PY'
from pathlib import Path
from typing import Optional

def must(p: str) -> Path:
    path = Path(p)
    if not path.exists():
        raise SystemExit(f'missing {p}')
    return path

def read(p: str) -> str:
    return must(p).read_text()

def write(p: str, text: str):
    must(p).write_text(text)

def replace_once(path: str, old: str, new: str, already: Optional[str] = None):
    text = read(path)
    if already and already in text and old not in text:
        print(f'skip {path}')
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}:\n---\n{old[:260]}\n---')
    write(path, text.replace(old, new, 1))
    print(f'patched {path}')

def ensure(path: str, needle: str, label: str):
    if needle not in read(path):
        raise SystemExit(f'missing {label} in {path}')
    print(f'ok {label}')

# =============================================================================
# 1) deleted_refs tombstones — stop SMS / auto-link from resurrecting deletes
# =============================================================================
replace_once(
    'lib/data/repo.dart',
    """  Future<void> ensureSchema() async {
    final cols = await db.rawQuery('PRAGMA table_info(transactions)');
    final names = cols.map((c) => c['name'] as String).toSet();
    if (!names.contains('affects_balance')) {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN affects_balance INTEGER NOT NULL DEFAULT 1');
    }
    if (!names.contains('goal_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN goal_id INTEGER');
    }
  }""",
    """  Future<void> ensureSchema() async {
    final cols = await db.rawQuery('PRAGMA table_info(transactions)');
    final names = cols.map((c) => c['name'] as String).toSet();
    if (!names.contains('affects_balance')) {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN affects_balance INTEGER NOT NULL DEFAULT 1');
    }
    if (!names.contains('goal_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN goal_id INTEGER');
    }
    await db.execute(
        'CREATE TABLE IF NOT EXISTS deleted_refs(ref TEXT PRIMARY KEY, deleted_at INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS budgets(id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER NOT NULL, amount REAL NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS goals(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, target REAL NOT NULL, saved REAL NOT NULL DEFAULT 0, color_index INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)');
  }

  Future<void> rememberDeletedRef(String? ref) async {
    final r = (ref ?? '').trim();
    if (r.isEmpty) return;
    await db.insert(
      'deleted_refs',
      {'ref': r, 'deleted_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> isDeletedRef(String ref) async {
    final n = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM deleted_refs WHERE ref = ?', [ref])) ??
        0;
    return n > 0;
  }""",
    already='deleted_refs',
)

# ConflictAlgorithm needs sqflite import — repo already imports sqflite
if 'ConflictAlgorithm' in read('lib/data/repo.dart') and 'import \'package:sqflite/sqflite.dart\';' not in read('lib/data/repo.dart'):
    replace_once(
        'lib/data/repo.dart',
        "import 'package:sqflite/sqflite.dart';\n",
        "import 'package:sqflite/sqflite.dart';\n",
        already='package:sqflite',
    )

replace_once(
    'lib/data/repo.dart',
    '''  Future<void> deleteTxn(Txn t) async {
    final mode = await _modeOf(t.id!);
    await _apply(t, -1, mode);
    await db.delete('transactions', where: 'id = ?', whereArgs: [t.id]);
  }''',
    '''  Future<void> deleteTxn(Txn t) async {
    final mode = await _modeOf(t.id!);
    await _apply(t, -1, mode);
    await rememberDeletedRef(t.ref);
    await db.delete('transactions', where: 'id = ?', whereArgs: [t.id]);
  }''',
    already='rememberDeletedRef(t.ref)',
)

# People: deleting a ledger entry must fully remove linked SMS txn (tombstone),
# not send it back to review where autoLinkPeople resurrects it.
replace_once(
    'lib/data/people_repo.dart',
    '''  Future<void> deleteEntry(LedgerEntry e) async {
    if (e.txnId != null) {
      final t = await txnById(e.txnId!);
      if (t != null) {
        if (t.smsBody != null) {
          await db.update('transactions', {'person_id': null, 'status': 'review'},
              where: 'id = ?', whereArgs: [t.id]);
        } else {
          await this.deleteTxn(t);
        }
      }
    }
    await db.delete('ledger', where: 'id = ?', whereArgs: [e.id]);
  }''',
    '''  Future<void> deleteEntry(LedgerEntry e) async {
    if (e.txnId != null) {
      final t = await txnById(e.txnId!);
      if (t != null) {
        // Always delete the linked txn and remember its SMS ref so sync cannot
        // re-import it, and autoLinkPeople cannot resurrect it on the person.
        await this.deleteTxn(t);
      }
    }
    await db.delete('ledger', where: 'id = ?', whereArgs: [e.id]);
  }''',
    already='Always delete the linked txn',
)

# =============================================================================
# 2) SMS sync: balance from last msg even when txn exists; honor deleted_refs
# =============================================================================
replace_once(
    'lib/sms/sync.dart',
    '''    for (final sms in msgs) {
      if (sms.date > maxDate) maxDate = sms.date;
      final p = SmsParser.parse(
          sms.address, sms.body, DateTime.fromMillisecondsSinceEpoch(sms.date));
      if (p == null) continue;
      final key = p.ref != null ? 'ref:${p.ref}' : 'sms:${sms.id}';
      if (await db.txnExists(key)) continue;

      var acc = _match(accounts, p);
      if (acc == null) {
        if (p.last4 == null) continue;
        final id = await db.insertAccount(Account(
          name: p.bankName,
          type: AccountType.bank,
          bank: p.bankName,
          last4: p.last4,
          colorIndex: accounts.length % 4,
          balance: p.balance ?? 0,
          balanceUpdatedAt: p.balance == null ? null : p.when,
        ));
        accounts = await db.accounts();
        acc = _byId(accounts, id);
        if (acc == null) continue;
      }
      final accId = acc.id!;
      final fresh = acc.balanceUpdatedAt == null ||
          p.when.isAfter(acc.balanceUpdatedAt!);

      if (p.balance != null) {
        final prev = latest[accId];
        if (prev == null || p.when.isAfter(prev.$1)) {
          latest[accId] = (p.when, p.balance!);
        }
      }

      if (p.isAtm) {''',
    '''    for (final sms in msgs) {
      if (sms.date > maxDate) maxDate = sms.date;
      final p = SmsParser.parse(
          sms.address, sms.body, DateTime.fromMillisecondsSinceEpoch(sms.date));
      if (p == null) continue;
      final key = p.ref != null ? 'ref:${p.ref}' : 'sms:${sms.id}';

      // Match account early so we can refresh balance even for known txns.
      var acc = _match(accounts, p);
      if (acc == null && p.last4 != null && !(await db.txnExists(key)) && !(await db.isDeletedRef(key))) {
        final id = await db.insertAccount(Account(
          name: p.bankName,
          type: AccountType.bank,
          bank: p.bankName,
          last4: p.last4,
          colorIndex: accounts.length % 4,
          balance: p.balance ?? 0,
          balanceUpdatedAt: p.balance == null ? null : p.when,
        ));
        accounts = await db.accounts();
        acc = _byId(accounts, id);
      }
      if (acc != null) {
        final accId = acc.id!;
        if (p.balance != null) {
          final prev = latest[accId];
          if (prev == null || !p.when.isBefore(prev.$1)) {
            latest[accId] = (p.when, p.balance!);
          }
        }
      }

      if (await db.isDeletedRef(key)) continue;
      if (await db.txnExists(key)) continue;
      if (acc == null) {
        if (p.last4 == null) continue;
        continue;
      }
      final accId = acc.id!;
      final fresh = acc.balanceUpdatedAt == null ||
          p.when.isAfter(acc.balanceUpdatedAt!);

      if (p.isAtm) {''',
    already='isDeletedRef(key)',
)

# Always apply latest SMS balances on sync (pull-to-refresh)
replace_once(
    'lib/sms/sync.dart',
    '''    for (final e in latest.entries) {
      final acc = _byId(accounts, e.key);
      if (acc == null) continue;
      final upd = acc.balanceUpdatedAt;
      if (upd == null || acc.balance == 0 || !e.value.$1.isBefore(upd)) {
        await db.setAccountBalance(e.key, e.value.$2, e.value.$1);
      }
    }''',
    '''    // Prefer newest available-balance SMS per account (home pull-to-refresh).
    for (final e in latest.entries) {
      final acc = _byId(accounts, e.key);
      if (acc == null) continue;
      final upd = acc.balanceUpdatedAt;
      if (upd == null || !e.value.$1.isBefore(upd)) {
        await db.setAccountBalance(e.key, e.value.$2, e.value.$1);
      }
    }''',
    already='Prefer newest available-balance',
)

# Home refresh: re-scan recent SMS window so balances update even if txns exist
replace_once(
    'lib/screens/home_screen.dart',
    '''        onRefresh: () async {
          await txns.sync(accounts);
        },''',
    '''        onRefresh: () async {
          // Re-read ~14 days so available balance is taken from the latest bank SMS
          // even when those messages were already imported as transactions.
          final since = DateTime.now()
              .subtract(const Duration(days: 14))
              .millisecondsSinceEpoch;
          await txns.sync(accounts, sinceMs: since);
        },''',
    already='Duration(days: 14)',
)

# =============================================================================
# 3) Spent today → bottom sheet of today's expense txns
# =============================================================================
replace_once(
    'lib/screens/home_screen.dart',
    '''import 'add_txn_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'sms_setup_screen.dart';''',
    '''import 'add_txn_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'sms_setup_screen.dart';

Future<void> _showTodaySpend(BuildContext context) async {
  final fin = context.fin;
  final hide = context.read<SettingsState>().hideAmounts;
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final to = from.add(const Duration(days: 1));
  final list = await AppDatabase.instance.txns(
      type: 'expense', from: from, to: to, limit: 200);
  // Exclude people-ledger rows from "spent today" detail (same as todaySpent).
  final spending = list.where((t) => t.personId == null).toList();
  if (!context.mounted) return;
  showModalBottomSheet<void>(
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
            Text('Spent today', style: AppText.display(size: 18, color: fin.text)),
            const SizedBox(height: 8),
            if (spending.isEmpty)
              Text('No spending logged today.',
                  style: TextStyle(color: fin.subtext))
            else
              for (final t in spending)
                TxnTile(
                  txn: t,
                  hide: hide,
                  showDate: false,
                  onTap: () {
                    Navigator.pop(c);
                    Navigator.of(context)
                        .push(fadeRoute(AddTxnScreen(editing: t)));
                  },
                ),
          ],
        ),
      ),
    ),
  );
}
''',
    already='_showTodaySpend',
)

# Make Spent today tappable — replace the Expanded _stat spent today block
replace_once(
    'lib/screens/home_screen.dart',
    '''                  Row(children: [
                    Expanded(
                        child: _stat(fin, Icons.north_east_rounded,
                            AppColors.expense, 'Spent today',
                            inr(txns.todaySpent, hide: hide))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _stat(fin, Icons.inbox_rounded,
                            AppColors.lavender, 'To review',
                            '${txns.reviewCount}')),
                  ]),''',
    '''                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showTodaySpend(context),
                        child: _stat(fin, Icons.north_east_rounded,
                            AppColors.expense, 'Spent today',
                            inr(txns.todaySpent, hide: hide)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: txns.reviewCount > 0
                            ? () => _open(const ReviewScreen())
                            : null,
                        child: _stat(fin, Icons.inbox_rounded,
                            AppColors.lavender, 'To review',
                            '${txns.reviewCount}'),
                      ),
                    ),
                  ]),''',
    already='_showTodaySpend(context)',
)

# Need AppText import? home already has theme. Need fadeRoute from common - has common.
# SettingsState read - provider already used.

# =============================================================================
# 4) Budgets / Goals create feedback + safer parse
# =============================================================================
replace_once(
    'lib/screens/budgets_screen.dart',
    '''    final db = AppDatabase.instance;
    if (res == 'delete') await db.deleteBudget(catId);
    if (res == 'save') {
      final v = double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0;
      if (v > 0) await db.setBudget(catId, v);
    }
    if (mounted) setState(() => _future = null);
  }''',
    '''    final db = AppDatabase.instance;
    final messenger = ScaffoldMessenger.of(context);
    if (res == 'delete') {
      await db.deleteBudget(catId);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Budget removed')));
      }
    }
    if (res == 'save') {
      final raw = ctrl.text.replaceAll(',', '').replaceAll('₹', '').trim();
      final v = double.tryParse(raw) ?? 0;
      if (v <= 0) {
        if (mounted) {
          messenger.showSnackBar(
              const SnackBar(content: Text('Enter a budget amount greater than 0')));
        }
      } else {
        await db.setBudget(catId, v);
        if (mounted) {
          messenger.showSnackBar(
              SnackBar(content: Text('Budget saved · ${cat?.name ?? 'category'}')));
        }
      }
    }
    if (mounted) setState(() => _future = null);
  }''',
    already='Budget saved',
)

replace_once(
    'lib/screens/goals_screen.dart',
    '''    final db = AppDatabase.instance;
    if (res == 'delete' && g != null) await db.deleteGoal(g.id);
    if (res == 'save') {
      final n = name.text.trim();
      final t = _parse(target.text);
      if (n.isNotEmpty && t > 0) {
        if (g == null) {
          await db.insertGoal(n, t, color);
        } else {
          await db.updateGoal(g.id, n, t, color);
        }
      }
    }
    if (mounted) _reload();
  }''',
    '''    final db = AppDatabase.instance;
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
  }''',
    already='Goal created',
)

# Trip / tag create: always enable Save and validate with snackbar
replace_once(
    'lib/screens/tags_screen.dart',
    '''  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final db = AppDatabase.instance;
    final budget = double.tryParse(_budget.text.replaceAll(',', '').trim());
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
    nav.pop();
  }''',
    '''  Future<void> _save() async {
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
  }''',
    already='Trip created',
)

replace_once(
    'lib/screens/tags_screen.dart',
    '''          PrimaryButton(label: 'Save', icon: Icons.check_rounded, onPressed: _valid ? _save : null),''',
    '''          PrimaryButton(label: 'Save', icon: Icons.check_rounded, onPressed: _save),''',
    already='onPressed: _save),',
)

# =============================================================================
# verify
# =============================================================================
checks = [
    ('lib/data/repo.dart', 'deleted_refs', 'tombstone table'),
    ('lib/data/repo.dart', 'rememberDeletedRef(t.ref)', 'delete remembers ref'),
    ('lib/data/people_repo.dart', 'Always delete the linked txn', 'people delete hard'),
    ('lib/sms/sync.dart', 'isDeletedRef(key)', 'sync skips deleted'),
    ('lib/sms/sync.dart', 'Prefer newest available-balance', 'balance refresh'),
    ('lib/screens/home_screen.dart', '_showTodaySpend', 'spent today sheet'),
    ('lib/screens/budgets_screen.dart', 'Budget saved', 'budget feedback'),
    ('lib/screens/goals_screen.dart', 'Goal created', 'goal feedback'),
]
for p, n, l in checks:
    ensure(p, n, l)
print('finup14 complete')
PY

echo "FinUp Part 14 applied."
