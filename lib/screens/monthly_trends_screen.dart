import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../models/transaction_analytics.dart';
import '../providers/expense_provider.dart';

class MonthlyTrendsScreen extends StatefulWidget {
  const MonthlyTrendsScreen({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  State<MonthlyTrendsScreen> createState() => _MonthlyTrendsScreenState();
}

class _MonthlyTrendsScreenState extends State<MonthlyTrendsScreen> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = ExpenseScope.of(context);
    final transactions = provider.transactions;
    final years = <int>{
      DateTime.now().year,
      ...transactions.map((transaction) => transaction.date.year),
    }.toList()..sort((a, b) => b.compareTo(a));
    if (!years.contains(_year)) _year = years.first;

    final period = DateTime(_year, _month);
    final periodLabel = DateFormat('MMMM yyyy').format(period);
    final isCurrentMonth =
        _year == DateTime.now().year && _month == DateTime.now().month;
    final periodTransactions = transactions.where(
      (transaction) =>
          transaction.date.year == _year && transaction.date.month == _month,
    );
    final hasTransactions = periodTransactions.isNotEmpty;
    final income = TransactionAnalytics.total(
      transactions,
      type: TransactionType.income,
      year: _year,
      month: _month,
    );
    final expenses = TransactionAnalytics.total(
      transactions,
      type: TransactionType.expense,
      year: _year,
      month: _month,
    );
    final saved = income - expenses;
    final categories = TransactionAnalytics.spendingByCategory(
      transactions,
      year: _year,
      month: _month,
    ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final previousPeriod = DateTime(_year, _month - 1);
    final previousExpenses = TransactionAnalytics.total(
      transactions,
      type: TransactionType.expense,
      year: previousPeriod.year,
      month: previousPeriod.month,
    );
    final hasComparison = expenses > 0 && previousExpenses > 0;
    final spendingChange = hasComparison
        ? (expenses - previousExpenses) / previousExpenses * 100
        : 0.0;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: provider.isLoadingTransactions
          ? const Center(child: CircularProgressIndicator())
          : provider.transactionLoadError != null
          ? Center(child: Text(provider.transactionLoadError!))
          : LayoutBuilder(
              builder: (context, constraints) => ListView(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth > 760 ? 34 : 18,
                  10,
                  constraints.maxWidth > 760 ? 34 : 18,
                  36,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your finances, in perspective',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      DropdownButton<int>(
                        value: _month,
                        underline: const SizedBox(),
                        items: List.generate(
                          12,
                          (index) => DropdownMenuItem<int>(
                            value: index + 1,
                            child: Text(
                              DateFormat(
                                'MMMM',
                              ).format(DateTime(2020, index + 1)),
                            ),
                          ),
                        ),
                        onChanged: (month) {
                          if (month != null) setState(() => _month = month);
                        },
                      ),
                      const SizedBox(width: 5),
                      DropdownButton<int>(
                        value: _year,
                        underline: const SizedBox(),
                        items: years
                            .map(
                              (year) => DropdownMenuItem<int>(
                                value: year,
                                child: Text('$year'),
                              ),
                            )
                            .toList(),
                        onChanged: (year) {
                          if (year != null) setState(() => _year = year);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isCurrentMonth ? 'THIS MONTH' : periodLabel.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          'Income',
                          income,
                          const Color(0xFF34D399),
                          currency,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          'Expenses',
                          expenses,
                          const Color(0xFFF87171),
                          currency,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          'Saved',
                          saved,
                          theme.colorScheme.primary,
                          currency,
                        ),
                      ),
                    ],
                  ),
                  if (!hasTransactions) ...[
                    const SizedBox(height: 30),
                    Text(
                      isCurrentMonth
                          ? 'No transactions this month.'
                          : 'No transactions in $periodLabel.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add a transaction to start tracking your finances.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: widget.onAdd,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add transaction'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 28),
                    Text(
                      'TOP SPENDING CATEGORIES',
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (categories.isEmpty)
                      Text(
                        'No spending data for $periodLabel.',
                        style: theme.textTheme.bodyMedium,
                      )
                    else
                      ...categories.map(
                        (category) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Icon(
                                category.key.icon,
                                size: 19,
                                color: category.key.color,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(category.key.displayName)),
                              Text(
                                currency.format(category.value),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 26),
                    if (categories.isNotEmpty || hasComparison) ...[
                      Text(
                        'SMART INSIGHTS ✨',
                        style: theme.textTheme.labelMedium?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (categories.isNotEmpty)
                        _Insight(
                          icon: categories.first.key.icon,
                          color: categories.first.key.color,
                          text:
                              '${categories.first.key.displayName} is your highest spending category in $periodLabel.',
                        ),
                      if (hasComparison)
                        _Insight(
                          icon: spendingChange >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: spendingChange >= 0
                              ? const Color(0xFFF87171)
                              : const Color(0xFF34D399),
                          text:
                              'You spent ${currency.format(expenses)} in $periodLabel, compared with ${currency.format(previousExpenses)} in ${DateFormat('MMMM yyyy').format(previousPeriod)}.',
                        ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color, this.format);
  final String label;
  final double value;
  final Color color;
  final NumberFormat format;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            format.format(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Insight extends StatelessWidget {
  const _Insight({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
