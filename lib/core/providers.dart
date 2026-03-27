import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../data/models/budget_model.dart';
import '../data/models/expense_item.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/expense_repository.dart';

// Box Providers (to be overridden in main)
final expenseBoxProvider = Provider<Box<ExpenseItem>>((ref) {
  throw UnimplementedError('Expense Box not initialized');
});

final budgetBoxProvider = Provider<Box<BudgetModel>>((ref) {
  throw UnimplementedError('Budget Box not initialized');
});

final settingsBoxProvider = Provider<Box<dynamic>>((ref) {
  throw UnimplementedError('Settings Box not initialized');
});

// Repository Providers
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(expenseBoxProvider));
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(budgetBoxProvider));
});

class CoinJarIncomeNotifier extends StateNotifier<double> {
  final Box<dynamic> _box;
  CoinJarIncomeNotifier(this._box)
      : super(_box.get('coin_jar_income', defaultValue: 0.0)) {
    // If we wanted to listen to changes outside, we might listen here,
    // but typically it's all through this notifier.
  }

  void updateIncome(double income) {
    state = income;
    _box.put('coin_jar_income', income);
  }
}

final coinJarIncomeProvider =
    StateNotifierProvider<CoinJarIncomeNotifier, double>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return CoinJarIncomeNotifier(box);
});
