import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_analytics.dart';
import '../providers/expense_provider.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.onAdd});
  final VoidCallback? onAdd;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  TransactionType? _type;
  ExpenseCategory? _category;
  DateTimeRange? _range;
  bool _ascending = false;

  bool _categoryMatchesType(ExpenseCategory category, TransactionType? type) {
    if (type == TransactionType.income) {
      return category == ExpenseCategory.salary ||
          category == ExpenseCategory.other;
    }
    if (type == TransactionType.expense) {
      return category != ExpenseCategory.salary;
    }
    return true;
  }

  void _selectType(TransactionType? type) {
    setState(() {
      _type = type;
      if (_category != null && !_categoryMatchesType(_category!, type)) {
        _category = null;
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _filters() async {
    var type = _type;
    var category = _category;
    var range = _range;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                const Text('Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: type == null,
                      onSelected: (_) => setSheetState(() => type = null),
                    ),
                    ...TransactionType.values.map(
                      (v) => FilterChip(
                        label: Text(v.displayName),
                        selected: type == v,
                        onSelected: (_) => setSheetState(() {
                          type = type == v ? null : v;
                          if (category != null &&
                              !_categoryMatchesType(category!, type)) {
                            category = null;
                          }
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Category'),
                const SizedBox(height: 8),
                DropdownButtonFormField<ExpenseCategory?>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Any category',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any category'),
                    ),
                    ...ExpenseCategory.values
                        .where(
                          (c) => type == TransactionType.income
                              ? c == ExpenseCategory.salary ||
                                    c == ExpenseCategory.other
                              : type == TransactionType.expense
                              ? c != ExpenseCategory.salary
                              : true,
                        )
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.displayName),
                          ),
                        ),
                  ],
                  onChanged: (v) => setSheetState(() => category = v),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 5),
                      lastDate: now,
                      initialDateRange: range,
                    );
                    if (picked != null) setSheetState(() => range = picked);
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    range == null
                        ? 'Any date'
                        : '${DateFormat('d MMM y').format(range!.start)} – ${DateFormat('d MMM y').format(range!.end)}',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _type = null;
                          _category = null;
                          _range = null;
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _type = type;
                          _category = category;
                          _range = range;
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Apply filters'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = ExpenseScope.of(context);
    final theme = Theme.of(context);
    final items =
        provider.transactions.where((t) {
          final matchesText = t.title.toLowerCase().contains(
            _search.text.toLowerCase(),
          );
          final matchesDate =
              _range == null ||
              (!t.date.isBefore(_range!.start) &&
                  !t.date.isAfter(
                    DateTime(
                      _range!.end.year,
                      _range!.end.month,
                      _range!.end.day,
                      23,
                      59,
                      59,
                    ),
                  ));
          return matchesText &&
              (_type == null || t.type == _type) &&
              (_category == null || t.category == _category) &&
              matchesDate;
        }).toList()..sort(
          (a, b) =>
              _ascending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
        );
    final income = TransactionAnalytics.total(
      items,
      type: TransactionType.income,
    );
    final expenses = TransactionAnalytics.total(
      items,
      type: TransactionType.expense,
    );
    final grouped = <String, List<Transaction>>{};
    for (final t in items) {
      grouped.putIfAbsent(_dayLabel(t.date), () => []).add(t);
    }
    final filterCount =
        (_type == null ? 0 : 1) +
        (_category == null ? 0 : 1) +
        (_range == null ? 0 : 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            onPressed:
                widget.onAdd ??
                () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddTransactionScreen(),
                ),
            icon: const Icon(Icons.add),
            tooltip: 'Add transaction',
          ),
        ],
      ),
      body: provider.isLoadingTransactions
          ? const Center(child: CircularProgressIndicator())
          : provider.transactionLoadError != null
          ? Center(child: Text(provider.transactionLoadError!))
          : LayoutBuilder(
              builder: (context, constraints) => ListView(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth > 760 ? 32 : 18,
                  12,
                  constraints.maxWidth > 760 ? 32 : 18,
                  110,
                ),
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in [
                          (null, 'All'),
                          (TransactionType.income, 'Income'),
                          (TransactionType.expense, 'Expenses'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(entry.$2),
                              selected: _type == entry.$1,
                              onSelected: (_) => _selectType(entry.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _filters,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(
                          filterCount == 0 ? 'Filter' : 'Filter ($filterCount)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _ascending = !_ascending),
                        icon: const Icon(Icons.swap_vert_rounded, size: 18),
                        label: Text(
                          _ascending ? 'Oldest first' : 'Newest first',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Filtered totals · ${items.length} transactions',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Total(
                            label: 'Income',
                            amount: income,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                        Expanded(
                          child: _Total(
                            label: 'Expenses',
                            amount: expenses,
                            color: const Color(0xFFF87171),
                          ),
                        ),
                        Expanded(
                          child: _Total(
                            label: 'Net',
                            amount: income - expenses,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 70),
                      child: Center(
                        child: Text(
                          'No transactions found.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    for (final group in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 14, 2, 5),
                        child: Text(
                          group.key.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      ...group.value.map(
                        (t) => TransactionTile(
                          transaction: t,
                          onEdit: () => _edit(context, t),
                          onDelete: () => provider.deleteTransaction(t.id),
                        ),
                      ),
                    ],
                ],
              ),
            ),
    );
  }

  String _dayLabel(DateTime date) {
    final today = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    if (day == DateTime(today.year, today.month, today.day)) return 'Today';
    if (day ==
        DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, d MMMM').format(date);
  }

  void _edit(BuildContext context, Transaction t) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddTransactionScreen(transaction: t),
  );
}

class _Total extends StatelessWidget {
  const _Total({
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
      const SizedBox(height: 4),
      Text(
        NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        ).format(amount),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ],
  );
}
