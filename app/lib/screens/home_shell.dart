import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../cloud/sync.dart';
import '../data/db.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../native.dart';
import '../theme.dart';
import '../update/updater.dart';
import '../widgets/common.dart';
import 'account_editor.dart';
import 'activity_screen.dart';
import 'add_txn_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'people_screen.dart';
import 'tags_screen.dart';
import '../actions/quick_actions.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  DateTime? _lastCloudSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  bool get _cloudDue {
    final last = _lastCloudSync;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(hours: 1);
  }

  Future<void> _cloudSyncIfNeeded({bool force = false}) async {
    if (!await CloudSync.instance.isSignedIn) return;
    if (!force && !_cloudDue && !(await CloudSync.instance.isDirty)) return;
    final res = await CloudSync.instance.sync();
    _lastCloudSync = DateTime.now();
    if (!mounted) return;
    if (res.ok && (res.message.contains('Pulled') || res.message.contains('Synced'))) {
      await context.read<AccountsState>().load();
      await context.read<TxnState>().load();
    }
  }

  Future<void> _sync() async {
    if (!mounted) return;
    await handleLaunchAction(context);
    if (!mounted) return;
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    await txns.load();
    if (txns.smsEnabled) {
      await Native.ensureSmsReceive();
      await txns.sync(accounts);
    }
    await _cloudSyncIfNeeded(force: true);
    if (mounted) UpdateService.autoCheck(context);
  }

  void _openAdd() {
    final fin = context.fin;
    void go(Widget page) {
      Navigator.pop(context);
      Navigator.of(context).push(fadeRoute(page));
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add new', style: AppText.display(size: 20, color: fin.text)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  _AddTile(
                      icon: Icons.north_east_rounded,
                      label: 'Expense',
                      color: AppColors.expense,
                      onTap: () => go(const AddTxnScreen(type: TxnType.expense))),
                  _AddTile(
                      icon: Icons.south_west_rounded,
                      label: 'Income',
                      color: AppColors.income,
                      onTap: () => go(const AddTxnScreen(type: TxnType.income))),
                  _AddTile(
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
                      label: 'Lend / Borrow',
                      color: const Color(0xFFF4A261),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        openPeopleEntry(context);
                      }),
                  _AddTile(icon: Icons.mic_rounded, label: 'Voice', color: const Color(0xFF5DADE2), onTap: () { Navigator.pop(sheetContext); startVoiceEntry(context); }),
                  _AddTile(icon: Icons.document_scanner_rounded, label: 'Scan receipt', color: const Color(0xFF7BC67E), onTap: () { Navigator.pop(sheetContext); startReceiptScan(context); }),
                  _AddTile(icon: Icons.luggage_rounded, label: 'Trips & tags', color: const Color(0xFFD78FD3), onTap: () => go(const TagsScreen())),
                  _AddTile(icon: Icons.account_balance_wallet_rounded,
                      label: 'Account',
                      color: AppColors.pink,
                      onTap: () => go(const AccountEditor())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onSeeAll: () => setState(() => _tab = 1)),
          const ActivityScreen(),
          const PeopleScreen(),
          const InsightsScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        onAdd: _openAdd,
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: fin.text, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _BottomBar(
      {required this.index, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 72,
        decoration: BoxDecoration(
          color: fin.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(children: [
          _item(context, 0, Icons.grid_view_rounded),
          _item(context, 1, Icons.receipt_long_rounded),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAdd();
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [AppColors.lavender, AppColors.pink]),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lavender.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.add_rounded, color: AppColors.ink, size: 30),
                ),
              ),
            ),
          ),
          _item(context, 2, Icons.people_alt_rounded),
          _item(context, 3, Icons.pie_chart_rounded),
        ]),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData icon) {
    final fin = context.fin;
    final selected = i == index;
    final active = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(i);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: selected ? active : fin.subtext, size: 26),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 18 : 0,
              height: 4,
              decoration: BoxDecoration(
                  color: active, borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }
}
