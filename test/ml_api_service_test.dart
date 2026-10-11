import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:expense_tracker/services/ml_api_service.dart';

import 'package:expense_tracker/models/category.dart';

void main() {
  test('ML API returns a category', () async {
    final mockClient = MockClient((http.Request request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/predict');

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['description'], 'dove shampoo');

      return http.Response(
        jsonEncode({'category': 'Personal Care', 'confidence': 0.70}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = MlApiService(client: mockClient);

    final result = await service.predictCategory('dove shampoo');

    expect(result, isNotNull);
    expect(result!.category, 'Personal Care');
    expect(result.confidence, 0.70);

    mockClient.close();
  });

  test('Prediction labels are mapped to known SpendSense categories', () {
    expect(
      MlApiService.categoryFromPrediction('Personal Care'),
      ExpenseCategory.personalCare,
    );
    expect(
      MlApiService.categoryFromPrediction('personal_care'),
      ExpenseCategory.personalCare,
    );
    expect(MlApiService.categoryFromPrediction('Food'), ExpenseCategory.food);
    expect(
      MlApiService.categoryFromPrediction('travel'),
      ExpenseCategory.travel,
    );
    expect(
      MlApiService.categoryFromPrediction('shopping'),
      ExpenseCategory.shopping,
    );
    expect(MlApiService.categoryFromPrediction('Unknown'), isNull);
  });
}
