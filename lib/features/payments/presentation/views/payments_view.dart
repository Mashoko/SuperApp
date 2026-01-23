import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/models/utility_bills/bill_type.dart';
import 'package:mvvm_sip_demo/features/utility_bills/presentation/viewmodels/utility_bills_viewmodel.dart';
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';

class PaymentsView extends StatefulWidget {
  const PaymentsView({super.key});

  @override
  State<PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<PaymentsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // using hardcoded user1 to match HomeView
      Provider.of<UtilityBillsViewModel>(context, listen: false).loadPayments('user1');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Payments"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // --- 1. Background Gradient & Blobs ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE0E7FF), Color(0xFFF3F4F6)],
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.greenAccent.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.indigo.withValues(alpha: 0.1),
              ),
            ),
          ),

          // --- 2. Main Content ---
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  
                  const Text(
                    "Pay Bills",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WunzaColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  
                  // Service Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                    children: [
                      _buildServiceItem(context, "Airtime & Data", Icons.phonelink_ring, Colors.blue, Routes.serviceProviders, {'type': 'Airtime & Data'}),
                      _buildServiceItem(
                        context,
                        "Africom Internet",
                        Icons.language,
                        Colors.green,
                        Routes.utilityBills,
                        {'type': UtilityBillType.internet},
                        imagePath: 'assets/images/africom_logo.png',
                        onTap: () async {
                          const url = 'https://selfservice.ai.co.zw/recharge';
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                      _buildServiceItem(context, "Utilities", Icons.category, Colors.orange, Routes.utilityBills, {}),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    "Recent Transactions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WunzaColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  
                  // Recent List
                  Consumer<UtilityBillsViewModel>(
                    builder: (context, viewModel, child) {
                      if (viewModel.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (viewModel.payments.isEmpty) {
                        return const Center(
                          child: Text(
                            "No recent transactions",
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: viewModel.payments.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          // Show most recent first (assuming list might be chronological, otherwise sorting needed)
                          // For now taking standard list order, or reverse it if needed.
                          // Let's assume most recent are added at the end, so we reverse index
                          final reversedIndex = viewModel.payments.length - 1 - index;
                          final payment = viewModel.payments[reversedIndex];
                          
                          // Format bill type name (e.g. UtilityBillType.airtime -> "Airtime")
                          String subtitle = payment.billType.toString().split('.').last;
                          subtitle = subtitle[0].toUpperCase() + subtitle.substring(1);
                          
                          return _buildRecentTransaction(
                            payment.provider, 
                            subtitle, 
                            "-\$${payment.amount.toStringAsFixed(2)}"
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildServiceItem(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String route,
    Map<String, dynamic> args, {
    String? imagePath,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pushNamed(context, route, arguments: args),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        opacity: 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: imagePath != null ? const EdgeInsets.all(8) : const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: imagePath != null
                  ? Image.asset(
                      imagePath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    )
                  : Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransaction(String title, String subtitle, String amount) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      opacity: 0.5,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        ],
      ),
    );
  }
}