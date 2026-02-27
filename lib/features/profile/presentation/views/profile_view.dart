import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Theme
import '../../../../shared/theme/theme_provider.dart';

// Existing feature views
import '../../../shopping/presentation/views/order_history_view.dart';
import '../../../shopping/presentation/views/wishlist_view.dart';
import '../../../payments/presentation/views/payments_view.dart';
import '../../../login/presentation/views/login_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  File? _imageFile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Generic navigation helper
  void _navigateTo(BuildContext context, Widget view) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => view),
    );
  }

  void _handleLogout(BuildContext context) {
    // TODO: Call your AuthViewModel or AuthService to clear user tokens/session here
    
    // Navigate back to Login and clear the navigation stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginView()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
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
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                children: [
                  // User Avatar & Info
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
                                backgroundColor: isDark ? Colors.white24 : Colors.grey.shade300,
                                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                                child: _imageFile == null
                                    ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color: isDark ? Colors.white : Colors.grey.shade700,
                                      )
                                    : null,
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tanaka Mashoko',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // eCommerce Profile Fields
                  _buildProfileSection(
                    title: 'Account',
                    isDark: isDark,
                    items: [
                      _buildProfileTile(
                        icon: Icons.shopping_bag_outlined,
                        title: 'My Orders',
                        subtitle: 'History of your orders',
                        isDark: isDark,
                        onTap: () => _navigateTo(context, const OrderHistoryView()),
                      ),
                      _buildProfileTile(
                        icon: Icons.favorite_border,
                        title: 'Wishlist',
                        subtitle: 'Your saved items',
                        isDark: isDark,
                        onTap: () => _navigateTo(context, const WishlistView()),
                      ),
                      _buildProfileTile(
                        icon: Icons.location_on_outlined,
                        title: 'Shipping Addresses',
                        subtitle: 'Manage delivery locations',
                        isDark: isDark,
                        onTap: () => _navigateTo(
                          context, 
                          const PlaceholderScreen(title: 'Shipping Addresses')
                        ),
                      ),
                      _buildProfileTile(
                        icon: Icons.payment_outlined,
                        title: 'Payment Methods',
                        subtitle: 'Manage linked cards and wallets',
                        isDark: isDark,
                        onTap: () => _navigateTo(context, 
                          const PlaceholderScreen(title: 'Payment Methods'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildProfileSection(
                    title: 'Preferences',
                    isDark: isDark,
                    items: [
                      _buildProfileTile(
                        icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        title: 'Theme',
                        subtitle: isDark ? 'Dark Mode' : 'Light Mode',
                        isDark: isDark,
                        trailing: Switch(
                          value: isDark,
                          onChanged: (value) => themeProvider.toggleTheme(),
                        ),
                        onTap: () => themeProvider.toggleTheme(),
                      ),
                      _buildProfileTile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Notifications, privacy, & security',
                        isDark: isDark,
                        onTap: () => _navigateTo(
                          context, 
                          const PlaceholderScreen(title: 'Settings')
                        ),
                      ),
                      _buildProfileTile(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        subtitle: 'FAQ and customer service',
                        isDark: isDark,
                        onTap: () => _navigateTo(
                          context, 
                          const PlaceholderScreen(title: 'Help & Support')
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection({
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
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : Colors.blueAccent,
        ),
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
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
      onTap: onTap,
    );
  }
}

/// A simple placeholder screen for views that haven't been built yet.
/// Feel free to replace these with your actual screens when you build them!
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.blue.shade300),
            const SizedBox(height: 20),
            Text(
              '$title coming soon!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'This screen is currently under construction.',
              style: TextStyle(color: Colors.grey),
            )
          ],
        ),
      ),
    );
  }
}
