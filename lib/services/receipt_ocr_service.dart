import '../models/category.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A purchasable line detected on a receipt. The category is a best-effort
/// suggestion and is always editable before it is saved.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.title,
    required this.amount,
    required this.category,
  });

  final String title;
  final double amount;
  final ExpenseCategory category;

  ReceiptLineItem copyWith({ExpenseCategory? category}) {
    return ReceiptLineItem(
      title: title,
      amount: amount,
      category: category ?? this.category,
    );
  }
}

/// Receipt details inferred from text recognized by Google ML Kit.
class ReceiptScanResult {
  const ReceiptScanResult({
    this.amount,
    this.merchant,
    this.items = const [],
    this.rawText = '',
  });

  final double? amount;
  final String? merchant;
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

  Future<ReceiptScanResult> scanImage(String imagePath) async {
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
    final amount = _findTotal(lines) ?? _findLargestAmount(rawText);
    final merchant = _findMerchant(lines);
    return ReceiptScanResult(
      amount: amount,
      merchant: merchant,
      items: _findLineItems(lines),
      rawText: rawText,
    );
  }

  static List<ReceiptLineItem> _findLineItems(List<String> lines) {
    final items = <ReceiptLineItem>[];
    final itemPattern = RegExp(
      r'^(.+?)\s+(?:₹|Rs\.?|INR|\$|USD)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+(?:\.\d{2}))$',
      caseSensitive: false,
    );
    final excluded = RegExp(
      r'\b(?:grand\s*total|sub\s*total|total|amount\s*due|net\s*amount|tax|gst|vat|discount|change|cash|card|upi|invoice|date|phone)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (excluded.hasMatch(line)) continue;
      final match = itemPattern.firstMatch(line);
      if (match == null) continue;
      final title = match
          .group(1)!
          .replaceFirst(RegExp(r'^\d+\s*[xX]\s*'), '')
          .trim();
      final amount = double.tryParse(match.group(2)!.replaceAll(',', ''));
      if (title.length < 2 || amount == null || amount <= 0) continue;
      items.add(
        ReceiptLineItem(
          title: title,
          amount: amount,
          category: _categoryFor(title),
        ),
      );
    }
    return items;
  }

  static ExpenseCategory _categoryFor(String title) {
    final text = title.toLowerCase();
    if (RegExp(
      r'food|milk|bread|rice|vegetable|fruit|grocery|coffee|tea|meal|pizza|burger|snack|restaurant',
    ).hasMatch(text)) {
      return ExpenseCategory.food;
    }
    if (RegExp(
      r'petrol|diesel|fuel|taxi|uber|ola|metro|bus|train|parking',
    ).hasMatch(text)) {
      return ExpenseCategory.transport;
    }
    if (RegExp(
      r'electricity|water|gas|internet|wifi|mobile|recharge|phone',
    ).hasMatch(text)) {
      return ExpenseCategory.utilities;
    }
    if (RegExp(r'movie|cinema|game|netflix|spotify|concert').hasMatch(text)) {
      return ExpenseCategory.entertainment;
    }
    if (RegExp(
      r'shirt|shoe|dress|bag|cosmetic|clothing|stationery',
    ).hasMatch(text)) {
      return ExpenseCategory.shopping;
    }
    return ExpenseCategory.other;
  }

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

  static double? _findLargestAmount(String text) {
    final amounts = _amountsIn(text);
    if (amounts.isEmpty) return null;
    return amounts.reduce((current, next) => next > current ? next : current);
  }

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
