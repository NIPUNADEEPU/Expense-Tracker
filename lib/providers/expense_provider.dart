import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/transaction_analytics.dart';
import '../services/notification_service.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Transaction> _transactions = [];
  final _uuid = const Uuid();
  StreamSubscription? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;
  String? _currentUserId;
  bool _isLoadingTransactions = true;
  String? _transactionLoadError;

  bool get isLoadingTransactions => _isLoadingTransactions;
  String? get transactionLoadError => _transactionLoadError;

  ExpenseProvider() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // Avoid briefly exposing the prior account's cached transactions while
        // the new user's Firestore stream is establishing its first snapshot.
        if (_currentUserId != user.uid) {
          _transactions.clear();
          _isLoadingTransactions = true;
          _transactionLoadError = null;
          notifyListeners();
        }
        _currentUserId = user.uid;
        _subscribeToTransactions(user.uid);
        if (!kIsWeb) {
          unawaited(NotificationService.registerCurrentUserDevice());
        }
      } else {
        _currentUserId = null;
        _unsubscribeFromTransactions();
        _transactions.clear();
        _isLoadingTransactions = false;
        _transactionLoadError = null;
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
            if (_currentUserId != uid) return;
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
            _isLoadingTransactions = false;
            _transactionLoadError = null;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Firestore listen error: $error');
            _isLoadingTransactions = false;
            _transactionLoadError = 'Could not load your transactions.';
            notifyListeners();
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
    return TransactionAnalytics.total(
      _transactions,
      type: TransactionType.income,
    );
  }

  double get totalExpenses {
    return TransactionAnalytics.total(
      _transactions,
      type: TransactionType.expense,
    );
  }

  double get totalBalance {
    return totalIncome - totalExpenses;
  }

  Map<ExpenseCategory, double> get categoryTotals {
    return TransactionAnalytics.spendingByCategory(_transactions);
  }

  Future<void> addTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required ExpenseCategory category,
    required DateTime date,
  }) {
    final uid = _currentUserId;
    if (uid == null) return Future<void>.value();

    final id = _uuid.v4();
    final newTransaction = Transaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
    );

    return _writeTransaction(uid, id, newTransaction);
  }

  Future<void> addTransactions({
    required List<({String title, double amount, ExpenseCategory category})>
    items,
    required DateTime date,
  }) async {
    final uid = _currentUserId;
    if (uid == null || items.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final item in items) {
      final id = _uuid.v4();
      final transaction = Transaction(
        id: id,
        title: item.title,
        amount: item.amount,
        type: TransactionType.expense,
        category: item.category,
        date: date,
      );
      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(id);
      batch.set(reference, transaction.toJson());
    }
    await batch.commit();
  }

  void deleteTransaction(String id) {
    final uid = _currentUserId;
    if (uid == null) return;

    unawaited(_deleteTransaction(uid, id));
  }

  void updateTransaction(Transaction transaction) {
    final uid = _currentUserId;
    if (uid == null) return;

    unawaited(_writeTransaction(uid, transaction.id, transaction));
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
