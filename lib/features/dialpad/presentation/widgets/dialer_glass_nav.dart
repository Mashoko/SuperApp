import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

/// The 3-tab floating glass nav bar shown at the bottom of the redesigned
/// dialer sheet: Recents, Contacts, Market Place.
///
/// This is deliberately a separate, smaller widget from Home's own
/// `GlassBottomNav` — that widget assumes exactly 4 tabs plus a centered
/// dial-PAD button (see its own doc comment), which doesn't fit this
/// screen (already inside the dialer; no PAD needed). Both widgets share
/// the same [WunzaColors] tokens for visual consistency.
class DialerGlassNav extends StatelessWidget {
  const DialerGlassNav({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onMarketPlaceTap,
  });

  /// 0 = Recents, 1 = Contacts.
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onMarketPlaceTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      decoration: BoxDecoration(
        color: WunzaColors.navGlassDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Row(
          children: [
            Expanded(
              child: _NavTabButton(
                icon: Icons.access_time_outlined,
                activeIcon: Icons.access_time_filled,
                label: 'Recents',
                isActive: activeIndex == 0,
                onTap: () => onTabSelected(0),
              ),
            ),
            Expanded(
              child: _NavTabButton(
                icon: Icons.contacts_outlined,
                activeIcon: Icons.contacts,
                label: 'Contacts',
                isActive: activeIndex == 1,
                onTap: () => onTabSelected(1),
              ),
            ),
            Expanded(
              child: _NavTabButton(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront,
                label: 'Market Place',
                isActive: false,
                onTap: onMarketPlaceTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? WunzaColors.dialerNavActive : Colors.white54;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
