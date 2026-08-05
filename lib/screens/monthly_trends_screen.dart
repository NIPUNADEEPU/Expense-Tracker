import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../providers/expense_provider.dart';
import 'ai_insights_screen.dart';

class MonthlyTrendsScreen extends StatefulWidget {
  const MonthlyTrendsScreen({super.key});

  @override
  State<MonthlyTrendsScreen> createState() => _MonthlyTrendsScreenState();
}

class _MonthlyTrendsScreenState extends State<MonthlyTrendsScreen> {
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ExpenseScope.of(context).transactions;
    final years = <int>{DateTime.now().year, ...transactions.map((item) => item.date.year)}
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (!years.contains(_selectedYear)) _selectedYear = years.first;

    final income = List<double>.filled(12, 0);
    final expenses = List<double>.filled(12, 0);
    for (final transaction in transactions.where((item) => item.date.year == _selectedYear)) {
      final totals = transaction.type == TransactionType.income ? income : expenses;
      totals[transaction.date.month - 1] += transaction.amount;
    }

    final totalIncome = income.fold(0.0, (sum, value) => sum + value);
    final totalExpenses = expenses.fold(0.0, (sum, value) => sum + value);
    final highestExpense = expenses.reduce((a, b) => a > b ? a : b);
    final highestExpenseMonth = expenses.indexOf(highestExpense);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Trends')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Analytics overview', style: theme.textTheme.titleMedium),
                DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox(),
                  items: years
                      .map((year) => DropdownMenuItem(value: year, child: Text('$year')))
                      .toList(),
                  onChanged: (year) {
                    if (year != null) setState(() => _selectedYear = year);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _SummaryCard('Income', totalIncome, const Color(0xFF10B981))),
                const SizedBox(width: 12),
                Expanded(child: _SummaryCard('Expenses', totalExpenses, theme.colorScheme.error)),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard('Net savings', totalIncome - totalExpenses, theme.colorScheme.primary),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Income vs expenses', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Monthly totals for $_selectedYear', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    SizedBox(height: 260, child: _MonthlyLineChart(income: income, expenses: expenses)),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Legend(color: Color(0xFF10B981), label: 'Income'),
                        SizedBox(width: 20),
                        _Legend(color: Color(0xFFEF4444), label: 'Expenses'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.insights_rounded, color: theme.colorScheme.primary),
                title: const Text('Highest spending month'),
                subtitle: Text(_monthLabel(highestExpenseMonth)),
                trailing: Text(
                  '\$${highestExpense.toStringAsFixed(2)}',
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AiInsightsScreen()),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('View AI Insights'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyLineChart extends StatelessWidget {
  final List<double> income;
  final List<double> expenses;

  const _MonthlyLineChart({required this.income, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final maxValue = [...income, ...expenses].fold(0.0, (max, value) => value > max ? value : max);
    final chartMax = maxValue == 0 ? 100.0 : maxValue * 1.2;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: chartMax,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: chartMax / 4,
              getTitlesWidget: (value, meta) => Text(
                value >= 1000 ? '\$${(value / 1000).toStringAsFixed(1)}k' : '\$${value.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 11 || value != value.roundToDouble()) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_monthLabel(value.toInt()).substring(0, 1), style: Theme.of(context).textTheme.bodySmall),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _line(income, const Color(0xFF10B981)),
          _line(expenses, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) => LineChartBarData(
        spots: List.generate(12, (index) => FlSpot(index.toDouble(), values[index])),
        isCurved: true,
        color: color,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('\$${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
}

String _monthLabel(int monthIndex) => const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ][monthIndex];
