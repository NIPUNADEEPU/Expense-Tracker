import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_analytics.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_chart.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'history_screen.dart';
import 'monthly_trends_screen.dart';
import 'profile_screen.dart';

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  ExpenseProvider? _expenseProvider;
  bool _showingCategoryReview = false;
  final Set<String> _deferredCategoryIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = ExpenseScope.of(context);
    if (_expenseProvider == provider) return;
    _expenseProvider?.removeListener(_onTransactionsChanged);
    _expenseProvider = provider..addListener(_onTransactionsChanged);
    _scheduleCategoryReview();
  }

  void _onTransactionsChanged() => _scheduleCategoryReview();

  void _scheduleCategoryReview() {
    final provider = _expenseProvider;
    if (!mounted ||
        provider == null ||
        provider.isLoadingTransactions ||
        _showingCategoryReview) {
      return;
    }
    final pending = provider.transactions
        .where(
          (transaction) =>
              transaction.category == ExpenseCategory.uncategorized &&
              !_deferredCategoryIds.contains(transaction.id),
        )
        .toList();
    if (pending.isEmpty) return;
    _showingCategoryReview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reviewUncategorizedTransactions(pending);
    });
  }

  Future<void> _reviewUncategorizedTransactions(
    List<Transaction> pending,
  ) async {
    final provider = _expenseProvider;
    if (provider == null || !mounted) {
      _showingCategoryReview = false;
      return;
    }
    for (var index = 0; index < pending.length; index++) {
      final transaction = pending[index];
      if (!mounted) break;
      final category = await showDialog<ExpenseCategory>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Choose a category (${index + 1}/${pending.length})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(_inr.format(transaction.amount)),
              const SizedBox(height: 18),
              ...ExpenseCategory.values
                  .where(
                    (category) =>
                        category != ExpenseCategory.salary &&
                        category != ExpenseCategory.uncategorized,
                  )
                  .map(
                    (category) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(category.icon, color: category.color),
                      title: Text(category.displayName),
                      onTap: () => Navigator.pop(dialogContext, category),
                    ),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Review later'),
            ),
          ],
        ),
      );
      if (category == null) {
        _deferredCategoryIds.addAll(pending.skip(index).map((item) => item.id));
        break;
      }
      provider.updateTransaction(
        Transaction(
          id: transaction.id,
          title: transaction.title,
          amount: transaction.amount,
          type: transaction.type,
          category: category,
          date: transaction.date,
          currency: transaction.currency,
        ),
      );
    }
    _showingCategoryReview = false;
    if (mounted) _scheduleCategoryReview();
  }

  @override
  void dispose() {
    _expenseProvider?.removeListener(_onTransactionsChanged);
    super.dispose();
  }

  void _openAddTransaction() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboard(
        onAdd: _openAddTransaction,
        onSeeAll: () => setState(() => _selectedIndex = 1),
      ),
      HistoryScreen(onAdd: _openAddTransaction),
      MonthlyTrendsScreen(onAdd: _openAddTransaction),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _openAddTransaction,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add transaction'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key, required this.onAdd, required this.onSeeAll});
  final VoidCallback onAdd;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final provider = ExpenseScope.of(context);
    final now = DateTime.now();
    final transactions = provider.transactions;
    final income = TransactionAnalytics.total(
      transactions,
      type: TransactionType.income,
      year: now.year,
      month: now.month,
    );
    final expenses = TransactionAnalytics.total(
      transactions,
      type: TransactionType.expense,
      year: now.year,
      month: now.month,
    );
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim().split(' ').first
        : user?.email?.split('@').first ?? 'there';
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpendSense'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: CircleAvatar(
              radius: 17,
              child: Text(name.substring(0, 1).toUpperCase()),
            ),
          ),
        ],
      ),
      body: provider.isLoadingTransactions
          ? const Center(child: CircularProgressIndicator())
          : provider.transactionLoadError != null
          ? Center(child: Text(provider.transactionLoadError!))
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 760;
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 36 : 20,
                    20,
                    wide ? 36 : 20,
                    100,
                  ),
                  children: [
                    Text(
                      '$greeting, $name 👋',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Here's your financial overview",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEDE5DD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AVAILABLE BALANCE',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _inr.format(provider.totalBalance),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF28231F),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: _MonthAmount(
                                  label: 'Income · this month',
                                  amount: income,
                                  color: const Color(0xFF34D399),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _MonthAmount(
                                  label: 'Expenses · this month',
                                  amount: expenses,
                                  color: const Color(0xFFF87171),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const BudgetProgressCard(),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add transaction'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ExpenseCategoryChart(
                      transactions: transactions,
                      year: now.year,
                      month: now.month,
                    ),
                    const SizedBox(height: 28),
                    _SectionHeading(
                      title: 'Recent transactions',
                      trailing: TextButton(
                        onPressed: onSeeAll,
                        child: const Text('View all  →'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDE5DD)),
                      ),
                      child: provider.recentTransactions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No transactions yet. Add your first transaction.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : Column(
                              children: provider.recentTransactions
                                  .take(4)
                                  .map(
                                    (t) => TransactionTile(
                                      transaction: t,
                                      onEdit: () => _edit(context, t),
                                      onDelete: () =>
                                          provider.deleteTransaction(t.id),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  void _edit(BuildContext context, Transaction transaction) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddTransactionScreen(transaction: transaction),
      );
}

class _MonthAmount extends StatelessWidget {
  const _MonthAmount({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 5),
      Text(
        _inr.format(amount),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      trailing ?? const SizedBox.shrink(),
    ],
  );
}
