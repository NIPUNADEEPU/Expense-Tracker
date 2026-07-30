import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Transaction;
import '../models/transaction.dart';
import '../models/category.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Transaction> _transactions = [];
  final _uuid = const Uuid();
  StreamSubscription? _authSubscription;
  StreamSubscription? _databaseSubscription;
  String? _currentUserId;

  ExpenseProvider() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _currentUserId = user.uid;
        _subscribeToDatabase(user.uid);
      } else {
        _currentUserId = null;
        _unsubscribeFromDatabase();
        _transactions.clear();
        notifyListeners();
      }
    });
  }

  void _subscribeToDatabase(String uid) {
    _databaseSubscription?.cancel();
    final ref = FirebaseDatabase.instance.ref('users/$uid/transactions');
    _databaseSubscription = ref.onValue.listen((event) {
      _transactions.clear();
      final data = event.snapshot.value;
      if (data is Map) {
        data.forEach((key, value) {
          try {
            if (value is Map) {
              final Map<String, dynamic> txMap = Map<String, dynamic>.from(value);
              _transactions.add(Transaction.fromJson(txMap));
            }
          } catch (e) {
            debugPrint("Error parsing transaction: $e");
          }
        });
      }
      notifyListeners();
    }, onError: (error) {
      debugPrint("Database listen error: $error");
    });
  }

  void _unsubscribeFromDatabase() {
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _databaseSubscription?.cancel();
    super.dispose();
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
    final uid = _currentUserId;
    if (uid == null) return;

    final id = _uuid.v4();
    final newTransaction = Transaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
    );

    FirebaseDatabase.instance
        .ref('users/$uid/transactions/$id')
        .set(newTransaction.toJson())
        .catchError((error) {
      debugPrint("Failed to add transaction: $error");
    });
  }

  void deleteTransaction(String id) {
    final uid = _currentUserId;
    if (uid == null) return;

    FirebaseDatabase.instance
        .ref('users/$uid/transactions/$id')
        .remove()
        .catchError((error) {
      debugPrint("Failed to delete transaction: $error");
    });
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
