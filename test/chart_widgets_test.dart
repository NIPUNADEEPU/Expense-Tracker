import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/widgets/expense_chart.dart';
import 'package:expense_tracker/widgets/income_expense_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final transactions = [
    Transaction(
      id: 'salary',
      title: 'Salary',
      amount: 3000,
      type: TransactionType.income,
      category: ExpenseCategory.salary,
      date: DateTime(2026, 2, 5),
    ),
    Transaction(
      id: 'food',
      title: 'Groceries',
      amount: 1000,
      type: TransactionType.expense,
      category: ExpenseCategory.food,
      date: DateTime(2026, 2, 10),
    ),
    Transaction(
      id: 'transport',
      title: 'Metro',
      amount: 250,
      type: TransactionType.expense,
      category: ExpenseCategory.transport,
      date: DateTime(2026, 2, 12),
    ),
  ];

  testWidgets('expense chart displays period categories on a phone layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseCategoryChart(
            transactions: transactions,
            year: 2026,
            month: 2,
          ),
        ),
      ),
    );

    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('income and expense chart shows the monthly comparison', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncomeExpenseChart(
            transactions: transactions,
            year: 2026,
            month: 2,
          ),
        ),
      ),
    );

    expect(find.text('Income vs expenses'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense chart explains when the selected month has no data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpenseCategoryChart(transactions: [], year: 2026, month: 1),
        ),
      ),
    );

    expect(find.text('No spending recorded for this period.'), findsOneWidget);
  });
}
