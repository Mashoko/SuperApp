import 'package:flutter_contacts/flutter_contacts.dart';

/// Sorts [contacts] alphabetically by display name (case-insensitive) and
/// groups them by uppercased first letter, for section-header rendering.
/// Pure and side-effect-free so it's testable without a live
/// device-contacts call.
Map<String, List<Contact>> groupContactsByLetter(List<Contact> contacts) {
  final sorted = [...contacts]
    ..sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

  final grouped = <String, List<Contact>>{};
  for (final contact in sorted) {
    final letter =
        contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '#';
    grouped.putIfAbsent(letter, () => []).add(contact);
  }
  return grouped;
}
