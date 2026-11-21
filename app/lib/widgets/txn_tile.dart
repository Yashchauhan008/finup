import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';

String prettyParty(String? s) {
  if (s == null || s.trim().isEmpty) return '';
  var v = s.trim();
  if (v.contains('@')) v = v.split('@').first;
  return v.length > 28 ? '${v.substring(0, 28)}…' : v;
}

Color typeColor(TxnType t) => switch (t) {
      TxnType.expense => AppColors.expense,
      TxnType.income => AppColors.income,
      TxnType.transfer => AppColors.lavender,
      TxnType.invest => const Color(0xFF5B8DEF),
    };

String dayLabel(DateTime d) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat(d.year == n.year ? 'EEE, d MMM' : 'd MMM yyyy').format(d);
}

class TxnTile extends StatelessWidget {
  final Txn txn;
  final bool hide;
  final bool showDate;
  final VoidCallback? onTap;

  const TxnTile({
    super.key,
    required this.txn,
    this.hide = false,
    this.showDate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final cat = context.read<TxnState>().category(txn.categoryId);
    final accounts = context.read<AccountsState>().accounts;
    String accName(int? id) {
      for (final a in accounts) {
        if (a.id == id) return a.name;
      }
      return 'Account';
    }

    final isTransfer = txn.type == TxnType.transfer;
    final isInvest = txn.type == TxnType.invest;
    final color = txn.personId != null
        ? const Color(0xFFF4A261)
        : (cat?.colorValue ?? typeColor(txn.type));
    final icon = txn.personId != null
        ? Icons.people_alt_rounded
        : (isInvest
            ? (txn.amount < 0
                ? Icons.unpublished_rounded
                : Icons.savings_rounded)
            : (isTransfer
                ? Icons.swap_horiz_rounded
                : (cat?.icon ??
                    (txn.type == TxnType.income
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded))));
    final party = prettyParty(txn.counterparty);
    final title = isInvest
        ? (txn.amount < 0
            ? 'Goal → ${accName(txn.accountId)}'
            : '${accName(txn.accountId)} → Goal')
        : (isTransfer
            ? '${accName(txn.accountId)} → ${accName(txn.toAccountId)}'
            : (party.isNotEmpty
                ? party
                : (cat?.name ??
                    (txn.type == TxnType.income ? 'Income' : 'Expense'))));
    final time = DateFormat(showDate ? 'd MMM, h:mm a' : 'h:mm a')
        .format(txn.occurredAt);
    final label = isInvest
        ? (party.isNotEmpty
            ? party
            : (txn.amount < 0 ? 'Goal withdraw' : 'Invest to goal'))
        : (isTransfer
            ? (party.isNotEmpty ? party : 'Transfer')
            : (txn.personId != null
                ? (txn.type == TxnType.expense
                    ? 'Gave to a person'
                    : 'Got from a person')
                : (cat?.name ?? 'Needs review')));
    final displayAmount = txn.amount.abs();
    final sign = isInvest
        ? (txn.amount < 0 ? '+' : '-')
        : (txn.type == TxnType.expense
            ? '-'
            : (txn.type == TxnType.income ? '+' : ''));
    final amountColor = txn.type == TxnType.income
        ? AppColors.income
        : (isTransfer || isInvest ? typeColor(txn.type) : fin.text);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fin.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text('$label · $time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: txn.status == 'review'
                            ? AppColors.lavender
                            : fin.subtext,
                        fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hide ? '₹ ••••' : '$sign${inr(isInvest ? displayAmount : txn.amount)}',
            style: TextStyle(
                color: amountColor, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ]),
      ),
    );
  }
}
