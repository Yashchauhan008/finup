#!/usr/bin/env bash
# FinUp Part 13 — Insights: Invest in By category; Money analysis spending includes lent
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

def replace_once(path: str, old: str, new: str, already: Optional[str] = None):
    text = read(path)
    if already and already in text and old not in text:
        print(f'skip {path}')
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}:\n---\n{old[:240]}\n---')
    write(path, text.replace(old, new, 1))
    print(f'patched {path}')

def ensure(path: str, needle: str, label: str):
    if needle not in read(path):
        raise SystemExit(f'missing {label}')
    print(f'ok {label}')

# ----- stats.dart: invest usage bucket + money analysis uses full moneyFlow -----
replace_once(
    'lib/data/stats.dart',
    '''/// Synthetic category ids for people-ledger money in charts.
const int kUsageLentId = -101; // you gave / lent (not a settle note)
const int kUsageSettledOutId = -102; // you paid someone back / settled
const int kUsageBorrowedId = -103; // you got / borrowed
const int kUsageSettledInId = -104; // someone paid you back / settled''',
    '''/// Synthetic category ids for people-ledger / invest money in charts.
const int kUsageLentId = -101; // you gave / lent (not a settle note)
const int kUsageSettledOutId = -102; // you paid someone back / settled
const int kUsageBorrowedId = -103; // you got / borrowed
const int kUsageSettledInId = -104; // someone paid you back / settled
const int kUsageInvestId = -105; // account → goal (not expense)''',
    already='kUsageInvestId',
)

replace_once(
    'lib/data/stats.dart',
    '''String usageBucketName(int? id) {
  switch (id) {
    case kUsageLentId:
      return 'Lent to people';
    case kUsageSettledOutId:
      return 'Loan / settle paid';
    case kUsageBorrowedId:
      return 'Borrowed / received';
    case kUsageSettledInId:
      return 'Settlements received';
    default:
      return 'Needs review';
  }
}''',
    '''String usageBucketName(int? id) {
  switch (id) {
    case kUsageLentId:
      return 'Lent to people';
    case kUsageSettledOutId:
      return 'Loan / settle paid';
    case kUsageBorrowedId:
      return 'Borrowed / received';
    case kUsageSettledInId:
      return 'Settlements received';
    case kUsageInvestId:
      return 'Invested in goals';
    default:
      return 'Needs review';
  }
}''',
    already="'Invested in goals'",
)

replace_once(
    'lib/data/stats.dart',
    '''IconData usageBucketIcon(int? id) {
  switch (id) {
    case kUsageLentId:
      return Icons.volunteer_activism_rounded;
    case kUsageSettledOutId:
      return Icons.handshake_rounded;
    case kUsageBorrowedId:
      return Icons.south_west_rounded;
    case kUsageSettledInId:
      return Icons.handshake_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}''',
    '''IconData usageBucketIcon(int? id) {
  switch (id) {
    case kUsageLentId:
      return Icons.volunteer_activism_rounded;
    case kUsageSettledOutId:
      return Icons.handshake_rounded;
    case kUsageBorrowedId:
      return Icons.south_west_rounded;
    case kUsageSettledInId:
      return Icons.handshake_rounded;
    case kUsageInvestId:
      return Icons.savings_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}''',
    already='case kUsageInvestId:\n      return Icons.savings_rounded',
)

replace_once(
    'lib/data/stats.dart',
    '''Color usageBucketColor(int? id) {
  switch (id) {
    case kUsageLentId:
      return AppColors.pink;
    case kUsageSettledOutId:
      return const Color(0xFFE8A87C);
    case kUsageBorrowedId:
      return AppColors.income;
    case kUsageSettledInId:
      return AppColors.lavender;
    default:
      return AppColors.lavender;
  }
}

bool isUsageBucket(int? id) =>
    id == kUsageLentId ||
    id == kUsageSettledOutId ||
    id == kUsageBorrowedId ||
    id == kUsageSettledInId;''',
    '''Color usageBucketColor(int? id) {
  switch (id) {
    case kUsageLentId:
      return AppColors.pink;
    case kUsageSettledOutId:
      return const Color(0xFFE8A87C);
    case kUsageBorrowedId:
      return AppColors.income;
    case kUsageSettledInId:
      return AppColors.lavender;
    case kUsageInvestId:
      return const Color(0xFF5B8DEF);
    default:
      return AppColors.lavender;
  }
}

bool isUsageBucket(int? id) =>
    id == kUsageLentId ||
    id == kUsageSettledOutId ||
    id == kUsageBorrowedId ||
    id == kUsageSettledInId ||
    id == kUsageInvestId;''',
    already='id == kUsageInvestId',
)

# Money analysis: spending/income from moneyFlow (includes lent / people)
replace_once(
    'lib/data/stats.dart',
    '''  Future<({double opening, double income, double spending, double invested, double closing})>
      monthMoneyAnalysis(DateTime from, DateTime to) async {
    final (income, spending) = await incomeExpense(from, to);
    double invested = 0;
    double netAccounts = 0;
    for (final r in await _rows(from, to)) {
      final a = (r['amount'] as num).toDouble();
      final t = r['type'];
      if (t == 'income') {
        netAccounts += a;
      } else if (t == 'expense') {
        netAccounts -= a;
      } else if (t == 'invest') {
        netAccounts -= a; // +invest leaves accounts; -invest returns
        if (a > 0) invested += a;
      }
    }
    double closing = 0;
    final accs = await db.query('accounts',
        columns: ['balance'], where: 'archived = 0');
    for (final a in accs) {
      closing += (a['balance'] as num).toDouble();
    }
    final opening = closing - netAccounts;
    return (
      opening: opening,
      income: income,
      spending: spending,
      invested: invested,
      closing: closing,
    );
  }''',
    '''  Future<({double opening, double income, double spending, double invested, double closing})>
      monthMoneyAnalysis(DateTime from, DateTime to) async {
    // Include lent / people money in spending & income (same as Insights total).
    final (income, spending) = await moneyFlow(from, to);
    double invested = 0;
    double netAccounts = 0;
    for (final r in await _rows(from, to)) {
      final a = (r['amount'] as num).toDouble();
      final t = r['type'];
      if (t == 'income') {
        netAccounts += a;
      } else if (t == 'expense') {
        netAccounts -= a;
      } else if (t == 'invest') {
        netAccounts -= a; // +invest leaves accounts; -invest returns
        if (a > 0) invested += a;
      }
    }
    double closing = 0;
    final accs = await db.query('accounts',
        columns: ['balance'], where: 'archived = 0');
    for (final a in accs) {
      closing += (a['balance'] as num).toDouble();
    }
    final opening = closing - netAccounts;
    return (
      opening: opening,
      income: income,
      spending: spending,
      invested: invested,
      closing: closing,
    );
  }''',
    already='Include lent / people money',
)

# ----- insights: fold invest into By category on Spending tab -----
replace_once(
    'lib/screens/insights_screen.dart',
    '''    final cats = await db.usageBreakdown(s, e, _type);
    final daily = await db.dailyTotals(s, e, _type);
    final analysis = await db.monthMoneyAnalysis(s, e);
    final list = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final inc = _type == 'income';
    return _Insight(
      inc ? cur.$1 : cur.$2,
      inc ? prev.$1 : prev.$2,
      list,
      daily,
      opening: analysis.opening,
      income: analysis.income,
      spending: analysis.spending,
      invested: analysis.invested,
      closing: analysis.closing,
    );
  }''',
    '''    final cats = await db.usageBreakdown(s, e, _type);
    final daily = await db.dailyTotals(s, e, _type);
    final analysis = await db.monthMoneyAnalysis(s, e);
    // Show invested under By category on the Spending tab (not counted as expense).
    if (_type == 'expense' && analysis.invested > 0) {
      cats[kUsageInvestId] = analysis.invested;
    }
    final list = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final inc = _type == 'income';
    return _Insight(
      inc ? cur.$1 : cur.$2,
      inc ? prev.$1 : prev.$2,
      list,
      daily,
      opening: analysis.opening,
      income: analysis.income,
      spending: analysis.spending,
      invested: analysis.invested,
      closing: analysis.closing,
    );
  }''',
    already='cats[kUsageInvestId]',
)

# Bucket txns for invest
replace_once(
    'lib/screens/insights_screen.dart',
    '''  Future<List<Txn>> _bucketTxns(int id, DateTime s, DateTime e) async {
    final db = AppDatabase.instance;
    if (!isUsageBucket(id)) {
      return db.txns(categoryId: id, type: _type, from: s, to: e);
    }
    final all = await db.txns(type: _type, from: s, to: e);
    return all.where((t) {
      if (t.personId == null) return false;
      final settled = isSettledNote(t.note);
      if (id == kUsageLentId) return _type == 'expense' && !settled;
      if (id == kUsageSettledOutId) return _type == 'expense' && settled;
      if (id == kUsageBorrowedId) return _type == 'income' && !settled;
      if (id == kUsageSettledInId) return _type == 'income' && settled;
      return false;
    }).toList();
  }''',
    '''  Future<List<Txn>> _bucketTxns(int id, DateTime s, DateTime e) async {
    final db = AppDatabase.instance;
    if (id == kUsageInvestId) {
      final all = await db.txns(type: 'invest', from: s, to: e);
      return all.where((t) => t.amount > 0).toList();
    }
    if (!isUsageBucket(id)) {
      return db.txns(categoryId: id, type: _type, from: s, to: e);
    }
    final all = await db.txns(type: _type, from: s, to: e);
    return all.where((t) {
      if (t.personId == null) return false;
      final settled = isSettledNote(t.note);
      if (id == kUsageLentId) return _type == 'expense' && !settled;
      if (id == kUsageSettledOutId) return _type == 'expense' && settled;
      if (id == kUsageBorrowedId) return _type == 'income' && !settled;
      if (id == kUsageSettledInId) return _type == 'income' && settled;
      return false;
    }).toList();
  }''',
    already='id == kUsageInvestId',
)

# Percent / donut: use sum of listed cats so Invest row % is correct (not vs expense-only total)
# Find the percent line that uses d.total
ins = read('lib/screens/insights_screen.dart')
old_pct = '''                              Text(
                                  d.total > 0
                                      ? '${(d.cats[i].value / d.total * 100).round()}%'
                                      : '',
                                  style: TextStyle(color: fin.subtext, fontSize: 12.5)),'''
new_pct = '''                              Text(
                                  () {
                                    final denom = d.cats.fold<double>(0, (a, e) => a + e.value);
                                    return denom > 0
                                        ? '${(d.cats[i].value / denom * 100).round()}%'
                                        : '';
                                  }(),
                                  style: TextStyle(color: fin.subtext, fontSize: 12.5)),'''
if 'fold<double>(0, (a, e) => a + e.value)' not in ins:
    if old_pct not in ins:
        raise SystemExit('category percent pattern missing')
    write('lib/screens/insights_screen.dart', ins.replace(old_pct, new_pct, 1))
    print('patched category percent denom')
else:
    print('skip category percent')

# Money analysis subtitle clarify lent is in spending
replace_once(
    'lib/screens/insights_screen.dart',
    '''                        Text(
                          'How this month moved your accounts. Invest is not spending.',
                          style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.35),
                        ),''',
    '''                        Text(
                          'Spending includes money given to people. Invest moves to goals and is listed separately.',
                          style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.35),
                        ),''',
    already='Spending includes money given to people',
)

# Category tap: use bucket label (invest / lent), not empty category name
replace_once(
    'lib/screens/insights_screen.dart',
    '''                          onTap: d.cats[i].key == null
                              ? null
                              : () => _showCategory(d.cats[i].key!,
                                  txns.category(d.cats[i].key)?.name ?? ''),''',
    '''                          onTap: d.cats[i].key == null
                              ? null
                              : () => _showCategory(
                                  d.cats[i].key!, _bucketLabel(d.cats[i].key, txns)),''',
    already='_bucketLabel(d.cats[i].key, txns)',
)

for path, needle, label in [
    ('lib/data/stats.dart', 'kUsageInvestId', 'invest bucket id'),
    ('lib/data/stats.dart', 'Include lent / people money', 'analysis uses moneyFlow'),
    ('lib/screens/insights_screen.dart', 'cats[kUsageInvestId]', 'invest in by category'),
    ('lib/screens/insights_screen.dart', 'Spending includes money given to people', 'analysis copy'),
]:
    ensure(path, needle, label)

print('finup13 complete')
PY

echo "FinUp Part 13 applied."
