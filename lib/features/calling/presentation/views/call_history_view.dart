import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:mvvm_sip_demo/features/calling/presentation/views/widgets/call_history_tile.dart';
import 'package:mvvm_sip_demo/features/recents/data/models/recent_call.dart';
import 'package:mvvm_sip_demo/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/quick_dialer_overlay.dart';

class CallHistoryView extends StatefulWidget {
  const CallHistoryView({super.key});

  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DialpadViewModel>(context, listen: false).loadRecents();
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Call History", style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.transparent, // Transparent for glass effect
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
               // ---------------------------------------------
              // 2. LIQUID GLASS TABS IMPLEMENTATION
              // ---------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25), // Pill shape for the whole bar
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // The Blur Effect
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1), // Translucent background
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: Colors.white, // Active tab bubble
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [
                             BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                          ]
                        ),
                        labelColor: WunzaColors.indigo,
                        unselectedLabelColor: Colors.grey.shade600,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: const [
                           Tab(text: "All"),
                           Tab(text: "Incoming"),
                           Tab(text: "Outgoing"),
                           Tab(text: "Missed"),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ---------------------------------------------
              // 3. FLAT SEARCH BAR
              // ---------------------------------------------
               Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100, // Light grey background
                  borderRadius: BorderRadius.circular(24), // Pill shape
                  // No box shadow for a cleaner, flatter look
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    hintText: "Search calls...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            
            // Tab Views
            Expanded(
              child: Consumer<DialpadViewModel>(
                builder: (context, dialpadViewModel, child) {
                  final allCalls = dialpadViewModel.recents;
                  final filteredBySearch = allCalls.where((call) {
                    final query = _searchQuery.toLowerCase();
                    final name = call.name?.toLowerCase() ?? '';
                    final number = call.number.toLowerCase();
                    return name.contains(query) || number.contains(query);
                  }).toList();

                  return TabBarView(
                    children: [
                      _buildCallList(context, filteredBySearch), // All
                      _buildCallList(context, filteredBySearch.where((call) => call.direction == 'incoming' && !call.isMissed).toList()), // Incoming
                      _buildCallList(context, filteredBySearch.where((call) => call.direction == 'outgoing').toList()), // Outgoing
                      _buildCallList(context, filteredBySearch.where((call) => call.isMissed).toList()), // Missed
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          // Navigate to Dialpad or open a modal
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.9, 
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: const DialPadScreen(),
            ),
          );
        },
        child: Container(
          width: 64, // Fixed size for the circle
          height: 64,
          decoration: BoxDecoration(
            // Gradient background for the circular shape
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2196F3), // Blue
                Color(0xFF1976D2), // Darker Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.dialpad,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildCallList(BuildContext context, List<RecentCall> calls) {
    if (calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No calls found",
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Group calls by date
    final groupedCalls = <String, List<RecentCall>>{};
    
    for (var call in calls) {
      final dateKey = _getDateKey(call.timestamp);
      if (!groupedCalls.containsKey(dateKey)) {
        groupedCalls[dateKey] = [];
      }
      groupedCalls[dateKey]!.add(call);
    }

    final sortedKeys = groupedCalls.keys.toList(); // Should be naturally sorted by insertion if processed chronologically from recents? 
    // Usually recents are date sorted descending. If not, manual sort needed.
    // Assuming dialpadViewModel.recents is sorted descending.

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final callsForDate = groupedCalls[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ...callsForDate.map((call) {
              final isMissed = call.isMissed;
              final direction = call.direction;
              
              String callType = 'incoming';
              if (isMissed) {
                callType = 'missed';
              } else if (direction == 'outgoing') {
                callType = 'outgoing';
              }

              // Determine date label
              // If Today/Yesterday, show time. Else show Date.
              String dateLabel;
              if (dateKey == 'Today' || dateKey == 'Yesterday') {
                dateLabel = DateFormat('h:mm a').format(call.timestamp);
              } else {
                 dateLabel = DateFormat('MMM d, h:mm a').format(call.timestamp);
              }

              return CallHistoryTile(
                nameOrNumber: call.name ?? call.number,
                dateLabel: dateLabel,
                callType: callType,
                onTap: () {
                   final callViewModel = Provider.of<CallViewModel>(context, listen: false);
                   // final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                   // final callerId = authViewModel.currentUser?['username'] ?? 'unknown'; // fallback
                   callViewModel.makeCall(call.number, voiceOnly: true);
                },
              );
            }),
          ],
        );
      },
    );
  }

  String _getDateKey(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(timestamp);
    }
  }
}
