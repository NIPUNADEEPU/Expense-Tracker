import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/category.dart';

class ExpenseChart extends StatefulWidget {
  final Map<ExpenseCategory, double> categoryTotals;

  const ExpenseChart({
    super.key,
    required this.categoryTotals,
  });

  @override
  State<ExpenseChart> createState() => _ExpenseChartState();
}

class _ExpenseChartState extends State<ExpenseChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // Filter to only categories with non-zero expenses
    final Map<ExpenseCategory, double> activeExpenses = Map.fromEntries(
      widget.categoryTotals.entries.where((entry) => entry.value > 0),
    );

    final double totalExpense = activeExpenses.values.fold(0.0, (sum, val) => sum + val);

    if (totalExpense == 0) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 48,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No expenses recorded yet',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Donut Chart
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 4,
              centerSpaceRadius: 45,
              sections: _buildChartSections(activeExpenses, totalExpense),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Wrap for Legend / Indicators
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: activeExpenses.keys.map((category) {
            final amount = activeExpenses[category]!;
            final percentage = (amount / totalExpense) * 100;
            return _buildIndicator(
              color: category.color,
              text: '${category.displayName} (${percentage.toStringAsFixed(1)}%)',
            );
          }).toList(),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildChartSections(
    Map<ExpenseCategory, double> activeExpenses,
    double total,
  ) {
    int index = 0;
    return activeExpenses.entries.map((entry) {
      final category = entry.key;
      final amount = entry.value;
      final isTouched = index == touchedIndex;
      final double radius = isTouched ? 28.0 : 20.0;
      final double percentage = (amount / total) * 100;
      
      final section = PieChartSectionData(
        color: category.color,
        value: amount,
        title: isTouched ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
      index++;
      return section;
    }).toList();
  }

  Widget _buildIndicator({required Color color, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
