import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/widgets/sms_category_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('small screen dialog scrolls all options without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    ExpenseCategory? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showDialog<ExpenseCategory>(
                    context: context,
                    builder: (_) => SmsCategoryReviewDialog(
                      transaction: Transaction(
                        id: 'sms-1',
                        title: 'Corner Shop',
                        amount: 1250,
                        type: TransactionType.expense,
                        category: ExpenseCategory.uncategorized,
                        date: DateTime(2026, 10, 12),
                        currency: TransactionCurrency.inr,
                      ),
                      index: 1,
                      total: 1,
                    ),
                  );
                },
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a category (1/1)'), findsOneWidget);
    expect(find.text('Corner Shop'), findsOneWidget);
    expect(find.text('\u20B91,250'), findsOneWidget);
    expect(find.text('Review later'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text(ExpenseCategory.other.displayName),
      250,
      scrollable: find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ExpenseCategory.other.displayName), findsOneWidget);
    expect(find.text('Review later'), findsOneWidget);
    expect(find.text('Choose a category (1/1)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(ExpenseCategory.other.displayName));
    await tester.pumpAndSettle();
    expect(selected, ExpenseCategory.other);
    expect(tester.takeException(), isNull);
  });
}
