import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../native.dart';
import 'parser.dart';

class SmsSync {
  static Account? _byId(List<Account> list, int? id) {
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Account? _firstCash(List<Account> list) {
    for (final a in list) {
      if (a.type == AccountType.cash) return a;
    }
    return null;
  }

  static Account? _match(List<Account> list, ParsedSms p) {
    if (p.last4 != null) {
      for (final a in list) {
        if (a.last4 == p.last4) return a;
      }
      return null;
    }
    if (!p.knownBank) return null;
    for (final a in list) {
      if (a.type == AccountType.bank) return a;
    }
    return null;
  }

  static Future<int> run({int? sinceMs}) async {
    if (!await Native.hasSms()) return 0;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('smsLastSync');
    final since = sinceMs ??
        last ??
        DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch;
    final msgs = await Native.readSms(since);
    final db = AppDatabase.instance;
    var accounts = await db.accounts();
    final rules = await db.rules();
    var added = 0;
    var maxDate = last ?? since;
    final latest = <int, (DateTime, double)>{};

    for (final sms in msgs) {
      if (sms.date > maxDate) maxDate = sms.date;
      final p = SmsParser.parse(
          sms.address, sms.body, DateTime.fromMillisecondsSinceEpoch(sms.date));
      if (p == null) continue;
      final key = p.ref != null ? 'ref:${p.ref}' : 'sms:${sms.id}';

      // Match account early so we can refresh balance even for known txns.
      var acc = _match(accounts, p);
      if (acc == null && p.last4 != null && !(await db.txnExists(key)) && !(await db.isDeletedRef(key))) {
        final id = await db.insertAccount(Account(
          name: p.bankName,
          type: AccountType.bank,
          bank: p.bankName,
          last4: p.last4,
          colorIndex: accounts.length % 4,
          balance: p.balance ?? 0,
          balanceUpdatedAt: p.balance == null ? null : p.when,
        ));
        accounts = await db.accounts();
        acc = _byId(accounts, id);
      }
      if (acc != null) {
        final accId = acc.id!;
        if (p.balance != null) {
          final prev = latest[accId];
          if (prev == null || !p.when.isBefore(prev.$1)) {
            latest[accId] = (p.when, p.balance!);
          }
        }
      }

      if (await db.isDeletedRef(key)) continue;
      if (await db.txnExists(key)) continue;
      if (acc == null) {
        if (p.last4 == null) continue;
        continue;
      }
      final accId = acc.id!;
      final fresh = acc.balanceUpdatedAt == null ||
          p.when.isAfter(acc.balanceUpdatedAt!);

      if (p.isAtm) {
        var cash = _firstCash(accounts);
        if (cash == null) {
          final cid = await db.insertAccount(const Account(
              name: 'Cash', type: AccountType.cash, colorIndex: 2));
          accounts = await db.accounts();
          cash = _byId(accounts, cid);
        }
        final mode = !fresh ? 0 : (p.balance == null ? 1 : 2);
        await db.addTxn(
          Txn(
            accountId: accId,
            toAccountId: cash?.id,
            type: TxnType.transfer,
            amount: p.amount,
            counterparty: 'ATM withdrawal',
            ref: key,
            smsBody: sms.body,
            status: 'done',
            occurredAt: p.when,
          ),
          balanceMode: mode,
        );
      } else {
        final party = p.counterparty;
        int? cat;
        if (party != null) {
          final l = party.toLowerCase();
          for (final r in rules) {
            if (l == r.$1 || l.contains(r.$1)) {
              cat = r.$2;
              break;
            }
          }
        }
        await db.addTxn(
          Txn(
            accountId: accId,
            type: p.isDebit ? TxnType.expense : TxnType.income,
            amount: p.amount,
            categoryId: cat,
            counterparty: party,
            ref: key,
            smsBody: sms.body,
            status: cat == null ? 'review' : 'done',
            occurredAt: p.when,
          ),
          balanceMode: (p.balance == null && fresh) ? 1 : 0,
        );
      }
      added++;
    }

    // Prefer newest available-balance SMS per account (home pull-to-refresh).
    for (final e in latest.entries) {
      final acc = _byId(accounts, e.key);
      if (acc == null) continue;
      final upd = acc.balanceUpdatedAt;
      if (upd == null || !e.value.$1.isBefore(upd)) {
        await db.setAccountBalance(e.key, e.value.$2, e.value.$1);
      }
    }
    await prefs.setInt('smsLastSync', maxDate);
    return added;
  }
}
