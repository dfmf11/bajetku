import 'package:hive_flutter/hive_flutter.dart';
import '../models/expense_item.dart';

class ExpenseRepository {
  final Box<ExpenseItem> _box;

  ExpenseRepository(this._box);

  Future<void> addExpense(ExpenseItem expense) async {
    await _box.put(expense.id, expense);
  }

  Future<void> deleteExpense(String id) async {
    await _box.delete(id);
  }

  Future<void> updateExpense(ExpenseItem expense) async {
    await _box.put(expense.id, expense);
  }

  List<ExpenseItem> getAllExpenses() {
    return _box.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date desc
  }
}
