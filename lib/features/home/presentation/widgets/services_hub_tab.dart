import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/shared/widgets/glide_card.dart';

/// Secondary tab: quick entry to bills, payments, calling, and utilities.
class ServicesHubTab extends StatelessWidget {
  const ServicesHubTab({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pad = (mq.size.width * 0.05).clamp(16.0, 24.0);

    final items = <_ServiceLink>[
      _ServiceLink(
        icon: Icons.receipt_long_outlined,
        title: 'Utility bills',
        subtitle: 'ZESA, water, council',
        route: Routes.utilityBills,
      ),
      _ServiceLink(
        icon: Icons.payments_outlined,
        title: 'Payments',
        subtitle: 'Send & receive money',
        route: Routes.payments,
      ),
      _ServiceLink(
        icon: Icons.storefront_outlined,
        title: 'Service providers',
        subtitle: 'Airtime, bundles, partners',
        route: Routes.serviceProviders,
      ),
      _ServiceLink(
        icon: Icons.history,
        title: 'Order history',
        subtitle: 'Track shop purchases',
        route: Routes.orderHistory,
      ),
      _ServiceLink(
        icon: Icons.call_outlined,
        title: 'Calling',
        subtitle: 'Contacts & dialer',
        route: Routes.calling,
      ),
      _ServiceLink(
        icon: Icons.history_toggle_off_outlined,
        title: 'Call history',
        subtitle: 'All recent calls',
        route: Routes.callHistory,
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 8),
            child: Text(
              'Services',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 120),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return GlideCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                onTap: () => Navigator.pushNamed(context, item.route),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WunzaColors.glidePrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.icon,
                        color: WunzaColors.glidePrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: WunzaColors.textSecondary),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceLink {
  const _ServiceLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
