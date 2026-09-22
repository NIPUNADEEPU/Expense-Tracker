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

  ReceiptLineItem copyWith({ExpenseCategory? category}) {
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

  /// Merchant/store/restaurant name.
  final String? title;

  String? get merchant => title;

  final List<ReceiptLineItem> items;
  final String rawText;
}

class ReceiptOcrService {
  ReceiptOcrService({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
      _ownsRecognizer = recognizer == null;

  final TextRecognizer _recognizer;
  final bool _ownsRecognizer;

  // ================================================================
  // PUBLIC OCR METHOD
  // ================================================================

  Future<ReceiptScanResult> scanImage(String imagePath) async {
    final recognizedText = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );

    final visualText = _textInVisualRows(recognizedText);

    return parseRecognizedText(visualText);
  }

  Future<void> dispose() async {
    if (_ownsRecognizer) {
      await _recognizer.close();
    }
  }

  // ================================================================
  // REBUILD OCR INTO VISUAL ROWS
  // ================================================================
  //
  // ML Kit can return:
  //
  // ITEM BLOCK       QTY BLOCK       PRICE BLOCK       TOTAL BLOCK
  //
  // as separate blocks.
  //
  // This method reconstructs them according to their Y and X
  // positions so that a receipt table becomes one logical row.
  //
  // ================================================================

  static String _textInVisualRows(RecognizedText recognizedText) {
    final lines =
        recognizedText.blocks
            .expand((block) => block.lines)
            .where((line) => line.text.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    if (lines.isEmpty) {
      return recognizedText.text;
    }

    final rows = <List<TextLine>>[];

    for (final line in lines) {
      final centerY = line.boundingBox.top + line.boundingBox.height / 2;

      List<TextLine>? matchingRow;

      for (final row in rows) {
        final reference = row.first;

        final referenceCenterY =
            reference.boundingBox.top + reference.boundingBox.height / 2;

        final tolerance =
            (reference.boundingBox.height > line.boundingBox.height
                ? reference.boundingBox.height
                : line.boundingBox.height) *
            0.65;

        if ((centerY - referenceCenterY).abs() <= tolerance) {
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

    return rows
        .map((row) {
          row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

          return row.map((line) => line.text.trim()).join('   ');
        })
        .join('\n');
  }

  // ================================================================
  // MAIN PARSER
  // ================================================================

  static ReceiptScanResult parseRecognizedText(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList();

    final merchant = _findMerchant(lines);

    final items = _findLineItems(lines);

    final total =
        _findTotal(lines) ??
        _findLargestReasonableAmount(lines) ??
        _calculateTotalFromItems(items);

    return ReceiptScanResult(
      amount: total,
      title: merchant,
      items: items,
      rawText: rawText,
    );
  }

  // ================================================================
  // ITEM EXTRACTION
  // ================================================================

  static List<ReceiptLineItem> _findLineItems(List<String> lines) {
    if (lines.isEmpty) {
      return [];
    }

    final result = <ReceiptLineItem>[];

    // Find where the item section probably begins.
    final itemStart = _findItemSectionStart(lines);

    // Find where the item section ends.
    final itemEnd = _findItemSectionEnd(lines, itemStart);

    final candidateLines = lines.sublist(itemStart, itemEnd);

    for (var i = 0; i < candidateLines.length; i++) {
      final line = candidateLines[i];

      if (_isClearlyNonItem(line)) {
        continue;
      }

      // ------------------------------------------------------------
      // FORMAT 1
      //
      // Item        Qty      Unit Price      Total
      //
      // Milk         2         30.00         60.00
      //
      // ------------------------------------------------------------

      final table = _parseTableRow(line);

      if (table != null) {
        result.add(table);
        continue;
      }

      // ------------------------------------------------------------
      // FORMAT 2
      //
      // Item                    Total
      //
      // Bread                   40.00
      //
      // ------------------------------------------------------------

      final simple = _parseSimpleItem(line);

      if (simple != null) {
        result.add(simple);
        continue;
      }

      // ------------------------------------------------------------
      // FORMAT 3
      //
      // Item
      // 40.00
      //
      // Some OCR engines separate the item and price.
      // ------------------------------------------------------------

      if (i + 1 < candidateLines.length) {
        final nextLine = candidateLines[i + 1];

        final amount = _parseStandaloneAmount(nextLine);

        if (amount != null &&
            !_isClearlyNonItem(line) &&
            _looksLikeItemName(line)) {
          result.add(
            ReceiptLineItem(
              title: _cleanItemName(line),
              quantity: 1,
              unitPrice: amount,
              totalPrice: amount,
              category: _categoryFor(_cleanItemName(line)),
            ),
          );

          i++;
        }
      }
    }

    return _removeDuplicateItems(result);
  }

  // ================================================================
  // FIND ITEM SECTION START
  // ================================================================

  static int _findItemSectionStart(List<String> lines) {
    final itemHeader = RegExp(
      r'\b(?:item|items|description|product|'
      r'particulars|details)\b',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      if (itemHeader.hasMatch(lines[i])) {
        return i + 1;
      }
    }

    // No item header.
    //
    // Many simple receipts have:
    //
    // STORE
    // ADDRESS
    // PHONE
    // DATE
    // ----------------
    // Item 10.00
    //
    // Start after obvious metadata.
    for (var i = 0; i < lines.length; i++) {
      if (_looksLikeItem(lines[i])) {
        return i;
      }
    }

    return 0;
  }

  // ================================================================
  // FIND ITEM SECTION END
  // ================================================================

  static int _findItemSectionEnd(List<String> lines, int start) {
    final endPattern = RegExp(
      r'\b(?:'
      r'subtotal|sub\s*total|'
      r'grand\s*total|'
      r'total|'
      r'amount\s*due|'
      r'net\s*amount|'
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
      r'payment\s*mode|'
      r'payment\s*status|'
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
  // PARSE TABLE ROW
  // ================================================================

  static ReceiptLineItem? _parseTableRow(String line) {
    var cleaned = line.trim();

    // Remove item numbering.
    cleaned = cleaned.replaceFirst(RegExp(r'^\s*\d+\s*[\.\)\-:]\s*'), '');

    // ------------------------------------------------------------
    // Pattern:
    //
    // Name   Qty   Price   Amount
    //
    // ------------------------------------------------------------

    final pattern = RegExp(
      r'^(.+?)\s+'
      r'(\d+(?:\.\d+)?)\s+'
      r'(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)\s+'
      r'(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(cleaned);

    if (match == null) {
      return _parseUsingColumns(cleaned);
    }

    final name = _cleanItemName(match.group(1)!);

    final quantity = double.tryParse(match.group(2)!);

    final unitPrice = double.tryParse(match.group(3)!.replaceAll(',', ''));

    final total = double.tryParse(match.group(4)!.replaceAll(',', ''));

    if (!_isValidItemName(name)) {
      return null;
    }

    if (quantity == null || unitPrice == null || total == null || total <= 0) {
      return null;
    }

    return ReceiptLineItem(
      title: name,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: total,
      category: _categoryFor(name),
    );
  }

  // ================================================================
  // PARSE COLUMN-BASED OCR
  // ================================================================

  static ReceiptLineItem? _parseUsingColumns(String line) {
    final columns = line
        .split(RegExp(r'\s{2,}'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (columns.length < 3) {
      return null;
    }

    // Look for the last three numeric columns.
    final numericIndexes = <int>[];

    for (var i = 0; i < columns.length; i++) {
      if (_parseNumber(columns[i]) != null) {
        numericIndexes.add(i);
      }
    }

    if (numericIndexes.length < 3) {
      return null;
    }

    final totalIndex = numericIndexes[numericIndexes.length - 1];

    final unitIndex = numericIndexes[numericIndexes.length - 2];

    final qtyIndex = numericIndexes[numericIndexes.length - 3];

    final nameParts = columns.sublist(0, qtyIndex).join(' ');

    final name = _cleanItemName(nameParts);

    final quantity = _parseNumber(columns[qtyIndex]);

    final unitPrice = _parseNumber(columns[unitIndex]);

    final total = _parseNumber(columns[totalIndex]);

    if (!_isValidItemName(name)) {
      return null;
    }

    if (quantity == null || unitPrice == null || total == null || total <= 0) {
      return null;
    }

    return ReceiptLineItem(
      title: name,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: total,
      category: _categoryFor(name),
    );
  }

  // ================================================================
  // SIMPLE ITEM
  // ================================================================

  static ReceiptLineItem? _parseSimpleItem(String line) {
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

    final name = _cleanItemName(match.group(1)!);

    final amount = double.tryParse(match.group(2)!.replaceAll(',', ''));

    if (!_isValidItemName(name)) {
      return null;
    }

    if (amount == null || amount <= 0) {
      return null;
    }

    if (_looksLikeMetadata(name)) {
      return null;
    }

    return ReceiptLineItem(
      title: name,
      quantity: 1,
      unitPrice: amount,
      totalPrice: amount,
      category: _categoryFor(name),
    );
  }

  // ================================================================
  // STANDALONE AMOUNT
  // ================================================================

  /// Parses an isolated receipt number, optionally prefixed by a currency
  /// marker that may have been altered by OCR encoding.
  static double? _parseNumber(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9,.]'), '').trim();
    if (!RegExp(r'^\d+(?:,\d{3})*(?:\.\d{1,2})?$').hasMatch(normalized)) {
      return null;
    }
    return double.tryParse(normalized.replaceAll(',', ''));
  }

  static double? _parseStandaloneAmount(String line) {
    final cleaned = line.trim();

    final match = RegExp(
      r'^(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  // ================================================================
  // MERCHANT / STORE NAME
  // ================================================================

  static String? _findMerchant(List<String> lines) {
    if (lines.isEmpty) {
      return null;
    }

    final ignored = RegExp(
      r'\b(?:'
      r'address|road|rd|street|st|avenue|ave|lane|'
      r'nagar|city|pincode|pin|'
      r'phone|ph\.?|mobile|tel|'
      r'date|time|'
      r'gstin|gst|vat|'
      r'invoice|invoice\s*no|'
      r'bill|bill\s*no|'
      r'receipt|'
      r'cashier|manager|operator|'
      r'customer|order|table|token'
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

    final limit = lines.length < 12 ? lines.length : 12;

    for (var i = 0; i < limit; i++) {
      final line = lines[i];

      if (line.length < 3) {
        continue;
      }

      if (!RegExp(r'[A-Za-z]').hasMatch(line)) {
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

    // ------------------------------------------------------------
    // Combine a business name with a generic business type.
    //
    // Example:
    //
    // FRESH MART
    // SUPERMARKET
    //
    // becomes:
    //
    // FRESH MART SUPERMARKET
    //
    // This is generic — no store name is hardcoded.
    // ------------------------------------------------------------

    if (lines.length >= 2) {
      for (var i = 0; i < limit - 1; i++) {
        final first = lines[i];
        final second = lines[i + 1];

        if (!_isPotentialMerchant(first)) {
          continue;
        }

        if (_isBusinessType(second)) {
          return '$first $second';
        }
      }
    }

    return candidates.first;
  }

  // ================================================================
  // BUSINESS TYPE
  // ================================================================

  static bool _isBusinessType(String value) {
    final normalized = value.toLowerCase().trim();

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

  static bool _isPotentialMerchant(String line) {
    if (line.length < 3) {
      return false;
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(line)) {
      return false;
    }

    if (_isClearlyNonItem(line)) {
      return false;
    }

    if (_looksLikeMetadata(line)) {
      return false;
    }

    return true;
  }

  // ================================================================
  // ITEM NAME VALIDATION
  // ================================================================

  static bool _isValidItemName(String name) {
    if (name.length < 2) {
      return false;
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(name)) {
      return false;
    }

    final normalized = name.toLowerCase().trim();

    if (RegExp(
      r'^(?:'
      r'item|items|description|product|'
      r'particulars|details|'
      r'qty|quantity|unit|price|amount|total'
      r')$',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return false;
    }

    return true;
  }

  // ================================================================
  // NON-ITEM DETECTION
  // ================================================================

  static bool _isClearlyNonItem(String line) {
    if (line.trim().isEmpty) {
      return true;
    }

    // Separators.
    if (RegExp(r'^[-_=.*•:]+$').hasMatch(line.trim())) {
      return true;
    }

    // Barcode / long numeric strings.
    if (RegExp(r'^\s*\d{8,}\s*$').hasMatch(line)) {
      return true;
    }

    if (_looksLikeMetadata(line)) {
      return true;
    }

    final excluded = RegExp(
      r'\b(?:'
      r'subtotal|sub\s*total|'
      r'grand\s*total|'
      r'total|'
      r'amount\s*due|'
      r'net\s*amount|'
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
      r'paid|'
      r'tender|'
      r'cash|'
      r'card|'
      r'upi|'
      r'visit\s+again|'
      r'thank\s+you|'
      r'welcome|'
      r'loyalty|'
      r'points|'
      r'saving'
      r')\b',
      caseSensitive: false,
    );

    return excluded.hasMatch(line);
  }

  // ================================================================
  // METADATA DETECTION
  // ================================================================

  static bool _looksLikeMetadata(String text) {
    return RegExp(
      r'^(?:'
      r'phone|ph|tel|mobile|'
      r'date|time|'
      r'invoice|invoice\s*no|'
      r'bill|bill\s*no|'
      r'receipt|receipt\s*no|'
      r'cashier|manager|operator|'
      r'gstin|gst|vat|'
      r'txn|transaction|'
      r'reference|ref|'
      r'customer|'
      r'payment|'
      r'order|'
      r'table|'
      r'token'
      r')\b',
      caseSensitive: false,
    ).hasMatch(text.trim());
  }

  // ================================================================
  // LOOKS LIKE ITEM
  // ================================================================

  static bool _looksLikeItem(String line) {
    if (_isClearlyNonItem(line)) {
      return false;
    }

    if (!_looksLikeItemName(_removeTrailingAmount(line))) {
      return false;
    }

    return true;
  }

  static bool _looksLikeItemName(String text) {
    final name = _cleanItemName(text);

    if (!_isValidItemName(name)) {
      return false;
    }

    if (_looksLikeMetadata(name)) {
      return false;
    }

    return true;
  }

  static String _removeTrailingAmount(String line) {
    return line.replaceFirst(
      RegExp(
        r'\s+(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
        r'\d+(?:,\d{3})*(?:\.\d{1,2})?$',
        caseSensitive: false,
      ),
      '',
    );
  }

  // ================================================================
  // CLEAN ITEM NAME
  // ================================================================

  static String _cleanItemName(String value) {
    var name = value.trim();

    // Remove numbering:
    //
    // 1. Rice
    // 2) Milk
    // 3- Bread
    //
    name = name.replaceFirst(RegExp(r'^\s*\d+\s*[\.\)\-:]\s*'), '');

    // Remove leading currency symbol.
    name = name.replaceFirst(RegExp(r'^[₹$€£]\s*'), '');

    // Normalize whitespace.
    name = name.replaceAll(RegExp(r'\s+'), ' ');

    return name.trim();
  }

  // ================================================================
  // TOTAL DETECTION
  // ================================================================

  static double? _findTotal(List<String> lines) {
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

    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];

      if (!totalLabels.hasMatch(line)) {
        continue;
      }

      final amounts = _amountsIn(line);

      if (amounts.isNotEmpty) {
        return amounts.last;
      }

      // Sometimes OCR separates:
      //
      // TOTAL
      // 707.70
      //
      if (i + 1 < lines.length) {
        final nextAmount = _parseStandaloneAmount(lines[i + 1]);

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

  static List<double> _amountsIn(String text) {
    return RegExp(
          r'(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
          r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+(?:\.\d{2}))',
          caseSensitive: false,
        )
        .allMatches(text)
        .map((match) => double.tryParse(match.group(1)!.replaceAll(',', '')))
        .whereType<double>()
        .where((value) => value > 0)
        .toList();
  }

  // ================================================================
  // FALLBACK TOTAL
  // ================================================================

  static double? _findLargestReasonableAmount(List<String> lines) {
    final values = <double>[];

    for (final line in lines) {
      if (_isClearlyNonItem(line)) {
        continue;
      }

      for (final value in _amountsIn(line)) {
        values.add(value);
      }
    }

    if (values.isEmpty) {
      return null;
    }

    values.sort();

    return values.last;
  }

  // ================================================================
  // CALCULATE FROM ITEMS
  // ================================================================

  static double? _calculateTotalFromItems(List<ReceiptLineItem> items) {
    if (items.isEmpty) {
      return null;
    }

    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);

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

  static String _normalizeLine(String line) {
    return line
        .replaceAll(RegExp(r'[|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ================================================================
  // SLOGAN DETECTION
  // ================================================================

  static bool _looksLikeSlogan(String line) {
    final text = line.toLowerCase();

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
    ).hasMatch(text);
  }

  // ================================================================
  // CATEGORY
  // ================================================================
  //
  // Your teammates can later replace this with the ML classifier.
  //
  // ================================================================

  static ExpenseCategory _categoryFor(String title) {
    final text = title.toLowerCase();

    if (RegExp(
      r'food|milk|bread|rice|vegetable|fruit|'
      r'grocery|coffee|tea|meal|pizza|burger|'
      r'snack|restaurant|dosa|paneer|jamun',
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

    if (RegExp(r'movie|cinema|game|netflix|spotify|concert').hasMatch(text)) {
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
