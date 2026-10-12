#!/usr/bin/env bash
set -euo pipefail
rm -rf app
mkdir -p app/lib/data app/lib/state app/lib/widgets app/lib/screens app/android/app/src/main
cd app

############################ pubspec.yaml ############################
cat > pubspec.yaml <<'__END__'
name: finup
description: FinUp - private, offline expense manager
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  sqflite: ^2.3.3
  path: ^1.9.0
  shared_preferences: ^2.2.3
  google_fonts: ^6.2.1
  intl: '>=0.19.0 <1.0.0'

flutter:
  uses-material-design: true
__END__

############################ AndroidManifest ############################
cat > android/app/src/main/AndroidManifest.xml <<'__END__'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:label="FinUp"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
__END__

############################ lib/main.dart ############################
cat > lib/main.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.init();
  final settings = SettingsState();
  await settings.load();
  final accounts = AccountsState();
  await accounts.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsState>.value(value: settings),
        ChangeNotifierProvider<AccountsState>.value(value: accounts),
      ],
      child: const FinUpApp(),
    ),
  );
}

class FinUpApp extends StatelessWidget {
  const FinUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode =
        context.select<SettingsState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'FinUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
__END__

############################ lib/theme.dart ############################
cat > lib/theme.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppColors {
  static const indigo = Color(0xFF2D2A6E);
  static const indigoDeep = Color(0xFF1C1A47);
  static const lavender = Color(0xFF8E8BEA);
  static const pink = Color(0xFFEBB9D6);
  static const ink = Color(0xFF15151C);
  static const income = Color(0xFF34B892);
  static const expense = Color(0xFFE5677F);

  static const List<LinearGradient> cardGradients = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7471E3), Color(0xFFB7A2EA), Color(0xFFF1C6DD)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A36A0), Color(0xFF6F6BDA)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF15151C), Color(0xFF3B3B4D)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE79BC0), Color(0xFFF6D4C2)],
    ),
  ];

  static LinearGradient gradientAt(int i) =>
      cardGradients[i.abs() % cardGradients.length];
}

@immutable
class FinColors extends ThemeExtension<FinColors> {
  final Color bg;
  final Color card;
  final Color text;
  final Color subtext;
  final Color hero;
  final Color divider;

  const FinColors({
    required this.bg,
    required this.card,
    required this.text,
    required this.subtext,
    required this.hero,
    required this.divider,
  });

  static const light = FinColors(
    bg: Color(0xFFEEF0F7),
    card: Colors.white,
    text: AppColors.ink,
    subtext: Color(0xFF8B8BA1),
    hero: AppColors.indigo,
    divider: Color(0xFFE2E3EE),
  );

  static const dark = FinColors(
    bg: Color(0xFF0D0D12),
    card: Color(0xFF1A1A24),
    text: Color(0xFFF2F2F7),
    subtext: Color(0xFF8E8EA6),
    hero: AppColors.indigoDeep,
    divider: Color(0xFF2A2A37),
  );

  @override
  FinColors copyWith({
    Color? bg,
    Color? card,
    Color? text,
    Color? subtext,
    Color? hero,
    Color? divider,
  }) {
    return FinColors(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      text: text ?? this.text,
      subtext: subtext ?? this.subtext,
      hero: hero ?? this.hero,
      divider: divider ?? this.divider,
    );
  }

  @override
  FinColors lerp(ThemeExtension<FinColors>? other, double t) {
    if (other is! FinColors) return this;
    return FinColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtext: Color.lerp(subtext, other.subtext, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension FinContext on BuildContext {
  FinColors get fin => Theme.of(this).extension<FinColors>() ?? FinColors.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppText {
  static TextStyle display({
    double size = 32,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) {
    try {
      return GoogleFonts.getFont(
        'Unbounded',
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: -0.5,
      );
    } catch (_) {
      return TextStyle(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      );
    }
  }
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final fin = isDark ? FinColors.dark : FinColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.lavender,
      brightness: b,
    ).copyWith(
      primary: isDark ? AppColors.lavender : AppColors.indigo,
      onPrimary: Colors.white,
      secondary: AppColors.pink,
      surface: fin.card,
      onSurface: fin.text,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: fin.bg,
    );

    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.getTextTheme('DM Sans', base.textTheme);
    } catch (_) {
      textTheme = base.textTheme;
    }

    return base.copyWith(
      textTheme: textTheme.apply(bodyColor: fin.text, displayColor: fin.text),
      extensions: <ThemeExtension<dynamic>>[fin],
      dividerColor: fin.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: fin.bg,
        foregroundColor: fin.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fin.card,
        hintStyle: TextStyle(color: fin.subtext),
        labelStyle: TextStyle(color: fin.subtext),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: fin.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

String inr(double v, {bool hide = false, int decimals = 2}) {
  if (hide) return '₹ • • • •';
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimals,
  ).format(v);
}
__END__

############################ lib/data/db.dart ############################
cat > lib/data/db.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ---------------- Accounts ----------------

enum AccountType { bank, cash, card, wallet }

extension AccountTypeX on AccountType {
  String get label => switch (this) {
        AccountType.bank => 'Bank',
        AccountType.cash => 'Cash',
        AccountType.card => 'Credit Card',
        AccountType.wallet => 'Wallet',
      };

  IconData get icon => switch (this) {
        AccountType.bank => Icons.account_balance_rounded,
        AccountType.cash => Icons.payments_rounded,
        AccountType.card => Icons.credit_card_rounded,
        AccountType.wallet => Icons.account_balance_wallet_rounded,
      };
}

class Account {
  final int? id;
  final String name;
  final AccountType type;
  final String? bank;
  final String? last4;
  final double balance;
  final int colorIndex;
  final DateTime? balanceUpdatedAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.bank,
    this.last4,
    this.balance = 0,
    this.colorIndex = 0,
    this.balanceUpdatedAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type.name,
        'bank': bank,
        'last4': last4,
        'balance': balance,
        'color_index': colorIndex,
        'balance_updated_at': balanceUpdatedAt?.millisecondsSinceEpoch,
      };

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: AccountType.values.byName(m['type'] as String),
        bank: m['bank'] as String?,
        last4: m['last4'] as String?,
        balance: (m['balance'] as num?)?.toDouble() ?? 0,
        colorIndex: (m['color_index'] as int?) ?? 0,
        balanceUpdatedAt: m['balance_updated_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                m['balance_updated_at'] as int),
      );
}

// ---------------- Categories ----------------

const Map<String, IconData> kCategoryIcons = {
  'food': Icons.restaurant_rounded,
  'grocery': Icons.local_grocery_store_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'transport': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'bills': Icons.receipt_rounded,
  'rent': Icons.home_rounded,
  'health': Icons.favorite_rounded,
  'entertainment': Icons.movie_rounded,
  'education': Icons.school_rounded,
  'travel': Icons.flight_rounded,
  'care': Icons.spa_rounded,
  'gift': Icons.card_giftcard_rounded,
  'other': Icons.category_rounded,
  'salary': Icons.work_rounded,
  'business': Icons.storefront_rounded,
  'refund': Icons.replay_rounded,
  'interest': Icons.savings_rounded,
  'other_income': Icons.attach_money_rounded,
};

class Category {
  final int? id;
  final String name;
  final String iconKey;
  final int color;
  final String kind; // expense | income
  final int sort;

  const Category({
    this.id,
    required this.name,
    required this.iconKey,
    required this.color,
    required this.kind,
    this.sort = 0,
  });

  IconData get icon => kCategoryIcons[iconKey] ?? Icons.category_rounded;
  Color get colorValue => Color(color);

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        iconKey: m['icon'] as String,
        color: m['color'] as int,
        kind: m['kind'] as String,
        sort: (m['sort'] as int?) ?? 0,
      );
}

const List<(String, String, int)> _expenseSeed = [
  ('Food & Dining', 'food', 0xFFF4A261),
  ('Groceries', 'grocery', 0xFF7BC67E),
  ('Shopping', 'shopping', 0xFF8E8BEA),
  ('Transport', 'transport', 0xFF5DADE2),
  ('Fuel', 'fuel', 0xFFE76F51),
  ('Bills & Recharge', 'bills', 0xFFF6C85F),
  ('Rent', 'rent', 0xFF9B7EDE),
  ('Health', 'health', 0xFFEF7C8E),
  ('Entertainment', 'entertainment', 0xFFEBB9D6),
  ('Education', 'education', 0xFF4FB3A9),
  ('Travel', 'travel', 0xFF6C8EF5),
  ('Personal Care', 'care', 0xFFD78FD3),
  ('Gifts & Donations', 'gift', 0xFFF08A5D),
  ('Others', 'other', 0xFF9AA0B4),
];

const List<(String, String, int)> _incomeSeed = [
  ('Salary', 'salary', 0xFF34B892),
  ('Business', 'business', 0xFF2D9CDB),
  ('Refund & Cashback', 'refund', 0xFF27AE60),
  ('Interest', 'interest', 0xFF56CCF2),
  ('Other Income', 'other_income', 0xFF6FCF97),
];

// ---------------- Transactions ----------------

enum TxnType { expense, income, transfer }

class Txn {
  final int? id;
  final int? accountId;
  final int? toAccountId;
  final TxnType type;
  final double amount;
  final int? categoryId;
  final int? personId;
  final String? counterparty;
  final String? note;
  final String? ref;
  final String? smsBody;
  final String status; // review | done
  final DateTime occurredAt;

  const Txn({
    this.id,
    this.accountId,
    this.toAccountId,
    required this.type,
    required this.amount,
    this.categoryId,
    this.personId,
    this.counterparty,
    this.note,
    this.ref,
    this.smsBody,
    this.status = 'done',
    required this.occurredAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'type': type.name,
        'amount': amount,
        'category_id': categoryId,
        'person_id': personId,
        'counterparty': counterparty,
        'note': note,
        'ref': ref,
        'sms_body': smsBody,
        'status': status,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int?,
        accountId: m['account_id'] as int?,
        toAccountId: m['to_account_id'] as int?,
        type: TxnType.values.byName(m['type'] as String),
        amount: (m['amount'] as num).toDouble(),
        categoryId: m['category_id'] as int?,
        personId: m['person_id'] as int?,
        counterparty: m['counterparty'] as String?,
        note: m['note'] as String?,
        ref: m['ref'] as String?,
        smsBody: m['sms_body'] as String?,
        status: (m['status'] as String?) ?? 'done',
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(m['occurred_at'] as int),
      );
}

// ---------------- Database ----------------

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  late Database db;

  Future<void> init() async {
    final dir = await getDatabasesPath();
    db = await openDatabase(
      p.join(dir, 'finup.db'),
      version: 1,
      onCreate: (d, version) async {
        await _createSchema(d);
        await _seed(d);
      },
    );
  }

  Future<void> _createSchema(Database d) async {
    final b = d.batch();
    b.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        bank TEXT,
        last4 TEXT,
        balance REAL NOT NULL DEFAULT 0,
        color_index INTEGER NOT NULL DEFAULT 0,
        balance_updated_at INTEGER,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        kind TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        to_account_id INTEGER,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER,
        person_id INTEGER,
        counterparty TEXT,
        note TEXT,
        ref TEXT,
        sms_body TEXT,
        status TEXT NOT NULL DEFAULT 'done',
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    b.execute('CREATE INDEX idx_txn_time ON transactions(occurred_at)');
    b.execute('CREATE INDEX idx_txn_ref ON transactions(ref)');
    b.execute('''
      CREATE TABLE people(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        upi_ids TEXT,
        note TEXT,
        created_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE ledger(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        txn_id INTEGER,
        due_at INTEGER,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE rules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL,
        category_id INTEGER,
        person_id INTEGER,
        created_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL
      )''');
    b.execute('''
      CREATE TABLE goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target REAL NOT NULL,
        saved REAL NOT NULL DEFAULT 0,
        color_index INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )''');
    await b.commit(noResult: true);
  }

  Future<void> _seed(Database d) async {
    final b = d.batch();
    var sort = 0;
    for (final c in _expenseSeed) {
      b.insert('categories', {
        'name': c.$1,
        'icon': c.$2,
        'color': c.$3,
        'kind': 'expense',
        'sort': sort++,
      });
    }
    for (final c in _incomeSeed) {
      b.insert('categories', {
        'name': c.$1,
        'icon': c.$2,
        'color': c.$3,
        'kind': 'income',
        'sort': sort++,
      });
    }
    await b.commit(noResult: true);
  }

  // ----- Accounts -----

  Future<List<Account>> accounts() async {
    final rows =
        await db.query('accounts', where: 'archived = 0', orderBy: 'id');
    return rows.map(Account.fromMap).toList();
  }

  Future<int> insertAccount(Account a) {
    return db.insert('accounts', {
      ...a.toMap(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateAccount(Account a) async {
    await db.update('accounts', a.toMap(),
        where: 'id = ?', whereArgs: [a.id]);
  }

  Future<void> removeAccount(int id) async {
    final used = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM transactions WHERE account_id = ? OR to_account_id = ?',
          [id, id],
        )) ??
        0;
    if (used > 0) {
      await db.update('accounts', {'archived': 1},
          where: 'id = ?', whereArgs: [id]);
    } else {
      await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    }
  }

  // ----- Categories -----

  Future<List<Category>> categories() async {
    final rows = await db.query('categories', orderBy: 'sort');
    return rows.map(Category.fromMap).toList();
  }

  // ----- Stats -----

  Future<double> expenseBetween(DateTime from, DateTime to) async {
    final r = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS s FROM transactions "
      "WHERE type = 'expense' AND occurred_at >= ? AND occurred_at < ?",
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (r.first['s'] as num).toDouble();
  }

  Future<int> reviewCount() async {
    return Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM transactions WHERE status = 'review'")) ??
        0;
  }
}
__END__

############################ lib/state/app_state.dart ############################
cat > lib/state/app_state.dart <<'__END__'
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
__END__

############################ lib/widgets/common.dart ############################
cat > lib/widgets/common.dart <<'__END__'
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../theme.dart';

/// Progress of [t] inside the window [start]..[end], clamped to 0..1.
double iv(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0).toDouble();

Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 550),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class OrbitPainter extends CustomPainter {
  final double t;
  final Color line;
  final bool showDots;
  final Alignment center;
  final double scale;

  OrbitPainter(
    this.t, {
    this.line = const Color(0x4DFFFFFF),
    this.showDots = true,
    this.center = const Alignment(-0.1, -0.35),
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = center.alongSize(size);
    final base = size.shortestSide * 0.85 * scale;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line;
    const rings = 7;
    for (var i = 0; i < rings; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final angle = i * math.pi / rings + dir * t * 2 * math.pi * 0.15;
      final w = base * (1.5 + 0.06 * i);
      final h = base * (0.5 + 0.09 * i);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: w, height: h), stroke);
      if (showDots && i % 2 == 0) {
        final a = dir * t * 2 * math.pi + i * 1.3;
        final pos = Offset(math.cos(a) * w / 2, math.sin(a) * h / 2);
        final dot = Paint()
          ..color = (i % 4 == 0) ? AppColors.lavender : AppColors.pink;
        canvas.drawCircle(pos, 5.0 + i * 1.6, dot);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant OrbitPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.line != line;
}

class OrbitBackground extends StatefulWidget {
  final Alignment center;
  final double scale;

  const OrbitBackground({
    super.key,
    this.center = const Alignment(-0.1, -0.35),
    this.scale = 1.0,
  });

  @override
  State<OrbitBackground> createState() => _OrbitBackgroundState();
}

class _OrbitBackgroundState extends State<OrbitBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: OrbitPainter(
            _c.value,
            center: widget.center,
            scale: widget.scale,
          ),
        ),
      ),
    );
  }
}

/// Repeats an animation forever and rebuilds with progress 0..1.
class Looping extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  const Looping({super.key, required this.duration, required this.builder});

  @override
  State<Looping> createState() => _LoopingState();
}

class _LoopingState extends State<Looping> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(context, _c.value),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.lavender, AppColors.pink]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: AppColors.ink, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  final Account account;
  final bool hide;
  final VoidCallback? onTap;

  const AccountCard({
    super.key,
    required this.account,
    this.hide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final digits = account.last4;
    final bottom = (digits != null && digits.isNotEmpty)
        ? '****   ****   ****   $digits'
        : account.type.label.toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientAt(account.colorIndex),
          borderRadius: BorderRadius.circular(26),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: OrbitPainter(
                    0.15,
                    line: Colors.white.withValues(alpha: 0.18),
                    showDots: false,
                    center: const Alignment(0.7, -0.1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(account.type.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            account.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          account.type.label,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        inr(account.balance, hide: hide),
                        style: AppText.display(size: 26, color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      bottom,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddAccountCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddAccountCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.25), width: 1.5),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white, size: 36),
              SizedBox(height: 10),
              Text(
                'Add account',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/splash_screen.dart ############################
cat > lib/screens/splash_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'intro_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    Future.delayed(const Duration(milliseconds: 2300), _go);
  }

  void _go() {
    if (!mounted) return;
    final onboarded = context.read<SettingsState>().onboarded;
    Navigator.of(context).pushReplacement(
      fadeRoute(onboarded ? const HomeShell() : const IntroScreen()),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(child: OrbitBackground()),
            Positioned(
              left: 28,
              right: 28,
              bottom: 90,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final v = Curves.easeOutCubic.transform(_c.value);
                  return Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - v)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                              colors: [AppColors.lavender, AppColors.pink],
                            ).createShader(r),
                            child: Text(
                              'FinUp',
                              style: AppText.display(
                                  size: 56, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your money, auto-tracked.\nPrivate. Offline. Yours.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/intro_screen.dart ############################
cat > lib/screens/intro_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'setup_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    _IntroData(
      'Every rupee,\nauto-tracked',
      'FinUp reads your bank SMS right on your phone and turns them into clean entries with amount, time, account and balance.',
    ),
    _IntroData(
      'Review in\n30 seconds',
      'Open FinUp at night, tap a category for each new transaction and you are done. It learns your merchants as you go.',
    ),
    _IntroData(
      'Know who\nowes you',
      'Keep a running ledger for friends and family. UPI transfers link to the right person automatically.',
    ),
  ];

  void _finish() =>
      Navigator.of(context).pushReplacement(fadeRoute(const SetupScreen()));

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _pc.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Widget _art(int i) => switch (i) {
        0 => const SmsArt(),
        1 => const ReviewArt(),
        _ => const LedgerArt(),
      };

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(
              child: Opacity(
                opacity: 0.35,
                child: OrbitBackground(
                    center: Alignment(0.2, -0.6), scale: 1.1),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: last ? 0 : 1,
                        child: TextButton(
                          onPressed: last ? null : _finish,
                          child: const Text('Skip',
                              style: TextStyle(color: Colors.white60)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pc,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) {
                        final d = _pages[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _art(i),
                                  ),
                                ),
                              ),
                              Text(d.title,
                                  style: AppText.display(
                                      size: 32, color: Colors.white)),
                              const SizedBox(height: 14),
                              Text(
                                d.body,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                    child: Row(
                      children: [
                        Row(
                          children: List.generate(
                            _pages.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _page ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? AppColors.lavender
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _next,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            height: 60,
                            width: last ? 170 : 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.lavender, AppColors.pink],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: last
                                  ? const Text(
                                      'Get started',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded,
                                      color: AppColors.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroData {
  final String title;
  final String body;
  const _IntroData(this.title, this.body);
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.lavender.withValues(alpha: 0.35),
            AppColors.lavender.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class SmsArt extends StatelessWidget {
  const SmsArt({super.key});

  static const _rows = [
    ('Rs.4,000.00 Dr.', 'to cafe@okaxis', '06:42 AM'),
    ('Rs.126.00 Dr.', 'to store@ybl', '05:32 AM'),
    ('Rs.12,500.00 Cr.', 'Salary credited', '09:00 AM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Looping(
      duration: const Duration(milliseconds: 4200),
      builder: (context, t) {
        final out = 1 - iv(t, 0.88, 1.0);
        return SizedBox(
          width: 290,
          height: 290,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const _Glow(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _rows.length; i++) _bubble(i, t, out),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bubble(int i, double t, double out) {
    final s = 0.08 + i * 0.18;
    final v = iv(t, s, s + 0.22);
    final e = Curves.easeOutCubic.transform(v);
    final tick = iv(t, s + 0.25, s + 0.35);
    final r = _rows[i];
    final credit = r.$1.contains('Cr.');
    return Opacity(
      opacity: (v * out).clamp(0.0, 1.0).toDouble(),
      child: Transform.translate(
        offset: Offset(-36 * (1 - e), 0),
        child: Container(
          width: 270,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B25),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppColors.lavender.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.lavender, AppColors.pink]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sms_rounded,
                    color: AppColors.ink, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.$1,
                      style: TextStyle(
                        color: credit ? AppColors.income : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(r.$2,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(r.$3,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Transform.scale(
                    scale: tick,
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.income, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewArt extends StatelessWidget {
  const ReviewArt({super.key});

  @override
  Widget build(BuildContext context) {
    return Looping(
      duration: const Duration(milliseconds: 3800),
      builder: (context, t) {
        final fade = iv(t, 0.0, 0.08) * (1 - iv(t, 0.9, 1.0));
        final pick = iv(t, 0.3, 0.4);
        final done = iv(t, 0.48, 0.62);
        final picked = pick > 0.5;
        final finished = done > 0.5;
        return Opacity(
          opacity: fade,
          child: SizedBox(
            width: 290,
            height: 290,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _Glow(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 270,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Color.lerp(Colors.white12,
                                  const Color(0xFFF4A261), done),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              finished
                                  ? Icons.restaurant_rounded
                                  : Icons.help_outline_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Swiggy',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  finished ? 'Food & Dining' : 'Needs a category',
                                  style: TextStyle(
                                    color: finished
                                        ? const Color(0xFFF4A261)
                                        : Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text('₹249',
                              style: AppText.display(
                                  size: 17, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _chip('Food', picked),
                        const SizedBox(width: 8),
                        _chip('Shopping', false),
                        const SizedBox(width: 8),
                        _chip('Travel', false),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Transform.scale(
                      scale: Curves.easeOutBack.transform(done),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.income,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(colors: [AppColors.lavender, AppColors.pink])
            : null,
        color: selected ? null : const Color(0xFF1B1B25),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: selected ? Colors.transparent : Colors.white12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.ink : Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LedgerArt extends StatelessWidget {
  const LedgerArt({super.key});

  @override
  Widget build(BuildContext context) {
    return Looping(
      duration: const Duration(milliseconds: 3400),
      builder: (context, t) {
        final fade = iv(t, 0.0, 0.08) * (1 - iv(t, 0.9, 1.0));
        final move = Curves.easeInOutCubic.transform(iv(t, 0.12, 0.55));
        final pill = iv(t, 0.58, 0.72);
        return Opacity(
          opacity: fade,
          child: SizedBox(
            width: 290,
            height: 290,
            child: Stack(
              children: [
                const Positioned.fill(child: Center(child: _Glow())),
                Positioned(
                  left: 70,
                  right: 70,
                  top: 119,
                  child: Container(height: 2, color: Colors.white12),
                ),
                Positioned(
                    left: 14, top: 82, child: _avatar('You', AppColors.lavender)),
                Positioned(
                    right: 14, top: 82, child: _avatar('R', AppColors.pink)),
                Positioned(
                  left: 90 + move * 70,
                  top: 100,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [Color(0xFFF6D365), Color(0xFFFDA085)]),
                    ),
                    child: const Center(
                      child: Text(
                        '₹',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 190,
                  child: Center(
                    child: Opacity(
                      opacity: pill,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - pill)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B25),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: AppColors.income.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.north_east_rounded,
                                  color: AppColors.income, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Rahul owes you ₹500',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatar(String label, Color c) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.18),
        border: Border.all(color: c, width: 2),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.w800,
            fontSize: label.length > 1 ? 16 : 26,
          ),
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/setup_screen.dart ############################
cat > lib/screens/setup_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _total = 4;
  int _step = 0;
  bool _saving = false;
  bool _addBank = true;

  final _name = TextEditingController();
  final _cash = TextEditingController();
  final _bankName = TextEditingController(text: 'Bank of Baroda');
  final _bankLast4 = TextEditingController(text: '2261');
  final _bankBal = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _cash, _bankName, _bankLast4, _bankBal]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canContinue {
    if (_saving) return false;
    if (_step == 1) return _name.text.trim().isNotEmpty;
    if (_step == 2) return !_addBank || _bankName.text.trim().isNotEmpty;
    return true;
  }

  double _num(String s) => double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step < _total - 1) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    final settings = context.read<SettingsState>();
    final accounts = context.read<AccountsState>();
    final navigator = Navigator.of(context);

    await settings.setUserName(_name.text.trim());
    if (_addBank) {
      await accounts.save(Account(
        name: _bankName.text.trim(),
        type: AccountType.bank,
        bank: 'BOB',
        last4: _bankLast4.text.trim(),
        balance: _num(_bankBal.text),
        colorIndex: 0,
        balanceUpdatedAt: DateTime.now(),
      ));
    }
    await accounts.save(Account(
      name: 'Cash',
      type: AccountType.cash,
      balance: _num(_cash.text),
      colorIndex: 2,
      balanceUpdatedAt: DateTime.now(),
    ));
    await settings.completeOnboarding();
    navigator.pushAndRemoveUntil(
        fadeRoute(const HomeShell()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _step > 0 ? 1 : 0,
                      child: IconButton(
                        onPressed:
                            _step > 0 ? () => setState(() => _step--) : null,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: List.generate(
                          _total,
                          (i) => Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i <= _step
                                    ? AppColors.lavender
                                    : fin.divider,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 24, bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: _stepBody(context),
                      ),
                    ),
                  ),
                ),
              ),
              PrimaryButton(
                label: _step == _total - 1 ? 'Start using FinUp' : 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: _canContinue ? _next : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    final fin = context.fin;
    switch (_step) {
      case 0:
        return _privacy(fin);
      case 1:
        return _nameStep(fin);
      case 2:
        return _accountsStep(fin);
      default:
        return _themeStep(context, fin);
    }
  }

  Widget _title(String t, String sub, FinColors fin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: AppText.display(size: 28, color: fin.text)),
        const SizedBox(height: 10),
        Text(sub,
            style: TextStyle(color: fin.subtext, fontSize: 15, height: 1.5)),
      ],
    );
  }

  // ---------- Step 0: privacy ----------
  Widget _privacy(FinColors fin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Looping(
            duration: const Duration(milliseconds: 2400),
            builder: (context, t) => SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var k = 0; k < 2; k++) _ring((t + k * 0.5) % 1.0),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [AppColors.lavender, AppColors.pink]),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        size: 44, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _title('Your data stays\non your phone',
            'FinUp works fully offline. Here is the promise:', fin),
        const SizedBox(height: 22),
        _promise(Icons.phone_android_rounded, 'Stored only on this device',
            'Nothing is uploaded anywhere.', fin),
        _promise(Icons.cloud_off_rounded, 'No servers, no sign-up',
            'No tracking and no ads.', fin),
        _promise(Icons.sms_rounded, 'SMS used only for transactions',
            'Only bank messages are read to log your spending.', fin),
        _promise(Icons.delete_outline_rounded, 'Delete anytime',
            'Wipe all data from Settings whenever you want.', fin),
      ],
    );
  }

  Widget _ring(double p) {
    return Opacity(
      opacity: 1 - p,
      child: Container(
        width: 92 + 88 * p,
        height: 92 + 88 * p,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lavender, width: 2),
        ),
      ),
    );
  }

  Widget _promise(IconData icon, String title, String sub, FinColors fin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lavender.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.lavender),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: fin.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: fin.subtext, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Step 1: name ----------
  Widget _nameStep(FinColors fin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('What should we\ncall you?',
            'Just for greeting you on the home screen.', fin),
        const SizedBox(height: 28),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: 18, color: fin.text),
          decoration: const InputDecoration(
            hintText: 'Your name',
            prefixIcon: Icon(Icons.person_rounded),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_canContinue) _next();
          },
        ),
      ],
    );
  }

  // ---------- Step 2: accounts ----------
  Widget _box(FinColors fin, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fin.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _accountsStep(FinColors fin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'Set up your\naccounts',
          'Bank balance will update automatically from SMS once tracking is on. You can edit everything later.',
          fin,
        ),
        const SizedBox(height: 24),
        _box(
          fin,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconBadge(Icons.account_balance_rounded, AppColors.lavender),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Bank account',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: fin.text)),
                  ),
                  Switch(
                    value: _addBank,
                    onChanged: (v) => setState(() => _addBank = v),
                  ),
                ],
              ),
              if (_addBank) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _bankName,
                  decoration: InputDecoration(
                      labelText: 'Bank name', fillColor: fin.bg),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bankLast4,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Last 4 digits',
                          counterText: '',
                          fillColor: fin.bg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _bankBal,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Balance',
                          prefixText: '₹ ',
                          fillColor: fin.bg,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _box(
          fin,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconBadge(Icons.payments_rounded, AppColors.pink),
                  const SizedBox(width: 12),
                  Text('Cash in hand',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: fin.text)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _cash,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'How much cash do you have?',
                  prefixText: '₹ ',
                  fillColor: fin.bg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Step 3: theme ----------
  Widget _themeStep(BuildContext context, FinColors fin) {
    final settings = context.watch<SettingsState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Pick your look', 'Switch anytime from Settings.', fin),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
                child: _themeTile(settings, ThemeMode.light, 'Light', fin)),
            const SizedBox(width: 12),
            Expanded(child: _themeTile(settings, ThemeMode.dark, 'Dark', fin)),
            const SizedBox(width: 12),
            Expanded(
                child: _themeTile(settings, ThemeMode.system, 'System', fin)),
          ],
        ),
      ],
    );
  }

  Widget _themeTile(
      SettingsState s, ThemeMode mode, String label, FinColors fin) {
    final selected = s.themeMode == mode;
    return GestureDetector(
      onTap: () => s.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: fin.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.lavender : fin.divider,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 0.62,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: mode == ThemeMode.system
                    ? Row(children: [
                        Expanded(child: _mini(false)),
                        Expanded(child: _mini(true)),
                      ])
                    : _mini(mode == ThemeMode.dark),
              ),
            ),
            const SizedBox(height: 10),
            Text(label,
                style:
                    TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.lavender : fin.subtext,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(bool dark) {
    final c = dark ? FinColors.dark : FinColors.light;
    return Container(
      color: c.bg,
      child: Column(
        children: [
          Container(
            height: 46,
            color: c.hero,
            padding: const EdgeInsets.all(6),
            alignment: Alignment.bottomLeft,
            child: Container(width: 30, height: 6, color: Colors.white70),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradients[0],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
__END__

############################ lib/screens/home_shell.dart ############################
cat > lib/screens/home_shell.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_editor.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _openAdd() {
    final fin = context.fin;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
                children: [
                  const _AddTile(
                      icon: Icons.north_east_rounded,
                      label: 'Expense',
                      color: AppColors.expense,
                      soon: true),
                  const _AddTile(
                      icon: Icons.south_west_rounded,
                      label: 'Income',
                      color: AppColors.income,
                      soon: true),
                  const _AddTile(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transfer',
                      color: AppColors.lavender,
                      soon: true),
                  _AddTile(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Account',
                    color: AppColors.pink,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context)
                          .push(fadeRoute(const AccountEditor()));
                    },
                  ),
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
        children: const [
          HomeScreen(),
          ComingSoon(
            title: 'Activity',
            icon: Icons.receipt_long_rounded,
            note:
                'SMS auto-tracking and your end-of-day review inbox arrive in Part 2.',
          ),
          ComingSoon(
            title: 'People',
            icon: Icons.people_alt_rounded,
            note: 'Your personal ledger for friends and family arrives in Part 4.',
          ),
          ComingSoon(
            title: 'Insights',
            icon: Icons.pie_chart_rounded,
            note: 'Charts, budgets and goals arrive in Part 3.',
          ),
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
  final bool soon;
  final VoidCallback? onTap;

  const _AddTile({
    required this.icon,
    required this.label,
    required this.color,
    this.soon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: soon ? null : onTap,
      child: Opacity(
        opacity: soon ? 0.5 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: fin.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            if (soon)
              Text('Soon',
                  style: TextStyle(color: fin.subtext, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _BottomBar({
    required this.index,
    required this.onTap,
    required this.onAdd,
  });

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
              color:
                  Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
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
                    child: const Icon(Icons.add_rounded,
                        color: AppColors.ink, size: 30),
                  ),
                ),
              ),
            ),
            _item(context, 2, Icons.people_alt_rounded),
            _item(context, 3, Icons.pie_chart_rounded),
          ],
        ),
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
              child:
                  Icon(icon, color: selected ? active : fin.subtext, size: 26),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 18 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: active,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  Future<(double, int)> _todayStats() async {
    final db = AppDatabase.instance;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final spent =
        await db.expenseBetween(start, start.add(const Duration(days: 1)));
    final review = await db.reviewCount();
    return (spent, review);
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final settings = context.watch<SettingsState>();
    final accounts = context.watch<AccountsState>();
    final hide = settings.hideAmounts;
    final top = MediaQuery.of(context).padding.top;
    final list = accounts.accounts;
    final greeting = settings.userName.isEmpty
        ? 'Hello there'
        : 'Hi, ${settings.userName}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListView(
        padding: EdgeInsets.zero,
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
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          greeting,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => settings.setHideAmounts(!hide),
                        icon: Icon(
                          hide
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context)
                            .push(fadeRoute(const SettingsScreen())),
                        icon: const Icon(Icons.settings_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          inr(accounts.total, hide: hide),
                          style: AppText.display(size: 38, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total balance · ${list.length} ${list.length == 1 ? 'account' : 'accounts'}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'My Accounts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .push(fadeRoute(const AccountEditor())),
                        icon: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 18),
                        label: const Text('Add',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
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
                              onTap: () => Navigator.of(context).push(
                                  fadeRoute(AccountEditor(account: list[i]))),
                            )
                          : AddAccountCard(
                              onTap: () => Navigator.of(context)
                                  .push(fadeRoute(const AccountEditor())),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today',
                    style: TextStyle(
                        color: fin.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                FutureBuilder<(double, int)>(
                  future: _todayStats(),
                  builder: (context, snap) {
                    final spent = snap.data?.$1 ?? 0;
                    final review = snap.data?.$2 ?? 0;
                    return Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.north_east_rounded,
                            color: AppColors.expense,
                            label: 'Spent today',
                            value: inr(spent, hide: hide),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.inbox_rounded,
                            color: AppColors.lavender,
                            label: 'To review',
                            value: '$review',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Statistic',
                    style: TextStyle(
                        color: fin.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: fin.card,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.insights_rounded,
                          size: 40, color: AppColors.lavender),
                      const SizedBox(height: 12),
                      Text(
                        'Your spending charts will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: fin.text, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Once transactions start coming in from SMS, FinUp will show monthly trends and category breakdowns.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: fin.subtext, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 130),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fin.card,
        borderRadius: BorderRadius.circular(22),
      ),
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
            child:
                Text(value, style: AppText.display(size: 20, color: fin.text)),
          ),
        ],
      ),
    );
  }
}

class ComingSoon extends StatelessWidget {
  final String title;
  final IconData icon;
  final String note;

  const ComingSoon({
    super.key,
    required this.title,
    required this.icon,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [AppColors.lavender, AppColors.pink]),
                  ),
                  child: Icon(icon, size: 44, color: AppColors.ink),
                ),
                const SizedBox(height: 20),
                Text(title, style: AppText.display(size: 24, color: fin.text)),
                const SizedBox(height: 10),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fin.subtext, height: 1.5),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/account_editor.dart ############################
cat > lib/screens/account_editor.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AccountEditor extends StatefulWidget {
  final Account? account;

  const AccountEditor({super.key, this.account});

  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  late final TextEditingController _name;
  late final TextEditingController _last4;
  late final TextEditingController _balance;
  late AccountType _type;
  late int _color;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _last4 = TextEditingController(text: a?.last4 ?? '');
    _balance = TextEditingController(
        text: a == null ? '' : a.balance.toStringAsFixed(2));
    _type = a?.type ?? AccountType.bank;
    _color = a?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _last4.dispose();
    _balance.dispose();
    super.dispose();
  }

  double get _bal =>
      double.tryParse(_balance.text.replaceAll(',', '').trim()) ?? 0;

  bool get _needsDigits =>
      _type == AccountType.bank || _type == AccountType.card;

  Account _build() => Account(
        id: widget.account?.id,
        name: _name.text.trim().isEmpty ? 'Account name' : _name.text.trim(),
        type: _type,
        bank: widget.account?.bank,
        last4: _needsDigits ? _last4.text.trim() : null,
        balance: _bal,
        colorIndex: _color,
        balanceUpdatedAt: DateTime.now(),
      );

  Future<void> _save() async {
    final nav = Navigator.of(context);
    await context.read<AccountsState>().save(_build());
    nav.pop();
  }

  Future<void> _delete() async {
    final state = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'If this account has transactions it will be archived instead, so your history stays correct.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.remove(widget.account!.id!);
      nav.pop();
    }
  }

  Widget _label(String text, FinColors fin) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
        child: Text(text,
            style: TextStyle(
                color: fin.subtext,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit account' : 'New account'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          SizedBox(height: 190, child: AccountCard(account: _build())),
          const SizedBox(height: 8),
          _label('Type', fin),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AccountType.values
                .map((t) => ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(t.icon, size: 18),
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ))
                .toList(),
          ),
          _label('Name', fin),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'e.g. Bank of Baroda'),
            onChanged: (_) => setState(() {}),
          ),
          if (_needsDigits) ...[
            _label('Last 4 digits (used to match bank SMS)', fin),
            TextField(
              controller: _last4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(hintText: '2261', counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
          ],
          _label(
            _type == AccountType.card
                ? 'Outstanding (enter as minus, e.g. -2500)'
                : 'Current balance',
            fin,
          ),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration:
                const InputDecoration(hintText: '0.00', prefixText: '₹ '),
            onChanged: (_) => setState(() {}),
          ),
          _label('Card colour', fin),
          Row(
            children: List.generate(
              AppColors.cardGradients.length,
              (i) => GestureDetector(
                onTap: () => setState(() => _color = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientAt(i),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == i ? primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Save account',
            icon: Icons.check_rounded,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
__END__

############################ lib/screens/settings_screen.dart ############################
cat > lib/screens/settings_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_editor.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editName(BuildContext context, SettingsState s) async {
    final c = TextEditingController(text: s.userName);
    final result = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await s.setUserName(result);
    }
  }

  Future<void> _pickTime(BuildContext context, SettingsState s) async {
    final picked =
        await showTimePicker(context: context, initialTime: s.reminderTime);
    if (picked != null) {
      await s.setReminderTime(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final accounts = context.watch<AccountsState>().accounts;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _Section(title: 'Profile', children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Name'),
              subtitle: Text(s.userName.isEmpty ? 'Not set' : s.userName),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _editName(context, s),
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
          _Section(title: 'Privacy', children: [
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded),
              title: const Text('Hide amounts on Home'),
              value: s.hideAmounts,
              onChanged: s.setHideAmounts,
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
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text(
                  (a.last4 != null && a.last4!.isNotEmpty)
                      ? '${a.type.label} · ••${a.last4}'
                      : a.type.label,
                ),
                trailing: Text(inr(a.balance, hide: s.hideAmounts)),
                onTap: () => Navigator.of(context)
                    .push(fadeRoute(AccountEditor(account: a))),
              ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Add account'),
              onTap: () =>
                  Navigator.of(context).push(fadeRoute(const AccountEditor())),
            ),
          ]),
          _Section(title: 'Notifications', children: [
            ListTile(
              leading: const Icon(Icons.alarm_rounded),
              title: const Text('Daily review reminder'),
              subtitle: Text(
                  '${s.reminderTime.format(context)} · alerts switch on in Part 2'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickTime(context, s),
            ),
          ]),
          const _Section(title: 'About', children: [
            ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('FinUp'),
              subtitle: Text('Version 1.0.0 · Part 1'),
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
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: fin.subtext,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
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
__END__

echo "FinUp source generated."