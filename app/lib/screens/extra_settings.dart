import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native.dart';
import '../security/lock.dart';
import '../theme.dart';
import '../update/updater.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'update_screen.dart';

class ExtraSettings extends StatefulWidget {
  const ExtraSettings({super.key});

  @override
  State<ExtraSettings> createState() => _ExtraSettingsState();
}

class _ExtraSettingsState extends State<ExtraSettings> with WidgetsBindingObserver {
  bool _sms = true;
  bool _budget = true;
  bool _restricted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final sms = await Native.getSmsAlerts();
    final p = await SharedPreferences.getInstance();
    final b = p.getBool('budgetAlerts') ?? true;
    final r = await Native.batteryOptimized();
    if (!mounted) return;
    setState(() {
      _sms = sms;
      _budget = b;
      _restricted = r;
    });
  }

  Widget _section(FinColors fin, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  color: fin.subtext,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ),
        Material(
          color: fin.card,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    void open(Widget p) => Navigator.of(context).push(fadeRoute(p));
    return Column(children: [
      _section(fin, 'Smart alerts', [
        SwitchListTile(
          secondary: const Icon(Icons.sms_rounded),
          title: const Text('Instant SMS alerts'),
          subtitle: const Text('Notify on every bank SMS with category buttons'),
          value: _sms,
          onChanged: (v) async {
            setState(() => _sms = v);
            await Native.setSmsAlerts(v);
            if (v) {
              await Native.ensureSmsReceive();
              await Native.requestNotifications();
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.warning_amber_rounded),
          title: const Text('Budget alerts'),
          subtitle: const Text('Notify at 80% and 100% of a budget'),
          value: _budget,
          onChanged: (v) async {
            setState(() => _budget = v);
            final p = await SharedPreferences.getInstance();
            await p.setBool('budgetAlerts', v);
            if (v) await Native.requestNotifications();
          },
        ),
        ListTile(
          leading: Icon(Icons.battery_charging_full_rounded,
              color: _restricted ? kAmber : AppColors.income),
          title: const Text('Background reliability'),
          subtitle: Text(_restricted
              ? 'Battery saver may delay alerts. Tap to let FinUp run in the background.'
              : 'FinUp is allowed to run in the background'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Native.openBatterySettings(),
        ),
      ]),
      _section(fin, 'Updates', [
        ListTile(
          leading: const Icon(Icons.system_update_rounded),
          title: const Text('Check for updates'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => open(const UpdateScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.share_rounded),
          title: const Text('Share FinUp'),
          subtitle: const Text('Send the download link to a friend'),
          onTap: () =>
              AppLockGate.suspendWhile(() => Native.shareText(UpdateService.shareText)),
        ),
      ]),
      _section(fin, 'Developer', [
        ListTile(
          leading: const Text('❤️', style: TextStyle(fontSize: 22)),
          title: const Text('Made by Yash with ❤️'),
          subtitle: const Text('yashchauhan.pro'),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => Native.openUrl(kPortfolio),
        ),
      ]),
    ]);
  }
}
