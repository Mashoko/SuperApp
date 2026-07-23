import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mvvm_sip_demo/features/faq/data/faq_service.dart';

Map<String, dynamic> _categoryJson() => {
      'title': 'Payments',
      'items': [
        {'question': 'Why is my payment pending?', 'answer': 'It can take up to 24 hours.'},
      ],
    };

void main() {
  group('fetchFaqs', () {
    test('parses a successful response into FaqCategory list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/faqs');
        return http.Response(json.encode([_categoryJson()]), 200);
      });

      final service = FaqService(client: mockClient);
      final result = await service.fetchFaqs();

      expect(result.ok, isTrue);
      expect(result.categories, hasLength(1));
      expect(result.categories.first.title, 'Payments');
      expect(result.categories.first.items.first.question, 'Why is my payment pending?');
    });

    test('returns ok:false with an empty list on a non-200 response', () async {
      final mockClient = MockClient((request) async => http.Response('error', 500));
      final service = FaqService(client: mockClient);

      final result = await service.fetchFaqs();

      expect(result.ok, isFalse);
      expect(result.categories, isEmpty);
    });

    test('returns ok:false with an empty list when the request throws', () async {
      final mockClient = MockClient((request) async => throw Exception('network down'));
      final service = FaqService(client: mockClient);

      final result = await service.fetchFaqs();

      expect(result.ok, isFalse);
      expect(result.categories, isEmpty);
    });
  });
}
