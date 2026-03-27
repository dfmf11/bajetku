import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/providers.dart';
import 'data/models/budget_model.dart';
import 'data/models/expense_category.dart';
import 'data/models/expense_item.dart';
import 'presentation/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(ExpenseCategoryAdapter());
  Hive.registerAdapter(ExpenseItemAdapter());
  Hive.registerAdapter(BudgetModelAdapter());

  // Open Boxes
  final expenseBox = await Hive.openBox<ExpenseItem>('expenses');
  final budgetBox = await Hive.openBox<BudgetModel>('budgets');
  final settingsBox = await Hive.openBox('settings');

  runApp(
    ProviderScope(
      overrides: [
        expenseBoxProvider.overrideWithValue(expenseBox),
        budgetBoxProvider.overrideWithValue(budgetBox),
        settingsBoxProvider.overrideWithValue(settingsBox),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BajetKu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B9AC4)), // Soft Blue
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
