import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/expense_category.dart';

// ---------------------------------------------------------------------------
// Internal row model — decoupled from Hive so we can edit freely in memory.
// ---------------------------------------------------------------------------
class _BudgetRow {
  final String storageKey; // Hive key — null means "new, not yet saved"
  final bool isCustom;
  final ExpenseCategory? category; // null for custom rows
  final TextEditingController nameController;
  final TextEditingController amountController;
  bool isWeeklyProjected;

  _BudgetRow({
    required this.storageKey,
    required this.isCustom,
    this.category,
    required this.nameController,
    required this.amountController,
    this.isWeeklyProjected = false,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final List<_BudgetRow> _rows = [];
  bool _isSaving = false;

  // Keys to delete when saving (if user removed a row)
  final Set<String> _keysToDelete = {};

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  void _loadRows() {
    final repo = ref.read(budgetRepositoryProvider);
    final all = repo.getAllBudgets();

    // Track which enum categories already have a saved budget.
    final savedCategories = <ExpenseCategory>{};

    for (final budget in all) {
      if (budget.category != null) {
        savedCategories.add(budget.category!);
      }
      _rows.add(_BudgetRow(
        storageKey: budget.storageKey,
        isCustom: budget.isCustom,
        category: budget.category,
        nameController: TextEditingController(text: budget.displayName),
        amountController:
            TextEditingController(text: budget.monthlyLimit.toStringAsFixed(2)),
        isWeeklyProjected: budget.isWeeklyProjected,
      ));
    }

    // For enum categories that have NO saved budget yet, seed default rows.
    for (final cat in ExpenseCategory.values) {
      if (!savedCategories.contains(cat)) {
        _rows.add(_BudgetRow(
          storageKey: cat.name,
          isCustom: false,
          category: cat,
          nameController: TextEditingController(text: cat.displayName),
          amountController: TextEditingController(text: '0.00'),
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _addCustomBudget() {
    setState(() {
      final uniqueKey = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      _rows.add(_BudgetRow(
        storageKey: uniqueKey,
        isCustom: true,
        category: null,
        nameController: TextEditingController(text: ''),
        amountController: TextEditingController(text: '0.00'),
        isWeeklyProjected: false,
      ));
    });
    // Scroll to bottom after the frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No explicit scroll controller needed — the new card will be visible
    });
  }

  void _deleteRow(_BudgetRow row) {
    setState(() {
      _keysToDelete.add(row.storageKey);
      _rows.remove(row);
      row.dispose();
    });
  }

  Future<void> _saveAll() async {
    // Validate
    for (final row in _rows) {
      if (row.isCustom && row.nameController.text.trim().isEmpty) {
        _showError('Please enter a name for all custom budgets.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final repo = ref.read(budgetRepositoryProvider);

    // Delete removed rows
    for (final key in _keysToDelete) {
      await repo.deleteBudget(key);
    }

    // Save / update every visible row
    for (final row in _rows) {
      final amount = double.tryParse(row.amountController.text) ?? 0.0;
      final customName = row.isCustom ? row.nameController.text.trim() : null;

      // For enum-backed rows the user may have edited the name display label —
      // we store that in customName even though category is still set.
      final editedLabel = row.nameController.text.trim();
      final originalLabel = row.category?.displayName ?? '';
      final labelChanged = !row.isCustom && editedLabel != originalLabel;

      final budget = BudgetModel(
        category: row.category,
        monthlyLimit: amount,
        customName:
            row.isCustom ? customName : (labelChanged ? editedLabel : null),
        isWeeklyProjected: row.isWeeklyProjected,
      );

      await repo.setBudget(budget);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Budgets saved!'),
            ],
          ),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Color _categoryColor(ExpenseCategory? cat) {
    if (cat == null) return const Color(0xFF7C3AED); // violet for custom
    switch (cat) {
      case ExpenseCategory.bills:
        return const Color(0xFFEF4444);
      case ExpenseCategory.groceries:
        return const Color(0xFF10B981);
      case ExpenseCategory.foodOut:
        return const Color(0xFFF59E0B);
      case ExpenseCategory.pets:
        return const Color(0xFF8B5CF6);
      case ExpenseCategory.transport:
        return const Color(0xFF3B82F6);
      case ExpenseCategory.misc:
        return const Color(0xFF6B7280);
    }
  }

  IconData _categoryIcon(ExpenseCategory? cat) {
    if (cat == null) return Icons.label_outline;
    switch (cat) {
      case ExpenseCategory.bills:
        return Icons.receipt_long_outlined;
      case ExpenseCategory.groceries:
        return Icons.local_grocery_store_outlined;
      case ExpenseCategory.foodOut:
        return Icons.restaurant_outlined;
      case ExpenseCategory.pets:
        return Icons.pets_outlined;
      case ExpenseCategory.transport:
        return Icons.directions_car_outlined;
      case ExpenseCategory.misc:
        return Icons.category_outlined;
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Monthly Budgets',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : TextButton.icon(
                  onPressed: _saveAll,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: _rows.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                return _BudgetCard(
                  key: ValueKey(_rows[index].storageKey),
                  row: _rows[index],
                  accentColor: _categoryColor(_rows[index].category),
                  icon: _categoryIcon(_rows[index].category),
                  onDelete: _rows[index].isCustom
                      ? () => _deleteRow(_rows[index])
                      : null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomBudget,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Budget',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No budgets yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + New Budget to get started.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Budget card widget
// ---------------------------------------------------------------------------
class _BudgetCard extends StatefulWidget {
  final _BudgetRow row;
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onDelete;

  const _BudgetCard({
    super.key,
    required this.row,
    required this.accentColor,
    required this.icon,
    this.onDelete,
  });

  @override
  State<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<_BudgetCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + name field + delete button
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.row.nameController,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      hintText: 'Budget name',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: widget.accentColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                if (widget.onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: Color(0xFFEF4444)),
                    tooltip: 'Remove budget',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Amount field
            Row(
              children: [
                const SizedBox(width: 52), // indent to align with name
                Expanded(
                  child: TextField(
                    controller: widget.row.amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.accentColor,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      prefixText: 'RM  ',
                      prefixStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      labelText: 'Monthly limit',
                      labelStyle:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: widget.accentColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 8),

            // Projection toggle
            InkWell(
              onTap: () {
                setState(() {
                  widget.row.isWeeklyProjected = !widget.row.isWeeklyProjected;
                });
              },
              child: Row(
                children: [
                  Checkbox(
                    value: widget.row.isWeeklyProjected,
                    onChanged: (val) {
                      setState(() {
                        widget.row.isWeeklyProjected = val ?? false;
                      });
                    },
                    activeColor: widget.accentColor,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const Expanded(
                    child: Text(
                      'Project weekly targets in charts',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
