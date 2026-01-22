import 'package:flutter/material.dart';

class AccountServicesView extends StatelessWidget {
  const AccountServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Services',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 32),
          
          // Profile Section
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1), // Light teal
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00897B), width: 2),
                ),
                child: const Icon(Icons.person, size: 40, color: Color(0xFF00897B)),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account +26378342458',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Registered Account',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    'Status: Registered',
                    style: TextStyle(fontSize: 14, color: Color(0xFF00897B)),
                  ),
                  Text(
                    'Minutes: 1 hr 35 min',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    'RTGS: -5:01',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          
          const Text(
            'My Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Dashboard Items
          _buildDashboardItem(Icons.attach_money, 'Voucher recharge'),
          const Divider(height: 1),
          _buildDashboardItem(Icons.attach_money, 'Share airtime'),
          
          const SizedBox(height: 48),
          
          // CatchApp Logo/Branding
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.phone, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CatchApp',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00897B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00897B), size: 28),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF00897B)),
        ],
      ),
    );
  }
}
