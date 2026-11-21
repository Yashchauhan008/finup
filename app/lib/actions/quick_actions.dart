import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../native.dart';
import '../screens/add_txn_screen.dart';
import '../screens/review_screen.dart';
import '../screens/budgets_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/people_screen.dart';
import '../security/lock.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../widgets/common.dart';

/// Handles actions from the home screen widget and long-press shortcuts.
Future<void> handleLaunchAction(BuildContext context) async {
  final a = await Native.takeLaunchAction();
  if (a == null || !context.mounted) return;
  switch (a) {
    case 'add_expense':
      Navigator.of(context).push(fadeRoute(const AddTxnScreen()));
    case 'invest':
      Navigator.of(context).push(fadeRoute(const AddTxnScreen(type: TxnType.invest)));
    case 'voice':
      await startVoiceEntry(context);
    case 'scan':
      await startReceiptScan(context);
    case 'review':
      Navigator.of(context).push(fadeRoute(const ReviewScreen()));
    case 'budgets':
      Navigator.of(context).push(fadeRoute(const BudgetsScreen()));
    case 'people':
      Navigator.of(context).push(fadeRoute(const PeopleScreen()));
    case 'insights':
      Navigator.of(context).push(fadeRoute(const InsightsScreen()));
    default:
      break;
  }
}

// ---------------- Voice entry ----------------

class VoiceResult {
  final TxnType type;
  final double? amount;
  final int? categoryId;
  final int? accountId;
  final String? payee;
  const VoiceResult(this.type, this.amount, this.categoryId, this.accountId, this.payee);
}

const Map<String, String> _voiceKeywords = {
  'petrol': 'fuel', 'diesel': 'fuel', 'fuel': 'fuel', 'cng': 'fuel',
  'chai': 'food', 'tea': 'food', 'coffee': 'food', 'lunch': 'food', 'dinner': 'food',
  'breakfast': 'food', 'food': 'food', 'swiggy': 'food', 'zomato': 'food', 'pizza': 'food',
  'snacks': 'food', 'restaurant': 'food',
  'grocery': 'grocery', 'groceries': 'grocery', 'vegetables': 'grocery', 'vegetable': 'grocery',
  'milk': 'grocery', 'fruits': 'grocery', 'blinkit': 'grocery', 'zepto': 'grocery',
  'uber': 'transport', 'ola': 'transport', 'auto': 'transport', 'rickshaw': 'transport',
  'bus': 'transport', 'metro': 'transport', 'train': 'transport', 'cab': 'transport',
  'parking': 'transport', 'rapido': 'transport',
  'recharge': 'bills', 'bill': 'bills', 'electricity': 'bills', 'wifi': 'bills', 'internet': 'bills',
  'rent': 'rent',
  'medicine': 'health', 'medicines': 'health', 'doctor': 'health', 'hospital': 'health', 'pharmacy': 'health',
  'movie': 'entertainment', 'netflix': 'entertainment', 'game': 'entertainment',
  'shopping': 'shopping', 'amazon': 'shopping', 'flipkart': 'shopping', 'clothes': 'shopping', 'shoes': 'shopping',
  'book': 'education', 'books': 'education', 'course': 'education', 'fees': 'education',
  'flight': 'travel', 'hotel': 'travel', 'trip': 'travel',
  'haircut': 'care', 'salon': 'care',
  'gift': 'gift', 'donation': 'gift',
  'salary': 'salary', 'refund': 'refund', 'cashback': 'refund', 'interest': 'interest',
};

VoiceResult parseVoice(String raw, List<Category> cats, List<Account> accounts) {
  final s = raw.toLowerCase().replaceAll('₹', ' ').replaceAll(',', '');
  double? amount;
  final m = RegExp(r'(\d+(?:\.\d+)?)\s*(k|thousand|hundred|lakh)?\b').firstMatch(s);
  if (m != null) {
    var v = double.parse(m.group(1)!);
    switch (m.group(2)) {
      case 'k':
      case 'thousand':
        v *= 1000;
      case 'hundred':
        v *= 100;
      case 'lakh':
        v *= 100000;
      default:
        break;
    }
    amount = v;
  }
  bool has(String w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(s);
  final income = ['received', 'got paid', 'salary', 'credited', 'income', 'earned', 'refund', 'cashback']
      .any((w) => s.contains(w));
  final type = income ? TxnType.income : TxnType.expense;
  final kind = income ? 'income' : 'expense';

  int? catId;
  var bestLen = 0;
  for (final c in cats.where((c) => c.kind == kind)) {
    final n = c.name.toLowerCase();
    if (n.length > bestLen && s.contains(n)) {
      catId = c.id;
      bestLen = n.length;
    }
  }
  if (catId == null) {
    for (final e in _voiceKeywords.entries) {
      if (!has(e.key)) continue;
      for (final c in cats) {
        if (c.iconKey == e.value && c.kind == kind) {
          catId = c.id;
          break;
        }
      }
      if (catId != null) break;
    }
  }

  int? accId;
  AccountType? want;
  if (has('cash')) want = AccountType.cash;
  if (has('card') || has('credit card')) want = AccountType.card;
  if (has('wallet') || has('paytm')) want = AccountType.wallet;
  if (want != null) {
    for (final a in accounts) {
      if (a.type == want) {
        accId = a.id;
        break;
      }
    }
  }

  String? payee;
  final pm = RegExp(r'\b(?:at|to|from)\s+([a-z][a-z\s]{1,25}?)(?:\s+(?:for|on|by|using|with|in|via)\b|$)')
      .firstMatch(s);
  if (pm != null) {
    final p = pm.group(1)!.trim();
    if (p.isNotEmpty && !['cash', 'card', 'wallet'].contains(p)) {
      payee = p.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
    }
  }
  return VoiceResult(type, amount, catId, accId, payee);
}

Future<void> startVoiceEntry(BuildContext context) async {
  final txns = context.read<TxnState>();
  final accounts = context.read<AccountsState>().accounts;
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final text = await AppLockGate.suspendWhile(
      () => Native.voice('Say something like: Spent 250 on petrol'));
  if (text == '__unavailable__') {
    messenger.showSnackBar(const SnackBar(
        content: Text('Voice input needs the Google app or speech services on this phone.')));
    return;
  }
  if (text == null || text.trim().isEmpty) return;
  final v = parseVoice(text, txns.categories, accounts);
  nav.push(fadeRoute(AddTxnScreen(
    type: v.type,
    initialAmount: v.amount,
    initialCategoryId: v.categoryId,
    initialAccountId: v.accountId,
    initialPayee: v.payee,
    initialNote: text,
    voiceText: text,
  )));
}

// ---------------- Receipts ----------------

class ReceiptResult {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  const ReceiptResult(this.amount, this.merchant, this.date);
}

final RegExp _num = RegExp(r'(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+\.\d{1,2}|\d+)');

double? _largest(String line) {
  double? best;
  for (final m in _num.allMatches(line)) {
    final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (v != null && v < 10000000 && (best == null || v > best)) best = v;
  }
  return best;
}

ReceiptResult parseReceipt(String text) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  double? amount;
  const keys = [
    'grand total', 'net amount', 'net payable', 'amount payable', 'total amount',
    'bill amount', 'amount due', 'to pay', 'total'
  ];
  outer:
  for (final k in keys) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final l = lines[i].toLowerCase();
      if (!l.contains(k)) continue;
      if (k == 'total' && (l.contains('sub') || l.contains('qty') || l.contains('items'))) continue;
      final v = _largest(lines[i]) ?? (i + 1 < lines.length ? _largest(lines[i + 1]) : null);
      if (v != null && v > 0) {
        amount = v;
        break outer;
      }
    }
  }
  if (amount == null) {
    double? best;
    for (final l in lines) {
      if (!l.contains('.')) continue;
      final v = _largest(l);
      if (v != null && (best == null || v > best)) best = v;
    }
    amount = best;
  }
  String? merchant;
  for (final l in lines.take(5)) {
    final letters = l.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length >= 3 && l.length <= 40) {
      merchant = l;
      break;
    }
  }
  DateTime? date;
  final dm = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(text);
  if (dm != null) {
    var y = int.parse(dm.group(3)!);
    if (y < 100) y += 2000;
    final mo = int.parse(dm.group(2)!);
    final d = int.parse(dm.group(1)!);
    final now = DateTime.now();
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31 && y > 2000 && y < 2100) {
      final candidate = DateTime(y, mo, d, now.hour, now.minute);
      if (!candidate.isAfter(now)) date = candidate;
    }
  }
  return ReceiptResult(amount, merchant, date);
}

Future<String?> pickReceiptImage({bool fromGallery = false}) async {
  try {
    final x = await AppLockGate.suspendWhile(() => ImagePicker().pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1800));
    return x?.path;
  } catch (_) {
    return null;
  }
}

Future<String> saveReceiptFile(int txnId, String src) async {
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/receipts');
  if (!await folder.exists()) await folder.create(recursive: true);
  if (src.startsWith(folder.path)) return src;
  final dest = '${folder.path}/receipt_${txnId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(src).copy(dest);
  return dest;
}

Future<void> deleteReceiptFile(String? path) async {
  if (path == null) return;
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

Future<void> startReceiptScan(BuildContext context, {bool fromGallery = false}) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final path = await pickReceiptImage(fromGallery: fromGallery);
  if (path == null) return;
  final text = await Native.ocr(path) ?? '';
  final r = parseReceipt(text);
  nav.push(fadeRoute(AddTxnScreen(
    type: TxnType.expense,
    initialAmount: r.amount,
    initialPayee: r.merchant,
    initialWhen: r.date,
    receiptPath: path,
  )));
  if (r.amount == null) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Could not read the total. Enter it with the keypad.')));
  }
}
