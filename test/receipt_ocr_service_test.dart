import 'package:flutter_test/flutter_test.dart';

import '../lib/services/receipt_ocr_service.dart';

void main() {
  group('ReceiptOcrService', () {
    // ==============================================================
    // RECEIPT 1
    // Simple cash receipt
    // ==============================================================

    test('extracts merchant, items and total from a simple receipt', () {
      const text = '''
CASH RECEIPT
Shop Name
Address: Lorem Ipsum 3/18
Tel: 0987 123 890 5678
Date: MM/DD/YYYY
Manager: Lorem Ipsum
--------------------------------
Lorem                         2.15
Ipsum                         8.75
Dolor sit                     3.50
--------------------------------
Price                        14.40
Tax                           1.25
--------------------------------
Total                        15.65
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      // Merchant
      expect(result.title, 'Shop Name');

      // Total
      expect(result.amount, 15.65);

      // Items
      expect(result.items.length, 3);

      expect(result.items[0].title, 'Lorem');
      expect(result.items[0].totalPrice, 2.15);

      expect(result.items[1].title, 'Ipsum');
      expect(result.items[1].totalPrice, 8.75);

      expect(result.items[2].title, 'Dolor sit');
      expect(result.items[2].totalPrice, 3.50);
    });

    // ==============================================================
    // RECEIPT 2
    // Restaurant receipt with:
    // ITEM | QTY | UNIT | TOTAL
    // ==============================================================

    test('extracts restaurant table items correctly', () {
      const text = '''
YOUR RESTAURANT
GOOD FOOD. GREAT MEMORIES.

Your Restaurant Address
Bengaluru, Karnataka 560001
Ph: 080-4567-8910
GSTIN: 29ABCDE1234F1Z5

--------------------------------
Bill No.       : SKB/25-05/0142
Date           : 17 Jun 2026
Time           : 20:45
Order Type     : Dine In
Table No.      : T-08
Token No.      : A42
--------------------------------

ITEM                 QTY       UNIT       TOTAL

1. Masala Dosa        1       ₹149.00     ₹149.00
2. Paneer Roll        1       ₹249.00     ₹249.00
3. Tea                2       ₹49.00       ₹98.00
4. Gulab Jamun        2       ₹89.00      ₹178.00

--------------------------------
SUBTOTAL                              ₹674.00
CGST (2.5%)                            ₹16.85
SGST (2.5%)                            ₹16.85

GRAND TOTAL                            ₹707.70

--------------------------------
Customer Name : Dine In Guest
Payment Status                 PAID
Payment Mode                   UPI

THANK YOU, VISIT AGAIN!
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      // Merchant
      expect(result.title, 'YOUR RESTAURANT');

      // Total
      expect(result.amount, 707.70);

      // Exactly four items
      expect(result.items.length, 4);

      // ------------------------------------------------------------
      // Item 1
      // ------------------------------------------------------------

      expect(result.items[0].title, 'Masala Dosa');
      expect(result.items[0].quantity, 1);
      expect(result.items[0].unitPrice, 149.00);
      expect(result.items[0].totalPrice, 149.00);

      // ------------------------------------------------------------
      // Item 2
      // ------------------------------------------------------------

      expect(result.items[1].title, 'Paneer Roll');
      expect(result.items[1].quantity, 1);
      expect(result.items[1].unitPrice, 249.00);
      expect(result.items[1].totalPrice, 249.00);

      // ------------------------------------------------------------
      // Item 3
      // ------------------------------------------------------------

      expect(result.items[2].title, 'Tea');
      expect(result.items[2].quantity, 2);
      expect(result.items[2].unitPrice, 49.00);
      expect(result.items[2].totalPrice, 98.00);

      // ------------------------------------------------------------
      // Item 4
      // ------------------------------------------------------------

      expect(result.items[3].title, 'Gulab Jamun');
      expect(result.items[3].quantity, 2);
      expect(result.items[3].unitPrice, 89.00);
      expect(result.items[3].totalPrice, 178.00);
    });

    // ==============================================================
    // RECEIPT 3
    // Supermarket receipt
    // ==============================================================

    test('extracts all supermarket items correctly', () {
      const text = '''
FRESH MART
SUPERMARKET
123 MG Road, Bengaluru - 560001
Ph: 080-1234 5678

Invoice No: FM25092100123
Date: 21-09-2025
Time: 14:32
Cashier: 1023

--------------------------------
Item                    Qty       Price       Amount

Rice (1kg)               1       120.00       120.00
Milk (1L)                2        30.00        60.00
Bread                    1        40.00        40.00
Eggs (6 pcs)             1        45.00        45.00
Tomatoes (500g)          1        25.00        25.00
Onions (1kg)             1        30.00        30.00
Cooking Oil (1L)         1       135.00       135.00
Soap                     1        40.00        40.00

--------------------------------
Subtotal                                      455.00
GST (5%)                                       22.75

--------------------------------
Total                                          477.75

--------------------------------
Payment Mode: UPI
Txn Ref No: 5098217345

Thank you for shopping with us!
Visit Again!
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      // Merchant
      expect(result.title, 'FRESH MART SUPERMARKET');

      // Total
      expect(result.amount, 477.75);

      // Exactly 8 products
      expect(result.items.length, 8);

      // ------------------------------------------------------------
      // Item names
      // ------------------------------------------------------------

      expect(result.items.map((item) => item.title).toList(), [
        'Rice (1kg)',
        'Milk (1L)',
        'Bread',
        'Eggs (6 pcs)',
        'Tomatoes (500g)',
        'Onions (1kg)',
        'Cooking Oil (1L)',
        'Soap',
      ]);

      // ------------------------------------------------------------
      // Quantities
      // ------------------------------------------------------------

      expect(result.items.map((item) => item.quantity).toList(), [
        1,
        2,
        1,
        1,
        1,
        1,
        1,
        1,
      ]);

      // ------------------------------------------------------------
      // Unit prices
      // ------------------------------------------------------------

      expect(result.items.map((item) => item.unitPrice).toList(), [
        120.00,
        30.00,
        40.00,
        45.00,
        25.00,
        30.00,
        135.00,
        40.00,
      ]);

      // ------------------------------------------------------------
      // Total prices
      // ------------------------------------------------------------

      expect(result.items.map((item) => item.totalPrice).toList(), [
        120.00,
        60.00,
        40.00,
        45.00,
        25.00,
        30.00,
        135.00,
        40.00,
      ]);
    });

    // ==============================================================
    // SIMPLE RECEIPT WITHOUT TOTAL LABEL
    // ==============================================================

    test('uses largest reasonable amount when total label is missing', () {
      const text = '''
MY STORE
Address: Main Road
Apple                         50.00
Milk                          40.00
Bread                         35.00
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      expect(result.title, 'MY STORE');

      expect(result.items.length, 3);

      expect(result.items[0].title, 'Apple');
      expect(result.items[1].title, 'Milk');
      expect(result.items[2].title, 'Bread');

      expect(result.amount, 50.00);
    });

    // ==============================================================
    // TWO-LINE ITEM
    //
    // Product name
    // Price
    // ==============================================================

    test('handles item name and price on separate lines', () {
      const text = '''
MY SHOP
Address: Main Road

Milk
54.00

Whole Wheat Bread
45.00

Total
99.00
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      expect(result.title, 'MY SHOP');

      expect(result.items.length, 2);

      expect(result.items[0].title, 'Milk');
      expect(result.items[0].totalPrice, 54.00);

      expect(result.items[1].title, 'Whole Wheat Bread');
      expect(result.items[1].totalPrice, 45.00);

      expect(result.amount, 99.00);
    });

    // ==============================================================
    // METADATA SHOULD NEVER BECOME AN ITEM
    // ==============================================================

    test('does not treat receipt metadata as purchased items', () {
      const text = '''
ABC STORE
123 Main Road
Phone: 9876543210
Date: 21-09-2026
Time: 14:30
Invoice No: INV12345
Cashier: 1023

ITEM             QTY       PRICE       TOTAL

Notebook          1         50.00       50.00
Pen               2         10.00       20.00

Subtotal                                70.00
GST                                      3.50
Total                                    73.50

Payment Mode: UPI
Txn Ref No: 1234567890

Thank you
Visit Again
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      expect(result.title, 'ABC STORE');

      expect(result.items.length, 2);

      expect(result.items.map((item) => item.title).toList(), [
        'Notebook',
        'Pen',
      ]);

      expect(result.amount, 73.50);
    });

    // ==============================================================
    // CURRENCY SYMBOLS
    // ==============================================================

    test('handles different currency formats', () {
      const text = '''
MY SHOP

Coffee                 ₹120.00
Cake                   Rs. 250.00
Juice                  INR 80.00

Total                  ₹450.00
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      expect(result.items.length, 3);

      expect(result.items[0].title, 'Coffee');
      expect(result.items[0].totalPrice, 120.00);

      expect(result.items[1].title, 'Cake');
      expect(result.items[1].totalPrice, 250.00);

      expect(result.items[2].title, 'Juice');
      expect(result.items[2].totalPrice, 80.00);

      expect(result.amount, 450.00);
    });

    // ==============================================================
    // ITEM NUMBERING
    // ==============================================================

    test('removes item numbering from product names', () {
      const text = '''
RESTAURANT

1. Pizza                 250.00
2. Burger                180.00
3. Coffee                 80.00

Total                    510.00
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      expect(result.items.length, 3);

      expect(result.items[0].title, 'Pizza');
      expect(result.items[1].title, 'Burger');
      expect(result.items[2].title, 'Coffee');

      expect(result.amount, 510.00);
    });

    // ==============================================================
    // DUPLICATE PROTECTION
    // ==============================================================

    test('removes duplicate OCR items', () {
      const text = '''
STORE

Milk             2        30.00        60.00
Milk             2        30.00        60.00

Total                                      60.00
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      expect(result.items.length, 1);

      expect(result.items[0].title, 'Milk');
      expect(result.items[0].quantity, 2);
      expect(result.items[0].unitPrice, 30.00);
      expect(result.items[0].totalPrice, 60.00);
    });

    // ==============================================================
    // EMPTY OCR
    // ==============================================================

    test('handles empty OCR text safely', () {
      const text = '';

      final result = ReceiptOcrService.parseRecognizedText(text);

      expect(result.title, isNull);
      expect(result.amount, isNull);
      expect(result.items, isEmpty);
      expect(result.rawText, isEmpty);
    });

    // ==============================================================
    // RAW TEXT IS PRESERVED
    // ==============================================================

    test('preserves original OCR text', () {
      const text = '''
MY STORE
Milk 50.00
Total 50.00
''';

      final result = ReceiptOcrService.parseRecognizedText(text);

      expect(result.rawText, text);
    });
  });
}
