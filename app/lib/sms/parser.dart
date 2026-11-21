class ParsedSms {
  final double amount;
  final bool isDebit;
  final String? last4;
  final String? counterparty;
  final String? ref;
  final double? balance;
  final DateTime when;
  final bool isAtm;
  final String bankName;
  final bool knownBank;

  const ParsedSms({
    required this.amount,
    required this.isDebit,
    required this.last4,
    required this.counterparty,
    required this.ref,
    required this.balance,
    required this.when,
    required this.isAtm,
    required this.bankName,
    required this.knownBank,
  });
}

class SmsParser {
  static final RegExp _skip = RegExp(
      r'\b(otp|one time password|verification code|requested|request money|will be debited|failed|declined|unsuccessful)\b',
      caseSensitive: false);
  static final RegExp _promo = RegExp(
      r'\b(offer|apply now|pre-approved|preapproved|loan|win|congratulations|voucher|discount)\b',
      caseSensitive: false);
  static final RegExp _amount = RegExp(
      r'(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false);
  static final RegExp _drcr = RegExp(
      r'(?:rs\.?|inr|₹)\s*[0-9][0-9,]*(?:\.[0-9]{1,2})?\s*(dr|cr)\b',
      caseSensitive: false);
  static final RegExp _acct = RegExp(
      r'(?:a/c|acct|account)\.?\s*(?:no\.?\s*)?[x*.\-\s]*([0-9]{3,6})',
      caseSensitive: false);
  static final RegExp _vpa =
      RegExp(r'[a-z0-9][a-z0-9.\-_]+@[a-z][a-z0-9]+', caseSensitive: false);
  static final RegExp _ref = RegExp(
      r'(?:ref(?:erence)?|utr|rrn|txn\s*id)(?:\s*no)?[\s.:#-]*([0-9]{6,})',
      caseSensitive: false);
  static final RegExp _bal = RegExp(
      r'(?:avl\.?\s*bal(?:ance)?|available\s+bal(?:ance)?|\bbal(?:ance)?)\s*(?:is)?[\s:.-]*(?:rs\.?|inr|₹)?\s*(-?[0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false);
  static final RegExp _date = RegExp(
      r'(\d{4})[:\-/](\d{2})[:\-/](\d{2})[\sT]+(\d{2}):(\d{2})(?::(\d{2}))?');
  static final RegExp _merchant = RegExp(
      r'\b(?:at|to|towards|from|by)\s+([A-Za-z][A-Za-z0-9&\s.\-]{2,30}?)(?=\s+on\b|\.|,|\s+ref|\s+avl|$)',
      caseSensitive: false);
  static final RegExp _badParty =
      RegExp(r'a/c|your|account', caseSensitive: false);

  static String? _bankName(String up) {
    if (up.contains('BOB')) return 'Bank of Baroda';
    if (up.contains('HDFC')) return 'HDFC Bank';
    if (up.contains('ICICI')) return 'ICICI Bank';
    if (up.contains('SBI')) return 'State Bank of India';
    if (up.contains('AXIS')) return 'Axis Bank';
    if (up.contains('KOTAK')) return 'Kotak Bank';
    if (up.contains('PNB')) return 'Punjab National Bank';
    return null;
  }

  static ParsedSms? parse(String address, String body, DateTime received) {
    final text = body.replaceAll('\n', ' ');
    if (_skip.hasMatch(text)) return null;
    final am = _amount.firstMatch(text);
    if (am == null) return null;
    final amount = double.tryParse(am.group(1)!.replaceAll(',', ''));
    if (amount == null || amount <= 0) return null;
    final lower = text.toLowerCase();

    final bool debit;
    final dc = _drcr.firstMatch(text);
    if (dc != null) {
      debit = dc.group(1)!.toLowerCase() == 'dr';
    } else {
      int first(List<String> words) {
        var best = -1;
        for (final w in words) {
          final i = lower.indexOf(w);
          if (i >= 0 && (best < 0 || i < best)) best = i;
        }
        return best;
      }

      final d = first(const ['debited', 'spent', 'paid', 'sent', 'withdrawn', 'purchase', 'debit', ' dr ']);
      final c = first(const ['credited', 'received', 'deposited', 'refund', 'credit', ' cr ']);
      if (d < 0 && c < 0) return null;
      debit = c < 0 || (d >= 0 && d < c);
    }

    String? last4;
    final acct = _acct.firstMatch(text);
    if (acct != null) {
      final g = acct.group(1)!;
      last4 = g.length > 4 ? g.substring(g.length - 4) : g;
    }

    final vpa = _vpa.firstMatch(text)?.group(0);
    String? party = vpa;
    if (party == null) {
      final cand = _merchant.firstMatch(text)?.group(1)?.trim();
      if (cand != null && cand.isNotEmpty && !_badParty.hasMatch(cand)) {
        party = cand;
      }
    }

    final ref = _ref.firstMatch(text)?.group(1);
    final bm = _bal.firstMatch(text);
    final balance =
        bm == null ? null : double.tryParse(bm.group(1)!.replaceAll(',', ''));

    var when = received;
    final dm = _date.firstMatch(text);
    if (dm != null) {
      final y = int.parse(dm.group(1)!);
      final mo = int.parse(dm.group(2)!);
      final d = int.parse(dm.group(3)!);
      if (y > 2000 && y < 2100 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
        when = DateTime(y, mo, d, int.parse(dm.group(4)!),
            int.parse(dm.group(5)!), int.parse(dm.group(6) ?? '0'));
      }
    }

    final bank = _bankName(address.toUpperCase());
    final known = bank != null;
    if (last4 == null && (_promo.hasMatch(text) || (!known && vpa == null))) {
      return null;
    }
    final atm = debit &&
        (lower.contains('atm') ||
            lower.contains('cash withdrawal') ||
            lower.contains('withdrawn'));

    return ParsedSms(
      amount: amount,
      isDebit: debit,
      last4: last4,
      counterparty: atm ? 'ATM withdrawal' : party,
      ref: ref,
      balance: balance,
      when: when,
      isAtm: atm,
      bankName: bank ?? 'Bank',
      knownBank: known,
    );
  }
}
