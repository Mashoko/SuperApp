import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/call_view_model.dart';
import 'account_screen.dart';
import 'phone_dialer_screen.dart';
import 'static_placeholder_screen.dart';

class DialerShell extends StatefulWidget {
  const DialerShell({super.key});

  @override
  State<DialerShell> createState() => _DialerShellState();
}

class _DialerShellState extends State<DialerShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages = <Widget>[
    const PhoneDialerScreen(),
    const StaticPlaceholderScreen(
      icon: Icons.history,
      title: 'Recents',
      message: 'Your recent calls will show up here.',
    ),
    const StaticPlaceholderScreen(
      icon: Icons.contacts_rounded,
      title: 'Contacts',
      message: 'Sync contacts to see them here.',
    ),
    const StaticPlaceholderScreen(
      icon: Icons.network_check,
      title: 'Speed Test',
      message: 'Network test results will appear here.',
    ),
  ];

  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'account':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        );
        break;
      case 'about':
        showAboutDialog(
          context: context,
          applicationName: 'CatchCall',
          applicationVersion: '1.0.0',
          children: const [
            Text(
              'CatchCall is a MVVM Flutter client for the Afri Com userService.',
            ),
          ],
        );
        break;
      case 'refresh':
        PhoneDialerScreen.refreshBalances(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad),
            label: 'Phone',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Recents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: 'Speed Test',
          ),
        ],
      ),
      appBar: _currentIndex == 0
          ? PhoneDialerAppBar(
              onMenuSelection: (value) => _handleMenuSelection(value, context),
            )
          : null,
    );
  }
}

class PhoneDialerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PhoneDialerAppBar({
    super.key,
    required this.onMenuSelection,
  });

  final void Function(String value) onMenuSelection;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      toolbarHeight: 72,
      leadingWidth: 48,
      leading: IconButton(
        icon: const Icon(Icons.search),
        onPressed: () {},
      ),
      titleSpacing: 0,
      title: Consumer<CallViewModel>(
        builder: (_, vm, __) {
          final summary = vm.accountSummary;
          final voiceText = summary?.infoMessage ?? 'Voice Bal: --';
          final balanceText =
              summary != null ? 'Balance: ${summary.formattedBalance}' : 'Balance: --';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 10, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      voiceText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                balanceText,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: onMenuSelection,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'account',
              child: Text('Account'),
            ),
            PopupMenuItem(
              value: 'about',
              child: Text('About'),
            ),
            PopupMenuItem(
              value: 'refresh',
              child: Text('Refresh'),
            ),
          ],
        ),
      ],
    );
  }
}

