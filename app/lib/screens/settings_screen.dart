import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backup.dart';
import '../data/db.dart';
import '../native.dart';
import '../security/lock.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'account_editor.dart';
import 'cloud_account_screen.dart';
import 'extra_settings.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'goals_screen.dart';
import 'intro_screen.dart';
import 'legal_screen.dart';
import 'sms_setup_screen.dart';
import '../cloud/sync.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remOn = true;
  bool _lockOn = false;
  bool _bioOn = false;
  bool _canBio = false;
  bool _busy = false;
  bool _cloudOn = false;
  String? _cloudEmail;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final rem = await ReminderPrefs.isOn();
    final lock = await LockPrefs.enabled();
    final bio = await LockPrefs.biometric();
    final can = await Native.canBiometric();
    final cloudOn = await CloudSync.instance.isSignedIn;
    final cloudEmail = await CloudSync.instance.email;
    if (!mounted) return;
    setState(() {
      _remOn = rem;
      _lockOn = lock;
      _bioOn = bio;
      _canBio = can;
      _cloudOn = cloudOn;
      _cloudEmail = cloudEmail;
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(fadeRoute(page));
  }

  Future<void> _editName(SettingsState s) async {
    final c = TextEditingController(text: s.userName);
    final result = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
            controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) await s.setUserName(result);
  }

  Future<void> _pickTime(SettingsState s) async {
    final picked = await showTimePicker(context: context, initialTime: s.reminderTime);
    if (picked == null) return;
    await s.setReminderTime(picked);
    await Native.requestNotifications();
    await Native.scheduleReminder(picked.hour, picked.minute, _remOn);
  }

  Future<void> _toggleReminder(SettingsState s, bool v) async {
    setState(() => _remOn = v);
    await ReminderPrefs.setOn(v);
    if (v) await Native.requestNotifications();
    await Native.scheduleReminder(s.reminderTime.hour, s.reminderTime.minute, v);
  }

  Future<void> _toggleLock(bool v) async {
    if (v) {
      final ok = await Navigator.of(context)
          .push<bool>(fadeRoute<bool>(const PinSetupScreen()));
      if (ok == true && mounted) {
        setState(() => _lockOn = true);
        _snack('App lock is on.');
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Turn off app lock?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Turn off')),
          ],
        ),
      );
      if (ok == true) {
        await LockPrefs.clear();
        if (mounted) {
          setState(() {
            _lockOn = false;
            _bioOn = false;
          });
        }
      }
    }
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      final ok = await AppLockGate.suspendWhile(
          () => Native.authenticate('Confirm your fingerprint'));
      if (!ok) return;
    }
    await LockPrefs.setBiometric(v);
    if (mounted) setState(() => _bioOn = v);
  }

  Future<void> _rescan() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final since =
        DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
    final n = await txns.sync(accounts, sinceMs: since);
    if (mounted) {
      _snack(n == 0 ? 'No new transactions found.' : 'Added $n new transactions.');
    }
  }

  String get _stamp => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

  Future<void> _backup() async {
    setState(() => _busy = true);
    final json = await AppDatabase.instance.exportJson();
    final ok = await AppLockGate.suspendWhile(() => Native.saveDocument(
        'FinUp-backup-$_stamp.json',
        'application/json',
        Uint8List.fromList(utf8.encode(json))));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _snack('Backup saved.');
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    final csv = await AppDatabase.instance.exportCsv();
    final ok = await AppLockGate.suspendWhile(() => Native.saveDocument(
        'FinUp-transactions-$_stamp.csv',
        'text/csv',
        Uint8List.fromList(utf8.encode(csv))));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _snack('CSV exported.');
  }

  Future<void> _restore() async {
    final accounts = context.read<AccountsState>();
    final txns = context.read<TxnState>();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore a backup?'),
        content: const Text(
            'Everything currently in FinUp will be replaced by the backup file you choose.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Choose file')),
        ],
      ),
    );
    if (go != true) return;
    final bytes = await AppLockGate.suspendWhile(() => Native.openDocument());
    if (bytes == null) return;
    var ok = false;
    try {
      ok = await AppDatabase.instance.importJson(utf8.decode(bytes));
    } catch (_) {
      ok = false;
    }
    if (ok) {
      await CloudSync.instance.markDirty();
      await accounts.load();
      await txns.load();
      if (await CloudSync.instance.isSignedIn) {
        await CloudSync.instance.sync();
      }
    }
    if (mounted) _snack(ok ? 'Backup restored.' : 'That file is not a FinUp backup.');
  }

  Future<void> _deleteAll() async {
    final settings = context.read<SettingsState>();
    final accounts = context.read<AccountsState>();
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
            'This removes all accounts, transactions, people, budgets, goals and settings from this phone. Make a backup first if you might need it. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete everything',
                  style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.wipeAll();
    final p = await SharedPreferences.getInstance();
    await p.clear();
    await Native.scheduleReminder(21, 0, false);
    await settings.load();
    await settings.setThemeMode(ThemeMode.system);
    await accounts.load();
    await txns.load();
    nav.pushAndRemoveUntil(fadeRoute(const IntroScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final txns = context.watch<TxnState>();
    final accounts = context.watch<AccountsState>().accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2), child: LinearProgressIndicator())
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _Section(title: 'Profile', children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Name'),
              subtitle: Text(s.userName.isEmpty ? 'Not set' : s.userName),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _editName(s),
            ),
            ListTile(
              leading: Icon(Icons.cloud_sync_rounded,
                  color: _cloudOn ? AppColors.income : null),
              title: Text(_cloudOn ? 'Cloud sync on' : 'Cloud sync'),
              subtitle: Text(_cloudOn
                  ? (_cloudEmail ?? 'Signed in · 2-way with web')
                  : 'Sign in to sync with FinUp web'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await _open(const CloudAccountScreen());
                if (mounted) _init();
              },
            ),
          ]),
          _Section(title: 'Appearance', children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_rounded)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded)),
                    ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_rounded)),
                  ],
                  selected: {s.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => s.setThemeMode(v.first),
                ),
              ),
            ),
          ]),
          _Section(title: 'Security', children: [
            SwitchListTile(
              secondary: const Icon(Icons.lock_rounded),
              title: const Text('App lock'),
              subtitle: const Text('Ask for a PIN when opening FinUp'),
              value: _lockOn,
              onChanged: _toggleLock,
            ),
            if (_lockOn && _canBio)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded),
                title: const Text('Unlock with fingerprint'),
                value: _bioOn,
                onChanged: _toggleBio,
              ),
            if (_lockOn)
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Change PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final ok = await Navigator.of(context)
                      .push<bool>(fadeRoute<bool>(const PinSetupScreen()));
                  if (ok == true && mounted) _snack('PIN changed.');
                },
              ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded),
              title: const Text('Hide amounts on Home'),
              value: s.hideAmounts,
              onChanged: s.setHideAmounts,
            ),
          ]),
          _Section(title: 'SMS tracking', children: [
            ListTile(
              leading: Icon(Icons.sms_rounded,
                  color: txns.smsEnabled ? AppColors.income : null),
              title: Text(txns.smsEnabled ? 'Auto-tracking is on' : 'Turn on auto-tracking'),
              subtitle: Text(txns.smsEnabled
                  ? 'New bank SMS are imported each time you open FinUp'
                  : 'Allow FinUp to read bank SMS'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const SmsSetupScreen()),
            ),
            if (txns.smsEnabled)
              ListTile(
                leading: txns.syncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                title: const Text('Scan last 3 months again'),
                subtitle: const Text('Duplicates are skipped automatically'),
                onTap: txns.syncing ? null : _rescan,
              ),
          ]),
          _Section(title: 'Organise', children: [
            ListTile(
              leading: const Icon(Icons.category_rounded),
              title: const Text('Categories'),
              subtitle: Text('${txns.categories.length} categories'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const CategoriesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.donut_large_rounded),
              title: const Text('Budgets'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const BudgetsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Savings goals'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const GoalsScreen()),
            ),
          ]),
          _Section(title: 'Accounts', children: [
            for (final a in accounts)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradientAt(a.colorIndex),
                      shape: BoxShape.circle),
                  child: Icon(a.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text((a.last4 != null && a.last4!.isNotEmpty)
                    ? '${a.type.label} · ••${a.last4}'
                    : a.type.label),
                trailing: Text(inr(a.balance, hide: s.hideAmounts)),
                onTap: () => _open(AccountEditor(account: a)),
              ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Add account'),
              onTap: () => _open(const AccountEditor()),
            ),
          ]),
          _Section(title: 'Notifications', children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_rounded),
              title: const Text('Daily review reminder'),
              value: _remOn,
              onChanged: (v) => _toggleReminder(s, v),
            ),
            ListTile(
              enabled: _remOn,
              leading: const Icon(Icons.alarm_rounded),
              title: const Text('Reminder time'),
              subtitle: Text(s.reminderTime.format(context)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickTime(s),
            ),
          ]),
          _Section(title: 'Your data', children: [
            ListTile(
              leading: const Icon(Icons.backup_rounded),
              title: const Text('Back up to a file'),
              subtitle: const Text('Save everything as one .json file'),
              onTap: _busy ? null : _backup,
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore_rounded),
              title: const Text('Restore from backup'),
              onTap: _busy ? null : _restore,
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded),
              title: const Text('Export transactions (CSV)'),
              subtitle: const Text('Open in Excel or Google Sheets'),
              onTap: _busy ? null : _exportCsv,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.expense),
              title: const Text('Delete all data',
                  style: TextStyle(color: AppColors.expense)),
              onTap: _deleteAll,
            ),
          ]),
          const ExtraSettings(),
          _Section(title: 'About', children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About FinUp'),
              subtitle: const Text('Version 2.0.0'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const AboutScreenV2()),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: const Text('Terms & Conditions'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const LegalScreen(
                  title: 'Terms & Conditions',
                  updated: '13 October 2026',
                  sections: termsSections)),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_rounded),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const LegalScreen(
                  title: 'Privacy Policy',
                  updated: '13 October 2026',
                  sections: privacySections)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
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
}
