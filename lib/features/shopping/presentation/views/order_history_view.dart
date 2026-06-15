import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/services/otp_auth_service.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'package:mvvm_sip_demo/models/shopping/order.dart';
import 'package:mvvm_sip_demo/models/shopping/order_status.dart';

class OrderHistoryView extends StatefulWidget {
  const OrderHistoryView({super.key});

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final creds = await getIt<OtpAuthService>().getStoredCredentials();
      final userId = creds?['username'] ?? '';
      if (!mounted) return;
      Provider.of<ShoppingViewModel>(context, listen: false)
          .loadOrders(userId: userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Consumer<ShoppingViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(vm.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final creds =
                          await getIt<OtpAuthService>().getStoredCredentials();
                      final userId = creds?['username'] ?? '';
                      if (!context.mounted) return;
                      Provider.of<ShoppingViewModel>(context, listen: false)
                          .loadOrders(userId: userId);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (vm.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No orders yet',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Your order history will appear here.',
                      style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.orders.length,
            itemBuilder: (context, index) {
              final order = vm.orders[index];
              return _OrderCard(order: order);
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered: return Colors.green;
      case OrderStatus.cancelled: return Colors.red;
      case OrderStatus.shipped: return Colors.blue;
      default: return WunzaColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    final date = DateFormat('MMM d, yyyy').format(order.createdAt);
    final itemCount = order.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WunzaColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.orderId.split('_').last.substring(0, 6).toUpperCase()}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.value[0].toUpperCase() +
                      order.status.value.substring(1),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$itemCount ${itemCount == 1 ? 'Item' : 'Items'} · \$${order.totalAmount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Placed on $date',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: WunzaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
