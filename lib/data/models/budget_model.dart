import 'package:hive/hive.dart';
import 'expense_category.dart';

part 'budget_model.g.dart';

@HiveType(typeId: 2)
class BudgetModel {
  @HiveField(0)
  final ExpenseCategory? category;

  @HiveField(1)
  final double monthlyLimit;

  /// Optional custom name — used when the user creates a custom budget
  /// that doesn't map to one of the built-in ExpenseCategory enum values.
  @HiveField(2)
  final String? customName;

  @HiveField(3, defaultValue: false)
  final bool isWeeklyProjected;

  BudgetModel({
    this.category,
    required this.monthlyLimit,
    this.customName,
    this.isWeeklyProjected = false,
  }) : assert(
          category != null || (customName != null && customName.isNotEmpty),
          'Either category or customName must be provided',
        );

  /// Human-readable display name for this budget entry.
  String get displayName => customName ?? category?.displayName ?? 'Unknown';

  /// Whether this budget uses the built-in enum category.
  bool get isCustom => category == null;

  /// The storage key for this budget in Hive.
  /// For enum-backed budgets:   bills, groceries, …
  /// For custom budgets:        custom_<customName>
  String get storageKey =>
      category != null ? category!.name : 'custom_$customName';
}
