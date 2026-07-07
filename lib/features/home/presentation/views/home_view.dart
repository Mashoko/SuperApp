import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/call_history_widget.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/views/dialpad_view.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_tab.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/glass_bottom_nav.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/scale_tap_wrapper.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/services_grid_section.dart';
import 'package:mvvm_sip_demo/shared/widgets/maintenance_screen.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/master_balance_card.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/promotions_carousel.dart';
import 'package:mvvm_sip_demo/features/profile/presentation/views/profile_view.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/views/shopping_view.dart';
import 'package:mvvm_sip_demo/shared/widgets/shimmer_widget.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;
  bool _navVisible = true;

  static const _tabs = [
    GlassNavTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    GlassNavTab(
        icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Explore'),
    GlassNavTab(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront,
        label: 'Shop'),
    GlassNavTab(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<AccountSummaryViewModel>(context, listen: false)
          .loadCurrentUser();

      final creds = await getIt<OtpAuthService>().getStoredCredentials();
      final userId = creds?['username'] ?? 'guest';

      if (!mounted) return;

      Provider.of<DashboardViewModel>(context, listen: false)
          .loadDashboard(userId);
      Provider.of<ShoppingViewModel>(context, listen: false).loadCart(userId);

      final dialpad = Provider.of<DialpadViewModel>(context, listen: false);
      dialpad.loadRecents();
      dialpad.loadAccountInfo();
    });
  }

  void _onTabChange(int index) => setState(() => _currentIndex = index);

  void _openDialpadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: const DialpadView(),
      ),
    );
  }

  void _openMaintenance(
      {required String label, required IconData icon, required Color color}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceScreen(label: label, icon: icon, color: color),
      ),
    );
  }

  List<GlassNavQuickAction> _quickActions() => [
        GlassNavQuickAction(
          icon: Icons.send_outlined,
          label: 'Send',
          onTap: () => _openMaintenance(
            label: 'Send Money',
            icon: Icons.send_outlined,
            color: WunzaColors.glidePrimary,
          ),
        ),
        GlassNavQuickAction(
          icon: Icons.qr_code_scanner_outlined,
          label: 'Scan',
          onTap: () => _openMaintenance(
            label: 'Scan',
            icon: Icons.qr_code_scanner_outlined,
            color: WunzaColors.glideAccent,
          ),
        ),
        GlassNavQuickAction(
          icon: Icons.payments_outlined,
          label: 'Pay',
          onTap: () => _openMaintenance(
            label: 'Payments',
            icon: Icons.payments_outlined,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ];

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse && _navVisible) {
      setState(() => _navVisible = false);
    } else if (notification.direction == ScrollDirection.forward &&
        !_navVisible) {
      setState(() => _navVisible = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [WunzaColors.glideNeutral, Color(0xFFE8E8ED)],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.glidePrimary.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onScrollNotification,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Container(
                  key: ValueKey<int>(_currentIndex),
                  child: _buildCurrentTab(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18 + MediaQuery.of(context).padding.bottom,
            child: Center(
              child: SizedBox(
                width: (MediaQuery.of(context).size.width - 28)
                    .clamp(0.0, 420.0)
                    .toDouble(),
                child: GlassBottomNav(
                  tabs: _tabs,
                  activeIndex: _currentIndex,
                  onTabSelected: _onTabChange,
                  onDialerTap: _openDialpadSheet,
                  quickActions: _quickActions(),
                  visible: _navVisible,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _GlideHomeTab(
          onGoShop: () => _onTabChange(2),
          onGoCart: () => Navigator.pushNamed(context, Routes.cart),
        );
      case 1:
        return const ExploreTab();
      case 2:
        return ShoppingView(onBack: () => _onTabChange(0));
      case 3:
        return const ProfileView(embeddedInMainShell: true);
      default:
        return _GlideHomeTab(
          onGoShop: () => _onTabChange(2),
          onGoCart: () => Navigator.pushNamed(context, Routes.cart),
        );
    }
  }
}

// ── Home tab ───────────────────────────────────────────────────────────────────

class _GlideHomeTab extends StatelessWidget {
  const _GlideHomeTab({
    required this.onGoShop,
    required this.onGoCart,
  });

  final VoidCallback onGoShop;
  final VoidCallback onGoCart;

  @override
  Widget build(BuildContext context) {
    return Consumer3<ShoppingViewModel, AccountSummaryViewModel,
        DialpadViewModel>(
      builder: (context, shoppingVM, accountVM, dialpadVM, _) {
        final cartCount = (shoppingVM.cart['items'] as List?)?.length ?? 0;
        final alias = accountVM.alias ?? '…';
        final mq = MediaQuery.of(context);
        final h = (mq.size.width * 0.05).clamp(16.0, 22.0).toDouble();

        final pb = accountVM.paymentsBalance;
        final pbLoading = accountVM.paymentsLoading;
        final voiceMins = accountVM.formattedMinutes;
        final walletKey = '${pb ?? voiceMins}_$alias';
        final walletPrimary = pbLoading
            ? '…'
            : pb != null
                ? '\$${NumberFormat('#,##0.00', 'en_US').format(pb)}'
                : voiceMins;
        final walletChipText = (accountVM.loading && accountVM.alias == null) ||
                pbLoading
            ? 'Wallet · …'
            : pb != null
                ? 'Wallet · \$${NumberFormat('#,##0.00', 'en_US').format(pb)}'
                : 'Balance · $voiceMins';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeTopBar(
                userName: accountVM.loading && accountVM.alias == null
                    ? '…'
                    : alias,
                walletChipLabel: accountVM.loading && accountVM.alias == null
                    ? 'Loading…'
                    : walletChipText,
                notificationCount: cartCount,
                onNotificationsTap: onGoCart,
                onAvatarTap: () => Navigator.pushNamed(context, Routes.profile),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (accountVM.loading && accountVM.alias == null)
                      const ShimmerWidget.rectangular(
                          height: 180, width: double.infinity)
                    else
                      GestureDetector(
                        onLongPress: () => accountVM.loadCurrentUser(),
                        child: MasterBalanceCard(
                          walletBalanceKey: walletKey,
                          walletBalanceText: walletPrimary,
                          voiceChipLabel: _voiceChipLabel(accountVM.balance),
                          dataChipLabel: 'Data — add a bundle',
                          onTopUp: () => _launchTopUp(context),
                          onManageAccount: () =>
                              Navigator.pushNamed(context, Routes.profile),
                        ),
                      ),
                    const SizedBox(height: 28),
                    _QuickServicesRow(onGoShop: onGoShop),
                    const SizedBox(height: 28),
                    Text('All services',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const ServicesGridSection(),
                    const SizedBox(height: 28),
                    GlidePromotionsCarousel(
                        apiBanners: shoppingVM.banners,
                        onBannerTap: (_) => onGoShop()),
                    const SizedBox(height: 28),
                    const CallHistoryWidget(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Quick services row ─────────────────────────────────────────────────────────

class _QuickServicesRow extends StatelessWidget {
  const _QuickServicesRow({required this.onGoShop});

  final VoidCallback onGoShop;

  @override
  Widget build(BuildContext context) {
    final actions = <_QA>[
      _QA(
        icon: Icons.call_outlined,
        label: 'Call',
        color: WunzaColors.glidePrimary,
        onTap: () => Navigator.pushNamed(context, Routes.calling),
      ),
      _QA(
        icon: Icons.storefront_outlined,
        label: 'Shop',
        color: WunzaColors.glideAccent,
        onTap: onGoShop,
      ),
      _QA(
        icon: Icons.receipt_long_outlined,
        label: 'Bills',
        color: const Color(0xFF0288D1),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MaintenanceScreen(
              label: 'Utility Bills',
              icon: Icons.receipt_long_outlined,
              color: Color(0xFF0288D1),
            ),
          ),
        ),
      ),
      _QA(
        icon: Icons.payments_outlined,
        label: 'Pay',
        color: const Color(0xFF2E7D32),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MaintenanceScreen(
              label: 'Payments',
              icon: Icons.payments_outlined,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ),
      _QA(
        icon: Icons.history_outlined,
        label: 'History',
        color: const Color(0xFF5D4037),
        onTap: () => Navigator.pushNamed(context, Routes.callHistory),
      ),
      _QA(
        icon: Icons.manage_accounts_outlined,
        label: 'Account',
        color: const Color(0xFF7B1FA2),
        onTap: () => Navigator.pushNamed(context, Routes.profile),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick services', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) => _QuickActionTile(qa: actions[i]),
          ),
        ),
      ],
    );
  }
}

class _QA {
  const _QA({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.qa});
  final _QA qa;

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      onTap: qa.onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: qa.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: qa.color.withValues(alpha: 0.18), width: 1),
              ),
              child: Icon(qa.icon, color: qa.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              qa.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _voiceChipLabel(double? balanceNs) {
  final raw = _formatVoiceBalance(balanceNs ?? 0);
  return raw.replaceAll('Voice Bal: ', 'Minutes · ');
}

Future<void> _launchTopUp(BuildContext context) async {
  const url = 'https://selfservice.ai.co.zw/';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

String _formatVoiceBalance(double nanoseconds) {
  if (nanoseconds <= 0) return 'Voice Bal: 0 m';
  final duration = Duration(microseconds: (nanoseconds / 1000).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return 'Voice Bal: $hours hrs $minutes m';
  return 'Voice Bal: $minutes m $seconds s';
}
