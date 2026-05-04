import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/call_history_widget.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/glide_quick_service_card.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/hanging_dialer.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/master_balance_card.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/promotions_carousel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/quick_dialer_overlay.dart';
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
  final String _userId = 'user1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardViewModel>(context, listen: false)
          .loadDashboard(_userId);
      Provider.of<ShoppingViewModel>(context, listen: false).loadCart(_userId);
      Provider.of<AccountSummaryViewModel>(context, listen: false)
          .loadCurrentUser();
      final dialpad = Provider.of<DialpadViewModel>(context, listen: false);
      dialpad.loadRecents();
      dialpad.loadAccountInfo();
    });
  }

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

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
        child: const DialPadScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      floatingActionButton: HangingDialerButton(onTap: _openDialpadSheet),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  WunzaColors.glideNeutral,
                  Color(0xFFE8E8ED),
                ],
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
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                key: ValueKey<int>(_currentIndex),
                child: _buildCurrentTab(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildGlideBottomNav(context),
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
        return const ServicesHubTab();
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

  Widget _buildGlideBottomNav(BuildContext context) {
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
            Row(
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.apps_outlined,
                  activeIcon: Icons.apps,
                  label: 'Services',
                  index: 1,
                ),
              ],
            ),
            const SizedBox(width: 56),
            Row(
              children: [
                _buildNavItem(
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront,
                  label: 'Shop',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  index: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final color =
        isSelected ? WunzaColors.glidePrimary : WunzaColors.textSecondary;
    final currentIcon = isSelected ? activeIcon : icon;

    return MaterialButton(
      minWidth: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: () => _onTabChange(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(currentIcon, color: color, size: isSelected ? 26 : 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

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
      builder: (context, shoppingViewModel, accountViewModel, dialpadViewModel,
          child) {
        final cartItemsList =
            shoppingViewModel.cart['items'] as List<dynamic>? ?? [];
        final cartCount = cartItemsList.length;

        final alias = accountViewModel.alias ?? 'there';
        final mq = MediaQuery.of(context);
        final horizontal =
            (mq.size.width * 0.05).clamp(16.0, 22.0).toDouble();

        final walletKey =
            '${accountViewModel.balance}_${dialpadViewModel.accountBalance}_$alias';
        final walletPrimary =
            _primaryWalletLine(accountViewModel, dialpadViewModel);

        final walletChipText = accountViewModel.loading &&
                accountViewModel.alias == null
            ? 'Wallet · …'
            : 'Wallet · ${dialpadViewModel.accountBalance}';

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(0, 6, 0, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeTopBar(
                userName: accountViewModel.alias == null && accountViewModel.loading
                    ? '…'
                    : alias,
                walletChipLabel: accountViewModel.alias == null &&
                        accountViewModel.loading
                    ? 'Loading…'
                    : walletChipText,
                notificationCount: cartCount,
                onNotificationsTap: onGoCart,
                onAvatarTap: () => Navigator.pushNamed(context, Routes.profile),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (accountViewModel.alias == null && accountViewModel.loading)
                      const ShimmerWidget.rectangular(height: 180, width: double.infinity)
                    else
                      MasterBalanceCard(
                        walletBalanceKey: walletKey,
                        walletBalanceText: walletPrimary,
                        voiceChipLabel: _voiceChipLabel(accountViewModel.balance),
                        dataChipLabel: 'Data — add a bundle',
                        onTopUp: () => _launchTopUpFor(context),
                        onManageAccount: () =>
                            Navigator.pushNamed(context, Routes.profile),
                      ),
                    const SizedBox(height: 28),
                    Text(
                      'Quick actions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.92,
                      children: [
                        GlideQuickServiceCard(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Shop',
                          subtitle: 'Devices & accessories',
                          onTap: onGoShop,
                        ),
                        GlideQuickServiceCard(
                          icon: Icons.call_outlined,
                          title: 'Calling',
                          subtitle: 'Contacts & keypad',
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.calling),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    GlidePromotionsCarousel(
                      onBannerTap: (_) => onGoShop(),
                    ),
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

String _voiceChipLabel(double? balanceNs) {
  final raw = _formatVoiceBalance(balanceNs ?? 0);
  return raw.replaceAll('Voice Bal: ', 'Minutes · ');
}

String _primaryWalletLine(
  AccountSummaryViewModel account,
  DialpadViewModel dialpad,
) {
  final d = dialpad.accountBalance.trim();
  if (d.isNotEmpty && d != r'$0.00') {
    return d;
  }
  if (account.balance != null && account.balance! > 0) {
    return _formatVoiceBalance(account.balance!)
        .replaceAll('Voice Bal: ', '')
        .trim();
  }
  return r'$0.00';
}

Future<void> _launchTopUpFor(BuildContext context) async {
  const url = 'https://selfservice.ai.co.zw/';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not launch $url')),
    );
  }
}

String _formatVoiceBalance(double nanoseconds) {
  if (nanoseconds <= 0) return 'Voice Bal: 0 m';
  final duration = Duration(microseconds: (nanoseconds / 1000).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return 'Voice Bal: $hours hrs $minutes m';
  } else {
    return 'Voice Bal: $minutes m $seconds s';
  }
}
