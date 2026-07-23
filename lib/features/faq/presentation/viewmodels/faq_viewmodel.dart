import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../help_support/data/faq_data.dart';
import '../../data/faq_service.dart';

class FaqViewModel extends ChangeNotifier {
  FaqViewModel(this._service);

  final FaqService _service;
  static const _cacheKey = 'faq_cache_v1';

  List<FaqCategory> _categories = [];
  List<FaqCategory> get categories => _categories;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return;
    try {
      final decoded = json.decode(cached) as List;
      _categories = decoded
          .map((e) => FaqCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {
      await prefs.remove(_cacheKey);
    }
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    final result = await _service.fetchFaqs();
    if (result.ok) {
      _categories = result.categories;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        json.encode(_categories.map((c) => c.toJson()).toList()),
      );
    }
    _loading = false;
    notifyListeners();
  }
}
