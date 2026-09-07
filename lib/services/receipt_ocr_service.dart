import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Receipt details inferred from text recognized by Google ML Kit.
class ReceiptScanResult {
  const ReceiptScanResult({this.amount, this.merchant, this.rawText = ''});

  final double? amount;
  final String? merchant;
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
      rawText: rawText,
    );
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
