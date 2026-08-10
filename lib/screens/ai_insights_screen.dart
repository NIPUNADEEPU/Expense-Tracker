import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/expense_provider.dart';

class AiInsightsScreen extends StatelessWidget {
  const AiInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ExpenseScope.of(context).transactions;
    final now = DateTime.now();
    final thisMonth = transactions
        .where((item) => item.date.year == now.year && item.date.month == now.month)
        .toList();
    final income = _total(thisMonth, TransactionType.income);
    final expenses = _total(thisMonth, TransactionType.expense);
    final savings = income - expenses;
    final savingsRate = income == 0 ? 0.0 : (savings / income) * 100;
    final categoryTotals = <ExpenseCategory, double>{};
    for (final item in thisMonth.where((item) => item.type == TransactionType.expense)) {
      categoryTotals[item.category] = (categoryTotals[item.category] ?? 0) + item.amount;
    }
    final topCategory = categoryTotals.entries.isEmpty
        ? null
        : categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
    final previousMonth = DateTime(now.year, now.month - 1);
    final previousExpenses = _total(
      transactions.where((item) => item.date.year == previousMonth.year && item.date.month == previousMonth.month),
      TransactionType.expense,
    );
    final spendingChange = previousExpenses == 0 ? 0.0 : ((expenses - previousExpenses) / previousExpenses) * 100;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Insights')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.colorScheme.primary, const Color(0xFF6D28D9)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white),
                  SizedBox(height: 12),
                  Text('Your money, made clearer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Personalized insights from this month\'s transactions.', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle('Monthly snapshot'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MetricCard('Spent', expenses, theme.colorScheme.error)),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard('Saved', savings, const Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle('Smart alerts'),
            const SizedBox(height: 10),
            if (income == 0 && expenses > 0)
              const _InsightCard(
                icon: Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                title: 'Income needed',
                message: 'You have expenses this month but no income recorded yet.',
              )
            else if (expenses > income && income > 0)
              const _InsightCard(
                icon: Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
                title: 'Over your monthly income',
                message: 'Your spending is higher than your recorded income this month.',
              )
            else if (income > 0 && expenses >= income * 0.8)
              const _InsightCard(
                icon: Icons.notifications_active_rounded,
                color: Color(0xFFF59E0B),
                title: 'Budget alert',
                message: 'You have used 80% or more of this month\'s recorded income.',
              )
            else
              const _InsightCard(
                icon: Icons.verified_rounded,
                color: Color(0xFF10B981),
                title: 'Spending looks healthy',
                message: 'Your expenses are currently within your recorded income.',
              ),
            const SizedBox(height: 24),
            _SectionTitle('Spending trend'),
            const SizedBox(height: 10),
            _InsightCard(
              icon: spendingChange > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: spendingChange > 0 ? theme.colorScheme.error : const Color(0xFF10B981),
              title: previousExpenses == 0 ? 'First month of data' : '${spendingChange.abs().toStringAsFixed(0)}% ${spendingChange > 0 ? 'more' : 'less'} than last month',
              message: previousExpenses == 0
                  ? 'Keep adding transactions to unlock month-over-month comparisons.'
                  : 'You spent \$${expenses.toStringAsFixed(2)} this month compared with \$${previousExpenses.toStringAsFixed(2)} last month.',
            ),
            const SizedBox(height: 24),
            _SectionTitle('Savings suggestion'),
            const SizedBox(height: 10),
            _InsightCard(
              icon: Icons.savings_rounded,
              color: theme.colorScheme.primary,
              title: savingsRate >= 20 ? 'Great savings habit' : 'Build your savings buffer',
              message: income == 0
                  ? 'Add your income to receive a personalized savings target.'
                  : savingsRate >= 20
                      ? 'You are saving ${savingsRate.toStringAsFixed(0)}% of your income. Keep it consistent.'
                      : 'Try setting aside \$${(income * 0.2).toStringAsFixed(2)}—20% of this month\'s income.',
            ),
            const SizedBox(height: 24),
            _SectionTitle('Personalized tip'),
            const SizedBox(height: 10),
            _InsightCard(
              icon: topCategory?.key.icon ?? Icons.lightbulb_outline_rounded,
              color: topCategory?.key.color ?? theme.colorScheme.primary,
              title: topCategory == null ? 'Start tracking your spending' : '${topCategory.key.displayName} is your top category',
              message: topCategory == null
                  ? 'Add an expense to receive category-based recommendations.'
                  : 'You spent \$${topCategory.value.toStringAsFixed(2)} here. A small weekly limit can help you reduce this category.',
            ),
          ],
        ),
      ),
    );
  }

  double _total(Iterable<Transaction> items, TransactionType type) => items
      .where((item) => item.type == type)
      .fold(0.0, (sum, item) => sum + item.amount);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
}

class _MetricCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _MetricCard(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  const _InsightCard({required this.icon, required this.color, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(message)),
        ),
      );
}
