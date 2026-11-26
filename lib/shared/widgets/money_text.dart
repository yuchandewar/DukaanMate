import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MoneyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool showSymbol;

  const MoneyText({
    super.key,
    required this.amount,
    this.style,
    this.showSymbol = true,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: showSymbol ? '₹' : '',
      decimalDigits: amount.truncateToDouble() == amount ? 0 : 2,
    );

    return Text(
      format.format(amount),
      style: style,
      maxLines: 1,
    );
  }
}
