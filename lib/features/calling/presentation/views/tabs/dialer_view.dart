import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';

class DialerView extends StatefulWidget {
  const DialerView({super.key});

  @override
  State<DialerView> createState() => _DialerViewState();
}

class _DialerViewState extends State<DialerView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onKeyPress(String value) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(
      selection.start >= 0 ? selection.start : text.length,
      selection.end >= 0 ? selection.end : text.length,
      value,
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (selection.start >= 0 ? selection.start : text.length) + value.length),
    );
  }

  void _onBackspace() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.start >= 0 && selection.end > selection.start) {
        // Selection delete
        final newText = text.replaceRange(selection.start, selection.end, '');
         _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start),
        );
    } else if (text.isNotEmpty) {
      // Backspace
      final offset = selection.start >= 0 ? selection.start : text.length;
      if (offset > 0) {
        final newText = text.replaceRange(offset - 1, offset, '');
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: offset - 1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isSmallScreen = availableHeight < 600;

        return Consumer<AccountSummaryViewModel>(
          builder: (context, accountViewModel, child) {
            final balance = accountViewModel.balance;
            final loading = accountViewModel.loading;
            
            // Assume registered if we have data, logic can be improved with SIP status listener
            final isRegistered = balance != null; 

            return Column(
              children: [
                // Balance Display
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.grey),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      // Connection Status Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isRegistered ? WunzaColors.greenAccent : Colors.red, 
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           if (loading)
                             const Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey))
                           else ...[
                             Text(
                              'User: ${accountViewModel.alias ?? "Unknown"}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                             Text(
                              _formatVoiceBalance(balance ?? 0),
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                           ]
                        ],
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'Refresh') {
                             accountViewModel.loadCurrentUser();
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return {'Account', 'About', 'Refresh'}.map((String choice) {
                            return PopupMenuItem<String>(
                              value: choice,
                              child: Text(choice),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                ),
            
            const Spacer(),

            // Phone Number Display
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: isSmallScreen ? 8.0 : 16.0,
              ),
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallScreen ? 28 : 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter number',
                ),
                keyboardType: TextInputType.none, // Suppress system keyboard but allow events
                enableInteractiveSelection: true, // Allow Copy/Paste
                showCursor: true,
              ),
            ),

            const Spacer(),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3'], [' ', 'ABC', 'DEF'], isSmallScreen),
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO'], isSmallScreen),
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ'], isSmallScreen),
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  _buildRow(['*', '0', '#'], ['', '+', ''], isSmallScreen),
                ],
              ),
            ),

            SizedBox(height: isSmallScreen ? 24 : 32),

            // Call Button
            Padding(
              // Increased padding to clear the floating NavigationBar (approx 80-100px)
              padding: EdgeInsets.only(bottom: isSmallScreen ? 90.0 : 110.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 64), // Spacer to center the call button
                  GestureDetector(
                    onTap: () {
                      if (_controller.text.isNotEmpty) {
                        // Use legacy CallViewModel for real SIP calls
                        getIt<CallViewModel>().makeCall(_controller.text, voiceOnly: true);
                      }
                    },
                    child: Container(
                      width: isSmallScreen ? 56 : 64,
                      height: isSmallScreen ? 56 : 64,
                      decoration: const BoxDecoration(
                        color: WunzaColors.indigo, // Teal color
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.phone,
                        color: Colors.white,
                        size: isSmallScreen ? 28 : 32,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: IconButton(
                      icon: const Icon(Icons.backspace_outlined, color: Colors.grey),
                      onPressed: _onBackspace,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ); // Closes Consumer
      },
    ); // Closes LayoutBuilder
  }

  String _formatVoiceBalance(double nanoseconds) {
    if (nanoseconds <= 0) return 'Voice Bal: 0 m';
    final duration = Duration(microseconds: (nanoseconds / 1000).round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return 'Voice Bal: $hours hrs $minutes m';
    } else {
      return 'Voice Bal: $minutes m $seconds s';
    }
  }

  Widget _buildRow(List<String> keys, List<String> subtexts, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        return _buildKey(keys[index], subtexts[index], isSmallScreen);
      }),
    );
  }

  Widget _buildKey(String key, String subtext, bool isSmallScreen) {
    return InkWell(
      onTap: () => _onKeyPress(key),
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: isSmallScreen ? 60 : 80,
        height: isSmallScreen ? 60 : 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              key,
              style: TextStyle(
                fontSize: isSmallScreen ? 28 : 32,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (subtext.isNotEmpty)
              Text(
                subtext,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
