import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Transaction> _transactions = [];
  final _uuid = const Uuid();

  ExpenseProvider() {
    _loadMockData();
  }

  List<Transaction> get transactions {
    final sorted = List<Transaction>.from(_transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  List<Transaction> get recentTransactions {
    final sorted = transactions;
    return sorted.take(5).toList();
  }

  double get totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalBalance {
    return totalIncome - totalExpenses;
  }

  Map<ExpenseCategory, double> get categoryTotals {
    final Map<ExpenseCategory, double> totals = {};
    for (var transaction in _transactions) {
      if (transaction.type == TransactionType.expense) {
        totals[transaction.category] = (totals[transaction.category] ?? 0.0) + transaction.amount;
      }
    }
    return totals;
  }

  void addTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required ExpenseCategory category,
    required DateTime date,
  }) {
    final newTransaction = Transaction(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
    );
    _transactions.add(newTransaction);
    notifyListeners();
  }

  void deleteTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void _loadMockData() {
    final now = DateTime.now();
    _transactions.addAll([
      Transaction(
        id: _uuid.v4(),
        title: 'Monthly Salary',
        amount: 4500.0,
        type: TransactionType.income,
        category: ExpenseCategory.salary,
        date: now.subtract(const Duration(days: 5)),
      ),
      Transaction(
        id: _uuid.v4(),
        title: 'Supermarket Groceries',
        amount: 142.50,
        type: TransactionType.expense,
        category: ExpenseCategory.food,
        date: now.subtract(const Duration(days: 4)),
      ),
      Transaction(
        id: _uuid.v4(),
        title: 'House Rent',
        amount: 1200.0,
        type: TransactionType.expense,
        category: ExpenseCategory.rent,
        date: now.subtract(const Duration(days: 3)),
      ),
      Transaction(
        id: _uuid.v4(),
        title: 'Gas Refill',
        amount: 45.0,
        type: TransactionType.expense,
        category: ExpenseCategory.transport,
        date: now.subtract(const Duration(days: 2)),
      ),
      Transaction(
        id: _uuid.v4(),
        title: 'Netflix Subscription',
        amount: 15.99,
        type: TransactionType.expense,
        category: ExpenseCategory.entertainment,
        date: now.subtract(const Duration(days: 1)),
      ),
      Transaction(
        id: _uuid.v4(),
        title: 'Electricity Bill',
        amount: 88.40,
        type: TransactionType.expense,
        category: ExpenseCategory.utilities,
        date: now.subtract(const Duration(minutes: 45)),
      ),
      Transaction(
        id: _uuid.v4(),
        title: 'Freelance Design Project',
        amount: 850.0,
        type: TransactionType.income,
        category: ExpenseCategory.salary,
        date: now.subtract(const Duration(minutes: 15)),
      ),
    ]);
  }
}

// InheritedNotifier to expose the provider efficiently to the widget tree
class ExpenseScope extends InheritedNotifier<ExpenseProvider> {
  const ExpenseScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static ExpenseProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ExpenseScope>();
    assert(scope != null, 'No ExpenseScope found in context');
    return scope!.notifier!;
  }
}
