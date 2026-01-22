import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/calling/presentation/viewmodels/calling_viewmodel.dart';
import 'package:intl/intl.dart';

class RecentsView extends StatelessWidget {
  const RecentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallingViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.callHistory.isEmpty) {
          return const Center(
            child: Text('No recent calls'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: viewModel.callHistory.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final call = viewModel.callHistory[index];
            final isMissed = call.status.toString().contains('missed');
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isMissed ? Colors.red[50] : const Color(0xFFE0F2F1),
                child: Icon(
                  isMissed ? Icons.call_missed : Icons.call_made,
                  color: isMissed ? Colors.red : const Color(0xFF00897B),
                ),
              ),
              title: Text(
                call.receiverId,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMissed ? Colors.red : Colors.black,
                ),
              ),
              subtitle: Text(
                DateFormat('MMM d, h:mm a').format(call.startTime ?? DateTime.now()),
              ),
              trailing: const Icon(Icons.info_outline, color: Color(0xFF00897B)),
            );
          },
        );
      },
    );
  }
}
