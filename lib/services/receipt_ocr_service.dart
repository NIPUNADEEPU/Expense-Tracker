import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Receipt details inferred from text recognized by Google ML Kit.
class ReceiptScanResult {
  const ReceiptScanResult({this.amount, this.merchant, this.rawText = ''});

  final double? amount;

  /// Store / restaurant / business name.
  final String? title;

  String? get merchant => title;

  final List<ReceiptLineItem> items;

  /// Complete OCR text.
  final String rawText;

  /// Currency explicitly identified from the receipt.
  final TransactionCurrency currency;
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

  // ================================================================
  // OCR
  // ================================================================

  Future<ReceiptScanResult> scanImage(
    String imagePath,
  ) async {
    final recognizedText = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return parseRecognizedText(recognizedText.text);
  }

  Future<void> dispose() async {
    if (_ownsRecognizer) await _recognizer.close();
  }

  static ReceiptScanResult parseRecognizedText(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
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
      currency: _detectCurrency(rawText),
    );
  }

  // ================================================================
  // FIND LINE ITEMS
  // ================================================================

  static List<ReceiptLineItem> _findLineItems(List<String> lines) {
    final items = <ReceiptLineItem>[];

    if (lines.isEmpty) {
      return items;
    }

    final start = _findItemSectionStart(lines);

    final end = _findItemSectionEnd(lines, start);

    if (start >= end) {
      return items;
    }

    final candidateLines = lines.sublist(start, end);

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

      final tableItem = _parseReceiptTableItem(line);

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

      final simpleItem = _parseSimpleReceiptItem(line);

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
        final nextLine = candidateLines[i + 1];

        final price = _parseStandalonePrice(nextLine);

        if (price != null && _looksLikeProductName(line)) {
          final productName = _cleanProductName(line);

          if (_isValidProductName(productName)) {
            items.add(
              ReceiptLineItem(
                title: productName,
                quantity: 1,
                unitPrice: price,
                totalPrice: price,
                category: _categoryFor(productName),
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

  static int _findItemSectionStart(List<String> lines) {
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

      // Some OCR engines place a product name and its price on
      // separate lines. Treat that pair as the start of the item
      // section even when there is no explicit ITEM header.
      if (i + 1 < lines.length &&
          !_isInternalProductCode(lines[i + 1]) &&
          _parseStandalonePrice(lines[i + 1]) != null &&
          _looksLikeProductName(lines[i])) {
        return i;
      }
    }

    return lines.length;
  }

  // ================================================================
  // FIND END OF PURCHASE SECTION
  // ================================================================

  static int _findItemSectionEnd(List<String> lines, int start) {
    final endPattern = RegExp(
      r'^\s*(?:'
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

  static bool _looksLikePurchaseLine(String line) {
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

    final productPart = text.replaceFirst(pricePattern, '').trim();

    final productName = _cleanProductName(productPart);

    return _isValidProductName(productName);
  }

  // ================================================================
  // ADDRESS DETECTION
  // ================================================================

  static bool _looksLikeAddress(String text) {
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
    if (RegExp(r'^[A-Za-z .]+,\s*[A-Za-z .]+\s+\d{5,6}$').hasMatch(value)) {
      return true;
    }

    // Street address:
    //
    // 101 MAIN STREET
    // 123 MG ROAD
    // 45 PARK AVENUE
    //
    if (RegExp(
      r'^\s*(?:'
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

  static ReceiptLineItem? _parseReceiptTableItem(String line) {
    var text = line.trim();

    // Remove item numbering, such as "1." or "2)".
    text = text.replaceFirst(RegExp(r'^\s*\d+\s*[\.\)\-:]\s*'), '');

    // Normalize the currency text used by OCR and receipt fixtures.
    text = text
        .replaceAll('â‚¹', ' ')
        .replaceAll('â‚¬', ' ')
        .replaceAll('Â£', ' ')
        .replaceAll('₹', ' ')
        .replaceAll('€', ' ')
        .replaceAll('£', ' ')
        .replaceAll(RegExp(r'\b(?:Rs\.?|INR|USD)\b', caseSensitive: false), ' ')
        .replaceAll('\$', ' ')
        .trim();

    // Expected format after normalization:
    // Masala Dosa 1 149.00 149.00
    final pattern = RegExp(
      r'^(.+?)\s+'
      r'(\d+(?:\.\d+)?)\s+'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)\s+'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(text);

    if (match == null) {
      // Some tables omit a separate total column. In that format the
      // final two numbers are quantity and unit price.
      final withoutTotalPattern = RegExp(
        r'^(.+?)\s+'
        r'(\d+(?:\.\d+)?)\s+'
        r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
        caseSensitive: false,
      );
      final withoutTotal = withoutTotalPattern.firstMatch(text);

      if (withoutTotal != null) {
        final rawName = withoutTotal.group(1)!;
        final quantity = double.tryParse(withoutTotal.group(2)!);
        final unitPrice = double.tryParse(
          withoutTotal.group(3)!.replaceAll(',', ''),
        );
        final productName = _cleanProductName(rawName);

        if (quantity != null &&
            unitPrice != null &&
            quantity > 0 &&
            unitPrice > 0 &&
            _isValidProductName(productName)) {
          return ReceiptLineItem(
            title: productName,
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: quantity * unitPrice,
            category: _categoryFor(productName),
          );
        }
      }

      return _parseUsingColumns(text);
    }

    final rawName = match.group(1)!;

    final quantity = double.tryParse(match.group(2)!);

    final unitPrice = double.tryParse(match.group(3)!.replaceAll(',', ''));

    final totalPrice = double.tryParse(match.group(4)!.replaceAll(',', ''));

    if (quantity == null ||
        unitPrice == null ||
        totalPrice == null ||
        quantity <= 0 ||
        unitPrice < 0 ||
        totalPrice <= 0) {
      return null;
    }

    final productName = _cleanProductName(rawName);

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

  static ReceiptLineItem? _parseUsingColumns(String line) {
    final columns = line
        .split(RegExp(r'\s{2,}'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
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

    final totalIndex = numericIndexes.last;

    final unitIndex = numericIndexes[numericIndexes.length - 2];

    final quantityIndex = numericIndexes[numericIndexes.length - 3];

    final nameParts = columns.sublist(0, quantityIndex).join(' ');

    final productName = _cleanProductName(nameParts);

    final quantity = _parseNumber(columns[quantityIndex]);

    final unitPrice = _parseNumber(columns[unitIndex]);

    final total = _parseNumber(columns[totalIndex]);

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

  static ReceiptLineItem? _parseSimpleReceiptItem(String line) {
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

    final price = double.tryParse(match.group(2)!.replaceAll(',', ''));

    if (price == null || price <= 0) {
      return null;
    }

    final productName = _cleanProductName(rawName);

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

  static double? _parseStandalonePrice(String line) {
    final match = RegExp(
      r'^(?:₹|Rs\.?|INR|\$|USD|€|£)?\s*'
      r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)$',
      caseSensitive: false,
    ).firstMatch(line.trim());

    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  // ================================================================
  // PRODUCT NAME CLEANING
  // ================================================================

  static String _cleanProductName(String value) {
    var name = value.trim();

    // --------------------------------------------------------------
    // Remove item numbering.
    //
    // 1. Milk
    // 2) Bread
    // 3- Soap
    // --------------------------------------------------------------

    name = name.replaceFirst(RegExp(r'^\s*\d+\s*[\.\)\-:]\s*'), '');

    // --------------------------------------------------------------
    // Remove leading numeric product codes.
    //
    // 04011 BANANAS ORG
    // -> BANANAS ORG
    //
    // 9012345 WHOLE MILK
    // -> WHOLE MILK
    // --------------------------------------------------------------

    name = name.replaceFirst(RegExp(r'^\s*\d{4,12}\s+'), '');

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

    final tokens = name.split(RegExp(r'\s+'));

    final cleanedTokens = <String>[];

    for (final token in tokens) {
      final cleanToken = token.trim();

      if (cleanToken.isEmpty) {
        continue;
      }

      if (_isInternalProductCode(cleanToken)) {
        continue;
      }

      cleanedTokens.add(cleanToken);
    }

    name = cleanedTokens.join(' ');

    // Remove unwanted surrounding symbols.
    name = name.replaceAll(RegExp(r'^[\s\-_:|]+'), '');

    name = name.replaceAll(RegExp(r'[\s\-_:|]+$'), '');

    // Normalize whitespace.
    name = name.replaceAll(RegExp(r'\s+'), ' ');

    return name.trim();
  }

  // ================================================================
  // INTERNAL PRODUCT CODE
  // ================================================================

  static bool _isInternalProductCode(String token) {
    var value = token.trim();

    value = value.replaceAll(RegExp(r'^[#.,:;]+|[#.,:;]+$'), '');

    if (value.isEmpty) {
      return false;
    }

    // Pure numeric codes.
    //
    // 04011
    // 9012345
    // 12345678
    //
    if (RegExp(r'^\d{4,12}$').hasMatch(value)) {
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
    if (RegExp(r'^[A-Z]{1,4}\d{3,}$', caseSensitive: false).hasMatch(value)) {
      return true;
    }

    return false;
  }

  // ================================================================
  // CODE-ONLY LINE
  // ================================================================

  static bool _isCodeOnlyLine(String line) {
    final value = line.trim();

    if (value.isEmpty) {
      return true;
    }

    // Only numbers.
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return true;
    }

    // Numbers and symbols only.
    if (RegExp(r'^[\d\s\-_/.,:#*]+$').hasMatch(value)) {
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

  static bool _looksLikeProductName(String line) {
    final value = line.trim();

    if (value.isEmpty ||
        value.contains(':') ||
        _isCodeOnlyLine(value) ||
        _looksLikeAddress(value) ||
        _looksLikeMetadata(value)) {
      return false;
    }

    return _isValidProductName(_cleanProductName(value));
  }

  static bool _isValidProductName(String name) {
    if (name.length < 2) {
      return false;
    }

    // Product must contain letters.
    if (!RegExp(r'[A-Za-z]').hasMatch(name)) {
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

  static bool _isNonItemLine(String line) {
    if (_isCodeOnlyLine(line)) {
      return true;
    }

    if (_looksLikeMetadata(line)) {
      return true;
    }

    if (RegExp(
      r'^\s*(?:'
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

  static bool _looksLikeMetadata(String text) {
    return RegExp(
      r'^\s*(?:'
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
      r')(?:\s*(?:[:#]|no\.?\b)|\s+\d|$)',
      caseSensitive: false,
    ).hasMatch(text.trim());
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

    final limit = lines.length < 12 ? lines.length : 12;

    for (var i = 0; i < limit; i++) {
      final line = lines[i].trim();

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

    // Combine:
    //
    // FRESH MART
    // SUPERMARKET
    //
    // -> FRESH MART SUPERMARKET

    final combineLimit = lines.length < 12 ? lines.length - 1 : 11;

    for (var i = 0; i < combineLimit; i++) {
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

  static double? _findTotal(List<String> lines) {
    final totalLabel = RegExp(
      r'\b(?:grand\s*total|amount\s*due|net\s*amount|total)\b',
      caseSensitive: false,
    );
    for (final line in lines.reversed) {
      if (!totalLabel.hasMatch(line)) continue;
      final amounts = _amountsIn(line);
      if (amounts.isNotEmpty) return amounts.last;
    }
    return null;
  }

  // ================================================================
  // AMOUNTS
  // ================================================================

  static List<double> _amountsIn(String text) {
    final matches = RegExp(
      r'(?:₹|Rs\.?|INR|\$|USD)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+(?:\.\d{2}))',
      caseSensitive: false,
    ).allMatches(text);
    return matches
        .map((match) => double.tryParse(match.group(1)!.replaceAll(',', '')))
        .whereType<double>()
        .where((amount) => amount > 0)
        .toList();
  }

  static String? _findMerchant(List<String> lines) {
    for (final line in lines.take(4)) {
      final isLikelyMerchant =
          line.length >= 3 &&
          !RegExp(
            r'\d{3,}|invoice|receipt|tax|gst|phone|date',
            caseSensitive: false,
          ).hasMatch(line);
      if (isLikelyMerchant) return line;
    }
    return null;
  }
}
