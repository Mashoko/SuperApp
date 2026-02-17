import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthViewModel, AccountSummaryViewModel>(
      builder: (context, authViewModel, accountSummary, child) {
        final user = authViewModel.currentUser;
        final sipAlias = accountSummary.alias;
        final sipUsername = accountSummary.summary?['username'];

        final displayName = (sipAlias != null && sipAlias.isNotEmpty) 
            ? sipAlias 
            : (sipUsername ?? user?['name'] ?? 'Guest User');
        
        final displaySubtitle = sipUsername ?? user?['email'] ?? 'Sign in to see your profile';

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
          ),
          body: Stack(
            children: [
              // Blurred Background
              Positioned.fill(
                child: Image.asset(
                  'assets/icon/icon.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 12),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, blur, child) {
                    return BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: Container(
                        color: Colors.black.withOpacity(0.4), // Darker overlay for better contrast
                      ),
                    );
                  },
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100), // Adjusted for extended body
                    _profileAvatar(context, authViewModel),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        displaySubtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileAvatar(BuildContext context, AuthViewModel auth) {
    final imagePath = auth.currentUser?['photo'];

    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.gallery);

        if (image != null) {
          auth.updateProfileImage(image.path);
        }
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: WunzaColors.primary,
            backgroundImage:
                imagePath != null ? FileImage(File(imagePath)) : null,
            child: imagePath == null
                ? const Icon(Icons.person, size: 60, color: Colors.white)
                : null,
          ),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.black54,
            child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
