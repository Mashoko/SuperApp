import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class CallHistoryTile extends StatelessWidget {
  final String nameOrNumber;
  final String dateLabel; // e.g., "Feb 10, 10:01 AM"
  final String callType; // "incoming", "outgoing", "missed"
  final VoidCallback onTap;

  const CallHistoryTile({
    super.key,
    required this.nameOrNumber,
    required this.dateLabel,
    required this.callType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine Color and Icon based on call type
    Color typeColor;
    IconData typeIcon;
    
    switch (callType) {
      case 'missed':
        typeColor = Colors.red;
        typeIcon = Icons.call_missed;
        break;
      case 'outgoing':
        typeColor = Colors.green;
        typeIcon = Icons.call_made;
        break;
      default: // incoming
        typeColor = Colors.blue; 
        typeIcon = Icons.call_received;
    }

    // Check if we should show a letter or the generic icon
    // If it looks like a phone number (digits), use Icon. Otherwise use Initial.
    final bool showGenericIcon = RegExp(r'^[0-9+]').hasMatch(nameOrNumber);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // 1. Avatar / Circle Background
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        child: !showGenericIcon && nameOrNumber.isNotEmpty
            ? Text(
                nameOrNumber.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: WunzaColors.premiumText, 
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : const Icon(Icons.person, color: Colors.grey),
      ),
      // 2. Contact Name or Number
      title: Text(
        nameOrNumber,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: WunzaColors.textPrimary),
      ),
      // 3. Call Type and Date Row
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            Icon(typeIcon, size: 14, color: typeColor),
            const SizedBox(width: 4),
            Text(
              callType.capitalize(), 
              style: TextStyle(color: typeColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(" • $dateLabel", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
      // 4. Call Button on Right
      trailing: IconButton(
        icon: const Icon(Icons.call, color: WunzaColors.indigo),
        onPressed: onTap,
      ),
    );
  }
}

// Helper extension for capitalizing text
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
