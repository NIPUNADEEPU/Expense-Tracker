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
  // Android emulator -> computer's localhost
  static const String _baseUrl = 'http://10.0.2.2:8000';

  final http.Client _client;

  MlApiService({http.Client? client})
      : _client = client ?? http.Client();

  Future<MlPrediction?> predictCategory(String description) async {
    final trimmedDescription = description.trim();

    if (trimmedDescription.isEmpty) {
      return null;
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'description': trimmedDescription,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
  'ML API error: ${response.statusCode} ${response.body}',
);
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return MlPrediction(
        category: data['category'] as String,
        confidence: (data['confidence'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('ML API connection error: $e');
      return null;
    }
  }
}