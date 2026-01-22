import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'package:mvvm_sip_demo/core/routes.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final TextEditingController _userIdController = TextEditingController(text: 'user1');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  void _loadDashboard() {
    final viewModel = Provider.of<DashboardViewModel>(context, listen: false);
    viewModel.loadDashboard(_userIdController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.pushNamed(context, Routes.profile);
            },
          ),
        ],
      ),
      body: Consumer<DashboardViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.dashboardData.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${viewModel.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDashboard,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = viewModel.dashboardData;
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDashboard,
                    child: const Text('Load Dashboard'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadDashboard(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const SizedBox(height: 24),
                  _buildSection(
                    '📞 Calling',
                    Colors.blue,
                    [
                      _buildStatCard('Total Calls', data['calling']['total_calls'].toString()),
                      _buildStatCard('Total Calls', data['calling']['total_calls'].toString()),
                      _buildMissedCallsCard(int.tryParse(data['calling']['missed_calls'].toString()) ?? 0),
                      _buildStatCard('Total Duration', '${(data['calling']['total_duration_seconds'] as num?)?.toStringAsFixed(2) ?? '0.00'}s'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '🛒 Shopping',
                    Colors.green,
                    [
                      _buildStatCard('Cart Items', data['shopping']['cart_items'].toString()),
                      _buildStatCard('Cart Total', '\$${(data['shopping']['cart_total'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                      _buildStatCard('Total Orders', data['shopping']['total_orders'].toString()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '💸 Payments',
                    WunzaColors.primary,
                    [
                      _buildStatCard('Total Spent', '\$${(data['payments']['total_spent'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                      _buildStatCard('Total Payments', data['payments']['total_payments'].toString()),
                      _buildStatCard('Last Payment', '\$${(data['payments']['last_payment_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, Color color, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    // Calculate width for 2 columns: Screen width - body padding (32) - card padding (32) - spacing (16) / 2
    final width = (MediaQuery.of(context).size.width - 64 - 16) / 2;
    return SizedBox(
      width: width,
      child: Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildMissedCallsCard(int missedCalls) {
    // Calculate width same as _buildStatCard
    final width = (MediaQuery.of(context).size.width - 64 - 16) / 2;
    final bool hasMissedCalls = missedCalls > 0;
    
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FD), // Light blueish grey from screenshot
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon and More Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0E7FF), // Icon background (lighter blue)
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_missed, 
                    color: Color(0xFF3B82F6), // Blue icon color
                    size: 20,
                  ),
                ),
                const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            
            // Label
            const Text(
              "Missed",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575), // Grey text
              ),
            ),
            const SizedBox(height: 4),
            
            // Count
            Text(
              missedCalls.toString(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, Routes.calling); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC7D2FE).withValues(alpha: 0.5), // Soft button background
                  foregroundColor: const Color(0xFF3B82F6), // Blue text
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  hasMissedCalls ? "Call Back" : "Start Calling",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

