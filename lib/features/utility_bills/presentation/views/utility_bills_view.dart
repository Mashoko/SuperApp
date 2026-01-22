
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/models/utility_bills/bill_type.dart';
import 'package:mvvm_sip_demo/features/utility_bills/presentation/viewmodels/utility_bills_viewmodel.dart';

class UtilityBillsView extends StatefulWidget {
  const UtilityBillsView({super.key});

  @override
  State<UtilityBillsView> createState() => _UtilityBillsViewState();
}

class _UtilityBillsViewState extends State<UtilityBillsView> {
  final TextEditingController _userIdController =
      TextEditingController(text: 'user1');
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  UtilityBillType? _selectedType;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final type = args['type'] as UtilityBillType?;
      final provider = args['provider'] as String?;
      if (type != null) {
        setState(() {
          _selectedType = type;
        });
      }
      if (provider != null) {
        _providerController.text = provider;
      }
    }
    
    // Load payments after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = Provider.of<UtilityBillsViewModel>(context, listen: false);
      vm.loadPayments(_userIdController.text);
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _accountController.dispose();
    _providerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment(UtilityBillsViewModel vm) async {
    if (_selectedType == null) return;

    final userId = _userIdController.text.trim();
    final account = _accountController.text.trim();
    final provider = _providerController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (userId.isEmpty || account.isEmpty || provider.isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields with valid values')),
      );
      return;
    }

    bool success = false;
    switch (_selectedType!) {
      case UtilityBillType.electricity:
        success = await vm.payElectricity(
          userId: userId,
          provider: provider,
          meterNumber: account,
          amount: amount,
        );
        break;
      case UtilityBillType.water:
        success = await vm.payWater(
          userId: userId,
          provider: provider,
          accountNumber: account,
          amount: amount,
        );
        break;
      case UtilityBillType.internet:
        success = await vm.payInternet(
          userId: userId,
          provider: provider,
          accountNumber: account,
          amount: amount,
        );
        break;
      case UtilityBillType.airtime:
        success = await vm.payAirtime(
          userId: userId,
          network: provider,
          phoneNumber: account,
          amount: amount,
        );
        break;
      default:
        // For now, just show a message or handle generically
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_labelForType(_selectedType!)} payment not implemented yet')),
        );
        return; // Exit early
    }

    if (success) {
      _amountController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment successful')),
        );
      }
    } else if (vm.errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.errorMessage!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedType != null ? _labelForType(_selectedType!) : 'Utility Bills'),
      ),
      body: Consumer<UtilityBillsViewModel>(
        builder: (context, viewModel, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Only show chips if type is NOT pre-selected (i.e. if we came here directly, which shouldn't happen in new flow but good fallback)
                // Actually, in the new flow, we always come with a type. But let's keep it flexible.
                // If we want to hide chips when type is selected via arguments, we can check a flag or just check if _selectedType is already set initially.
                // For now, let's hide the chips if we are in the "details" mode.
                if (_selectedType == null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: UtilityBillType.values
                        .where((t) => [
                              UtilityBillType.electricity,
                              UtilityBillType.water,
                            ].contains(t)) // Only show relevant options
                        .map((type) {
                      final selected = type == _selectedType;
                      final label = _labelForType(type);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            avatar: selected
                                ? null
                                : Icon(_iconForType(type), size: 18),
                            label: Text(label),
                            selected: selected,
                            showCheckmark: true,
                            onSelected: (_) {
                              setState(() {
                                _selectedType = type;
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_selectedType != null) ...[
                  TextField(
                    controller: _accountController,
                    decoration: InputDecoration(
                      labelText: _selectedType == UtilityBillType.airtime
                          ? 'Phone Number'
                          : _selectedType == UtilityBillType.electricity
                              ? 'Meter Number'
                              : 'Account Number',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _providerController,
                    decoration: InputDecoration(
                      labelText: _selectedType == UtilityBillType.airtime
                          ? 'Network (e.g. Econet)'
                          : 'Provider',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (USD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: viewModel.isLoading
                        ? null
                        : () => _submitPayment(viewModel),
                    child: viewModel.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Pay Bill'),
                  ),
                  const SizedBox(height: 24),
                  if (viewModel.errorMessage != null)
                    Card(
                      color: Colors.red[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          viewModel.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Recent Payments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (viewModel.payments.isEmpty)
                  const Text('No payments yet'),
                ...viewModel.payments.map((p) => ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                          '\$${p.amount.toStringAsFixed(2)} - ${_labelForType(p.billType)}'),
                      subtitle: Text(
                          '${p.provider} • ${p.accountOrMeter}\n${p.timestamp}'),
                      isThreeLine: true,
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  String _labelForType(UtilityBillType type) {
    switch (type) {
      case UtilityBillType.electricity:
        return 'Electricity';
      case UtilityBillType.water:
        return 'Water';
      case UtilityBillType.internet:
        return 'Internet';
      case UtilityBillType.airtime:
        return 'Airtime';
      case UtilityBillType.sendMoney:
        return 'Send Money';
      case UtilityBillType.remittances:
        return 'Remittances';
      case UtilityBillType.withdraw:
        return 'Withdraw';
      case UtilityBillType.topUp:
        return 'Top-up';
      case UtilityBillType.medical:
        return 'Medical';
      case UtilityBillType.zipit:
        return 'Zipit';
      case UtilityBillType.schools:
        return 'Schools';
      case UtilityBillType.funeral:
        return 'Funeral';
      case UtilityBillType.security:
        return 'Security';
      case UtilityBillType.insurance:
        return 'Insurance';
    }
  }

  IconData _iconForType(UtilityBillType type) {
    switch (type) {
      case UtilityBillType.electricity:
        return Icons.bolt;
      case UtilityBillType.water:
        return Icons.water_drop;
      case UtilityBillType.internet:
        return Icons.wifi;
      case UtilityBillType.airtime:
        return Icons.phone_android;
      case UtilityBillType.sendMoney:
        return Icons.send;
      case UtilityBillType.remittances:
        return Icons.public;
      case UtilityBillType.withdraw:
        return Icons.atm;
      case UtilityBillType.topUp:
        return Icons.store;
      case UtilityBillType.medical:
        return Icons.medical_services;
      case UtilityBillType.zipit:
        return Icons.flash_on;
      case UtilityBillType.schools:
        return Icons.school;
      case UtilityBillType.funeral:
        return Icons.church;
      case UtilityBillType.security:
        return Icons.security;
      case UtilityBillType.insurance:
        return Icons.umbrella;
    }
  }
}
