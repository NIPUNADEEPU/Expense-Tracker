import 'package:flutter/foundation.dart';
import 'category.dart';
import 'transaction.dart';

@immutable
class MonthlyBudget {
  const MonthlyBudget({required this.id, required this.year, required this.month, required this.amount, required this.currency, this.category});
  final String id;
  final int year;
  final int month;
  final double amount;
  final TransactionCurrency currency;
  final ExpenseCategory? category;
  String get periodKey => year.toString() + '-' + month.toString().padLeft(2, '0');
  bool get isOverall => category == null;
  Map<String, dynamic> toJson() => {'year': year, 'month': month, 'amount': amount, 'currency': currency.code, 'category': category?.name};
  factory MonthlyBudget.fromJson(String id, Map<String, dynamic> json) {
    final categoryName = json['category'] as String?;
    ExpenseCategory? category;
    if (categoryName != null) { for (final value in ExpenseCategory.values) { if (value.name == categoryName) { category = value; break; } } }
    return MonthlyBudget(id: id, year: (json['year'] as num).toInt(), month: (json['month'] as num).toInt(), amount: (json['amount'] as num).toDouble(), currency: TransactionCurrency.fromStoredValue(json['currency']), category: category);
  }
  static String documentId(int year, int month, ExpenseCategory? category) => year.toString() + '-' + month.toString().padLeft(2, '0') + (category == null ? '' : '__' + category.name);
}

class BudgetAnalytics {
  const BudgetAnalytics._();
  static double spentFor(Iterable<Transaction> transactions, MonthlyBudget budget) => transactions.where((t) => t.type == TransactionType.expense && t.date.year == budget.year && t.date.month == budget.month && t.currency == budget.currency && (budget.category == null || t.category == budget.category)).fold(0.0, (sum, t) => sum + t.amount);
  static double remaining(Iterable<Transaction> transactions, MonthlyBudget budget) => budget.amount - spentFor(transactions, budget);
  static double usageRatio(Iterable<Transaction> transactions, MonthlyBudget budget) => budget.amount <= 0 ? 0 : spentFor(transactions, budget) / budget.amount;
  static Map<ExpenseCategory, double> spendingByCategory(Iterable<Transaction> transactions, {required int year, required int month, required TransactionCurrency currency}) {
    final result = <ExpenseCategory, double>{};
    for (final t in transactions) { if (t.type == TransactionType.expense && t.date.year == year && t.date.month == month && t.currency == currency) result.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount); }
    return result;
  }
  static int? thresholdCrossed(double previousRatio, double currentRatio) {
    if (previousRatio < 1 && currentRatio >= 1) return 100;
    if (previousRatio < .8 && currentRatio >= .8) return 80;
    return null;
  }
}
