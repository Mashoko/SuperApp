import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/scale_tap_wrapper.dart';
import 'package:mvvm_sip_demo/shared/widgets/glide_card.dart';
import 'package:mvvm_sip_demo/shared/widgets/maintenance_screen.dart';

/// The services grid, embedded inside the Home tab's scroll view (it used
/// to be its own full-screen tab — see the glass-bottom-nav design spec for
/// why it moved).
class ServicesGridSection extends StatelessWidget {
  const ServicesGridSection({super.key});

  static const _items = <_ServiceItem>[
    _ServiceItem(
      icon: Icons.call_outlined,
      label: 'Calling',
      subtitle: 'Contacts & dialer',
      color: WunzaColors.glidePrimary,
      route: Routes.calling,
    ),
    _ServiceItem(
      icon: Icons.receipt_long_outlined,
      label: 'Utility Bills',
      subtitle: 'ZESA, water, council',
      color: Color(0xFF0288D1),
      route: Routes.utilityBills,
      underMaintenance: true,
    ),
    _ServiceItem(
      icon: Icons.payments_outlined,
      label: 'Payments',
      subtitle: 'Send & receive money',
      color: Color(0xFF2E7D32),
      route: Routes.payments,
      underMaintenance: true,
    ),
    _ServiceItem(
      icon: Icons.storefront_outlined,
      label: 'Providers',
      subtitle: 'Airtime, bundles, partners',
      color: WunzaColors.glideAccent,
      route: Routes.serviceProviders,
      underMaintenance: true,
    ),
    _ServiceItem(
      icon: Icons.history_toggle_off_outlined,
      label: 'Call History',
      subtitle: 'All recent calls',
      color: Color(0xFF5D4037),
      route: Routes.callHistory,
    ),
    _ServiceItem(
      icon: Icons.shopping_bag_outlined,
      label: 'Order History',
      subtitle: 'Track shop purchases',
      color: Color(0xFF6D4C41),
      route: Routes.orderHistory,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: _items.length,
      itemBuilder: (context, i) => _ServiceCard(item: _items[i]),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});
  final _ServiceItem item;

  void _onTap(BuildContext context) {
    if (item.underMaintenance) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MaintenanceScreen(
            label: item.label,
            icon: item.icon,
            color: item.color,
          ),
        ),
      );
    } else {
      Navigator.pushNamed(context, item.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      onTap: () => _onTap(context),
      child: GlideCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 26),
                ),
                if (item.underMaintenance)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Soon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              item.label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              item.subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
    this.underMaintenance = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;
  final bool underMaintenance;
}
