import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/expense_item.dart';
import '../widgets/category_transactions_sheet.dart';

// ─── Colour palette ──────────────────────────────────────────────────────────
const _catColors = {
  ExpenseCategory.bills: Color(0xFFEF4444),
  ExpenseCategory.groceries: Color(0xFF22C55E),
  ExpenseCategory.foodOut: Color(0xFFF59E0B),
  ExpenseCategory.pets: Color(0xFFA855F7),
  ExpenseCategory.transport: Color(0xFF3B82F6),
  ExpenseCategory.misc: Color(0xFF6B7280),
};

Color _col(ExpenseCategory c) => _catColors[c] ?? const Color(0xFF6B7280);

// ─── Analytics data holder ───────────────────────────────────────────────────
class _AnalyticsData {
  final double totalSpent;
  final Map<ExpenseCategory, double> byCategory; // sorted by amt desc
  final Map<ExpenseCategory, int> txCount;
  final Map<int, Map<ExpenseCategory, double>>
      weeklyCategoryTotals; // week-of-month (1-5) → category → amt
  final ExpenseCategory? topFreqCat;
  final int topFreqCount;
  final ExpenseItem? largestExpense;
  final int txTotal;

  const _AnalyticsData({
    required this.totalSpent,
    required this.byCategory,
    required this.txCount,
    required this.weeklyCategoryTotals,
    this.topFreqCat,
    required this.topFreqCount,
    this.largestExpense,
    required this.txTotal,
  });

  factory _AnalyticsData.empty() => const _AnalyticsData(
        totalSpent: 0,
        byCategory: {},
        txCount: {},
        weeklyCategoryTotals: {},
        topFreqCount: 0,
        txTotal: 0,
      );
}

_AnalyticsData _compute(List<ExpenseItem> all, DateTime month) {
  final filtered = all
      .where((e) => e.date.year == month.year && e.date.month == month.month)
      .toList();

  if (filtered.isEmpty) return _AnalyticsData.empty();

  double total = 0;
  final Map<ExpenseCategory, double> byCat = {};
  final Map<ExpenseCategory, int> txCnt = {};
  final Map<int, Map<ExpenseCategory, double>> weeklyCat = {};
  ExpenseItem? largest;

  for (final e in filtered) {
    total += e.amount;
    byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    txCnt[e.category] = (txCnt[e.category] ?? 0) + 1;

    int weekOfMonth = ((e.date.day - 1) ~/ 7) + 1;
    if (weekOfMonth > 4) weekOfMonth = 4; // Cap at 4 weeks per user request

    weeklyCat.putIfAbsent(weekOfMonth, () => {});
    weeklyCat[weekOfMonth]![e.category] =
        (weeklyCat[weekOfMonth]![e.category] ?? 0) + e.amount;

    if (largest == null || e.amount > largest.amount) largest = e;
  }

  // Sort categories by amount desc
  final sorted = Map.fromEntries(
    byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
  );

  // Most frequent category
  ExpenseCategory? topFreq;
  int topCnt = 0;
  txCnt.forEach((cat, cnt) {
    if (cnt > topCnt) {
      topCnt = cnt;
      topFreq = cat;
    }
  });

  return _AnalyticsData(
    totalSpent: total,
    byCategory: sorted,
    txCount: txCnt,
    weeklyCategoryTotals: weeklyCat,
    topFreqCat: topFreq,
    topFreqCount: topCnt,
    largestExpense: largest,
    txTotal: filtered.length,
  );
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedMonth;
  int? _touchedIndex;
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _prevMonth() {
    setState(() {
      _touchedIndex = null;
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _animCtrl
        ..reset()
        ..forward();
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return; // cap at current
    setState(() {
      _touchedIndex = null;
      _selectedMonth = next;
      _animCtrl
        ..reset()
        ..forward();
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final expenseRepo = ref.watch(expenseRepositoryProvider);
    final budgetRepo = ref.watch(budgetRepositoryProvider);
    final allExpenses = expenseRepo.getAllExpenses();
    final budgets = budgetRepo.getAllBudgets();
    final data = _compute(allExpenses, _selectedMonth);

    // Build budget map for progress bars (amounts)
    final Map<ExpenseCategory, double> budgetMap = {
      for (final b in budgets)
        if (b.category != null) b.category!: b.monthlyLimit,
    };

    // Build full budget map for projections
    final Map<ExpenseCategory, BudgetModel> budgetFullMap = {
      for (final b in budgets)
        if (b.category != null) b.category!: b,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Spending Breakdown',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFE2E8F0)),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Month navigation ─────────────────────────────────
                _buildMonthNav(),
                const SizedBox(height: 20),

                // ── Donut card ───────────────────────────────────────
                _buildDonutCard(data),
                const SizedBox(height: 16),

                // ── Category list card ───────────────────────────────
                if (data.byCategory.isNotEmpty) ...[
                  _buildCategoryListCard(data, budgetMap, allExpenses),
                  const SizedBox(height: 16),
                ],

                // ── Weekly spending bar chart ────────────────────────
                if (budgetFullMap.values.any((b) => b.isWeeklyProjected)) ...[
                  _buildWeeklyBarCard(data, budgetFullMap),
                  const SizedBox(height: 16),
                ],

                // ── Stats grid ───────────────────────────────────────
                _buildStatsGrid(data, allExpenses),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Month navigation bar ─────────────────────────────────────────────────
  Widget _buildMonthNav() {
    final label = DateFormat('MMMM yyyy').format(_selectedMonth);
    final canGoNext = !_isCurrentMonth;

    return Row(
      children: [
        _NavBtn(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 16, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (_isCurrentMonth) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _NavBtn(
          icon: Icons.chevron_right_rounded,
          onTap: canGoNext ? _nextMonth : null,
          disabled: !canGoNext,
        ),
      ],
    );
  }

  // ── Donut + total ────────────────────────────────────────────────────────
  Widget _buildDonutCard(_AnalyticsData data) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: data.totalSpent == 0
                ? _buildEmptyDonut()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total label
                      const Text(
                        'Total Spending',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${data.totalSpent.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Donut chart
                      SizedBox(
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sections: _buildSections(data),
                                centerSpaceRadius: 68,
                                sectionsSpace: 2,
                                startDegreeOffset: -90,
                                pieTouchData: PieTouchData(
                                  touchCallback: (evt, resp) {
                                    setState(() {
                                      if (!evt.isInterestedForInteractions ||
                                          resp?.touchedSection == null) {
                                        _touchedIndex = null;
                                      } else {
                                        _touchedIndex = resp!.touchedSection!
                                            .touchedSectionIndex;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                            // Centre text
                            _buildCenterText(data),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),

                      // Compact legend
                      _buildLegend(data),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDonut() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No expenses in\n${DateFormat('MMMM yyyy').format(_selectedMonth)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(_AnalyticsData data) {
    final entries = data.byCategory.entries.toList();
    return entries.asMap().entries.map((indexed) {
      final i = indexed.key;
      final cat = indexed.value.key;
      final amt = indexed.value.value;
      final pct = data.totalSpent > 0 ? amt / data.totalSpent : 0.0;
      final isTouched = _touchedIndex == i;

      return PieChartSectionData(
        color: _col(cat),
        value: amt,
        title: isTouched ? '${(pct * 100).toStringAsFixed(1)}%' : '',
        radius: isTouched ? 72 : 58,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildCenterText(_AnalyticsData data) {
    final entries = data.byCategory.entries.toList();
    if (_touchedIndex != null && _touchedIndex! < entries.length) {
      final cat = entries[_touchedIndex!].key;
      final amt = entries[_touchedIndex!].value;
      final pct = data.totalSpent > 0 ? amt / data.totalSpent * 100 : 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _col(cat), shape: BoxShape.circle),
          ),
          const SizedBox(height: 4),
          Text(
            cat.displayName,
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'RM ${amt.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Total',
          style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          'RM ${data.totalSpent.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${data.txTotal} transactions',
          style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLegend(_AnalyticsData data) {
    final entries = data.byCategory.entries.toList();
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: entries.map((e) {
        final pct = data.totalSpent > 0 ? e.value / data.totalSpent * 100 : 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: _col(e.key), shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '${e.key.displayName} (${pct.toStringAsFixed(0)}%)',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500),
            ),
          ],
        );
      }).toList(),
    );
  }



  // ── Category breakdown list ──────────────────────────────────────────────
  Widget _buildCategoryListCard(_AnalyticsData data,
      Map<ExpenseCategory, double> budgetMap, List<ExpenseItem> allExpenses) {
    final entries = data.byCategory.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Categories',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B)),
                  ),
                ),
                Text(
                  'Total Spending',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 14),

            // Rows
            ...entries.asMap().entries.map((indexed) {
              final i = indexed.key;
              final cat = indexed.value.key;
              final amt = indexed.value.value;
              final pct = data.totalSpent > 0 ? amt / data.totalSpent : 0.0;
              final budget = budgetMap[cat] ?? 0.0;
              final budgetPct = budget > 0
                  ? (amt / budget).clamp(0.0, 1.0)
                  : pct.clamp(0.0, 1.0);
              final color = _col(cat);
              final txCount = data.txCount[cat] ?? 0;

              return InkWell(
                onTap: () => showCategoryTransactionsSheet(
                  context: context,
                  allExpenses: allExpenses,
                  month: _selectedMonth,
                  category: cat,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      EdgeInsets.only(bottom: i < entries.length - 1 ? 16 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_catIcon(cat), color: color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      // Name + bar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  cat.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${(pct * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: AnimatedBuilder(
                                animation: _animCtrl,
                                builder: (_, __) => LinearProgressIndicator(
                                  value: budgetPct * _animCtrl.value,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(color),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$txCount transaction${txCount != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Amount + chevron
                      Text(
                        'RM ${amt.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Weekly spending bar chart ─────────────────────────────────────────────
  Widget _buildWeeklyBarCard(
      _AnalyticsData data, Map<ExpenseCategory, BudgetModel> budgetData) {
    const totalWeeksInMonth = 4; // Fixed at 4 weeks per user request

    // Calculate total per week for averages and maxY
    final Map<int, double> weeklyTotals = {};
    for (var entry in data.weeklyCategoryTotals.entries) {
      weeklyTotals[entry.key] =
          entry.value.values.fold(0.0, (sum, amt) => sum + amt);
    }

    // Average over weeks that actually have spending
    final activeWeeks = weeklyTotals.values.where((v) => v > 0).length;
    final avgWeekly = activeWeeks > 0 ? data.totalSpent / activeWeeks : 0.0;
    final maxY = weeklyTotals.values.isEmpty
        ? 10.0
        : weeklyTotals.values.reduce((a, b) => a > b ? a : b) * 1.3;

    // Precompute cumulative spending per category to drive dynamic sliding targets
    // cumulativeSpend[week][cat] = total spent in that category by end of `week`
    final cumulativeSpend = List.generate(
        totalWeeksInMonth + 1, (_) => <ExpenseCategory, double>{});
    for (int w = 1; w <= totalWeeksInMonth; w++) {
      for (final cat in ExpenseCategory.values) {
        final prior = cumulativeSpend[w - 1][cat] ?? 0.0;
        final current = data.weeklyCategoryTotals[w]?[cat] ?? 0.0;
        cumulativeSpend[w][cat] = prior + current;
      }
    }

    // First, determine exactly which categories are active for projection
    final activeCategories = data.byCategory.keys
        .where((cat) => budgetData[cat]?.isWeeklyProjected == true)
        .toList();

    // Sorting to ensure consistent order left-to-right (matching ExpenseCategory index ordering)
    activeCategories.sort((a, b) => a.index.compareTo(b.index));

    // Build one group per week of the month
    final barGroups = List.generate(totalWeeksInMonth, (i) {
      final week = i + 1;
      final catMap = data.weeklyCategoryTotals[week] ?? {};

      // Map each active category into its own BarChartRod
      final List<BarChartRodData> rods =
          List.generate(activeCategories.length, (catIndex) {
        final cat = activeCategories[catIndex];
        final amt = catMap[cat] ?? 0.0;

        final bModel = budgetData[cat];
        double targetForWeek = 0;

        if (bModel != null) {
          final totalBudget = bModel.monthlyLimit;
          final spentPrior = cumulativeSpend[week - 1][cat] ?? 0.0;
          final remainingBudget = totalBudget - spentPrior;
          final remainingWeeks = totalWeeksInMonth - (week - 1);
          targetForWeek = remainingWeeks > 0
              ? (remainingBudget / remainingWeeks).clamp(0.0, double.infinity)
              : 0.0;
        }

        final List<BarChartRodStackItem> stackItems = [];

        // 1. Base Actual Spending slice
        if (amt > 0) {
          stackItems.add(BarChartRodStackItem(0.0, amt, _col(cat)));
        }

        // 2. Projected Target Ghost slice (if actual spend < target)
        if (targetForWeek > amt) {
          stackItems.add(
            BarChartRodStackItem(
              amt,
              targetForWeek,
              const Color(0xFFCBD5E1), // Darker grey for ghost target
            ),
          );
        }

        // The column height is the max of amt or targetForWeek
        final columnTotal = targetForWeek > amt ? targetForWeek : amt;

        return BarChartRodData(
          toY: columnTotal > 0 ? columnTotal : 0.25,
          width: 14, // Narrower to fit multiples side-by-side
          borderRadius: BorderRadius.circular(4),
          rodStackItems: stackItems.isNotEmpty ? stackItems : null,
          color: columnTotal == 0 ? const Color(0xFFE2E8F0) : null,
        );
      });

      return BarChartGroupData(
        x: week,
        barsSpace: 4, // Space between rods in the same group
        barRods: rods,
      );
    });

    // Make sure our manual maxY calculation accommodates chart totals
    double highestY = 0;
    for (final group in barGroups) {
      if (group.barRods.isNotEmpty) {
        if (group.barRods.first.toY > highestY) {
          highestY = group.barRods.first.toY;
        }
      }
    }
    final adjustedMaxY = (highestY > maxY) ? highestY * 1.3 : maxY;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Spending Trend',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap a bar for exact amounts',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Legend chips
            if (activeCategories.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...activeCategories.map((cat) {
                    return _LegendChip(
                        color: _col(cat), label: cat.displayName);
                  }),
                  if (budgetData.values.any((b) => b.isWeeklyProjected))
                    const _LegendChip(
                        color: Color(0xFFCBD5E1), label: 'Target'),
                ],
              ),
            if (activeCategories.isNotEmpty) const SizedBox(height: 20),

            // Chart area
            SizedBox(
              height: 200,
              child: data.totalSpent == 0 || activeCategories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart_rounded,
                              size: 48, color: Colors.grey.shade200),
                          const SizedBox(height: 10),
                          Text(
                            activeCategories.isEmpty
                                ? 'No projected categories'
                                : 'No spending data',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        // Base width of 280, plus 40 pixels per extra rod per week beyond the 1st
                        width: 280 +
                            (activeCategories.length > 1
                                    ? (activeCategories.length - 1) * 40 * 4
                                    : 0)
                                .toDouble(),
                        padding: const EdgeInsets.only(right: 16),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: adjustedMaxY,
                            barGroups: barGroups,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) => const FlLine(
                                color: Color(0xFFF1F5F9),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            extraLinesData: avgWeekly > 0
                                ? ExtraLinesData(
                                    horizontalLines: [
                                      HorizontalLine(
                                        y: avgWeekly,
                                        color: const Color(0xFF94A3B8),
                                        strokeWidth: 1.5,
                                        dashArray: [5, 4],
                                        label: HorizontalLineLabel(
                                          show: true,
                                          alignment: Alignment.topRight,
                                          padding: const EdgeInsets.only(
                                              right: 4, bottom: 4),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          labelResolver: (_) =>
                                              'Avg RM ${avgWeekly.toStringAsFixed(0)}',
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  getTitlesWidget: (value, _) {
                                    final week = value.toInt();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'W$week',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w500),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 48,
                                  getTitlesWidget: (value, _) {
                                    if (value == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      'RM${value.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 8,
                                          color: Color(0xFF94A3B8)),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipBgColor: const Color(0xFF1E293B),
                                tooltipRoundedRadius: 10,
                                tooltipPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                getTooltipItem:
                                    (group, rodIndex, rod, stackItem) {
                                  final rawAmt = rod.toY;
                                  if (rawAmt <= 0.25) {
                                    return BarTooltipItem(
                                      'Week ${group.x}\nNo pending targets',
                                      const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                    );
                                  }

                                  final week = group.x;
                                  final catMap =
                                      data.weeklyCategoryTotals[week] ?? {};

                                  // If a specific stack slice is tapped
                                  if (stackItem != -1 &&
                                      stackItem < rod.rodStackItems.length) {
                                    final slice = rod.rodStackItems[stackItem];

                                    // Since rods precisely match activeCategories indices
                                    final targetCat =
                                        activeCategories[rodIndex];
                                    final sliceAmt = catMap[targetCat] ?? 0.0;

                                    // Check if this is the target ghost bar
                                    if (slice.color ==
                                        const Color(0xFFCBD5E1)) {
                                      return BarTooltipItem(
                                        'Week $week\n',
                                        const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500),
                                        children: [
                                          TextSpan(
                                            text: '${targetCat.displayName}\n',
                                            style: TextStyle(
                                                color: _col(targetCat),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          TextSpan(
                                            text:
                                                'RM ${sliceAmt.toStringAsFixed(2)} spent\n',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          const TextSpan(
                                            text: 'Projected Target\n',
                                            style: TextStyle(
                                              color: Color(0xFFCBD5E1),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                'RM ${(slice.toY).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      );
                                    }

                                    // Otherwise it's an actual category slice
                                    return BarTooltipItem(
                                      'Week $week\n',
                                      const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500),
                                      children: [
                                        TextSpan(
                                          text: '${targetCat.displayName}\n',
                                          style: TextStyle(
                                            color: slice.color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              'RM ${sliceAmt.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  // Overall bar tapped
                                  final targetCat = activeCategories[rodIndex];
                                  return BarTooltipItem(
                                    'Week $week\n',
                                    const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500),
                                    children: [
                                      TextSpan(
                                        text: '${targetCat.displayName}\n',
                                        style: TextStyle(
                                          color: _col(targetCat),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            'Total RM ${rawAmt.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          swapAnimationDuration:
                              const Duration(milliseconds: 400),
                          swapAnimationCurve: Curves.easeInOut,
                        ),
                      ),
                    ),
            ),

            // Average callout note
            if (avgWeekly > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Dashed line = avg on spending weeks  '
                    '(RM ${avgWeekly.toStringAsFixed(2)})',
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Stats grid ───────────────────────────────────────────────────────────
  Widget _buildStatsGrid(_AnalyticsData data, List<ExpenseItem> allExpenses) {
    // Average monthly spending — across all months that have data
    final monthTotals = <String, double>{};
    for (final e in allExpenses) {
      final key = '${e.date.year}-${e.date.month}';
      monthTotals[key] = (monthTotals[key] ?? 0) + e.amount;
    }
    final avgMonthly = monthTotals.isEmpty
        ? 0.0
        : monthTotals.values.reduce((a, b) => a + b) / monthTotals.length;

    // Average weekly in selected month
    final daysElapsed = _isCurrentMonth
        ? DateTime.now().day
        : DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final rawWeeks = daysElapsed / 7.0;
    final weeksElapsed = rawWeeks > 4.0 ? 4.0 : rawWeeks;
    final avgWeekly = weeksElapsed > 0 ? data.totalSpent / weeksElapsed : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Avg Monthly Spending',
                    value: 'RM ${avgMonthly.toStringAsFixed(2)}',
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Avg Weekly Spending',
                    value: 'RM ${avgWeekly.toStringAsFixed(2)}',
                    icon: Icons.date_range_rounded,
                    iconColor: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Most Frequent',
                    value: data.topFreqCat?.displayName ?? '—',
                    sub: data.topFreqCat != null
                        ? '${data.topFreqCount} transactions'
                        : null,
                    icon: Icons.repeat_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Largest Expense',
                    value: data.largestExpense != null
                        ? 'RM ${data.largestExpense!.amount.toStringAsFixed(2)}'
                        : '—',
                    sub: data.largestExpense?.description.isNotEmpty == true
                        ? data.largestExpense!.description
                        : data.largestExpense?.category.displayName,
                    icon: Icons.arrow_upward_rounded,
                    iconColor: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _catIcon(ExpenseCategory cat) {
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
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  const _NavBtn({
    required this.icon,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF1F5F9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: disabled ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color iconColor;

  const _StatTile({
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
