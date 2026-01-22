import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';
import 'package:mvvm_sip_demo/features/payments/presentation/views/payment_details_view.dart';

class ServiceProvidersView extends StatelessWidget {
  const ServiceProvidersView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final title = args?['type'] ?? 'Service Providers';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Select $title Provider"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE0E7FF), Color(0xFFF3F4F6)],
              ),
            ),
          ),
          // Subtle blob
          Positioned(
            top: 100,
            left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.indigo.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildProviderTile(
                  context, 
                  "Econet Wireless", 
                  "assets/images/econet_logo.png", 
                  WunzaColors.blueAccent
                ),
                const SizedBox(height: 16),
                _buildProviderTile(
                  context, 
                  "NetOne", 
                  "assets/images/netone_logo.png", 
                  WunzaColors.orangeAccent
                ),
                const SizedBox(height: 16),
                _buildProviderTile(
                  context, 
                  "Telecel", 
                  "assets/images/telecel_logo.png", 
                  Colors.redAccent
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderTile(BuildContext context, String name, String assetPath, Color glowColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentDetailsView(
              providerName: name,
              providerLogo: assetPath,
              glowColor: glowColor,
            ),
          ),
        );
      },
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        opacity: 0.7,
        child: Row(
          children: [
            // Logo Container
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (c, o, s) => Icon(Icons.business, color: glowColor),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: WunzaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Pay bill or top up",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}