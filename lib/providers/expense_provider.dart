import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../models/transaction.dart';
import '../models/monthly_budget.dart';
import '../models/category.dart';
import '../models/transaction_analytics.dart';
import '../services/notification_service.dart';

class ExpenseProvider with ChangeNotifier {
  final List<Transaction> _transactions = [];
  final _uuid = const Uuid();

  StreamSubscription? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _firestoreSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _budgetSubscription;
  final List<MonthlyBudget> _budgets = [];
  final Set<String> _notifiedBudgetThresholds = {};
  Map<String, double> _previousBudgetRatios = {};
  bool _hasBudgetBaseline = false;

  String? _currentUserId;
  bool _isLoadingTransactions = true;
  String? _transactionLoadError;

  bool get isLoadingTransactions => _isLoadingTransactions;
  String? get transactionLoadError => _transactionLoadError;

  ExpenseProvider() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // Clear the previous user's cached transactions.
        if (_currentUserId != user.uid) {
          _transactions.clear();
          _isLoadingTransactions = true;
          _transactionLoadError = null;
          notifyListeners();
        }

        _currentUserId = user.uid;
        _subscribeToTransactions(user.uid);
        _subscribeToBudgets(user.uid);

        if (!kIsWeb) {
          unawaited(NotificationService.registerCurrentUserDevice());
        }
      } else {
        _currentUserId = null;
        _unsubscribeFromTransactions();
        _budgetSubscription?.cancel();
        _budgetSubscription = null;
        _budgets.clear();
        _notifiedBudgetThresholds.clear();
        _previousBudgetRatios.clear();
        _hasBudgetBaseline = false;
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
            debugPrint(
              'Error parsing transaction ${document.id}: $error',
            );
          }
        }

        _transactions
          ..clear()
          ..addAll(transactions);
        _evaluateBudgetThresholds();

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

  void _subscribeToBudgets(String uid) {
    _budgetSubscription?.cancel();
    _budgetSubscription = FirebaseFirestore.instance.collection('users').doc(uid).collection('budgets').snapshots().listen((snapshot) {
      if (_currentUserId != uid) return;
      _budgets..clear();
      for (final doc in snapshot.docs) { try { _budgets.add(MonthlyBudget.fromJson(doc.id, doc.data())); } catch (error) { debugPrint('Error parsing budget ${doc.id}: $error'); } }
      _evaluateBudgetThresholds();
      notifyListeners();
    }, onError: (error) { debugPrint('Firestore budget listen error: $error'); });
  }

  void _evaluateBudgetThresholds() {
    final current = <String, double>{};
    for (final budget in _budgets) {
      final key = budget.id;
      final ratio = BudgetAnalytics.usageRatio(_transactions, budget);
      current[key] = ratio;
      if (_hasBudgetBaseline) {
        final threshold = BudgetAnalytics.thresholdCrossed(_previousBudgetRatios[key] ?? 0, ratio);
        final alertKey = '${budget.periodKey}:${budget.currency.code}:${budget.id}:$threshold';
        if (threshold != null && _notifiedBudgetThresholds.add(alertKey)) {
          NotificationService.showBudgetAlert(budget: budget, threshold: threshold);
        }
      }
    }
    _previousBudgetRatios = current;
    _hasBudgetBaseline = true;
  }

  List<MonthlyBudget> get budgets => List.unmodifiable(_budgets);
  List<MonthlyBudget> budgetsForMonth(int year, int month) => _budgets.where((b) => b.year == year && b.month == month).toList();
  Future<void> saveBudget({required int year, required int month, required double amount, required TransactionCurrency currency, ExpenseCategory? category}) async {
    final uid = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in to save a budget.');
    final id = MonthlyBudget.documentId(year, month, category);
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('budgets').doc(id).set(MonthlyBudget(id: id, year: year, month: month, amount: amount, currency: currency, category: category).toJson());
  }
  Future<void> deleteBudget(MonthlyBudget budget) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('budgets').doc(budget.id).delete();
  }

  void _unsubscribeFromTransactions() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _firestoreSubscription?.cancel();
    _budgetSubscription?.cancel();
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
    TransactionCurrency currency = TransactionCurrency.unknown,
  }) async {
    final uid = _currentUserId;

    if (uid == null) {
      throw StateError(
        'You must be signed in to save a transaction.',
      );
    }

    final id = _uuid.v4();

    final newTransaction = Transaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      currency: currency,
    );

    await _writeTransaction(uid, id, newTransaction);
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

// InheritedNotifier to expose the provider efficiently to the widget tree.
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