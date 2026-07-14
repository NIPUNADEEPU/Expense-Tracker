import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/expense_provider.dart';
import '../widgets/transaction_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  TransactionType? _selectedTypeFilter;
  ExpenseCategory? _selectedCategoryFilter;

  @override
  Widget build(BuildContext context) {
    final provider = ExpenseScope.of(context);
    final theme = Theme.of(context);

    // Apply filtering logic
    final filteredTransactions = provider.transactions.where((t) {
      final matchesSearch = t.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedTypeFilter == null || t.type == _selectedTypeFilter;
      final matchesCategory = _selectedCategoryFilter == null || t.category == _selectedCategoryFilter;
      return matchesSearch && matchesType && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          
          // 2. Type Filter (All, Income, Expense)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedTypeFilter == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTypeFilter = null;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Income'),
                  selected: _selectedTypeFilter == TransactionType.income,
                  selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _selectedTypeFilter == TransactionType.income
                        ? const Color(0xFF10B981)
                        : null,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedTypeFilter = selected ? TransactionType.income : null;
                      // Clear category filter if it conflicts with income
                      if (selected &&
                          _selectedCategoryFilter != null &&
                          _selectedCategoryFilter != ExpenseCategory.salary &&
                          _selectedCategoryFilter != ExpenseCategory.other) {
                        _selectedCategoryFilter = null;
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Expenses'),
                  selected: _selectedTypeFilter == TransactionType.expense,
                  selectedColor: theme.colorScheme.error.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _selectedTypeFilter == TransactionType.expense
                        ? theme.colorScheme.error
                        : null,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedTypeFilter = selected ? TransactionType.expense : null;
                      // Clear category filter if it conflicts with expense
                      if (selected && _selectedCategoryFilter == ExpenseCategory.salary) {
                        _selectedCategoryFilter = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // 3. Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ExpenseCategory.values.where((cat) {
                if (_selectedTypeFilter == TransactionType.income) {
                  return cat == ExpenseCategory.salary || cat == ExpenseCategory.other;
                } else if (_selectedTypeFilter == TransactionType.expense) {
                  return cat != ExpenseCategory.salary;
                }
                return true;
              }).map((category) {
                final isSelected = _selectedCategoryFilter == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(
                      category.icon,
                      color: isSelected ? Colors.white : category.color,
                      size: 14,
                    ),
                    label: Text(category.displayName),
                    selected: isSelected,
                    selectedColor: category.color,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryFilter = selected ? category : null;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 24, thickness: 1),
          
          // 4. Transactions List
          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions match filters.',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
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
          ),
        ],
      ),
    );
  }
}
