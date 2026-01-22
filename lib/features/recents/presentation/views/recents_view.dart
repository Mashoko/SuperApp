import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../dialpad/presentation/viewmodels/dialpad_viewmodel.dart';

class RecentsView extends StatelessWidget {
  const RecentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<DialpadViewModel>(
        builder: (context, viewModel, child) {
          final recents = viewModel.recents;

          if (recents.isEmpty) {
            return const Center(
              child: Text(
                'No recent calls',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: recents.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = recents[index];
              final isMissed = item.isMissed;
              final timeString = DateFormat('MMM d, h:mm a').format(item.timestamp);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isMissed ? Colors.red[50] : Colors.green[50],
                      child: Icon(
                        isMissed ? Icons.call_missed : Icons.call_made,
                        color: isMissed ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name ?? item.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (item.name != null)
                            Text(
                              item.number,
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      timeString,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
