import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/category.dart';

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.title,
    required this.totalPrice,
    required this.category,
    this.quantity,
    this.unitPrice,
  });

  final String title;
  final double? quantity;
  final double? unitPrice;
  final double totalPrice;
  final ExpenseCategory category;

  double get amount => totalPrice;

  ReceiptLineItem copyWith({
    ExpenseCategory? category,
  }) {
    return ReceiptLineItem(
      title: title,
      totalPrice: totalPrice,
      category: category ?? this.category,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }
}

class ReceiptScanResult {
  const ReceiptScanResult({
    this.amount,
    this.title,
    this.items = const [],
    this.rawText = '',
  });

  final double? amount;

  /// Store / restaurant / business name.
  final String? title;

  String? get merchant => title;

  final List<ReceiptLineItem> items;

  /// Complete OCR text.
  final String rawText;
}

class ReceiptOcrService {
  ReceiptOcrService({
    TextRecognizer? recognizer,
  })  : _recognizer = recognizer ??
            TextRecognizer(
              script: TextRecognitionScript.latin,
            ),
        _ownsRecognizer = recognizer == null;

  final TextRecognizer _recognizer;
  final bool _ownsRecognizer;

  // ================================================================
  // OCR
  // ================================================================

  Future<ReceiptScanResult> scanImage(
    String imagePath,
  ) async {
    final recognizedText = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );

    final visualText = _textInVisualRows(
      recognizedText,
    );

    return parseRecognizedText(
      visualText,
    );
  }

  Future<void> dispose() async {
    if (_ownsRecognizer) {
      await _recognizer.close();
    }
  }

  // ================================================================
  // REBUILD OCR TEXT USING VISUAL POSITION
  // ================================================================

  static String _textInVisualRows(
    RecognizedText recognizedText,
  ) {
    final lines = recognizedText.blocks
        .expand(
          (block) => block.lines,
        )
        .where(
          (line) => line.text.trim().isNotEmpty,
        )
        .toList()
      ..sort(
        (a, b) => a.boundingBox.top.compareTo(
          b.boundingBox.top,
        ),
      );

    if (lines.isEmpty) {
      return recognizedText.text;
    }

    final rows = <List<TextLine>>[];

    for (final line in lines) {
      final centerY =
          line.boundingBox.top +
          line.boundingBox.height / 2;

      List<TextLine>? matchingRow;

      for (final row in rows) {
        final reference = row.first;

        final referenceCenterY =
            reference.boundingBox.top +
            reference.boundingBox.height / 2;

        final tolerance =
            (reference.boundingBox.height >
                    line.boundingBox.height
                ? reference.boundingBox.height
                : line.boundingBox.height) *
            0.65;

        if ((centerY - referenceCenterY).abs() <=
            tolerance) {
          matchingRow = row;
          break;
        }
      }

      final row = matchingRow ?? <TextLine>[];

      if (matchingRow == null) {
        rows.add(row);
      }

      row.add(line);
    }

    return rows.map((row) {
      row.sort(
        (a, b) => a.boundingBox.left.compareTo(
          b.boundingBox.left,
        ),
      );

      return row
          .map(
            (line) => line.text.trim(),
          )
          .join('   ');
    }).join('\n');
  }

  // ================================================================
  // MAIN PARSER
  // ================================================================

  static ReceiptScanResult parseRecognizedText(
    String rawText,
  ) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map(_normalizeLine)
        .where(
          (line) => line.isNotEmpty,
        )
        .toList();

    final merchant = _findMerchant(lines);

    final items = _findLineItems(lines);

    final total =
        _findTotal(lines) ??
        _calculateTotalFromItems(items) ??
        _findLargestReasonableAmount(lines);

    return ReceiptScanResult(
      amount: total,
      title: merchant,
      items: items,
      rawText: rawText,
    );
  }

  // ================================================================
  // FIND LINE ITEMS
  // ================================================================

  static List<ReceiptLineItem> _findLineItems(
    List<String> lines,
  ) {
    final items = <ReceiptLineItem>[];

    if (lines.isEmpty) {
      return items;
    }

    final start = _findItemSectionStart(lines);

    final end = _findItemSectionEnd(
      lines,
      start,
    );

    if (start >= end) {
      return items;
    }

    final candidateLines = lines.sublist(
      start,
      end,
    );

    for (var i = 0; i < candidateLines.length; i++) {
      final line = candidateLines[i].trim();

      if (line.isEmpty) {
        continue;
      }

      // Ignore code-only lines.
      if (_isCodeOnlyLine(line)) {
        continue;
      }

      // Ignore metadata / totals / payment.
      if (_isNonItemLine(line)) {
        continue;
      }

      // ------------------------------------------------------------
      // TABLE FORMAT
      //
      // ITEM       QTY       PRICE       TOTAL
      // Milk        2        30.00       60.00
      // ------------------------------------------------------------

      final tableItem =
          _parseReceiptTableItem(line);

      if (tableItem != null) {
        items.add(tableItem);
        continue;
      }

      // ------------------------------------------------------------
      // SIMPLE FORMAT
      //
      // Milk                         60.00
      // Bread                        40.00
      // ------------------------------------------------------------

      final simpleItem =
          _parseSimpleReceiptItem(line);

      if (simpleItem != null) {
        items.add(simpleItem);
        continue;
      }

      // ------------------------------------------------------------
      // TWO-LINE FORMAT
      //
      // Milk
      // 60.00
      // ------------------------------------------------------------

      if (i + 1 < candidateLines.length) {
        final nextLine =
            candidateLines[i + 1];

        final price =
            _parseStandalonePrice(nextLine);

        if (price != null &&
            _looksLikeProductName(line)) {
          final productName =
              _cleanProductName(line);

          if (_isValidProductName(productName)) {
            items.add(
              ReceiptLineItem(
                title: productName,
                quantity: 1,
                unitPrice: price,
                totalPrice: price,
                category: _categoryFor(
                  productName,
                ),
              ),
            );

            i++;
          }
        }
      }
    }

    return _removeDuplicateItems(items);
  }

  // ================================================================
  // FIND START OF PURCHASE SECTION
  // ================================================================

  static int _findItemSectionStart(
    List<String> lines,
  ) {
    // Receipts with an explicit item header.
    final header = RegExp(
      r'^\s*(?:'
      r'item|items|'
      r'product|products|'
      r'description|'
      r'particulars|'
      r'details'
      r')\b',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      if (header.hasMatch(lines[i])) {
        return i + 1;
      }
    }

    // Receipts without an ITEM header.
    //
    // Find the first line that is strongly identified
    // as a purchase line.
    for (var i = 0; i < lines.length; i++) {
      if (_looksLikePurchaseLine(lines[i])) {
        return i;
      }
    }

    return lines.length;
  }

  // ================================================================
  // FIND END OF PURCHASE SECTION
  // ================================================================

  static int _findItemSectionEnd(
    List<String> lines,
    int start,
  ) {
    final endPattern = RegExp(
      r'\b(?:'
      r'subtotal|'
      r'sub\s*total|'
      r'grand\s*total|'
      r'total|'
      r'amount\s*due|'
      r'net\s*amount|'
      r'final\s*amount|'
      r'payable|'
      r'balance\s*due|'
      r'tax|'
      r'gst|'
      r'cgst|'
      r'sgst|'
      r'vat|'
      r'discount|'
      r'round(?:ing)?|'
      r'change|'
      r'balance|'
      r'payment|'
      r'paid'
      r')\b',
      caseSensitive: false,
    );

    for (var i = start; i < lines.length; i++) {
      if (endPattern.hasMatch(lines[i])) {
        return i;
      }
    }

    return lines.length;
  }

  // ================================================================
  // DETERMINE WHETHER A LINE IS A PURCHASE
  // ================================================================

  static bool _looksLikePurchaseLine(
    String line,
  ) {
    final text = line.trim();

    if (text.isEmpty) {
      return false;
    }

    // Pure codes / numbers are never products.
    if (_isCodeOnlyLine(text)) {
      return false;
    }

    // Metadata is never a product.
    if (_looksLikeMetadata(text)) {
      return false;
    }

    if (_isNonItemLine(text)) {
      return false;
    }

    // Key rule:
    //
    // Receipt metadata commonly uses:
    //
    // ID: 004
    // CARD: **** 4411
    // TYPE: VISA
    //
    // A product line generally does not.
    if (text.contains(':')) {
      return false;
    }

    // Addresses are not purchases.
    if (_looksLikeAddress(text)) {
      return false;
    }

    // A purchase line must end with a price.
    final pricePattern = RegExp(
      r'(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'\d+(?:,\d{3})*(?:\.\d{1,2})?\s*$',
      caseSensitive: false,
    );

    if (!pricePattern.hasMatch(text)) {
      return false;
    }

    final productPart = text.replaceFirst(
      pricePattern,
      '',
    ).trim();

    final productName =
        _cleanProductName(productPart);

    return _isValidProductName(productName);
  }

  // ================================================================
  // ADDRESS DETECTION
  // ================================================================

  static bool _looksLikeAddress(
    String text,
  ) {
    final value = text.trim();

    // US address:
    //
    // SPRINGFIELD, IL 62701
    //
    if (RegExp(
      r'^[A-Za-z .]+,\s*[A-Z]{2}\s+\d{5}(?:-\d{4})?$',
    ).hasMatch(value)) {
      return true;
    }

    // Indian address:
    //
    // Bengaluru, Karnataka 560001
    //
    if (RegExp(
      r'^[A-Za-z .]+,\s*[A-Za-z .]+\s+\d{5,6}$',
    ).hasMatch(value)) {
      return true;
    }

    // Street address:
    //
    // 101 MAIN STREET
    // 123 MG ROAD
    // 45 PARK AVENUE
    //
    if (RegExp(
      r'\b(?:'
      r'street|st\.|'
      r'road|rd\.|'
      r'avenue|ave\.|'
      r'lane|ln\.|'
      r'parkway|pkwy\.|'
      r'highway|hwy\.|'
      r'block|'
      r'main\s+street'
      r')\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }

    return false;
  }

  // ================================================================
  // TABLE ITEM
  // ================================================================

  static ReceiptLineItem? _parseReceiptTableItem(
    String line,
  ) {
    var text = line.trim();

    // Remove numbering.
    text = text.replaceFirst(
      RegExp(
        r'^\s*\d+\s*[\.\)\-:]\s*',
      ),
      '',
    );

    final pattern = RegExp(
      r'^(.+?)\s+'
      r'(\d+(?:\.\d+)?)\s+'
      r'(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)\s+'
      r'(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(text);

    if (match == null) {
      return _parseUsingColumns(text);
    }

    final rawName = match.group(1)!;

    final quantity =
        double.tryParse(match.group(2)!);

    final unitPrice = double.tryParse(
      match.group(3)!.replaceAll(',', ''),
    );

    final totalPrice = double.tryParse(
      match.group(4)!.replaceAll(',', ''),
    );

    if (quantity == null ||
        unitPrice == null ||
        totalPrice == null) {
      return null;
    }

    if (quantity <= 0 ||
        totalPrice <= 0) {
      return null;
    }

    final productName =
        _cleanProductName(rawName);

    if (!_isValidProductName(productName)) {
      return null;
    }

    return ReceiptLineItem(
      title: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      category: _categoryFor(productName),
    );
  }

  // ================================================================
  // COLUMN-BASED TABLE
  // ================================================================

  static ReceiptLineItem? _parseUsingColumns(
    String line,
  ) {
    final columns = line
        .split(RegExp(r'\s{2,}'))
        .map(
          (value) => value.trim(),
        )
        .where(
          (value) => value.isNotEmpty,
        )
        .toList();

    if (columns.length < 3) {
      return null;
    }

    final numericIndexes = <int>[];

    for (var i = 0; i < columns.length; i++) {
      if (_parseNumber(columns[i]) != null) {
        numericIndexes.add(i);
      }
    }

    if (numericIndexes.length < 3) {
      return null;
    }

    final totalIndex =
        numericIndexes.last;

    final unitIndex =
        numericIndexes[
          numericIndexes.length - 2
        ];

    final quantityIndex =
        numericIndexes[
          numericIndexes.length - 3
        ];

    final nameParts = columns
        .sublist(0, quantityIndex)
        .join(' ');

    final productName =
        _cleanProductName(nameParts);

    final quantity =
        _parseNumber(
      columns[quantityIndex],
    );

    final unitPrice =
        _parseNumber(
      columns[unitIndex],
    );

    final total =
        _parseNumber(
      columns[totalIndex],
    );

    if (!_isValidProductName(productName)) {
      return null;
    }

    if (quantity == null ||
        unitPrice == null ||
        total == null ||
        quantity <= 0 ||
        total <= 0) {
      return null;
    }

    return ReceiptLineItem(
      title: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: total,
      category: _categoryFor(productName),
    );
  }

  // ================================================================
  // SIMPLE PRODUCT + PRICE
  // ================================================================

  static ReceiptLineItem? _parseSimpleReceiptItem(
    String line,
  ) {
    // This is the important additional protection.
    if (!_looksLikePurchaseLine(line)) {
      return null;
    }

    final pattern = RegExp(
      r'^(.+?)\s+'
      r'(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(line);

    if (match == null) {
      return null;
    }

    final rawName = match.group(1)!;

    final price = double.tryParse(
      match.group(2)!.replaceAll(',', ''),
    );

    if (price == null || price <= 0) {
      return null;
    }

    final productName =
        _cleanProductName(rawName);

    if (!_isValidProductName(productName)) {
      return null;
    }

    if (_looksLikeMetadata(productName)) {
      return null;
    }

    return ReceiptLineItem(
      title: productName,
      quantity: 1,
      unitPrice: price,
      totalPrice: price,
      category: _categoryFor(productName),
    );
  }

  // ================================================================
  // TWO-LINE PRICE
  // ================================================================

  static double? _parseStandalonePrice(
    String line,
  ) {
    final match = RegExp(
      r'^(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
      caseSensitive: false,
    ).firstMatch(line.trim());

    if (match == null) {
      return null;
    }

    return double.tryParse(
      match.group(1)!.replaceAll(',', ''),
    );
  }

  // ================================================================
  // PRODUCT NAME CLEANING
  // ================================================================

  static String _cleanProductName(
    String value,
  ) {
    var name = value.trim();

    // --------------------------------------------------------------
    // Remove item numbering.
    //
    // 1. Milk
    // 2) Bread
    // 3- Soap
    // --------------------------------------------------------------

    name = name.replaceFirst(
      RegExp(
        r'^\s*\d+\s*[\.\)\-:]\s*',
      ),
      '',
    );

    // --------------------------------------------------------------
    // Remove leading numeric product codes.
    //
    // 04011 BANANAS ORG
    // -> BANANAS ORG
    //
    // 9012345 WHOLE MILK
    // -> WHOLE MILK
    // --------------------------------------------------------------

    name = name.replaceFirst(
      RegExp(
        r'^\s*\d{4,12}\s+',
      ),
      '',
    );

    // --------------------------------------------------------------
    // Remove labeled codes.
    //
    // SKU12345 BANANAS
    // PLU 4011 BANANAS
    // CODE-A893 BANANAS
    // --------------------------------------------------------------

    name = name.replaceFirst(
      RegExp(
        r'^\s*(?:SKU|PLU|CODE|ITEM\s*CODE)'
        r'[\s:#\-]*[A-Za-z0-9\-_]+'
        r'\s+',
        caseSensitive: false,
      ),
      '',
    );

    // --------------------------------------------------------------
    // Remove trailing #CODE.
    //
    // BANANAS ORG #04
    // -> BANANAS ORG
    // --------------------------------------------------------------

    name = name.replaceFirst(
      RegExp(
        r'\s+#\s*'
        r'[A-Za-z0-9]+'
        r'(?:[-_][A-Za-z0-9]+)*\s*$',
      ),
      '',
    );

    // --------------------------------------------------------------
    // Remove internal code tokens.
    // --------------------------------------------------------------

    final tokens =
        name.split(RegExp(r'\s+'));

    final cleanedTokens = <String>[];

    for (final token in tokens) {
      final cleanToken = token.trim();

      if (cleanToken.isEmpty) {
        continue;
      }

      if (_isInternalProductCode(
        cleanToken,
      )) {
        continue;
      }

      cleanedTokens.add(cleanToken);
    }

    name = cleanedTokens.join(' ');

    // Remove unwanted surrounding symbols.
    name = name.replaceAll(
      RegExp(r'^[\s\-_:|]+'),
      '',
    );

    name = name.replaceAll(
      RegExp(r'[\s\-_:|]+$'),
      '',
    );

    // Normalize whitespace.
    name = name.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return name.trim();
  }

  // ================================================================
  // INTERNAL PRODUCT CODE
  // ================================================================

  static bool _isInternalProductCode(
    String token,
  ) {
    var value = token.trim();

    value = value.replaceAll(
      RegExp(
        r'^[#.,:;]+|[#.,:;]+$',
      ),
      '',
    );

    if (value.isEmpty) {
      return false;
    }

    // Pure numeric codes.
    //
    // 04011
    // 9012345
    // 12345678
    //
    if (RegExp(
      r'^\d{4,12}$',
    ).hasMatch(value)) {
      return true;
    }

    // SKU / PLU / CODE.
    if (RegExp(
      r'^(?:SKU|PLU|CODE)[A-Z0-9_-]*$',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }

    // A893-X
    // ABC-12345
    if (RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)'
      r'[A-Za-z0-9]+'
      r'(?:[-_][A-Za-z0-9]+)+$',
    ).hasMatch(value)) {
      return true;
    }

    // A893
    // AB12345
    if (RegExp(
      r'^[A-Z]{1,4}\d{3,}$',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }

    return false;
  }

  // ================================================================
  // CODE-ONLY LINE
  // ================================================================

  static bool _isCodeOnlyLine(
    String line,
  ) {
    final value = line.trim();

    if (value.isEmpty) {
      return true;
    }

    // Only numbers.
    if (RegExp(
      r'^\d+$',
    ).hasMatch(value)) {
      return true;
    }

    // Numbers and symbols only.
    if (RegExp(
      r'^[\d\s\-_/.,:#*]+$',
    ).hasMatch(value)) {
      return true;
    }

    // Long barcode-like number.
    final digitsOnly =
        value.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (digitsOnly.length >= 8 &&
        RegExp(r'^\d+$')
            .hasMatch(digitsOnly)) {
      return true;
    }

    if (_isInternalProductCode(value)) {
      return true;
    }

    return false;
  }

  // ================================================================
  // PRODUCT NAME VALIDATION
  // ================================================================

  static bool _looksLikeProductName(
    String line,
  ) {
    final value = line.trim();

    if (value.isEmpty ||
        value.contains(':') ||
        _isCodeOnlyLine(value) ||
        _looksLikeAddress(value) ||
        _looksLikeMetadata(value)) {
      return false;
    }

    return _isValidProductName(
      _cleanProductName(value),
    );
  }

  static bool _isValidProductName(
    String name,
  ) {
    if (name.length < 2) {
      return false;
    }

    // Product must contain letters.
    if (!RegExp(
      r'[A-Za-z]',
    ).hasMatch(name)) {
      return false;
    }

    // Reject headers.
    if (RegExp(
      r'^(?:'
      r'item|items|'
      r'product|products|'
      r'description|'
      r'particulars|'
      r'details|'
      r'qty|quantity|'
      r'unit|price|amount|total'
      r')$',
      caseSensitive: false,
    ).hasMatch(name.trim())) {
      return false;
    }

    // Reject codes.
    if (_isCodeOnlyLine(name)) {
      return false;
    }

    // Reject metadata.
    if (_looksLikeMetadata(name)) {
      return false;
    }

    return true;
  }

  // ================================================================
  // NON-ITEM LINE
  // ================================================================

  static bool _isNonItemLine(
    String line,
  ) {
    if (_isCodeOnlyLine(line)) {
      return true;
    }

    if (_looksLikeMetadata(line)) {
      return true;
    }

    if (RegExp(
      r'\b(?:'
      r'subtotal|'
      r'sub\s*total|'
      r'grand\s*total|'
      r'total|'
      r'amount\s*due|'
      r'net\s*amount|'
      r'final\s*amount|'
      r'tax|'
      r'gst|'
      r'cgst|'
      r'sgst|'
      r'vat|'
      r'discount|'
      r'round(?:ing)?|'
      r'payment|'
      r'paid|'
      r'tender|'
      r'cash|'
      r'card|'
      r'upi|'
      r'change|'
      r'balance|'
      r'thank\s+you|'
      r'visit\s+again'
      r')\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    return false;
  }

  // ================================================================
  // METADATA
  // ================================================================

  static bool _looksLikeMetadata(
    String text,
  ) {
    return RegExp(
      r'\b(?:'
      r'id|'
      r'address|'
      r'phone|ph|tel|mobile|'
      r'date|time|'
      r'invoice|invoice\s*no|'
      r'bill|bill\s*no|'
      r'receipt|receipt\s*no|'
      r'cashier|manager|operator|'
      r'gstin|gst|cgst|sgst|vat|'
      r'txn|transaction|'
      r'reference|ref|'
      r'customer|'
      r'order|'
      r'table|'
      r'token|'
      r'register|'
      r'card|'
      r'type|'
      r'entry|'
      r'status|'
      r'payment'
      r')\b',
      caseSensitive: false,
    ).hasMatch(text.trim());
  }

  // ================================================================
  // MERCHANT / STORE NAME
  // ================================================================

  static String? _findMerchant(
    List<String> lines,
  ) {
    if (lines.isEmpty) {
      return null;
    }

    final ignored = RegExp(
      r'\b(?:'
      r'address|road|rd|street|st|'
      r'avenue|ave|lane|nagar|'
      r'city|pincode|pin|'
      r'phone|ph\.?|mobile|tel|'
      r'date|time|'
      r'gstin|gst|vat|'
      r'invoice|invoice\s*no|'
      r'bill|bill\s*no|'
      r'receipt|'
      r'cashier|manager|operator|'
      r'customer|order|table|token|'
      r'id|register'
      r')\b',
      caseSensitive: false,
    );

    final genericHeading = RegExp(
      r'^(?:'
      r'cash\s+receipt|'
      r'receipt|'
      r'bill|'
      r'invoice|'
      r'tax\s+invoice'
      r')$',
      caseSensitive: false,
    );

    final candidates = <String>[];

    final limit =
        lines.length < 12
            ? lines.length
            : 12;

    for (var i = 0; i < limit; i++) {
      final line = lines[i].trim();

      if (line.length < 3) {
        continue;
      }

      if (!RegExp(
        r'[A-Za-z]',
      ).hasMatch(line)) {
        continue;
      }

      if (ignored.hasMatch(line)) {
        continue;
      }

      if (genericHeading.hasMatch(line)) {
        continue;
      }

      if (_looksLikeSlogan(line)) {
        continue;
      }

      candidates.add(line);
    }

    if (candidates.isEmpty) {
      return null;
    }

    // Combine:
    //
    // FRESH MART
    // SUPERMARKET
    //
    // -> FRESH MART SUPERMARKET

    final combineLimit =
        lines.length < 12
            ? lines.length - 1
            : 11;

    for (var i = 0;
        i < combineLimit;
        i++) {
      final first = lines[i];
      final second = lines[i + 1];

      if (!_isPotentialMerchant(first)) {
        continue;
      }

      if (_isBusinessType(second)) {
        return '$first $second';
      }
    }

    return candidates.first;
  }

  // ================================================================
  // BUSINESS TYPE
  // ================================================================

  static bool _isBusinessType(
    String value,
  ) {
    final normalized =
        value.toLowerCase().trim();

    return RegExp(
      r'^(?:'
      r'supermarket|'
      r'market|'
      r'store|'
      r'shop|'
      r'restaurant|'
      r'cafe|'
      r'cafeteria|'
      r'bakery|'
      r'pharmacy|'
      r'mart|'
      r'clinic|'
      r'hotel|'
      r'fashion|'
      r'clothing|'
      r'electronics|'
      r'salon|'
      r'spa|'
      r'fuel\s+station|'
      r'petrol\s+pump'
      r')$',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  static bool _isPotentialMerchant(
    String line,
  ) {
    if (line.length < 3) {
      return false;
    }

    if (!RegExp(
      r'[A-Za-z]',
    ).hasMatch(line)) {
      return false;
    }

    if (_isNonItemLine(line)) {
      return false;
    }

    if (_looksLikeMetadata(line)) {
      return false;
    }

    return true;
  }

  // ================================================================
  // TOTAL DETECTION
  // ================================================================

  static double? _findTotal(
    List<String> lines,
  ) {
    final totalLabels = RegExp(
      r'\b(?:'
      r'grand\s*total|'
      r'total\s*amount|'
      r'amount\s*due|'
      r'net\s*amount|'
      r'final\s*amount|'
      r'payable|'
      r'balance\s*due|'
      r'total'
      r')\b',
      caseSensitive: false,
    );

    for (var i = lines.length - 1;
        i >= 0;
        i--) {
      final line = lines[i];

      if (!totalLabels.hasMatch(line)) {
        continue;
      }

      final amounts =
          _amountsIn(line);

      if (amounts.isNotEmpty) {
        return amounts.last;
      }

      // Handles:
      //
      // TOTAL
      // 707.70

      if (i + 1 < lines.length) {
        final nextAmount =
            _parseStandalonePrice(
          lines[i + 1],
        );

        if (nextAmount != null) {
          return nextAmount;
        }
      }
    }

    return null;
  }

  // ================================================================
  // AMOUNTS
  // ================================================================

  static List<double> _amountsIn(
    String text,
  ) {
    return RegExp(
      r'(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})|'
      r'\d+(?:\.\d{2}))',
      caseSensitive: false,
    )
        .allMatches(text)
        .map(
          (match) => double.tryParse(
            match
                .group(1)!
                .replaceAll(',', ''),
          ),
        )
        .whereType<double>()
        .where(
          (value) => value > 0,
        )
        .toList();
  }

  // ================================================================
  // FALLBACK TOTAL
  // ================================================================

  static double? _findLargestReasonableAmount(
    List<String> lines,
  ) {
    final values = <double>[];

    for (final line in lines) {
      if (_isNonItemLine(line)) {
        continue;
      }

      values.addAll(
        _amountsIn(line),
      );
    }

    if (values.isEmpty) {
      return null;
    }

    values.sort();

    return values.last;
  }

  // ================================================================
  // CALCULATE TOTAL FROM ITEMS
  // ================================================================

  static double? _calculateTotalFromItems(
    List<ReceiptLineItem> items,
  ) {
    if (items.isEmpty) {
      return null;
    }

    final total = items.fold<double>(
      0,
      (sum, item) =>
          sum + item.totalPrice,
    );

    return total > 0 ? total : null;
  }

  // ================================================================
  // REMOVE DUPLICATES
  // ================================================================

  static List<ReceiptLineItem> _removeDuplicateItems(
    List<ReceiptLineItem> items,
  ) {
    final seen = <String>{};
    final result = <ReceiptLineItem>[];

    for (final item in items) {
      final key =
          '${item.title.toLowerCase()}|'
          '${item.quantity}|'
          '${item.unitPrice}|'
          '${item.totalPrice}';

      if (seen.add(key)) {
        result.add(item);
      }
    }

    return result;
  }

  // ================================================================
  // NORMALIZE OCR LINE
  // ================================================================

  static String _normalizeLine(
    String line,
  ) {
    return line
        .replaceAll(
          RegExp(r'[|]'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  // ================================================================
  // SLOGAN DETECTION
  // ================================================================

  static bool _looksLikeSlogan(
    String line,
  ) {
    return RegExp(
      r'\b(?:'
      r'good\s+food|'
      r'great\s+memories|'
      r'thank\s+you|'
      r'visit\s+again|'
      r'welcome|'
      r'enjoy\s+your|'
      r'come\s+again'
      r')\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  // ================================================================
  // NUMBER PARSER
  // ================================================================

  static double? _parseNumber(
    String value,
  ) {
    final match = RegExp(
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
    ).firstMatch(value);

    if (match == null) {
      return null;
    }

    return double.tryParse(
      match
          .group(1)!
          .replaceAll(',', ''),
    );
  }

  // ================================================================
  // FALLBACK CATEGORY
  // ================================================================

  static ExpenseCategory _categoryFor(
    String title,
  ) {
    final text =
        title.toLowerCase();

    if (RegExp(
      r'food|milk|bread|rice|vegetable|'
      r'fruit|grocery|coffee|tea|meal|'
      r'pizza|burger|snack|restaurant|'
      r'dosa|paneer|jamun',
    ).hasMatch(text)) {
      return ExpenseCategory.food;
    }

    if (RegExp(
      r'petrol|diesel|fuel|taxi|uber|ola|'
      r'metro|bus|train|parking',
    ).hasMatch(text)) {
      return ExpenseCategory.transport;
    }

    if (RegExp(
      r'electricity|water|gas|internet|wifi|'
      r'mobile|recharge|phone',
    ).hasMatch(text)) {
      return ExpenseCategory.utilities;
    }

    if (RegExp(
      r'movie|cinema|game|netflix|spotify|concert',
    ).hasMatch(text)) {
      return ExpenseCategory.entertainment;
    }

    if (RegExp(
      r'shirt|shoe|dress|bag|cosmetic|'
      r'clothing|stationery|soap',
    ).hasMatch(text)) {
      return ExpenseCategory.shopping;
    }

    return ExpenseCategory.other;
  }
}