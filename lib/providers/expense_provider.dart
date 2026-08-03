import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/transaction.dart';
import '../models/category.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Transaction> _transactions = [];
  final _uuid = const Uuid();
  StreamSubscription? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;
  String? _currentUserId;

  ExpenseProvider() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _currentUserId = user.uid;
        _subscribeToTransactions(user.uid);
      } else {
        _currentUserId = null;
        _unsubscribeFromTransactions();
        _transactions.clear();
        notifyListeners();
      }
    });
  }

  void _subscribeToTransactions(String uid) {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .snapshots()
        .listen(
          (snapshot) {
            final transactions = <Transaction>[];

            for (final document in snapshot.docs) {
              try {
                final data = Map<String, dynamic>.from(document.data());
                data.putIfAbsent('id', () => document.id);
                transactions.add(Transaction.fromJson(data));
              } catch (error) {
                debugPrint('Error parsing transaction ${document.id}: $error');
              }
            }

            _transactions
              ..clear()
              ..addAll(transactions);
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Firestore listen error: $error');
          },
        );
  }

  void _unsubscribeFromTransactions() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _firestoreSubscription?.cancel();
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
        .fold(0.0, (total, t) => total + t.amount);
  }

  double get totalExpenses {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (total, t) => total + t.amount);
  }

  double get totalBalance {
    return totalIncome - totalExpenses;
  }

  Map<ExpenseCategory, double> get categoryTotals {
    final Map<ExpenseCategory, double> totals = {};
    for (var transaction in _transactions) {
      if (transaction.type == TransactionType.expense) {
        totals[transaction.category] =
            (totals[transaction.category] ?? 0.0) + transaction.amount;
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

    unawaited(_writeTransaction(uid, id, newTransaction));
  }

  void deleteTransaction(String id) {
    final uid = _currentUserId;
    if (uid == null) return;

    unawaited(_deleteTransaction(uid, id));
  }

  Future<void> _writeTransaction(
    String uid,
    String id,
    Transaction transaction,
  ) async {
    final transactionReference = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(id);
    await transactionReference.set(transaction.toJson());
  }

  Future<void> _deleteTransaction(String uid, String id) async {
    final transactionReference = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(id);
    await transactionReference.delete();
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
