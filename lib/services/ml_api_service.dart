import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

class MlPrediction {
  final String category;
  final double confidence;

  const MlPrediction({
    required this.category,
    required this.confidence,
  });
}

class MlApiService {
  // Android emulator -> computer localhost: 10.0.2.2
  // Physical Android device -> use your PC's LAN IP, for example:
  // flutter run --dart-define=ML_API_BASE_URL=http://192.168.1.12:8000
 static const String _baseUrl = String.fromEnvironment(
  'ML_API_BASE_URL',
  defaultValue: 'http://192.168.1.9:8000',
);

  final http.Client _client;
  final Duration _timeout;

  MlApiService({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 4);

  Future<MlPrediction?> predictCategory(String description) async {
    final trimmedDescription = description.trim();

    if (trimmedDescription.isEmpty) {
      return null;
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/predict'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'description': trimmedDescription,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('ML API error: ${response.statusCode} ${response.body}');
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final category = decoded['category'];
      final confidence = decoded['confidence'];

      if (category is! String || confidence is! num) {
        return null;
      }

      return MlPrediction(
        category: category,
        confidence: confidence.toDouble(),
      );
    } on TimeoutException {
      debugPrint('ML API timed out after $_timeout for: $trimmedDescription');
      return null;
    } catch (e) {
      debugPrint('ML API connection error: $e');
      return null;
    }
  }
}