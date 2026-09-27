import 'package:flutter_test/flutter_test.dart';

import '../lib/services/receipt_ocr_service.dart';

void main() {
  group('ReceiptOcrService', () {
    // ==============================================================
    // TEST 1
    // Simple cash receipt
    // ==============================================================

    test(
      'extracts items from simple receipt',
      () {
        const text = '''
CASH RECEIPT
Shop Name
Address: Lorem Ipsum 3/18
Tel: 0987 123 890 5678
Date: MM/DD/YYYY
Manager: Lorem Ipsum

Lorem                         2.15
Ipsum                         8.75
Dolor sit                     3.50

Price                        14.40
Tax                           1.25

Total                        15.65
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.title,
          'Shop Name',
        );

        expect(
          result.amount,
          15.65,
        );

        expect(
          result.items.length,
          3,
        );

        expect(
          result.items[0].title,
          'Lorem',
        );

        expect(
          result.items[0].totalPrice,
          2.15,
        );

        expect(
          result.items[1].title,
          'Ipsum',
        );

        expect(
          result.items[1].totalPrice,
          8.75,
        );

        expect(
          result.items[2].title,
          'Dolor sit',
        );

        expect(
          result.items[2].totalPrice,
          3.50,
        );
      },
    );

    // ==============================================================
    // TEST 2
    // Restaurant receipt
    // ==============================================================

    test(
      'extracts restaurant table items',
      () {
        const text = '''
YOUR RESTAURANT
GOOD FOOD. GREAT MEMORIES.

Your Restaurant Address
Bengaluru, Karnataka 560001
Ph: 080-4567-8910
GSTIN: 29ABCDE1234F1Z5

Bill No: SKB/25-05/0142
Date: 17 Jun 2026
Time: 20:45
Order Type: Dine In
Table No: T-08
Token No: A42

ITEM                 QTY       UNIT       TOTAL

1. Masala Dosa        1       ₹149.00     ₹149.00
2. Paneer Roll        1       ₹249.00     ₹249.00
3. Tea                2       ₹49.00       ₹98.00
4. Gulab Jamun        2       ₹89.00      ₹178.00

SUBTOTAL                              ₹674.00
CGST (2.5%)                            ₹16.85
SGST (2.5%)                            ₹16.85

GRAND TOTAL                            ₹707.70

Customer Name: Dine In Guest
Payment Status: PAID
Payment Mode: UPI

THANK YOU, VISIT AGAIN!
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.title,
          'YOUR RESTAURANT',
        );

        expect(
          result.amount,
          707.70,
        );

        expect(
          result.items.length,
          4,
        );

        expect(
          result.items[0].title,
          'Masala Dosa',
        );

        expect(
          result.items[0].quantity,
          1,
        );

        expect(
          result.items[0].unitPrice,
          149.00,
        );

        expect(
          result.items[0].totalPrice,
          149.00,
        );

        expect(
          result.items[1].title,
          'Paneer Roll',
        );

        expect(
          result.items[1].quantity,
          1,
        );

        expect(
          result.items[1].unitPrice,
          249.00,
        );

        expect(
          result.items[1].totalPrice,
          249.00,
        );

        expect(
          result.items[2].title,
          'Tea',
        );

        expect(
          result.items[2].quantity,
          2,
        );

        expect(
          result.items[2].unitPrice,
          49.00,
        );

        expect(
          result.items[2].totalPrice,
          98.00,
        );

        expect(
          result.items[3].title,
          'Gulab Jamun',
        );

        expect(
          result.items[3].quantity,
          2,
        );

        expect(
          result.items[3].unitPrice,
          89.00,
        );

        expect(
          result.items[3].totalPrice,
          178.00,
        );
      },
    );

    // ==============================================================
    // TEST 3
    // Supermarket receipt
    // ==============================================================

    test(
      'extracts all supermarket items',
      () {
        const text = '''
FRESH MART
SUPERMARKET
123 MG Road, Bengaluru - 560001
Ph: 080-1234 5678

Invoice No: FM25092100123
Date: 21-09-2025
Time: 14:32
Cashier: 1023

Item                    Qty       Price       Amount

Rice (1kg)               1       120.00       120.00
Milk (1L)                2        30.00        60.00
Bread                    1        40.00        40.00
Eggs (6 pcs)             1        45.00        45.00
Tomatoes (500g)          1        25.00        25.00
Onions (1kg)             1        30.00        30.00
Cooking Oil (1L)         1       135.00       135.00
Soap                     1        40.00        40.00

Subtotal                                      455.00
GST (5%)                                       22.75

Total                                          477.75

Payment Mode: UPI
Txn Ref No: 5098217345

Thank you for shopping with us!
Visit Again!
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.title,
          'FRESH MART SUPERMARKET',
        );

        expect(
          result.amount,
          477.75,
        );

        expect(
          result.items.length,
          8,
        );

        expect(
          result.items
              .map((item) => item.title)
              .toList(),
          [
            'Rice (1kg)',
            'Milk (1L)',
            'Bread',
            'Eggs (6 pcs)',
            'Tomatoes (500g)',
            'Onions (1kg)',
            'Cooking Oil (1L)',
            'Soap',
          ],
        );

        expect(
          result.items
              .map((item) => item.quantity)
              .toList(),
          [
            1,
            2,
            1,
            1,
            1,
            1,
            1,
            1,
          ],
        );

        expect(
          result.items
              .map((item) => item.unitPrice)
              .toList(),
          [
            120.00,
            30.00,
            40.00,
            45.00,
            25.00,
            30.00,
            135.00,
            40.00,
          ],
        );

        expect(
          result.items
              .map((item) => item.totalPrice)
              .toList(),
          [
            120.00,
            60.00,
            40.00,
            45.00,
            25.00,
            30.00,
            135.00,
            40.00,
          ],
        );
      },
    );

    // ==============================================================
    // TEST 4
    // EVERYDAY MART RECEIPT
    //
    // This specifically tests the problem shown by the user.
    // ==============================================================

    test(
      'extracts only purchased items from Everyday Mart receipt',
      () {
        const text = '''
EVERYDAY MART
101 MAIN STREET
SPRINGFIELD, IL 62701
(555) 210-1001
HELLO@EVERYDAYMART.EXAMPLE

10/10/2025 13:05

CASHIER: LANE
REGISTER: R-12
STORE ID: 004

REUSABLE BAG                 \$1
2X BOTTLED WATER 500ML      \$3

SUBTOTAL:                   \$3
TAX:                        \$0
TOTAL:                      \$3

CARD: **** 4411
TYPE: VISA
ENTRY: CONTACTLESS
TIME: 10/10/2025, 13:05:00
REF: AUTH-553210
STATUS: APPROVED

THANK YOU FOR SHOPPING WITH US!
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        // ----------------------------------------------------------
        // Merchant
        // ----------------------------------------------------------

        expect(
          result.title,
          'EVERYDAY MART',
        );

        // ----------------------------------------------------------
        // Total
        // ----------------------------------------------------------

        expect(
          result.amount,
          3.0,
        );

        // ----------------------------------------------------------
        // Exactly two purchased items.
        // ----------------------------------------------------------

        expect(
          result.items.length,
          2,
        );

        // ----------------------------------------------------------
        // Item 1
        // ----------------------------------------------------------

        expect(
          result.items[0].title,
          'REUSABLE BAG',
        );

        expect(
          result.items[0].quantity,
          1,
        );

        expect(
          result.items[0].totalPrice,
          1.0,
        );

        // ----------------------------------------------------------
        // Item 2
        // ----------------------------------------------------------

        expect(
          result.items[1].title,
          '2X BOTTLED WATER 500ML',
        );

        expect(
          result.items[1].quantity,
          1,
        );

        expect(
          result.items[1].totalPrice,
          3.0,
        );

        // ----------------------------------------------------------
        // Make sure metadata was NOT extracted.
        // ----------------------------------------------------------

        final names = result.items
            .map(
              (item) => item.title,
            )
            .toList();

        expect(
          names.any(
            (name) =>
                name.contains('SPRINGFIELD'),
          ),
          false,
        );

        expect(
          names.any(
            (name) =>
                name.contains('62701'),
          ),
          false,
        );

        expect(
          names.any(
            (name) =>
                name.contains('ID'),
          ),
          false,
        );

        expect(
          names.any(
            (name) =>
                name.contains('004'),
          ),
          false,
        );

        expect(
          names.any(
            (name) =>
                name.contains('REGISTER'),
          ),
          false,
        );

        expect(
          names.any(
            (name) =>
                name.contains('CARD'),
          ),
          false,
        );

        expect(
          names.any(
            (name) =>
                name.contains('VISA'),
          ),
          false,
        );

        expect(
          names.any(
            (name) =>
                name.contains('AUTH-553210'),
          ),
          false,
        );
      },
    );

    // ==============================================================
    // TEST 5
    // Product IDs / SKUs / PLUs
    // ==============================================================

    test(
      'removes product codes from product names',
      () {
        const text = '''
MY STORE

04011 BANANAS ORG        2       45.00       90.00
9012345 WHOLE MILK       1       65.00       65.00
BANANAS ORG #04          1       50.00       50.00
A893-X APPLE             1       80.00       80.00
SKU12345 BREAD           1       40.00       40.00

Total                                      325.00
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.items.length,
          5,
        );

        expect(
          result.items[0].title,
          'BANANAS ORG',
        );

        expect(
          result.items[1].title,
          'WHOLE MILK',
        );

        expect(
          result.items[2].title,
          'BANANAS ORG',
        );

        expect(
          result.items[3].title,
          'APPLE',
        );

        expect(
          result.items[4].title,
          'BREAD',
        );
      },
    );

    // ==============================================================
    // TEST 6
    // Standalone codes
    // ==============================================================

    test(
      'ignores standalone product codes',
      () {
        const text = '''
ABC STORE

04011
9012345
A893-X
12345678

Organic Bananas       120.00
Whole Milk             80.00
AA Batteries           250.00

Total                  450.00
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.items.length,
          3,
        );

        expect(
          result.items[0].title,
          'Organic Bananas',
        );

        expect(
          result.items[1].title,
          'Whole Milk',
        );

        expect(
          result.items[2].title,
          'AA Batteries',
        );
      },
    );

    // ==============================================================
    // TEST 7
    // Two-line item
    // ==============================================================

    test(
      'handles item name and price on separate lines',
      () {
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

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.title,
          'MY SHOP',
        );

        expect(
          result.items.length,
          2,
        );

        expect(
          result.items[0].title,
          'Milk',
        );

        expect(
          result.items[0].quantity,
          1,
        );

        expect(
          result.items[0].totalPrice,
          54.00,
        );

        expect(
          result.items[1].title,
          'Whole Wheat Bread',
        );

        expect(
          result.items[1].quantity,
          1,
        );

        expect(
          result.items[1].totalPrice,
          45.00,
        );

        expect(
          result.amount,
          99.00,
        );
      },
    );

    // ==============================================================
    // TEST 8
    // Metadata must not become products
    // ==============================================================

    test(
      'does not treat metadata as purchased items',
      () {
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

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.title,
          'ABC STORE',
        );

        expect(
          result.items.length,
          2,
        );

        expect(
          result.items
              .map((item) => item.title)
              .toList(),
          [
            'Notebook',
            'Pen',
          ],
        );

        expect(
          result.amount,
          73.50,
        );
      },
    );

    // ==============================================================
    // TEST 9
    // Currency
    // ==============================================================

    test(
      'handles currency symbols',
      () {
        const text = '''
MY SHOP

Coffee                 ₹120.00
Cake                   Rs. 250.00
Juice                  INR 80.00

Total                  ₹450.00
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.items.length,
          3,
        );

        expect(
          result.items[0].title,
          'Coffee',
        );

        expect(
          result.items[0].totalPrice,
          120.00,
        );

        expect(
          result.items[1].title,
          'Cake',
        );

        expect(
          result.items[1].totalPrice,
          250.00,
        );

        expect(
          result.items[2].title,
          'Juice',
        );

        expect(
          result.items[2].totalPrice,
          80.00,
        );

        expect(
          result.amount,
          450.00,
        );
      },
    );

    // ==============================================================
    // TEST 10
    // Item numbering
    // ==============================================================

    test(
      'removes item numbering',
      () {
        const text = '''
RESTAURANT

1. Pizza                 250.00
2. Burger                180.00
3. Coffee                 80.00

Total                    510.00
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.items.length,
          3,
        );

        expect(
          result.items[0].title,
          'Pizza',
        );

        expect(
          result.items[1].title,
          'Burger',
        );

        expect(
          result.items[2].title,
          'Coffee',
        );

        expect(
          result.amount,
          510.00,
        );
      },
    );

    // ==============================================================
    // TEST 11
    // Duplicate OCR lines
    // ==============================================================

    test(
      'removes duplicate OCR items',
      () {
        const text = '''
STORE

Milk             2        30.00        60.00
Milk             2        30.00        60.00

Total                                      60.00
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.items.length,
          1,
        );

        expect(
          result.items[0].title,
          'Milk',
        );

        expect(
          result.items[0].quantity,
          2,
        );

        expect(
          result.items[0].unitPrice,
          30.00,
        );

        expect(
          result.items[0].totalPrice,
          60.00,
        );
      },
    );

    // ==============================================================
    // TEST 12
    // Empty OCR
    // ==============================================================

    test(
      'handles empty OCR safely',
      () {
        const text = '';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.title,
          isNull,
        );

        expect(
          result.amount,
          isNull,
        );

        expect(
          result.items,
          isEmpty,
        );

        expect(
          result.rawText,
          isEmpty,
        );
      },
    );

    // ==============================================================
    // TEST 13
    // Raw OCR preserved
    // ==============================================================

    test(
      'preserves raw OCR text',
      () {
        const text = '''
MY STORE
Milk 50.00
Total 50.00
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.rawText,
          text,
        );
      },
    );

    // ==============================================================
    // TEST 14
    // Codes inside product names
    // ==============================================================

    test(
      'removes internal code tokens inside names',
      () {
        const text = '''
STORE

BANANAS A893-X ORG       1       60.00
MILK 04011               1       70.00
BREAD SKU12345           1       40.00

Total                          170.00
''';

        final result =
            ReceiptOcrService.parseRecognizedText(
          text,
        );

        expect(
          result.items.length,
          3,
        );

        expect(
          result.items[0].title,
          'BANANAS ORG',
        );

        expect(
          result.items[1].title,
          'MILK',
        );

        expect(
          result.items[2].title,
          'BREAD',
        );
      },
    );
  });
}