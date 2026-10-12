import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved and restored transaction keeps its predicted category', () {
    final transaction = Transaction(
      id: 'receipt-1',
      title: 'Dove Shampoo',
      amount: 249,
      type: TransactionType.expense,
      category: ExpenseCategory.personalCare,
      date: DateTime(2026, 10, 12),
    );

    final restored = Transaction.fromJson(transaction.toJson());

    expect(transaction.toJson()['category'], 'personalCare');
    expect(restored.category, ExpenseCategory.personalCare);
  });
}
