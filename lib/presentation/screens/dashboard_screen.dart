import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/viewmodels/dashboard_viewmodel.dart';
import '../../core/providers.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/category_transactions_sheet.dart';
import 'analytics_screen.dart';
import 'expense_log_screen.dart';
import 'settings_screen.dart';
import 'add_expense_screen.dart';
import 'coin_jar_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('BajetKu'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.monetization_on_outlined),
            tooltip: 'Coin Jar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoinJarScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseLogScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) {
                ref.read(dashboardViewModelProvider.notifier).refresh();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(dashboardViewModelProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary Card — tappable → Analytics ──────────────────
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Spending (This Month)',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'RM ${dashboardState.totalSpent.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(Icons.analytics_outlined,
                              color: Colors.white60, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'View Analytics',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.white60, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Categories Section ────────────────────────────────────
              const Text(
                'Budgets & Spending',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Dynamic List of Enum Categories
              ...dashboardState.categorySpending.entries.map((entry) {
                final category = entry.key;
                final spent = entry.value;
                final limit = dashboardState.categoryBudgets[category] ?? 0.0;

                return GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    showCategoryTransactionsSheet(
                      context: context,
                      allExpenses: dashboardState.allCurrentMonthExpenses,
                      month: DateTime(now.year, now.month),
                      category: category,
                    );
                  },
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: BudgetProgressBar(
                        spent: spent,
                        limit: limit,
                        label: category.displayName,
                      ),
                    ),
                  ),
                );
              }),

              // Custom budgets added in Monthly Budget Settings
              ...dashboardState.allBudgets
                  .where((b) => b.isCustom)
                  .map((budget) {
                final spent =
                    dashboardState.customBudgetSpending[budget.storageKey] ??
                        0.0;
                return GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    showCategoryTransactionsSheet(
                      context: context,
                      allExpenses: dashboardState.allCurrentMonthExpenses,
                      month: DateTime(now.year, now.month),
                      customCategoryKey: budget.storageKey,
                      customCategoryName: budget.displayName,
                    );
                  },
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: BudgetProgressBar(
                        spent: spent,
                        limit: budget.monthlyLimit,
                        label: budget.displayName,
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final income = ref.read(coinJarIncomeProvider);
          final totalSpent = ref.read(dashboardViewModelProvider).totalSpent;

          if (income <= 0 || (income - totalSpent) <= 0) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Action Required'),
                content: const Text(
                    'You must add an income before you can add any expense.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AddExpenseScreen(),
          ).then((_) {
            ref.read(dashboardViewModelProvider.notifier).refresh();
          });
        },
        label: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }
}
