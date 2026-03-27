import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class BudgetProgressBar extends StatelessWidget {
  final double spent;
  final double limit;
  final String label;
  final Color baseColor;

  const BudgetProgressBar({
    super.key,
    required this.spent,
    required this.limit,
    required this.label,
    this.baseColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    // Avoid division by zero
    final percentage = limit > 0 ? (spent / limit) : 0.0;
    // Cap at 1.0 for the bar, but logic handles color
    final displayPercentage = percentage > 1.0 ? 1.0 : percentage;

    Color progressColor;
    if (percentage < 0.7) {
      progressColor = Colors.green;
    } else if (percentage < 0.9) {
      progressColor = Colors.amber;
    } else {
      progressColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              '${(percentage * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: progressColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentIndicator(
          lineHeight: 12.0,
          percent: displayPercentage,
          backgroundColor: Colors.grey[200],
          progressColor: progressColor,
          barRadius: const Radius.circular(6),
          padding: EdgeInsets.zero,
          animation: true,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RM ${spent.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Limit: RM ${limit.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }
}
