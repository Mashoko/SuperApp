import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account_summary.dart';
import '../../models/operation_state.dart';
import '../../viewmodels/call_view_model.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final callViewModel = context.read<CallViewModel>();
    _usernameController = TextEditingController(text: callViewModel.lastUsername);
    _passwordController = TextEditingController(text: callViewModel.lastPassword);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refreshAccount(BuildContext context) async {
    final callViewModel = context.read<CallViewModel>();
    await callViewModel.refreshAccount(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callViewModel = context.watch<CallViewModel>();
    final summary = callViewModel.accountSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Services'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _AccountHeader(summary: summary),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Account / Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: callViewModel.accountState.isLoading
                ? null
                : () => _refreshAccount(context),
            child: callViewModel.accountState.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Refresh'),
          ),
          const SizedBox(height: 12),
          _StatusText(state: callViewModel.accountState),
          const SizedBox(height: 24),
          Text(
            'My Dashboard',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: const [
                _DashboardTile(
                  icon: Icons.attach_money,
                  title: 'Voucher recharge',
                ),
                Divider(height: 0),
                _DashboardTile(
                  icon: Icons.ios_share,
                  title: 'Share airtime',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({this.summary});

  final AccountSummary? summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.person, color: Colors.green, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary != null ? 'Account ${summary!.username}' : 'No account selected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (summary?.alias.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Alias No: ${summary!.alias}'),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Status: ${summary?.status.toUpperCase() ?? 'UNKNOWN'}',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Minutes: ${summary?.infoMessage ?? '--'}',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'RTGS: ${summary?.formattedBalance ?? '--'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.state});

  final OperationState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == OperationStatus.idle || state.message == null) {
      return const SizedBox.shrink();
    }

    Color color;
    switch (state.status) {
      case OperationStatus.success:
        color = Colors.green;
        break;
      case OperationStatus.error:
        color = Theme.of(context).colorScheme.error;
        break;
      case OperationStatus.loading:
        color = Colors.blueGrey;
        break;
      case OperationStatus.idle:
        color = Colors.black54;
        break;
    }

    return Text(
      state.message!,
      style: TextStyle(color: color),
    );
  }
}

