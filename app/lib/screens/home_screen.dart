import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dashboard.dart';
import '../widgets/logo.dart';
import '../widgets/txn_tile.dart';
import 'account_editor.dart';
import 'add_txn_screen.dart';
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


class HomeScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const HomeScreen({super.key, this.onSeeAll});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pc = PageController(viewportFraction: 0.86);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));

  Widget _quick(FinColors fin, IconData icon, String label, Color color,
      TxnType type) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _open(AddTxnScreen(type: type)),
        child: Column(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: fin.text, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _stat(FinColors fin, IconData icon, Color color, String label,
      String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: fin.card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: fin.subtext, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.display(size: 20, color: fin.text)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final settings = context.watch<SettingsState>();
    final accounts = context.watch<AccountsState>();
    final txns = context.watch<TxnState>();
    final hide = settings.hideAmounts;
    final top = MediaQuery.of(context).padding.top;
    final list = accounts.accounts;
    final greeting =
        settings.userName.isEmpty ? 'Hello there' : 'Hi, ${settings.userName}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: () async {
          // Re-read ~14 days so available balance is taken from the latest bank SMS
          // even when those messages were already imported as transactions.
          final since = DateTime.now()
              .subtract(const Duration(days: 14))
              .millisecondsSinceEpoch;
          await txns.sync(accounts, sinceMs: since);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: EdgeInsets.only(top: top + 8, bottom: 26),
              decoration: BoxDecoration(
                color: fin.hero,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      const SizedBox(width: 8),
                      const FinUpLogo(size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(greeting,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (txns.syncing)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)),
                        ),
                      IconButton(
                        onPressed: () => settings.setHideAmounts(!hide),
                        icon: Icon(
                            hide
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => _open(const SettingsScreen()),
                        icon: const Icon(Icons.settings_rounded,
                            color: Colors.white),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(inr(accounts.total, hide: hide),
                              style: AppText.display(
                                  size: 38, color: Colors.white)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Total balance · ${list.length} ${list.length == 1 ? 'account' : 'accounts'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 8),
                    child: Row(children: [
                      const Expanded(
                        child: Text('My Accounts',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: () => _open(const AccountEditor()),
                        icon: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 18),
                        label: const Text('Add',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 190,
                    child: PageView.builder(
                      controller: _pc,
                      padEnds: false,
                      itemCount: list.length + 1,
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.only(
                            left: i == 0 ? 20 : 6, right: 6, bottom: 4),
                        child: i < list.length
                            ? AccountCard(
                                account: list[i],
                                hide: hide,
                                onTap: () =>
                                    _open(AccountEditor(account: list[i])))
                            : AddAccountCard(
                                onTap: () => _open(const AccountEditor())),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!txns.smsEnabled) ...[
                    GestureDetector(
                      onTap: () => _open(const SmsSetupScreen()),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: fin.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.lavender, width: 1.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.sms_rounded, color: AppColors.lavender),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Turn on SMS auto-tracking',
                                    style: TextStyle(
                                        color: fin.text,
                                        fontWeight: FontWeight.w700)),
                                Text('Log every bank transaction automatically',
                                    style: TextStyle(
                                        color: fin.subtext, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded, color: fin.subtext),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (txns.reviewCount > 0) ...[
                    ReviewBanner(count: txns.reviewCount),
                    const SizedBox(height: 16),
                  ],
                  Row(children: [
                    _quick(fin, Icons.north_east_rounded, 'Expense',
                        AppColors.expense, TxnType.expense),
                    _quick(fin, Icons.south_west_rounded, 'Income',
                        AppColors.income, TxnType.income),
                    _quick(fin, Icons.swap_horiz_rounded, 'Transfer',
                        AppColors.lavender, TxnType.transfer),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
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
                  ]),
                  const SizedBox(height: 24),
                  const DashboardSection(),
                ],
              ),
            ),
            const SizedBox(height: 130),
          ],
        ),
      ),
    );
  }
}
