import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

// The colour scheme of WunzaTheme.darkTheme / lightTheme. The full themes
// load Inter through google_fonts, which fetches over the network in tests.
ColorScheme _appScheme(Brightness b) => ColorScheme.fromSeed(
      seedColor: WunzaColors.glidePrimary,
      primary: b == Brightness.dark ? const Color(0xFFCE93D8) : null,
      surface: b == Brightness.dark ? const Color(0xFF1E1E2E) : null,
      error: WunzaColors.error,
      brightness: b,
    );

void main() {
  for (final b in Brightness.values) {
    test('error text meets 4.5:1 on the surface (${b.name})', () {
      final base = ThemeData(useMaterial3: true, colorScheme: _appScheme(b));
      final theme = kycTheme(base);
      final surface = theme.colorScheme.surface;
      expect(_contrast(theme.colorScheme.error, surface),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(theme.inputDecorationTheme.errorStyle!.color!, surface),
          greaterThanOrEqualTo(4.5));
    });
  }

  test('a readable error colour is kept as is', () {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    expect(kycTheme(base).colorScheme.error, base.colorScheme.error);
  });
}
