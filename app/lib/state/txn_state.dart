import 'package:flutter/material.dart';

import '../cloud/sync.dart';
import '../data/db.dart';
import '../data/people_repo.dart';
import '../data/tags_repo.dart';
import '../notify/notify_sync.dart';
import '../data/repo.dart';
import '../native.dart';
import '../sms/sync.dart';
import 'app_state.dart';

class TxnState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;
  List<Category> categories = [];
  List<Txn> recent = [];
  int reviewCount = 0;
  double todaySpent = 0;
  bool smsEnabled = false;
  bool syncing = false;
  int version = 0;

  Category? category(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Category> byKind(String kind) =>
      categories.where((c) => c.kind == kind).toList();

  Future<void> load() async {
    categories = await _db.categories();
    recent = await _db.txns(limit: 6);
    reviewCount = await _db.reviewCount();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    todaySpent =
        await _db.expenseBetween(start, start.add(const Duration(days: 1)));
    smsEnabled = await Native.hasSms();
    version++;
    BudgetAlerts.check(this);
    Native.refreshWidget();
    notifyListeners();
  }

  Future<int> sync(AccountsState accounts, {int? sinceMs}) async {
    if (syncing) return 0;
    syncing = true;
    notifyListeners();
    var n = 0;
    try {
      n = await SmsSync.run(sinceMs: sinceMs);
      await AppDatabase.instance.autoLinkPeople();
      await applyPendingCategories();
      await AppDatabase.instance.autoTagTrips();
      if (n > 0) await CloudSync.instance.markDirty();
    } catch (_) {}
    syncing = false;
    await accounts.load();
    await load();
    return n;
  }

  Future<void> save(AccountsState accounts, Txn t, {Txn? old}) async {
    if (old == null) {
      await _db.addTxn(t);
    } else {
      await _db.editTxn(old, t);
    }
    await CloudSync.instance.markDirty();
    await accounts.load();
    await load();
  }

  Future<void> delete(AccountsState accounts, Txn t) async {
    await _db.deleteTxn(t);
    await CloudSync.instance.markDirty();
    await accounts.load();
    await load();
  }

  Future<void> categorize(Txn t, int categoryId, {bool remember = true}) async {
    await _db.markReviewed(t.id!, categoryId);
    final key = t.counterparty?.trim().toLowerCase();
    if (remember && key != null && key.isNotEmpty) {
      await _db.addRule(key, categoryId);
      await _db.applyRuleToPending(key, categoryId);
    }
    await CloudSync.instance.markDirty();
    await load();
  }

  Future<void> rememberRule(String payee, int categoryId) async {
    await _db.addRule(payee, categoryId);
    await _db.applyRuleToPending(payee, categoryId);
    await CloudSync.instance.markDirty();
    await load();
  }

  Future<void> markAllReviewed() async {
    await _db.markAllReviewed();
    await CloudSync.instance.markDirty();
    await load();
  }
}
