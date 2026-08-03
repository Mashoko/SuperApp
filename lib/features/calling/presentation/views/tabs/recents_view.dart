import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/call_log_status.dart';

class RecentsView extends StatelessWidget {
  const RecentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DialpadViewModel>(
      builder: (context, viewModel, child) {
        final recents = viewModel.recents;

        if (recents.isEmpty) {
          return const Center(
            child: Text('No recent calls'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: recents.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final call = recents[index];
            final visuals = _visualsFor(call.status);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: visuals.tint.withValues(alpha: 0.12),
                child: Icon(visuals.icon, color: visuals.tint),
              ),
              title: Text(
                call.name ?? call.number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: call.isMissed ? Colors.red : Colors.black,
                ),
              ),
              subtitle: Text(
                DateFormat('MMM d, h:mm a').format(call.timestamp),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Color(0xFF00897B)),
                onPressed: () async {
                  final callViewModel =
                      Provider.of<CallViewModel>(context, listen: false);
                  final error = await callViewModel.makeCall(
                    call.number,
                    voiceOnly: true,
                  );
                  if (!context.mounted || error == null) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

({IconData icon, Color tint}) _visualsFor(CallLogStatus status) {
  switch (status) {
    case CallLogStatus.missed:
      return (icon: Icons.call_missed, tint: Colors.red);
    case CallLogStatus.declined:
      return (icon: Icons.call_missed_outgoing, tint: Colors.orange);
    case CallLogStatus.failed:
      return (icon: Icons.error_outline, tint: Colors.red);
    case CallLogStatus.completed:
      return (icon: Icons.call_made, tint: const Color(0xFF00897B));
  }
}
