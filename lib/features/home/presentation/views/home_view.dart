import 'package:flutter/material.dart';
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
import 'package:mvvm_sip_demo/features/home/presentation/widgets/hanging_dialer.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/scale_tap_wrapper.dart';
import 'package:mvvm_sip_demo/shared/widgets/maintenance_screen.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/master_balance_card.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/promotions_carousel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/services_hub_tab.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load gRPC account — fires reactively, no await needed
      Provider.of<AccountSummaryViewModel>(context, listen: false)
          .loadCurrentUser();

      // Get the real stored user ID for user-keyed local services
      final creds = await getIt<OtpAuthService>().getStoredCredentials();
      final userId = creds?['username'] ?? 'guest';

      if (!mounted) return;

      Provider.of<DashboardViewModel>(context, listen: false)
          .loadDashboard(userId);
      Provider.of<ShoppingViewModel>(context, listen: false).loadCart(userId);

      final dialpad =
          Provider.of<DialpadViewModel>(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      floatingActionButton:
          HangingDialerButton(onTap: _openDialpadSheet),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
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
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _GlideHomeTab(
          onGoShop: () => _onTabChange(2),
          onGoCart: () => Navigator.pushNamed(context, Routes.cart),
          onGoServices: () => _onTabChange(1),
        );
      case 1:
        return const ServicesHubTab();
      case 2:
        return ShoppingView(onBack: () => _onTabChange(0));
      case 3:
        return const ProfileView(embeddedInMainShell: true);
      default:
        return _GlideHomeTab(
          onGoShop: () => _onTabChange(2),
          onGoCart: () => Navigator.pushNamed(context, Routes.cart),
          onGoServices: () => _onTabChange(1),
        );
    }
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: theme.colorScheme.surface,
      elevation: 12,
      shadowColor: Colors.black26,
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              _navItem(Icons.home_outlined, Icons.home, 'Home', 0),
              _navItem(Icons.apps_outlined, Icons.apps, 'Services', 1),
            ]),
            const SizedBox(width: 56),
            Row(children: [
              _navItem(
                  Icons.storefront_outlined, Icons.storefront, 'Shop', 2),
              _navItem(Icons.person_outline, Icons.person, 'Profile', 3),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
      IconData icon, IconData activeIcon, String label, int index) {
    final selected = _currentIndex == index;
    final color = selected
        ? WunzaColors.glidePrimary
        : WunzaColors.textSecondary;
    return MaterialButton(
      minWidth: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: () => _onTabChange(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(selected ? activeIcon : icon,
              color: color, size: selected ? 26 : 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Home tab ───────────────────────────────────────────────────────────────────

class _GlideHomeTab extends StatelessWidget {
  const _GlideHomeTab({
    required this.onGoShop,
    required this.onGoCart,
    required this.onGoServices,
  });

  final VoidCallback onGoShop;
  final VoidCallback onGoCart;
  final VoidCallback onGoServices;

  @override
  Widget build(BuildContext context) {
    return Consumer3<ShoppingViewModel, AccountSummaryViewModel,
        DialpadViewModel>(
      builder: (context, shoppingVM, accountVM, dialpadVM, _) {
        final cartCount =
            (shoppingVM.cart['items'] as List?)?.length ?? 0;
        final alias = accountVM.alias ?? '…';
        final mq = MediaQuery.of(context);
        final h = (mq.size.width * 0.05).clamp(16.0, 22.0).toDouble();

        final walletKey =
            '${accountVM.balance}_${dialpadVM.accountBalance}_$alias';
        final walletPrimary =
            _primaryWalletLine(accountVM, dialpadVM);
        final walletChipText =
            accountVM.loading && accountVM.alias == null
                ? 'Wallet · …'
                : 'Wallet · ${dialpadVM.accountBalance.isEmpty ? '—' : dialpadVM.accountBalance}';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeTopBar(
                userName: accountVM.loading && accountVM.alias == null
                    ? '…'
                    : alias,
                walletChipLabel:
                    accountVM.loading && accountVM.alias == null
                        ? 'Loading…'
                        : walletChipText,
                notificationCount: cartCount,
                onNotificationsTap: onGoCart,
                onAvatarTap: () =>
                    Navigator.pushNamed(context, Routes.profile),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Balance card ────────────────────────────────
                    if (accountVM.loading && accountVM.alias == null)
                      const ShimmerWidget.rectangular(
                          height: 180, width: double.infinity)
                    else
                      MasterBalanceCard(
                        walletBalanceKey: walletKey,
                        walletBalanceText: walletPrimary,
                        voiceChipLabel:
                            _voiceChipLabel(accountVM.balance),
                        dataChipLabel: 'Data — add a bundle',
                        onTopUp: () => _launchTopUp(context),
                        onManageAccount: () => Navigator.pushNamed(
                            context, Routes.profile),
                      ),

                    const SizedBox(height: 28),

                    // ── Quick services ──────────────────────────────
                    _QuickServicesRow(
                        onGoShop: onGoShop,
                        onGoServices: onGoServices),

                    const SizedBox(height: 28),

                    // ── Promotions ──────────────────────────────────
                    GlidePromotionsCarousel(
                        apiBanners: shoppingVM.banners,
                        onBannerTap: (_) => onGoShop()),

                    const SizedBox(height: 28),

                    // ── Recent activity ─────────────────────────────
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
  const _QuickServicesRow(
      {required this.onGoShop, required this.onGoServices});

  final VoidCallback onGoShop;
  final VoidCallback onGoServices;

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
        onTap: () =>
            Navigator.pushNamed(context, Routes.callHistory),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick services',
                style: Theme.of(context).textTheme.headlineSmall),
            TextButton(
              onPressed: onGoServices,
              child: const Text(
                'See all',
                style: TextStyle(
                  color: WunzaColors.glidePrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
                border: Border.all(
                    color: qa.color.withValues(alpha: 0.18), width: 1),
              ),
              child: Icon(qa.icon, color: qa.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              qa.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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

String _primaryWalletLine(
  AccountSummaryViewModel account,
  DialpadViewModel dialpad,
) {
  final d = dialpad.accountBalance.trim();
  if (d.isNotEmpty) return d;
  if (account.balance != null) {
    return '\$${account.balance!.toStringAsFixed(2)}';
  }
  return '—';
}

Future<void> _launchTopUp(BuildContext context) async {
  const url = 'https://selfservice.ai.co.zw/';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $url')),
    );
  }
}

String _formatVoiceBalance(double nanoseconds) {
  if (nanoseconds <= 0) return 'Voice Bal: 0 m';
  final duration =
      Duration(microseconds: (nanoseconds / 1000).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return 'Voice Bal: $hours hrs $minutes m';
  return 'Voice Bal: $minutes m $seconds s';
}
