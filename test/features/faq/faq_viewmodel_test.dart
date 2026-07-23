import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mvvm_sip_demo/features/faq/data/faq_service.dart';
import 'package:mvvm_sip_demo/features/faq/presentation/viewmodels/faq_viewmodel.dart';
import 'package:mvvm_sip_demo/features/help_support/data/faq_data.dart';

class _FakeFaqService implements FaqService {
  _FakeFaqService(this.result);
  final FaqFetchResult result;

  @override
  Future<FaqFetchResult> fetchFaqs() async => result;
}

const _sampleCategory = FaqCategory(
  title: 'Payments',
  items: [FaqItem('Why is my payment pending?', 'Because reasons.')],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with no categories and not loading', () {
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [], ok: true)));
    expect(vm.categories, isEmpty);
    expect(vm.loading, isFalse);
  });

  test('loadCached does nothing when no cache exists', () async {
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [], ok: true)));
    await vm.loadCached();
    expect(vm.categories, isEmpty);
  });

  test('loadCached populates categories from a prior cache', () async {
    SharedPreferences.setMockInitialValues({
      'faq_cache_v1': json.encode([_sampleCategory.toJson()]),
    });
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [], ok: true)));
    await vm.loadCached();
    expect(vm.categories, hasLength(1));
    expect(vm.categories.first.title, 'Payments');
  });

  test('refresh on success updates categories and writes the cache', () async {
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [_sampleCategory], ok: true)));
    await vm.refresh();

    expect(vm.categories, hasLength(1));
    expect(vm.loading, isFalse);

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('faq_cache_v1');
    expect(cached, isNotNull);
    expect(json.decode(cached!), hasLength(1));
  });

  test('refresh on failure leaves previously-cached categories untouched', () async {
    SharedPreferences.setMockInitialValues({
      'faq_cache_v1': json.encode([_sampleCategory.toJson()]),
    });
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [], ok: false)));
    await vm.loadCached();
    expect(vm.categories, hasLength(1));

    await vm.refresh();
    expect(vm.categories, hasLength(1));
  });

  test('notifies listeners on refresh', () async {
    final vm = FaqViewModel(_FakeFaqService(const FaqFetchResult(categories: [_sampleCategory], ok: true)));
    var notified = 0;
    vm.addListener(() => notified++);
    await vm.refresh();
    expect(notified, greaterThan(0));
  });
}
