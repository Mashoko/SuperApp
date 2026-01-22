import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../viewmodels/dialpad_viewmodel.dart';
import '../../../../core/di/inject.dart';


import '../../../call/presentation/views/call_view.dart';


import '../../../recents/presentation/views/recents_view.dart';
import '../../../contacts/presentation/views/contacts_view.dart';
import '../../../speed_test/presentation/views/speed_test_view.dart';

class DialpadView extends StatefulWidget {
  const DialpadView({super.key});

  @override
  State<DialpadView> createState() => _DialpadViewState();
}

class _DialpadViewState extends State<DialpadView>
    implements SipUaHelperListener {
  late DialpadViewModel _viewModel;
  late SIPUAHelper _sipHelper;
  final TextEditingController _textController = TextEditingController();

  // Removed duplicate initState
  // Note: The logic from the original initState (lines 29-36) is less comprehensive 
  // than the new one at lines 172-180, so we keep the new one (which will be at the bottom).
  // However, usually initState should be at the top. 
  // Let's merged them:
  @override
  void initState() {
    super.initState();
    _viewModel = getIt<DialpadViewModel>();
    _sipHelper = getIt<SIPUAHelper>();
    _sipHelper.addSipUaHelperListener(this);
    // _loadDestination(); // Removed per user request
    _updateRegistrationStatus();
    _viewModel.loadAccountInfo(); // Load balance
    _viewModel.loadRecents(); // Load recents
  }

  @override
  void dispose() {
    _textController.dispose();
    _sipHelper.removeSipUaHelperListener(this);
    super.dispose();
  }



  void _updateRegistrationStatus() {
    final state = _sipHelper.registerState.state?.name ?? '';
    _viewModel.updateRegistrationStatus(state);
  }

  Future<void> _handleCall(bool voiceOnly) async {
    final dest = _textController.text;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      // Only request microphone permission for voice calls
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _showAlert('Permission Required', 'Microphone permission is required to make calls.');
        return;
      }
    }
    if (dest.isEmpty) {
      _showAlert('Target is empty.', 'Please enter a SIP URI or username!');
      return;
    }

    await _viewModel.saveDestination(dest);
    await _viewModel.addToRecents(dest); // Add to recents
    
    // Make voice-only call using SIPUAHelper
    var mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': false, // Always voice-only for outgoing calls
    };

    try {
      final mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _sipHelper.call(dest, voiceOnly: true, mediaStream: mediaStream); // Always voice-only
    } catch (e) {
      _showAlert('Error', 'Failed to start call: $e');
    }
  }

  void _showAlert(String title, String content) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleBackSpace([bool deleteAll = false]) {
    var text = _textController.text;
    if (text.isNotEmpty) {
      setState(() {
        text = deleteAll ? '' : text.substring(0, text.length - 1);
        _textController.text = text;
        _viewModel.setDestination(text);
      });
    }
  }

  void _handleNum(String number) {
    setState(() {
      _textController.text += number;
      _viewModel.addDigit(number);
    });
  }



  // Removed second initState since we merged it into the first one.

  int _selectedIndex = 0;

  Widget _buildBody(DialpadViewModel viewModel) {
    switch (_selectedIndex) {
      case 0:
        return _buildDialpadScreen(viewModel);
      case 1:
        return const RecentsView();
      case 2:
        return const ContactsView();
      case 3:
        return const SpeedTestView();
      default:
        return _buildDialpadScreen(viewModel);
    }
  }

  Widget _buildDialpadScreen(DialpadViewModel viewModel) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Spacer(),

        // Display Area (Number)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _textController.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87, 
                  ),
                ),
              ),
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.backspace, color: Colors.grey),
                  onPressed: () => _handleBackSpace(),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Keypad
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: _buildNumPadGrid(),
          ),
        ),

        const SizedBox(height: 10),

        // Call Button
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: GestureDetector(
            onTap: () => _handleCall(true),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50), // Matches screenshot green
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<DialpadViewModel>(
        builder: (context, viewModel, child) {

          
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.search, color: Colors.grey, size: 28),
                onPressed: () {
                   // Search functionality or focus search bar
                },
              ),
              title: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Container(
                         width: 8, height: 8,
                         decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                       ),
                       const SizedBox(width: 8),
                       Text(
                         "Voice Bal: ${viewModel.voiceBalance}",
                         style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.normal),
                       ),
                     ],
                   ),
                   Text(
                     "Balance: ${viewModel.accountBalance}",
                     style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.normal),
                   ),
                ],
              ),
              centerTitle: true,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (String value) {
                     switch (value) {
                      case 'account':
                        Navigator.pushNamed(context, '/account');
                        break;
                      case 'about':
                        Navigator.pushNamed(context, '/about');
                        break;
                      case 'refresh':
                        viewModel.loadAccountInfo();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                     const PopupMenuItem(
                      value: 'account',
                      child: Text('Account'),
                    ),
                     const PopupMenuItem(
                      value: 'about',
                      child: Text('About'),
                    ),
                     const PopupMenuItem(
                      value: 'refresh',
                      child: Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              child: _buildBody(viewModel),
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.phone),
                  label: 'Phone',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_time),
                  label: 'Recents',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.contacts),
                  label: 'Contacts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.speed),
                  label: 'Speed Test',
                ),
              ],
            ),
          );
        },
      ),
    );
  }



  List<Widget> _buildNumPadGrid() {
    final labels = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['*', '0', '#'],
    ];

    final subLabels = {
      '1': '', '2': 'ABC', '3': 'DEF',
      '4': 'GHI', '5': 'JKL', '6': 'MNO',
      '7': 'PQRS', '8': 'TUV', '9': 'WXYZ',
      '*': '', '0': '+', '#': ''
    };

    return labels.map((row) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            return _buildKeypadButton(key, subLabels[key] ?? '');
          }).toList(),
        ),
      );
    }).toList();
  }

  Widget _buildKeypadButton(String label, String sub) {
    return InkWell(
      onTap: () => _handleNum(label),
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: Color(0xFF333333),
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  letterSpacing: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    _viewModel.updateRegistrationStatus(state.state?.name ?? '');
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void callStateChanged(Call call, CallState callState) {
    switch (callState.state) {
      case CallStateEnum.CALL_INITIATION:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallView(call: call),
          ),
        );
        break;
      case CallStateEnum.FAILED:
      case CallStateEnum.ENDED:
        // Handle re-registration if needed
        break;
      default:
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    String? msgBody = msg.request.body as String?;
    _viewModel.updateReceivedMessage(msgBody ?? '');
  }

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}
}

