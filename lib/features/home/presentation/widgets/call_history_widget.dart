import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/recent_call.dart';
import 'package:mvvm_sip_demo/shared/widgets/glide_card.dart';

/// Recent telecom activity: type, contact, duration, time, and call-back.
class CallHistoryWidget extends StatelessWidget {
  const CallHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DialpadViewModel>(
      builder: (context, dialpadViewModel, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, Routes.callHistory),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'View all',
                      style: TextStyle(
                        color: WunzaColors.glidePrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (dialpadViewModel.recents.isEmpty)
              _buildEmptyState(context)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dialpadViewModel.recents.take(6).length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final call = dialpadViewModel.recents[index];
                  final timeStr =
                      DateFormat('MMM d · h:mm a').format(call.timestamp);
                  final durationStr = _formatCallDuration(call);

                  final meta = _callVisuals(call);

                  return GlideCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: meta.tint.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            meta.icon,
                            color: meta.tint,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                call.name ?? call.number,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    durationStr,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final callViewModel =
                                Provider.of<CallViewModel>(
                              context,
                              listen: false,
                            );
                            final error = await callViewModel.makeCall(
                              call.number,
                              voiceOnly: true,
                            );
                            if (!context.mounted || error == null) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              'Call back',
                              style: TextStyle(
                                color: WunzaColors.glideAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return GlideCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No recent activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Calls you make or receive will show up here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, Routes.calling),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Start a call',
                  style: TextStyle(
                    color: WunzaColors.glidePrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCallDuration(RecentCall call) {
  if (call.isMissed) return 'Missed';
  final s = call.durationSeconds;
  if (s == null || s <= 0) return '—';
  final m = Duration(seconds: s);
  if (m.inHours >= 1) {
    return '${m.inHours}h ${m.inMinutes.remainder(60)}m';
  }
  if (m.inMinutes >= 1) {
    return '${m.inMinutes}m ${m.inSeconds.remainder(60)}s';
  }
  return '${s}s';
}

({IconData icon, Color tint}) _callVisuals(RecentCall call) {
  if (call.isMissed) {
    return (icon: Icons.call_missed_outgoing, tint: Colors.redAccent);
  }
  if (call.direction == 'incoming') {
    return (icon: Icons.call_received, tint: WunzaColors.glidePrimary);
  }
  return (icon: Icons.call_made, tint: const Color(0xFF2E7D32));
}
