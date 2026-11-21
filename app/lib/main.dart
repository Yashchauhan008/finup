import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db.dart';
import 'data/repo.dart';
import 'data/tags_repo.dart';
import 'native.dart';
import 'screens/splash_screen.dart';
import 'security/lock.dart';
import 'state/app_state.dart';
import 'state/txn_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Native.init();
  await AppDatabase.instance.init();
  await AppDatabase.instance.ensureSchema();
  await AppDatabase.instance.ensureTagSchema();
  final settings = SettingsState();
  await settings.load();
  final accounts = AccountsState();
  await accounts.load();
  final txns = TxnState();
  await txns.load();
  if (settings.onboarded) {
    await Native.scheduleReminder(settings.reminderTime.hour,
        settings.reminderTime.minute, await ReminderPrefs.isOn());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsState>.value(value: settings),
        ChangeNotifierProvider<AccountsState>.value(value: accounts),
        ChangeNotifierProvider<TxnState>.value(value: txns),
      ],
      child: const FinUpApp(),
    ),
  );
}

class FinUpApp extends StatelessWidget {
  const FinUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'FinUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(),
    );
  }
}
