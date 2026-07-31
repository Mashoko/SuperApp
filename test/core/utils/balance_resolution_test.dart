import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/utils/balance_resolution.dart';

void main() {
  group('resolveOnFetch', () {
    test('returns the new value on success', () {
      final result = resolveOnFetch<double?>(previous: 10.0, ok: true, onSuccess: 25.0);
      expect(result, 25.0);
    });

    test('preserves the previous value on failure', () {
      final result = resolveOnFetch<double?>(previous: 10.0, ok: false, onSuccess: 25.0);
      expect(result, 10.0);
    });

    test('works with non-nullable String values (Dialpad-style balance text)', () {
      expect(resolveOnFetch<String>(previous: '\$5.00', ok: true, onSuccess: '\$7.50'), '\$7.50');
      expect(resolveOnFetch<String>(previous: '\$5.00', ok: false, onSuccess: '\$7.50'), '\$5.00');
    });

    test('preserves null when nothing has ever loaded and the fetch fails', () {
      final result = resolveOnFetch<double?>(previous: null, ok: false, onSuccess: 25.0);
      expect(result, isNull);
    });
  });
}
