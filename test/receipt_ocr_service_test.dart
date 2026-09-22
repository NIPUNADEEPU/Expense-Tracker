import 'package:expense_tracker/services/receipt_ocr_service.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts a labelled receipt total and merchant', () {
    const receipt = '''
Fresh Mart
12 Market Road
Subtotal 1,109.50
GST 55.48
Grand Total ₹1,164.98
''';

    final result = ReceiptOcrService.parseRecognizedText(receipt);

    expect(result.merchant, 'Fresh Mart');
    expect(result.amount, 1164.98);
  });

  test('uses the largest value when no total label is detected', () {
    final result = ReceiptOcrService.parseRecognizedText('Coffee 120.00\nPaid 150.00');

    expect(result.amount, 150.00);
  });

  test('extracts single-line and two-line receipt items', () {
    const receipt = '''
Fresh Mart
Milk 54.00
Whole Wheat Bread
45.00
GST 8.91
Grand Total Rs. 107.91
''';

    final result = ReceiptOcrService.parseRecognizedText(receipt);

    expect(result.items, hasLength(2));
    expect(result.items[0].title, 'Milk');
    expect(result.items[0].amount, 54.00);
    expect(result.items[0].category, ExpenseCategory.food);
    expect(result.items[1].title, 'Whole Wheat Bread');
    expect(result.items[1].amount, 45.00);
  });

  test('extracts an item with quantity columns and a whole-number total', () {
    final result = ReceiptOcrService.parseRecognizedText(
      'Basmati Rice 2 50 100\nGrand Total 100',
    );

    expect(result.items, hasLength(1));
    expect(result.items.single.title, 'Basmati Rice');
    expect(result.items.single.amount, 100);
  });
}
