import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';






import 'package:mvvm_sip_demo/features/shopping/presentation/views/shopping_view.dart';
import 'package:mvvm_sip_demo/features/payments/presentation/views/payments_view.dart';
import 'package:mvvm_sip_demo/features/auth/presentation/viewmodels/auth_viewmodel.dart';
// - Import the glass widget
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/hanging_dialer.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/quick_dialer_overlay.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/call_history_widget.dart';
import 'package:mvvm_sip_demo/features/contacts/presentation/views/contacts_view.dart';
import 'package:mvvm_sip_demo/shared/widgets/shimmer_widget.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;
  // TODO: Replace with actual User ID from Auth Service
  final String _userId = "user1"; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardViewModel>(context, listen: false).loadDashboard(_userId);
      // Load real cart data
      Provider.of<ShoppingViewModel>(context, listen: false).loadCart(_userId);
      // Load account summary for header
      Provider.of<AccountSummaryViewModel>(context, listen: false).loadCurrentUser();
      // Load recent calls
      Provider.of<DialpadViewModel>(context, listen: false).loadRecents();
    });
  }

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows body to scroll behind the bottom nav
      body: Stack(
        children: [
          // --- 1. Global Background Gradient & Blobs ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE0E7FF), // Very light Indigo
                  Color(0xFFF3F4F6), // Grey/White
                ],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.indigo.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.blueAccent.withValues(alpha: 0.15),
              ),
            ),
          ),
          
          // --- 2. Main Content ---
          SafeArea(
            bottom: false, // Let content go behind the floating nav
            child: _buildCurrentTab(),
          ),

          // --- 3. Hanging Dialer ---
          if (_currentIndex == 0)
            Positioned(
              bottom: 100, // Positioned above the glass nav
              left: 0,
              right: 0,
              child: Center(
                child: HangingDialerButton(
                  onTap: () {
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
                  },
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _ModernDashboardTab(onTabChange: _onTabChange);
      case 1:
        return const ContactsView();
      case 2:
        return ShoppingView(
          onBack: () => _onTabChange(0),
        );
      case 3:
        return const PaymentsView();
      default:
        return _ModernDashboardTab(onTabChange: _onTabChange);
    }
  }

  Widget _buildModernBottomNav() {
    // Floating Glass Navigation Bar
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GlassContainer(
        borderRadius: 30,
        blur: 20,
        opacity: 0.7, // Slightly more opaque for legibility
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: NavigationBar(
          height: 60,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabChange,
          indicatorColor: WunzaColors.indigo.withValues(alpha: 0.2),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: WunzaColors.indigo),
              label: 'Home',
            ),
             NavigationDestination(
              icon: Icon(Icons.contacts_outlined),
              selectedIcon: Icon(Icons.contacts, color: Colors.blue),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag, color: WunzaColors.orangeAccent),
              label: 'Shop',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet, color: WunzaColors.greenAccent),
              label: 'Pay',
            ),
          ],
        ),
      ),
    );
  }
}



class _ModernDashboardTab extends StatelessWidget {
  final Function(int) onTabChange;

  const _ModernDashboardTab({required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Consumer5<DashboardViewModel, AuthViewModel, ShoppingViewModel, AccountSummaryViewModel, DialpadViewModel>(
      builder: (context, viewModel, authViewModel, shoppingViewModel, accountViewModel, dialpadViewModel, child) {
        final data = viewModel.dashboardData;

        // Use real cart data instead of dashboard snapshot
        // final shopping = data['shopping'] ?? {}; 
        final calling = data['calling'] ?? {};
        
        // final userName = authViewModel.currentUser?['name'] ?? 'User';
        
        // Calculate real cart count
        final cartItemsList = shoppingViewModel.cart['items'] as List<dynamic>? ?? [];
        final cartCount = cartItemsList.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 140), // Increased bottom padding for floating nav
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Status Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accountViewModel.balance != null ? WunzaColors.greenAccent : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           accountViewModel.alias == null 
                               ? const ShimmerWidget.rectangular(height: 20, width: 120)
                               : Text(
                                  "User: ${accountViewModel.alias}",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: WunzaColors.textPrimary),
                                ),
                           Text(
                            _formatVoiceBalance(accountViewModel.balance ?? 0),
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GlassContainer(
                    borderRadius: 50,
                    padding: const EdgeInsets.all(4),
                    opacity: 0.5,
                    child: IconButton(
                      onPressed: () => Navigator.pushNamed(context, Routes.profile),
                      icon: const Icon(Icons.person, color: WunzaColors.indigo),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // Hero Card (Gradient + Glass Overlay)
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20), // Reduced padding
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Purple to Blue
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back,",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _GlassStatsBubble(
                                icon: Icons.shopping_cart,
                                label: "Cart",
                                value: "$cartCount",
                                color: Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GlassStatsBubble(
                                icon: Icons.phone_missed,
                                label: "Missed",
                                value: "${calling['missed_calls'] ?? 0}",
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              
              const Text(
                "Quick Actions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WunzaColors.textPrimary),
              ),
              const SizedBox(height: 16),

              // Glass Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: [

                  Builder(
                    builder: (context) {
                      final hasItems = cartCount > 0;
                      
                      return _DashboardWidgetCard(
                        title: "Shopping",
                        value: "$cartCount",
                        subValue: "Cart Items",
                        icon: Icons.shopping_bag,
                        accentColor: WunzaColors.orangeAccent,
                        buttonText: hasItems ? "Proceed to Checkout" : "Start Shopping",
                        onTap: () {
                          if (hasItems) {
                             Navigator.pushNamed(context, Routes.cart);
                          } else {
                             onTabChange(2);
                          }
                        }, 
                      );
                    }
                  ),

                  _DashboardWidgetCard(
                    title: "Voice",
                    value: _formatVoiceBalance(accountViewModel.balance ?? 0).replaceAll("Voice Bal: ", ""),
                    subValue: "Remaining",
                    icon: Icons.mic,
                    accentColor: Colors.purple,
                    buttonText: "Add Funds",
                    onTap: () async {
                      const url = 'https://selfservice.ai.co.zw/';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Could not launch $url')),
                           );
                        }
                      }
                    }, 
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- Recent History Section ---
              // --- Recent History Section ---
              const CallHistoryWidget(),
            ],
          ),
        );
      },
    );
  }
}

// Updated Widget Card to use GlassContainer
class _DashboardWidgetCard extends StatelessWidget {
  final String title;
  final String value;
  final String subValue;
  final IconData icon;
  final Color accentColor;
  final String buttonText;
  final VoidCallback onTap;

  const _DashboardWidgetCard({
    required this.title,
    required this.value,
    required this.subValue,
    required this.icon,
    required this.accentColor,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Using GlassContainer instead of basic Container/Card
    return GlassContainer(
      opacity: 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10), // Slightly larger padding
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1), // Keep soft background
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 28), // Larger icon
              ),
              const Spacer(),
              // Removed more_horiz to clean up
            ],
          ),
          const Spacer(),
          Text(
            subValue,
            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22, // Slightly larger
              fontWeight: FontWeight.bold,
              color: WunzaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 40, // Taller button
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor, // Solid high-contrast color
                foregroundColor: Colors.white, // White text
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(buttonText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
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

class _GlassStatsBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _GlassStatsBubble({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.2, // Very subtle glass
      blur: 10,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}