import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class OrderCompletionView extends StatelessWidget {
  const OrderCompletionView({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock order status
    const int currentStep = 1; // Processing

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Stepper
            Container(
              color: WunzaColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusStep(context, 'Placed', 0, currentStep),
                  _buildStatusLine(context, 0, currentStep),
                  _buildStatusStep(context, 'Processing', 1, currentStep),
                  _buildStatusLine(context, 1, currentStep),
                  _buildStatusStep(context, 'Pickup', 2, currentStep),
                  _buildStatusLine(context, 2, currentStep),
                  _buildStatusStep(context, 'Collected', 3, currentStep),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Shop Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WunzaColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.store, color: WunzaColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Super Mart',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Order #123456',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.message_outlined, color: WunzaColors.primary),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_outlined, color: WunzaColors.primary),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items List
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WunzaColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildItemRow('Fresh Milk 1L', 2, 5.00),
                  const Divider(),
                  _buildItemRow('Whole Wheat Bread', 1, 3.00),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Order Summary
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WunzaColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', 8.00),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Shipping', 2.00),
                  const Divider(height: 24),
                  _buildSummaryRow('Total', 10.00, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStep(BuildContext context, String label, int stepIndex, int currentStep) {
    final bool isCompleted = stepIndex <= currentStep;
    final bool isCurrent = stepIndex == currentStep;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted ? WunzaColors.primary : Colors.grey[300],
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: WunzaColors.primary, width: 2) : null,
          ),
          child: Icon(
            Icons.check,
            size: 16,
            color: isCompleted ? Colors.white : Colors.grey[500],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isCompleted ? WunzaColors.primary : Colors.grey[500],
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ],
    );
  }

  Widget _buildStatusLine(BuildContext context, int stepIndex, int currentStep) {
    final bool isCompleted = stepIndex < currentStep;
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? WunzaColors.primary : Colors.grey[300],
      ),
    );
  }

  Widget _buildItemRow(String name, int qty, double price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${qty}x $name'),
          Text('\$${price.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 14,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 14,
            color: isTotal ? WunzaColors.primary : null,
          ),
        ),
      ],
    );
  }
}
