import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';

class SettingsState extends ChangeNotifier {
  late SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.system;
  bool onboarded = false;
  String userName = '';
  bool hideAmounts = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 21, minute: 0);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final mode = _prefs.getInt('themeMode') ?? 0;
    themeMode = (mode >= 0 && mode < ThemeMode.values.length)
        ? ThemeMode.values[mode]
        : ThemeMode.system;
    onboarded = _prefs.getBool('onboarded') ?? false;
    userName = _prefs.getString('userName') ?? '';
    hideAmounts = _prefs.getBool('hideAmounts') ?? false;
    reminderTime = TimeOfDay(
      hour: _prefs.getInt('remH') ?? 21,
      minute: _prefs.getInt('remM') ?? 0,
    );
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _prefs.setInt('themeMode', m.index);
  }

  Future<void> setUserName(String n) async {
    userName = n;
    notifyListeners();
    await _prefs.setString('userName', n);
  }

  Future<void> setHideAmounts(bool v) async {
    hideAmounts = v;
    notifyListeners();
    await _prefs.setBool('hideAmounts', v);
  }

  Future<void> setReminderTime(TimeOfDay t) async {
    reminderTime = t;
    notifyListeners();
    await _prefs.setInt('remH', t.hour);
    await _prefs.setInt('remM', t.minute);
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    await _prefs.setBool('onboarded', true);
    notifyListeners();
  }
}

class AccountsState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;
  List<Account> accounts = [];

  double get total => accounts.fold<double>(0, (s, a) => s + a.balance);

  Future<void> load() async {
    accounts = await _db.accounts();
    notifyListeners();
  }

  Future<void> save(Account a) async {
    if (a.id == null) {
      await _db.insertAccount(a);
    } else {
      await _db.updateAccount(a);
    }
    await load();
  }

  Future<void> remove(int id) async {
    await _db.removeAccount(id);
    await load();
  }
}
