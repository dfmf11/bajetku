import 'package:hive_flutter/hive_flutter.dart';
import '../models/budget_model.dart';
import '../models/expense_category.dart';

class BudgetRepository {
  final Box<BudgetModel> _box;

  BudgetRepository(this._box);

  /// Save (or update) a budget using its own storage key.
  Future<void> setBudget(BudgetModel budget) async {
    await _box.put(budget.storageKey, budget);
  }

  /// Legacy helper retained for compatibility — looks up by enum category.
  BudgetModel? getBudget(ExpenseCategory category) {
    return _box.get(category.name);
  }

  /// Look up any budget by its storage key.
  BudgetModel? getBudgetByKey(String key) {
    return _box.get(key);
  }

  List<BudgetModel> getAllBudgets() {
    return _box.values.toList();
  }

  /// Delete a budget entry by its storage key.
  Future<void> deleteBudget(String key) async {
    await _box.delete(key);
  }
}
