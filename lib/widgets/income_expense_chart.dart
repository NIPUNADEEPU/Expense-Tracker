import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class IncomeExpenseChart extends StatelessWidget {
  final double income;
  final double expenses;

  const IncomeExpenseChart({
    super.key,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final maximum = income > expenses ? income : expenses;
    final chartMaximum = maximum == 0 ? 100.0 : maximum * 1.25;
    final theme = Theme.of(context);

    return SizedBox(
      height: 210,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMaximum,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMaximum / 4,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: chartMaximum / 4,
                getTitlesWidget: (value, meta) => Text(
                  value >= 1000
                      ? '\$${(value / 1000).toStringAsFixed(1)}k'
                      : '\$${value.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final label = value == 0 ? 'Income' : value == 1 ? 'Expenses' : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: theme.textTheme.bodySmall),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            _barGroup(0, income, const Color(0xFF10B981)),
            _barGroup(1, expenses, theme.colorScheme.error),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double value, Color color) => BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: value,
            color: color,
            width: 34,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ],
      );
}
