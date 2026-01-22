import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mvvm_sip_demo/core/routes.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';

class CallHistoryWidget extends StatelessWidget {
  const CallHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DialpadViewModel>(
      builder: (context, dialpadViewModel, child) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent History",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: WunzaColors.textPrimary),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.callHistory),
                  child: const Text("View All",
                      style: TextStyle(color: WunzaColors.indigo)),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (dialpadViewModel.recents.isEmpty)
              _buildEmptyState(context)
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dialpadViewModel.recents.take(5).length,
                itemBuilder: (context, index) {
                  final call = dialpadViewModel.recents[index];
                  final isMissed = call.isMissed;
                  final formattedDate =
                      DateFormat('MMM d, h:mm a').format(call.timestamp);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      opacity: 0.5,
                      borderRadius: 16,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMissed
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isMissed ? Icons.call_missed : Icons.call_made,
                              color: isMissed ? Colors.red : Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  call.name ?? call.number,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: WunzaColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                            IconButton(
                            icon: const Icon(Icons.call,
                                color: WunzaColors.indigo),
                            onPressed: () {
                               // Direct call using CallViewModel
                               final callViewModel = Provider.of<CallViewModel>(context, listen: false);
                               callViewModel.makeCall(call.number, voiceOnly: true);
                            },
                          ),
                        ],
                      ),
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
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      opacity: 0.5,
      borderRadius: 16,
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              "No recent calls",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, Routes.calling),
              child: const Text("Start a call", style: TextStyle(color: WunzaColors.indigo)),
            )
          ],
        ),
      ),
    );
  }
}
