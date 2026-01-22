import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class QuickDialerOverlay extends StatefulWidget {
  const QuickDialerOverlay({super.key});

  @override
  State<QuickDialerOverlay> createState() => _QuickDialerOverlayState();
}

class _QuickDialerOverlayState extends State<QuickDialerOverlay> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onKeyPress(String value) {
    setState(() {
      _controller.text += value;
    });
  }

  void _onBackspace() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _controller.text = _controller.text.substring(0, _controller.text.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Light Blue background color from image approx
    const backgroundColor = Color(0xFFE8EEF7);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // Fill most of the screen
      decoration: const BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const SizedBox(height: 40),

          // Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter number',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                readOnly: true, // Prevent keyboard from showing
                showCursor: true,
              ),
            ),
          ),

          const Spacer(),

          // Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              children: [
                _buildRow(['1', '2', '3'], [' ', 'ABC', 'DEF']),
                const SizedBox(height: 24),
                _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                const SizedBox(height: 24),
                _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                const SizedBox(height: 24),
                _buildRow(['*', '0', '#'], ['', '+', '']),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Actions Row (Centered Call Button, Right Backspace)
          Padding(
            padding: const EdgeInsets.only(bottom: 50.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 80), // Spacer to balance backspace
                
                // Call Button
                GestureDetector(
                  onTap: () {
                    if (_controller.text.isNotEmpty) {
                       Navigator.pop(context); // Close overlay logic
                       getIt<CallViewModel>().makeCall(_controller.text, voiceOnly: true);
                    }
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF536DFE), // Bright Indigo/Blue
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black26, 
                          blurRadius: 10,
                          offset: Offset(0, 4)
                        )
                      ]
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                
                // Backspace Button
                SizedBox(
                  width: 80,
                  child: IconButton(
                    padding: const EdgeInsets.only(left: 24),
                    icon: Icon(Icons.backspace_outlined, color: Colors.grey[500], size: 28),
                    onPressed: _onBackspace,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys, List<String> subtexts) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        return _buildKey(keys[index], subtexts[index]);
      }),
    );
  }

  Widget _buildKey(String key, String subtext) {
    return InkWell(
      onTap: () => _onKeyPress(key),
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              key,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
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
