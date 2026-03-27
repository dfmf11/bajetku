import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/viewmodels/dashboard_viewmodel.dart';
import '../../data/models/expense_item.dart';

class ExpenseLogScreen extends ConsumerStatefulWidget {
  const ExpenseLogScreen({super.key});

  @override
  ConsumerState<ExpenseLogScreen> createState() => _ExpenseLogScreenState();
}

class _ExpenseLogScreenState extends ConsumerState<ExpenseLogScreen> {
  List<ExpenseItem> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    final expenses = ref.read(expenseRepositoryProvider).getAllExpenses();
    setState(() {
      _expenses = expenses;
    });
  }

  void _deleteExpense(String id) async {
    await ref.read(expenseRepositoryProvider).deleteExpense(id);
    // Refresh dashboard stats
    ref.read(dashboardViewModelProvider.notifier).loadDashboardData();
    _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
      ),
      body: _expenses.isEmpty
          ? const Center(child: Text('No expenses recorded yet.'))
          : ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                return Dismissible(
                  key: Key(expense.id),
                  background: Container(color: Colors.red),
                  onDismissed: (direction) {
                    _deleteExpense(expense.id);
                  },
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.money), // Can map to category icon
                    ),
                    title: Text(
                        expense.customCategory ?? expense.category.displayName),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(expense.date)}\n${expense.description}',
                    ),
                    trailing: Text(
                      'RM ${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
