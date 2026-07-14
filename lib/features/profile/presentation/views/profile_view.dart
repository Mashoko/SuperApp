import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/inject.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../../../features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import '../../../../features/account_summary/presentation/views/account_summary_view.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../shopping/presentation/views/order_history_view.dart';
import '../../../shopping/presentation/views/wishlist_view.dart';
import '../../../payment_methods/presentation/views/payment_methods_view.dart';
import '../../../help_support/presentation/views/help_support_view.dart';
import '../../../login/presentation/views/login_view.dart';
import '../viewmodels/profile_summary_viewmodel.dart';
import 'shipping_addresses_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key, this.embeddedInMainShell = false});

  final bool embeddedInMainShell;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  File? _imageFile;
  static const String _imagePathKey = 'profile_image_path';

  @override
  void initState() {
    super.initState();
    _loadSavedImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProfileSummaryViewModel>(context, listen: false).load();
    });
  }

  Future<void> _loadSavedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_imagePathKey);
    if (path != null && File(path).existsSync()) {
      setState(() => _imageFile = File(path));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_imagePathKey, pickedFile.path);
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _navigateTo(BuildContext context, Widget view) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => view));
  }

  Future<void> _handleLogout(BuildContext context) async {
    await getIt<OtpAuthService>().clearStoredCredentials();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Consumer2<AccountSummaryViewModel, ProfileSummaryViewModel>(
      builder: (context, accountVM, profileVM, _) {
        final username = accountVM.summary?['username'] as String? ?? '';
        final alias = accountVM.alias ?? '';
        final domain = accountVM.summary?['domain'] as String? ?? '';
        final balance = accountVM.balance;

        final displayName = username.isNotEmpty ? username : 'My Account';

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Profile'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: !widget.embeddedInMainShell,
            leading: widget.embeddedInMainShell
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
          ),
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.black, const Color(0xFF1A1A2E)]
                        : [Colors.blue.shade50, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 20.0),
                  child: Column(
                    children: [
                      // ── Avatar & identity ──────────────────────────────
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 55,
                                    backgroundColor: isDark
                                        ? Colors.white24
                                        : Colors.grey.shade300,
                                    backgroundImage: _imageFile != null
                                        ? FileImage(_imageFile!)
                                        : null,
                                    child: _imageFile == null
                                        ? Icon(Icons.person,
                                            size: 60,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.grey.shade700)
                                        : null,
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 20),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (accountVM.loading)
                              const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else ...[
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (alias.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Alias: $alias',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── SIP / Calling info card ────────────────────────
                      if (!accountVM.loading &&
                          (alias.isNotEmpty ||
                              domain.isNotEmpty ||
                              balance != null)) ...[
                        _buildSipInfoCard(
                          isDark: isDark,
                          alias: alias,
                          domain: domain,
                          balance: balance != null ? accountVM.formattedMinutes : null,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Account section ────────────────────────────────
                      _buildSection(
                        title: 'Account',
                        isDark: isDark,
                        items: [
                          _buildTile(
                            icon: Icons.manage_accounts_outlined,
                            title: 'Account Services',
                            subtitle: 'Balance, alias & calling details',
                            isDark: isDark,
                            onTap: () => _navigateTo(
                                context, const AccountSummaryView()),
                          ),
                          _buildTile(
                            icon: Icons.shopping_bag_outlined,
                            title: 'My Orders',
                            subtitle: profileVM.orderSubtitle,
                            isDark: isDark,
                            showBadge: profileVM.hasActiveOrders,
                            onTap: () => _navigateTo(
                                context, const OrderHistoryView()),
                          ),
                          _buildTile(
                            icon: Icons.favorite_border,
                            title: 'Wishlist',
                            subtitle: profileVM.wishlistSubtitle,
                            isDark: isDark,
                            showBadge: profileVM.hasWishlistItems,
                            onTap: () =>
                                _navigateTo(context, const WishlistView()),
                          ),
                          _buildTile(
                            icon: Icons.location_on_outlined,
                            title: 'Shipping Addresses',
                            subtitle: profileVM.addressSubtitle,
                            isDark: isDark,
                            onTap: () => _navigateTo(context, const ShippingAddressesView()),
                          ),
                          _buildTile(
                            icon: Icons.payment_outlined,
                            title: 'Payment Methods',
                            subtitle: profileVM.paymentSubtitle,
                            isDark: isDark,
                            onTap: () =>
                                _navigateTo(context, const PaymentMethodsView()),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Preferences section ────────────────────────────
                      _buildSection(
                        title: 'Preferences',
                        isDark: isDark,
                        items: [
                          _buildTile(
                            icon: isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            title: 'Theme',
                            subtitle: isDark ? 'Dark Mode' : 'Light Mode',
                            isDark: isDark,
                            trailing: Switch(
                              value: isDark,
                              onChanged: (_) => themeProvider.toggleTheme(),
                            ),
                            onTap: () => themeProvider.toggleTheme(),
                          ),
                          _buildTile(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            subtitle: 'Notifications, privacy, & security',
                            isDark: isDark,
                            onTap: () => _navigateTo(context,
                                const _PlaceholderScreen(title: 'Settings')),
                          ),
                          _buildTile(
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            subtitle: 'FAQ and customer service',
                            isDark: isDark,
                            onTap: () => _navigateTo(context,
                                const HelpSupportView()),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // ── Logout ─────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout,
                              color: Colors.redAccent),
                          label: const Text('Log Out',
                              style: TextStyle(color: Colors.redAccent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _handleLogout(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── SIP info card ──────────────────────────────────────────────────────────

  Widget _buildSipInfoCard({
    required bool isDark,
    required String alias,
    required String domain,
    required String? balance,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIP / Calling Info',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          if (alias.isNotEmpty)
            _buildInfoRow(isDark, Icons.person_pin_outlined, 'Alias', alias),
          if (domain.isNotEmpty)
            _buildInfoRow(isDark, Icons.dns_outlined, 'Domain', domain),
          if (balance != null)
            _buildInfoRow(isDark, Icons.account_balance_wallet_outlined,
                'Balance', balance),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      bool isDark, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDark ? Colors.white54 : Colors.blueAccent),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section / tile builders ────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required bool isDark,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    Widget? trailing,
    bool showBadge = false,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isDark ? Colors.white70 : Colors.blueAccent),
          ),
          if (showBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right,
              color: isDark ? Colors.white54 : Colors.black54),
      onTap: onTap,
    );
  }
}

// ── Placeholder for unbuilt screens ───────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.blue.shade300),
            const SizedBox(height: 20),
            Text(
              '$title coming soon!',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'This screen is currently under construction.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
