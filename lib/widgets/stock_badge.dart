import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// The running stock figure, shown big enough to read at arm's length.
class StockBadge extends StatelessWidget {
  final int quantity;
  final double fontSize;

  const StockBadge({super.key, required this.quantity, this.fontSize = 24});

  @override
  Widget build(BuildContext context) {
    final isZero = quantity == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isZero
            ? AppColors.dispatch.withValues(alpha: 0.10)
            : AppColors.brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$quantity',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isZero ? AppColors.dispatch : AppColors.brandBlue,
        ),
      ),
    );
  }
}
