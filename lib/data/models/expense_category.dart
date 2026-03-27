import 'package:hive/hive.dart';

part 'expense_category.g.dart';

@HiveType(typeId: 0)
enum ExpenseCategory {
  @HiveField(0)
  bills,
  @HiveField(1)
  groceries,
  @HiveField(2)
  foodOut,
  @HiveField(3)
  pets,
  @HiveField(4)
  transport,
  @HiveField(5)
  misc;

  String get displayName {
    switch (this) {
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.groceries:
        return 'Groceries';
      case ExpenseCategory.foodOut:
        return 'Food Out';
      case ExpenseCategory.pets:
        return 'Pets';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.misc:
        return 'Misc';
    }
  }
}
