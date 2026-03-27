import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/budget_model.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/expense_item.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../providers.dart';

class DashboardState {
  final double totalSpent;
  final Map<ExpenseCategory, double> categorySpending;
  final Map<ExpenseCategory, double> categoryBudgets;
  final ExpenseCategory? biggestSpendingCategory;
  final List<ExpenseItem> recentExpenses;

  /// Full list of current-month expenses — used by the Analytics screen.
  final List<ExpenseItem> allCurrentMonthExpenses;

  /// All budgets including custom ones — used by SettingsScreen & Dashboard.
  final List<BudgetModel> allBudgets;

  /// Spending for custom (non-enum) budgets, keyed by storageKey.
  final Map<String, double> customBudgetSpending;

  DashboardState({
    required this.totalSpent,
    required this.categorySpending,
    required this.categoryBudgets,
    this.biggestSpendingCategory,
    required this.recentExpenses,
    this.allCurrentMonthExpenses = const [],
    this.allBudgets = const [],
    this.customBudgetSpending = const {},
  });

  factory DashboardState.initial() {
    return DashboardState(
      totalSpent: 0,
      categorySpending: {for (var c in ExpenseCategory.values) c: 0.0},
      categoryBudgets: {for (var c in ExpenseCategory.values) c: 0.0},
      recentExpenses: [],
      allCurrentMonthExpenses: [],
      allBudgets: [],
      customBudgetSpending: {},
    );
  }

  DashboardState copyWith({
    double? totalSpent,
    Map<ExpenseCategory, double>? categorySpending,
    Map<ExpenseCategory, double>? categoryBudgets,
    ExpenseCategory? biggestSpendingCategory,
    List<ExpenseItem>? recentExpenses,
    List<ExpenseItem>? allCurrentMonthExpenses,
    List<BudgetModel>? allBudgets,
    Map<String, double>? customBudgetSpending,
  }) {
    return DashboardState(
      totalSpent: totalSpent ?? this.totalSpent,
      categorySpending: categorySpending ?? this.categorySpending,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      biggestSpendingCategory:
          biggestSpendingCategory ?? this.biggestSpendingCategory,
      recentExpenses: recentExpenses ?? this.recentExpenses,
      allCurrentMonthExpenses:
          allCurrentMonthExpenses ?? this.allCurrentMonthExpenses,
      allBudgets: allBudgets ?? this.allBudgets,
      customBudgetSpending: customBudgetSpending ?? this.customBudgetSpending,
    );
  }
}

class DashboardViewModel extends StateNotifier<DashboardState> {
  final ExpenseRepository _expenseRepository;
  final BudgetRepository _budgetRepository;

  DashboardViewModel(this._expenseRepository, this._budgetRepository)
      : super(DashboardState.initial()) {
    loadDashboardData();
  }

  void loadDashboardData() {
    final expenses = _expenseRepository.getAllExpenses();
    final budgets = _budgetRepository.getAllBudgets();

    // Filter for current month
    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) {
      return e.date.year == now.year && e.date.month == now.month;
    }).toList();

    // Calculate Total Spent
    double totalSpent = 0;
    final Map<ExpenseCategory, double> categorySpending = {
      for (var c in ExpenseCategory.values) c: 0.0
    };

    // Build spending map for custom budgets (keyed by storageKey).
    final Map<String, double> customBudgetSpending = {};
    for (final budget in budgets) {
      if (budget.isCustom) {
        customBudgetSpending[budget.storageKey] = 0.0;
      }
    }

    for (var expense in currentMonthExpenses) {
      totalSpent += expense.amount;

      if (expense.customCategory != null) {
        final storageKey = 'custom_${expense.customCategory}';
        customBudgetSpending[storageKey] =
            (customBudgetSpending[storageKey] ?? 0) + expense.amount;
      } else {
        categorySpending[expense.category] =
            (categorySpending[expense.category] ?? 0) + expense.amount;
      }
    }

    // Load Budgets
    final Map<ExpenseCategory, double> categoryBudgets = {
      for (var c in ExpenseCategory.values) c: 0.0
    };
    for (var budget in budgets) {
      if (budget.category != null) {
        categoryBudgets[budget.category!] = budget.monthlyLimit;
      }
    }

    // Find Biggest Spender
    ExpenseCategory? biggestSpender;
    double maxSpent = 0;
    categorySpending.forEach((key, value) {
      if (value > maxSpent) {
        maxSpent = value;
        biggestSpender = key;
      }
    });

    // Budgets are already populated earlier.

    state = state.copyWith(
      totalSpent: totalSpent,
      categorySpending: categorySpending,
      categoryBudgets: categoryBudgets,
      biggestSpendingCategory: biggestSpender,
      recentExpenses: currentMonthExpenses.take(5).toList(),
      allCurrentMonthExpenses: currentMonthExpenses,
      allBudgets: budgets,
      customBudgetSpending: customBudgetSpending,
    );
  }

  Future<void> refresh() async {
    loadDashboardData();
  }
}

final dashboardViewModelProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  return DashboardViewModel(expenseRepo, budgetRepo);
});
