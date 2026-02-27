import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/di/inject.dart';
import 'package:mvvm_sip_demo/features/call/presentation/viewmodels/call_viewmodel.dart';
import 'package:google_fonts/google_fonts.dart';

class DialPadScreen extends StatefulWidget {
  const DialPadScreen({super.key});

  @override
  _DialPadScreenState createState() => _DialPadScreenState();
}

class _DialPadScreenState extends State<DialPadScreen> {
  String phoneNumber = "";

  void _onNumberTap(String value) {
    setState(() {
      phoneNumber += value;
    });
  }

  void _onBackspace() {
    if (phoneNumber.isNotEmpty) {
      setState(() {
        phoneNumber = phoneNumber.substring(0, phoneNumber.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey, size: 30),
          onPressed: () { Future.delayed(Duration.zero, () { if (context.mounted) Navigator.pop(context); }); },
        ),
      ),
      body: Column(
        children: [
          // 1. THE NUMBER DISPLAY
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                phoneNumber.isEmpty ? "Enter Number" : phoneNumber,
                style: GoogleFonts.inter(
                  fontSize: phoneNumber.isEmpty ? 24 : 40, // Grows when typing
                  fontWeight: FontWeight.bold,
                  color: phoneNumber.isEmpty ? Colors.grey.shade400 : Colors.black,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),

          // 2. THE DIAL GRID
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                  _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                  _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                  _buildRow(['*', '0', '#'], ['', '+', '']),
                ],
              ),
            ),
          ),

          // 3. CALL & DELETE ACTIONS
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Invisible spacer to balance the row
                  const SizedBox(width: 60), 
                  
                  // Main Call Button
                  InkWell(
                    onTap: () {
                      if (phoneNumber.isNotEmpty) {
                         Navigator.pop(context); // Close overlay
                         getIt<CallViewModel>().makeCall(phoneNumber, voiceOnly: true);
                      }
                    },
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      height: 70,
                      width: 70,
                      decoration: BoxDecoration(
                        color: Colors.green, // Standard "Call" Green
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: const Icon(Icons.call, color: Colors.white, size: 32),
                    ),
                  ),
                  
                  // Delete Button (Only shows when numbers exist)
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: phoneNumber.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.backspace_outlined, color: Colors.grey),
                            iconSize: 28,
                            onPressed: _onBackspace,
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> numbers, List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        return _buildDialButton(numbers[index], letters[index]);
      }),
    );
  }

  Widget _buildDialButton(String number, String letters) {
    return InkWell(
      onTap: () => _onNumberTap(number),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
           shape: BoxShape.circle,
           // color: Colors.grey.shade50, // Optional: subtle background
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w400, color: Colors.black87),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
