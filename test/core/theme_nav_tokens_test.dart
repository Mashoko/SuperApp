import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

void main() {
  test('nav token colors match the glass-bottom-nav design spec', () {
    expect(WunzaColors.navBgDark, const Color(0xFF0B0B0E));
    expect(WunzaColors.navBgLight, const Color(0xFFF2F1EE));
    expect(WunzaColors.navGlassDark, const Color(0x801E1E24));
    expect(WunzaColors.navGlassLight, const Color(0x8CFFFFFF));
    expect(WunzaColors.navIndicator, const Color(0xFF9B8CFF));
    expect(WunzaColors.padGradientStart, const Color(0xFFFF7A45));
    expect(WunzaColors.padGradientEnd, const Color(0xFFFF4D6D));
  });
}
