import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/inject.dart';
import '../viewmodels/account_summary_viewmodel.dart';
import 'share_airtime_view.dart';
import 'voucher_recharge_view.dart';

class AccountSummaryView extends StatefulWidget {
  const AccountSummaryView({super.key});

  @override
  State<AccountSummaryView> createState() => _AccountSummaryViewState();
}

class _AccountSummaryViewState extends State<AccountSummaryView> {
  late AccountSummaryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<AccountSummaryViewModel>();
    _viewModel.loadCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFBD34D1)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Account Services',
            style: TextStyle(
              color: Color(0xFFBD34D1),
              fontWeight: FontWeight.w400,
              fontSize: 18,
            ),
          ),
          centerTitle: false,
          leadingWidth: 40,
        ),
        body: Consumer<AccountSummaryViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      viewModel.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => viewModel.loadCurrentUser(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final data = viewModel.summary;
            final username = data?['username'] as String? ?? '—';
            final alias = data?['alias'] as String? ?? '—';
            final statusRaw = data?['status'];
            final statusStr = statusRaw?.toString().split('.').last ?? 'UNKNOWN';
            final isOk = statusStr == 'SUCCESS' || statusStr == 'INFORMATION';
            final statusColor = isOk ? const Color(0xFF00C853) : Colors.red;

            final numberFormat = NumberFormat('#,##0.00', 'en_US');

            return RefreshIndicator(
              onRefresh: () => viewModel.loadCurrentUser(),
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  // Account Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.person_outline,
                                  color: Colors.white, size: 35),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Account',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  username,
                                  style: const TextStyle(
                                    color: Color(0xFFBD34D1),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Alias: ',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 14),
                                      ),
                                      TextSpan(
                                        text: alias,
                                        style: const TextStyle(
                                            color: Color(0xFFBD34D1),
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // Status Indicator
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Status: ',
                                    style: TextStyle(
                                        color: statusColor, fontSize: 14),
                                  ),
                                  TextSpan(
                                    text: statusStr,
                                    style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // Balances Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFCE4EC).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Balances',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Minutes:',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    viewModel.formattedMinutes,
                                    style: const TextStyle(
                                      color: Color(0xFFBD34D1),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'RTGS:',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                  viewModel.paymentsLoading
                                      ? const SizedBox(
                                          width: 72,
                                          height: 16,
                                          child: LinearProgressIndicator(
                                            borderRadius: BorderRadius.all(Radius.circular(4)),
                                            color: Color(0xFFBD34D1),
                                            backgroundColor: Color(0xFFEDE7F6),
                                          ),
                                        )
                                      : Text(
                                          viewModel.paymentsBalance != null
                                              ? '\$${numberFormat.format(viewModel.paymentsBalance)}'
                                              : '—',
                                          style: const TextStyle(
                                            color: Color(0xFFBD34D1),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Dashboard Header
                  const Text(
                    'My Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Dashboard Items
                  _buildDashboardItem(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Voucher recharge',
                    iconBgColor: const Color(0xFFE040FB),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VoucherRechargeView()),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildDashboardItem(
                    icon: Icons.send_to_mobile,
                    title: 'Share airtime',
                    iconBgColor: const Color(0xFF00C853),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShareAirtimeView()),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardItem({
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: iconBgColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF455A64),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFBD34D1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
