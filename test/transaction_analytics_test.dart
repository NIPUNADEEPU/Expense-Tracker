import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/models/transaction_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final transactions = [
    Transaction(
      id: 'income-jan',
      title: 'Salary',
      amount: 3000,
      type: TransactionType.income,
      category: ExpenseCategory.salary,
      date: DateTime(2026, 1, 5),
    ),
    Transaction(
      id: 'food-jan',
      title: 'Groceries',
      amount: 300,
      type: TransactionType.expense,
      category: ExpenseCategory.food,
      date: DateTime(2026, 1, 31, 23, 45),
    ),
    Transaction(
      id: 'transport-jan',
      title: 'Metro',
      amount: 50,
      type: TransactionType.expense,
      category: ExpenseCategory.transport,
      date: DateTime(2026, 1, 10),
    ),
    Transaction(
      id: 'food-feb',
      title: 'Lunch',
      amount: 200,
      type: TransactionType.expense,
      category: ExpenseCategory.food,
      date: DateTime(2026, 2, 1),
    ),
    Transaction(
      id: 'old-year',
      title: 'Older purchase',
      amount: 999,
      type: TransactionType.expense,
      category: ExpenseCategory.other,
      date: DateTime(2025, 1, 1),
    ),
  ];

  test('period and category totals use only matching transactions', () {
    expect(
      TransactionAnalytics.total(
        transactions,
        type: TransactionType.expense,
        year: 2026,
        month: 1,
      ),
      350,
    );
    expect(
      TransactionAnalytics.spendingByCategory(
        transactions,
        year: 2026,
        month: 1,
      ),
      {ExpenseCategory.food: 300, ExpenseCategory.transport: 50},
    );
  });
}
