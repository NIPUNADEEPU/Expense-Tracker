import 'category.dart';
import 'transaction.dart';

/// Pure aggregations over the authenticated user's transaction records.
class TransactionAnalytics {
  const TransactionAnalytics._();

  static double total(
    Iterable<Transaction> transactions, {
    TransactionType? type,
    int? year,
    int? month,
  }) => transactions
      .where((transaction) {
        if (type != null && transaction.type != type) return false;
        if (year != null && transaction.date.year != year) return false;
        if (month != null && transaction.date.month != month) return false;
        return true;
      })
      .fold<double>(0, (sum, transaction) => sum + transaction.amount);

  static Map<ExpenseCategory, double> spendingByCategory(
    Iterable<Transaction> transactions, {
    int? year,
    int? month,
  }) {
    final totals = <ExpenseCategory, double>{};
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) continue;
      if (year != null && transaction.date.year != year) continue;
      if (month != null && transaction.date.month != month) continue;
      totals.update(
        transaction.category,
        (current) => current + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return totals;
  }
}
