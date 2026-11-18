#!/usr/bin/env bash
# FinUp Part 12 — Invest visibility, Home/Insights cleanup, Activity filter, shortcut
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
        print(f'skip {path} ({already[:48]})')
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}:\n---\n{old[:240]}\n---')
    write(path, text.replace(old, new, 1))
    print(f'patched {path}')

def ensure(path: str, needle: str, label: str):
    if needle not in read(path):
        raise SystemExit(f'missing {label} in {path}')
    print(f'ok {label}')

# ===== 1) + sheet: Invest tile =====
replace_once(
    'lib/screens/home_shell.dart',
    '''                  _AddTile(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transfer',
                      color: AppColors.lavender,
                      onTap: () => go(const AddTxnScreen(type: TxnType.transfer))),
                  _AddTile(
                      icon: Icons.people_alt_rounded,
                      label: 'Lend / Borrow',''',
    '''                  _AddTile(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transfer',
                      color: AppColors.lavender,
                      onTap: () => go(const AddTxnScreen(type: TxnType.transfer))),
                  _AddTile(
                      icon: Icons.savings_rounded,
                      label: 'Invest',
                      color: const Color(0xFF5B8DEF),
                      onTap: () => go(const AddTxnScreen(type: TxnType.invest))),
                  _AddTile(
                      icon: Icons.people_alt_rounded,
                      label: 'Lend / Borrow',''',
    already="label: 'Invest'",
)

# ===== 2) Goals card: Add money → Invest =====
replace_once(
    'lib/screens/goals_screen.dart',
    "label: const Text('Add money'),",
    "label: const Text('Invest'),",
    already="label: const Text('Invest'),",
)

# ===== 3) Home: remove Recent list (Activity owns it) =====
home = read('lib/screens/home_screen.dart')
if "Text('Recent'" not in home:
    print('skip home Recent (already removed)')
else:
    replace_once(
        'lib/screens/home_screen.dart',
        '''                  const SizedBox(height: 24),
                  Row(children: [
                    Text('Recent',
                        style: TextStyle(
                            color: fin.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                        onPressed: widget.onSeeAll,
                        child: const Text('See all')),
                  ]),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: fin.card,
                        borderRadius: BorderRadius.circular(24)),
                    child: txns.recent.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                  'No transactions yet. Tap + or turn on SMS tracking.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: fin.subtext)),
                            ),
                          )
                        : Column(children: [
                            for (final t in txns.recent)
                              TxnTile(
                                  txn: t,
                                  hide: hide,
                                  showDate: true,
                                  onTap: () => _open(AddTxnScreen(editing: t))),
                          ]),
                  ),
                  const SizedBox(height: 24),
                  const DashboardSection(),''',
        '''                  const SizedBox(height: 24),
                  const DashboardSection(),''',
    )
    if "Text('Recent'" in read('lib/screens/home_screen.dart'):
        raise SystemExit('Home Recent section still present after patch')
    print('ok home Recent removed')

# ===== 4) Activity filter: Invest =====
replace_once(
    'lib/screens/activity_screen.dart',
    '''      child: Row(children: [
        item('all', 'All'),
        item('expense', 'Spending'),
        item('income', 'Income'),
      ]),''',
    '''      child: Row(children: [
        item('all', 'All'),
        item('expense', 'Spend'),
        item('income', 'Income'),
        item('invest', 'Invest'),
      ]),''',
    already="item('invest', 'Invest')",
)

# Slightly smaller filter labels so 4 fit
act = read('lib/screens/activity_screen.dart')
if 'fontSize: 12.5' not in act and "item('invest'" in act:
    # try shrink chip text if there's a fixed style — optional
    pass

# ===== 5) stats: month money analysis helper =====
replace_once(
    'lib/data/stats.dart',
    '''  /// Money in/out including lent, borrowed and settlements (full usage).
  Future<(double, double)> moneyFlow(DateTime from, DateTime to) async {
    double inc = 0;
    double exp = 0;
    for (final r in await _rows(from, to)) {
      final a = (r['amount'] as num).toDouble();
      if (r['type'] == 'income') {
        inc += a;
      } else if (r['type'] == 'expense') {
        exp += a;
      }
    }
    return (inc, exp);
  }''',
    '''  /// Money in/out including lent, borrowed and settlements (full usage).
  Future<(double, double)> moneyFlow(DateTime from, DateTime to) async {
    double inc = 0;
    double exp = 0;
    for (final r in await _rows(from, to)) {
      final a = (r['amount'] as num).toDouble();
      if (r['type'] == 'income') {
        inc += a;
      } else if (r['type'] == 'expense') {
        exp += a;
      }
    }
    return (inc, exp);
  }

  /// Month cash story for Insights: opening carry, income, spending, invested.
  /// Opening is reconstructed from current account totals rolled back by this month.
  Future<({double opening, double income, double spending, double invested, double closing})>
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
    already='monthMoneyAnalysis',
)

# ===== 6) Insights: drop payees + add Money analysis =====
# Extend _Insight and _load; replace parties card with analysis card.
replace_once(
    'lib/screens/insights_screen.dart',
    '''class _Insight {
  final double total;
  final double last;
  final List<MapEntry<int?, double>> cats;
  final List<(String, double, int)> parties;
  final Map<int, double> daily;
  const _Insight(this.total, this.last, this.cats, this.parties, this.daily);
}''',
    '''class _Insight {
  final double total;
  final double last;
  final List<MapEntry<int?, double>> cats;
  final Map<int, double> daily;
  final double opening;
  final double income;
  final double spending;
  final double invested;
  final double closing;
  const _Insight(
    this.total,
    this.last,
    this.cats,
    this.daily, {
    required this.opening,
    required this.income,
    required this.spending,
    required this.invested,
    required this.closing,
  });
}''',
    already='final double invested;',
)

replace_once(
    'lib/screens/insights_screen.dart',
    '''    final cur = await db.moneyFlow(s, e);
    final prev = await db.moneyFlow(ps, pe);
    final cats = await db.usageBreakdown(s, e, _type);
    final parties = await db.topParties(s, e, type: _type);
    final daily = await db.dailyTotals(s, e, _type);
    final list = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final inc = _type == 'income';
    return _Insight(inc ? cur.$1 : cur.$2, inc ? prev.$1 : prev.$2, list,
        parties, daily);
  }''',
    '''    final cur = await db.moneyFlow(s, e);
    final prev = await db.moneyFlow(ps, pe);
    final cats = await db.usageBreakdown(s, e, _type);
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
    already='monthMoneyAnalysis(s, e)',
)

# Remove maxParty / parties UI usage — replace parties card with money analysis
replace_once(
    'lib/screens/insights_screen.dart',
    '''                final colors = <Color>[
                  for (final e in d.cats) txns.category(e.key)?.colorValue ?? fin.subtext
                ];
                final maxParty = d.parties.isEmpty ? 1.0 : d.parties.first.$2;
                final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;''',
    '''                final colors = <Color>[
                  for (final e in d.cats)
                    _bucketColor(e.key, txns, fin)
                ];
                final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;''',
    already='_bucketColor(e.key, txns, fin)',
)

# Fix category list to use bucket helpers (people buckets) — already had wrong cat-only names in places
# Replace "Where it went" card with Money analysis
replace_once(
    'lib/screens/insights_screen.dart',
    '''                  const SizedBox(height: 14),
                  _card(
                    fin,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(fin, isExp ? 'Where it went' : 'Who paid you'),
                        if (d.parties.isEmpty)
                          Text('No payee details this month.',
                              style: TextStyle(color: fin.subtext)),
                        for (final p in d.parties)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(prettyParty(p.$1),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: fin.text,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  Text('${p.$3}x  ',
                                      style: TextStyle(
                                          color: fin.subtext, fontSize: 12)),
                                  Text(inr(p.$2, hide: hide, decimals: 0),
                                      style: TextStyle(
                                          color: fin.text,
                                          fontWeight: FontWeight.w700)),
                                ]),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: maxParty > 0 ? p.$2 / maxParty : 0,
                                    minHeight: 6,
                                    backgroundColor: fin.divider,
                                    color: isExp ? AppColors.pink : AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    fin,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(fin, isExp ? 'Daily spending' : 'Daily income'),''',
    '''                  const SizedBox(height: 14),
                  _card(
                    fin,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(fin, 'Money analysis'),
                        const SizedBox(height: 4),
                        Text(
                          'How this month moved your accounts. Invest is not spending.',
                          style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        _kv(fin, 'From last month', inr(d.opening, hide: hide, decimals: 0)),
                        _kv(fin, 'Income', inr(d.income, hide: hide, decimals: 0),
                            valueColor: AppColors.income),
                        _kv(fin, 'Spending', inr(d.spending, hide: hide, decimals: 0),
                            valueColor: AppColors.expense),
                        _kv(fin, 'Invested in goals', inr(d.invested, hide: hide, decimals: 0),
                            valueColor: const Color(0xFF5B8DEF)),
                        const Divider(height: 22),
                        _kv(fin, 'In accounts now', inr(d.closing, hide: hide, decimals: 0),
                            bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    fin,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(fin, isExp ? 'Daily spending' : 'Daily income'),''',
    already='Money analysis',
)

# Add _kv helper on InsightsScreen state if missing
ins = read('lib/screens/insights_screen.dart')
if 'Widget _kv(' not in ins:
    helper = '''
  Widget _kv(FinColors fin, String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: fin.subtext,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ),
        Text(value,
            style: TextStyle(
                color: valueColor ?? fin.text,
                fontWeight: FontWeight.w700,
                fontSize: bold ? 16 : 14)),
      ]),
    );
  }

'''
    # insert before build(
    marker = '  @override\n  Widget build(BuildContext context) {'
    if marker not in ins:
        raise SystemExit('insights build marker missing for _kv')
    write('lib/screens/insights_screen.dart', ins.replace(marker, helper + marker, 1))
    print('patched insights _kv helper')

# Category rows: use bucket label/icon/color (fixes lent buckets after color change)
replace_once(
    'lib/screens/insights_screen.dart',
    '''                                child: Icon(
                                    txns.category(d.cats[i].key)?.icon ??
                                        Icons.help_outline_rounded,
                                    color: colors[i],
                                    size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  txns.category(d.cats[i].key)?.name ??
                                      'Needs review',
                                  style: TextStyle(
                                      color: fin.text, fontWeight: FontWeight.w600),
                                ),
                              ),''',
    '''                                child: Icon(
                                    _bucketIcon(d.cats[i].key, txns),
                                    color: colors[i],
                                    size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _bucketLabel(d.cats[i].key, txns),
                                  style: TextStyle(
                                      color: fin.text, fontWeight: FontWeight.w600),
                                ),
                              ),''',
    already='_bucketIcon(d.cats[i].key, txns)',
)

# ===== 7) Long-press shortcut: Invest (replace Review) =====
# strings
if Path('android/app/src/main/res/values/finup_strings.xml').exists():
    replace_once(
        'android/app/src/main/res/values/finup_strings.xml',
        '''    <string name="sc_review_short">Review</string>
    <string name="sc_review_long">Review transactions</string>''',
        '''    <string name="sc_invest_short">Invest</string>
    <string name="sc_invest_long">Invest into a savings goal</string>''',
        already='sc_invest_short',
    )
elif Path('android/app/src/main/res/values/strings.xml').exists():
    # may already be in finup_strings only
    pass

# shortcuts.xml — after finup7/9 path
sx = 'android/app/src/main/res/xml/shortcuts.xml'
if Path(sx).exists():
    text = read(sx)
    if 'add_invest' not in text and 'invest' not in text.lower():
        old = '''    <shortcut android:shortcutId="review" android:enabled="true" android:icon="@drawable/sc_review"
        android:shortcutShortLabel="@string/sc_review_short" android:shortcutLongLabel="@string/sc_review_long">
        <intent android:action="finup.review" android:targetPackage="com.yash.finup"
            android:targetClass="com.yash.finup.MainActivity">
            <extra android:name="finup_action" android:value="review"/>
        </intent>
    </shortcut>'''
        new = '''    <shortcut android:shortcutId="invest" android:enabled="true" android:icon="@drawable/sc_add"
        android:shortcutShortLabel="@string/sc_invest_short" android:shortcutLongLabel="@string/sc_invest_long">
        <intent android:action="finup.invest" android:targetPackage="com.yash.finup"
            android:targetClass="com.yash.finup.MainActivity">
            <extra android:name="finup_action" android:value="invest"/>
        </intent>
    </shortcut>'''
        if old not in text:
            # try looser
            raise SystemExit('shortcuts review block not found')
        write(sx, text.replace(old, new, 1))
        print('patched shortcuts.xml')
    else:
        print('skip shortcuts (already invest)')

replace_once(
    'lib/actions/quick_actions.dart',
    '''    case 'add_expense':
      Navigator.of(context).push(fadeRoute(const AddTxnScreen()));
    case 'voice':''',
    '''    case 'add_expense':
      Navigator.of(context).push(fadeRoute(const AddTxnScreen()));
    case 'invest':
      Navigator.of(context).push(fadeRoute(const AddTxnScreen(type: TxnType.invest)));
    case 'voice':''',
    already="case 'invest':",
)

# ===== verify =====
checks = [
    ('lib/screens/home_shell.dart', "label: 'Invest'", '+ Invest tile'),
    ('lib/screens/goals_screen.dart', "label: const Text('Invest')", 'Goals Invest button'),
    ('lib/screens/activity_screen.dart', "item('invest', 'Invest')", 'Activity Invest filter'),
    ('lib/data/stats.dart', 'monthMoneyAnalysis', 'month analysis API'),
    ('lib/screens/insights_screen.dart', 'Money analysis', 'Insights analysis card'),
    ('lib/screens/insights_screen.dart', 'Invested in goals', 'Invested row'),
    ('lib/actions/quick_actions.dart', "case 'invest':", 'Invest shortcut handler'),
]
for path, needle, label in checks:
    ensure(path, needle, label)

if "Text('Recent'" in read('lib/screens/home_screen.dart'):
    raise SystemExit('Recent still on home')
if 'Where it went' in read('lib/screens/insights_screen.dart'):
    raise SystemExit('Where it went still in insights')
print('finup12 complete')
PY

echo "FinUp Part 12 applied."
