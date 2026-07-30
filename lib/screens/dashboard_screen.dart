import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/expense_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/expense_chart.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _showAddTransactionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = ExpenseScope.of(context);
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $displayName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Track your daily expenses',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to sign out: $e'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Balance Summary Card (Full Width)
              StatCard(
                title: 'Total Balance',
                amount: provider.totalBalance,
                icon: Icons.account_balance_wallet_rounded,
                color: theme.colorScheme.primary,
                isFullWidth: true,
              ),
              const SizedBox(height: 16),
              
              // 2. Income & Expense Cards (Side by Side)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatCard(
                    title: 'Income',
                    amount: provider.totalIncome,
                    icon: Icons.arrow_downward_rounded,
                    color: const Color(0xFF10B981), // Green
                  ),
                  StatCard(
                    title: 'Expenses',
                    amount: provider.totalExpenses,
                    icon: Icons.arrow_upward_rounded,
                    color: theme.colorScheme.error, // Red
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // 3. Category Breakdown (Pie Chart)
              Text(
                'Expense Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.05),
                    width: 1.0,
                  ),
                ),
                child: ExpenseChart(
                  categoryTotals: provider.categoryTotals,
                ),
              ),
              const SizedBox(height: 24),
              
              // 4. Recent Transactions Title & See All
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      );
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 5. Recent Transactions List
              if (provider.recentTransactions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'No transactions yet. Tap + to add.',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.recentTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = provider.recentTransactions[index];
                    return TransactionTile(
                      transaction: transaction,
                      onDelete: () {
                        provider.deleteTransaction(transaction.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Transaction deleted'),
                            action: SnackBarAction(
                              label: 'Dismiss',
                              onPressed: () {},
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 80), // Padding to prevent FAB overlap
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionSheet(context),
        label: const Text(
          'Add Transaction',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add_rounded),
        elevation: 4,
      ),
    );
  }
}
