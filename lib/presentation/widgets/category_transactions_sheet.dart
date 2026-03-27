import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/expense_category.dart';
import '../../data/models/expense_item.dart';

// ─── Colour palette (shared with analytics) ─────────────────────────────────
const _catColors = {
  ExpenseCategory.bills: Color(0xFFEF4444),
  ExpenseCategory.groceries: Color(0xFF22C55E),
  ExpenseCategory.foodOut: Color(0xFFF59E0B),
  ExpenseCategory.pets: Color(0xFFA855F7),
  ExpenseCategory.transport: Color(0xFF3B82F6),
  ExpenseCategory.misc: Color(0xFF6B7280),
};

Color _catColor(ExpenseCategory c) =>
    _catColors[c] ?? const Color(0xFF6B7280);

IconData _catIcon(ExpenseCategory cat) {
  switch (cat) {
    case ExpenseCategory.bills:
      return Icons.receipt_long_outlined;
    case ExpenseCategory.groceries:
      return Icons.local_grocery_store_outlined;
    case ExpenseCategory.foodOut:
      return Icons.restaurant_outlined;
    case ExpenseCategory.pets:
      return Icons.pets_outlined;
    case ExpenseCategory.transport:
      return Icons.directions_car_outlined;
    case ExpenseCategory.misc:
      return Icons.category_outlined;
  }
}

/// Shows a draggable bottom sheet listing transactions for a given category.
///
/// Works for both enum-based categories and custom budget categories.
///
/// For **enum categories**, pass [category] and leave [customCategoryKey] null.
/// For **custom budgets**, pass [customCategoryKey] (the storageKey, e.g.
/// `"custom_Coffee"`) and [customCategoryName] for display.
void showCategoryTransactionsSheet({
  required BuildContext context,
  required List<ExpenseItem> allExpenses,
  required DateTime month,
  ExpenseCategory? category,
  String? customCategoryKey,
  String? customCategoryName,
  Color? accentColor,
}) {
  assert(
    category != null || customCategoryKey != null,
    'Either category or customCategoryKey must be provided',
  );

  // Filter expenses for this category + month
  final filtered = allExpenses.where((e) {
    if (e.date.year != month.year || e.date.month != month.month) return false;
    if (category != null) {
      // Enum category — only include items that DON'T have a customCategory set
      return e.category == category && e.customCategory == null;
    } else {
      // Custom budget category
      return e.customCategory != null &&
          'custom_${e.customCategory}' == customCategoryKey;
    }
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final total = filtered.fold(0.0, (sum, e) => sum + e.amount);
  final displayName =
      category != null ? category.displayName : (customCategoryName ?? 'Custom');
  final color = accentColor ??
      (category != null ? _catColor(category) : const Color(0xFF6B7280));
  final icon = category != null ? _catIcon(category) : Icons.label_outlined;
  final monthLabel = DateFormat('MMMM yyyy').format(month);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          monthLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RM ${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      Text(
                        '${filtered.length} transaction${filtered.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0), height: 1),

            // Transaction list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                      itemBuilder: (_, idx) {
                        final tx = filtered[idx];
                        final dateLabel =
                            DateFormat('d MMM, EEE').format(tx.date);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              // Date badge
                              Container(
                                width: 46,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('d').format(tx.date),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM')
                                          .format(tx.date)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: color.withValues(alpha: 0.7),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.description.isNotEmpty
                                          ? tx.description
                                          : displayName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateLabel,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Amount
                              Text(
                                'RM ${tx.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
