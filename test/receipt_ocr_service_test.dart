import 'package:expense_tracker/services/receipt_ocr_service.dart';
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
}
