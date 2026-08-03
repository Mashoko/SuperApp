import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/contacts/data/utils/contact_grouping.dart';

void main() {
  group('groupContactsByLetter', () {
    test('sorts case-insensitively and groups by first letter', () {
      final contacts = [
        Contact(displayName: 'bob'),
        Contact(displayName: 'Alice'),
        Contact(displayName: 'anna'),
        Contact(displayName: 'Charlie'),
      ];

      final grouped = groupContactsByLetter(contacts);

      expect(grouped.keys.toList(), ['A', 'B', 'C']);
      expect(grouped['A']!.map((c) => c.displayName), ['Alice', 'anna']);
      expect(grouped['B']!.map((c) => c.displayName), ['bob']);
      expect(grouped['C']!.map((c) => c.displayName), ['Charlie']);
    });

    test('groups an empty displayName under "#"', () {
      final contacts = [Contact(displayName: '')];
      final grouped = groupContactsByLetter(contacts);
      expect(grouped.keys.toList(), ['#']);
    });

    test('returns an empty map for an empty list', () {
      expect(groupContactsByLetter(const []), isEmpty);
    });
  });
}
