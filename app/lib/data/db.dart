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

enum TxnType { expense, income, transfer, invest }

class Txn {
  final int? id;
  final int? accountId;
  final int? toAccountId;
  final int? goalId;
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
    this.goalId,
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
        'goal_id': goalId,
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
        goalId: m['goal_id'] as int?,
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
        goal_id INTEGER,
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
      "WHERE type = 'expense' AND person_id IS NULL AND occurred_at >= ? AND occurred_at < ?",
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
