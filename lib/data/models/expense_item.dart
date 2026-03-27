import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'expense_category.dart';

part 'expense_item.g.dart';

@HiveType(typeId: 1)
class ExpenseItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final ExpenseCategory category;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final String? customCategory;

  ExpenseItem({
    required this.id,
    required this.amount,
    required this.date,
    required this.category,
    required this.description,
    this.customCategory,
  });

  factory ExpenseItem.create({
    required double amount,
    required DateTime date,
    required ExpenseCategory category,
    required String description,
    String? customCategory,
  }) {
    return ExpenseItem(
      id: const Uuid().v4(),
      amount: amount,
      date: date,
      category: category,
      description: description,
      customCategory: customCategory,
    );
  }
}
