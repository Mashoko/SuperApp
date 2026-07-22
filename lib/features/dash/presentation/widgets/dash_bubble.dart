import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme.dart';
import '../viewmodels/dash_viewmodel.dart';
import 'dash_sheet.dart';

class DashBubble extends StatelessWidget {
  const DashBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final showNudge = context.watch<DashViewModel>().showNudge;
    return GestureDetector(
      onTap: () => showDashSheet(context),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: WunzaColors.glidePrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
            if (showNudge)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  key: const Key('dash_nudge_dot'),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: WunzaColors.glideAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
