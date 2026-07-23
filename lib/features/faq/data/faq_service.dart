import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../help_support/data/faq_data.dart';

class FaqFetchResult {
  const FaqFetchResult({required this.categories, required this.ok});
  final List<FaqCategory> categories;
  final bool ok;
}

class FaqService {
  FaqService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _base = 'https://superapp-diht.onrender.com/api';

  Future<FaqFetchResult> fetchFaqs() async {
    try {
      final uri = Uri.parse('$_base/faqs');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as List;
        final categories = decoded
            .map((e) => FaqCategory.fromJson(e as Map<String, dynamic>))
            .toList();
        return FaqFetchResult(categories: categories, ok: true);
      }
      return const FaqFetchResult(categories: [], ok: false);
    } catch (_) {
      return const FaqFetchResult(categories: [], ok: false);
    }
  }
}
