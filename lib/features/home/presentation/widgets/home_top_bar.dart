import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.userName,
    required this.walletChipLabel,
    this.notificationCount = 0,
    this.onNotificationsTap,
    this.onAvatarTap,
  });

  final String userName;
  final String walletChipLabel;
  final int notificationCount;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final horizontalPad = (mq.size.width * 0.04).clamp(16.0, 24.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $userName',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: WunzaColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                _WalletChip(label: walletChipLabel),
              ],
            ),
          ),
          badges.Badge(
            showBadge: notificationCount > 0,
            badgeContent: Text(
              notificationCount > 9 ? '9+' : '$notificationCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            badgeStyle: const badges.BadgeStyle(
              badgeColor: WunzaColors.glideAccent,
              padding: EdgeInsets.all(4),
            ),
            child: IconButton(
              onPressed: onNotificationsTap,
              icon: const Icon(Icons.notifications_outlined),
              color: WunzaColors.glidePrimary,
            ),
          ),
          Material(
            color: WunzaColors.glideNeutral,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAvatarTap,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: (mq.size.width * 0.055).clamp(20.0, 26.0),
                  backgroundColor: WunzaColors.glidePrimary.withValues(alpha: 0.15),
                  child: _avatarChild(userName, mq.size.width),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _avatarChild(String userName, double screenWidth) {
  final initial = userName.isNotEmpty ? userName[0] : '';
  final isDigit = initial.isNotEmpty && RegExp(r'\d').hasMatch(initial);
  final iconSize = (screenWidth * 0.055).clamp(20.0, 26.0);

  if (isDigit || initial.isEmpty) {
    return Icon(Icons.person, color: WunzaColors.glidePrimary, size: iconSize);
  }
  return Text(
    initial.toUpperCase(),
    style: const TextStyle(
      color: WunzaColors.glidePrimary,
      fontWeight: FontWeight.bold,
    ),
  );
}

class _WalletChip extends StatelessWidget {
  const _WalletChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: WunzaColors.glidePrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 16,
            color: WunzaColors.glidePrimary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: WunzaColors.glidePrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
