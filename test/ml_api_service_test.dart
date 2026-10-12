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
    expect(
      MlApiService.categoryFromPrediction('  PERSONAL   CARE  '),
      ExpenseCategory.personalCare,
    );
    expect(
      MlApiService.categoryFromPrediction('home-improvement'),
      ExpenseCategory.home,
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
    expect(MlApiService.categoryFromPrediction('Bills'), ExpenseCategory.bills);
    expect(
      MlApiService.categoryFromPrediction('Entertainment'),
      ExpenseCategory.entertainment,
    );
    expect(MlApiService.categoryFromPrediction('Home'), ExpenseCategory.home);
    expect(
      MlApiService.categoryFromPrediction('Financial'),
      ExpenseCategory.financial,
    );
  });

  test('valid API responses map each supported category', () async {
    const cases = <String, ExpenseCategory>{
      'Food': ExpenseCategory.food,
      'Shopping': ExpenseCategory.shopping,
      'Travel': ExpenseCategory.travel,
      'Bills': ExpenseCategory.bills,
      'Home': ExpenseCategory.home,
      'Personal Care': ExpenseCategory.personalCare,
      'Financial': ExpenseCategory.financial,
      'Entertainment': ExpenseCategory.entertainment,
    };

    for (final entry in cases.entries) {
      final client = MockClient((request) async {
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['description'], 'receipt item description');
        return http.Response(
          jsonEncode({'category': entry.key, 'confidence': 0.74}),
          200,
        );
      });
      final service = MlApiService(client: client);
      final prediction = await service.predictCategory(
        ' receipt item description ',
      );

      expect(prediction, isNotNull);
      expect(
        MlApiService.resolveCategory(prediction),
        entry.value,
        reason: entry.key,
      );
      client.close();
    }
  });

  test('malformed prediction responses are rejected', () async {
    final bodies = <String>[
      '{"category":"Food"}',
      '{"category":42,"confidence":0.8}',
      '{"category":"Food","confidence":"high"}',
      'not json',
    ];

    for (final body in bodies) {
      final client = MockClient((_) async => http.Response(body, 200));
      final service = MlApiService(client: client);
      expect(await service.predictCategory('coffee'), isNull, reason: body);
      client.close();
    }
  });

  test('failed or unsupported prediction preserves an existing category', () {
    expect(
      MlApiService.resolveCategory(
        null,
        existingCategory: ExpenseCategory.food,
      ),
      ExpenseCategory.food,
    );
    expect(
      MlApiService.resolveCategory(
        const MlPrediction(category: 'Unknown', confidence: 0.8),
        existingCategory: ExpenseCategory.shopping,
      ),
      ExpenseCategory.shopping,
    );
    expect(
      MlApiService.resolveCategory(
        null,
        existingCategory: ExpenseCategory.uncategorized,
      ),
      ExpenseCategory.uncategorized,
    );
    expect(MlApiService.resolveCategory(null), isNull);
  });

  test(
    'returns null on API failure so caller can preserve review category',
    () async {
      final mockClient = MockClient(
        (_) async => http.Response('unavailable', 503),
      );
      final service = MlApiService(client: mockClient);

      expect(await service.predictCategory('organic apples'), isNull);
      mockClient.close();
    },
  );
}
