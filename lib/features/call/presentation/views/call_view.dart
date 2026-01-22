import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import '../viewmodels/call_viewmodel.dart';
import '../../../../core/di/inject.dart';
import '../../../../shared/widgets/action_button.dart';

class CallView extends StatefulWidget {
  final Call call;

  const CallView({super.key, required this.call});

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> implements SipUaHelperListener {
  late CallViewModel _viewModel;
  late SIPUAHelper _sipHelper;
  final AudioPlayer _audioPlayer = AudioPlayer();
  RTCVideoRenderer? _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer? _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _showNumPad = false;
  bool _mirror = true;
  bool _callConfirmed = false;
  Timer? _timer;
  final ValueNotifier<String> _timeLabel = ValueNotifier<String>('00:00');

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<CallViewModel>();
    _sipHelper = getIt<SIPUAHelper>();
    _sipHelper.addSipUaHelperListener(this);
    _initRenderers();
    // Start timer only if already confirmed
    if (widget.call.state == CallStateEnum.CONFIRMED) {
      _startTimer();
    }
    _viewModel.setRemoteIdentity(widget.call.remote_identity ?? '');
    _viewModel.setCall(widget.call);

    if (widget.call.direction.toString().toUpperCase().contains('INCOMING') && 
        widget.call.state == CallStateEnum.CONNECTING) {
      _playRingtone();
    }
  }

  Future<void> _playRingtone() async {
    // Set release mode to loop so it repeats
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Play the asset
    await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _timer?.cancel();
    _sipHelper.removeSipUaHelperListener(this);
    _disposeRenderers();
    _cleanUp();
    super.dispose();
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      Duration duration = Duration(seconds: timer.tick);
      if (mounted) {
        _timeLabel.value = [duration.inMinutes, duration.inSeconds]
            .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
            .join(':');
        _viewModel.updateCallDuration(_timeLabel.value);
      } else {
        timer.cancel();
      }
    });
  }

  void _initRenderers() async {
    if (_localRenderer != null) {
      await _localRenderer!.initialize();
    }
    if (_remoteRenderer != null) {
      await _remoteRenderer!.initialize();
    }
  }

  void _disposeRenderers() {
    _localRenderer?.srcObject = null;
    _localRenderer?.dispose();
    _localRenderer = null;
    
    _remoteRenderer?.srcObject = null;
    _remoteRenderer?.dispose();
    _remoteRenderer = null;
  }

  void _cleanUp() {
    if (_localStream != null) {
      try {
        _localStream!.getTracks().forEach((track) {
          try {
            track.stop();
          } catch (e) {
            // Ignore track stop errors
          }
        });
        _localStream!.dispose();
      } catch (e) {
        debugPrint('Error cleaning up local stream: $e');
      }
      _localStream = null;
    }
  }

  void _backToDialPad() {
    _timer?.cancel();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
    _cleanUp();
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    if (call != widget.call) return;

    // Stop ringtone on any state change that implies the ringing phase is over
    if (callState.state == CallStateEnum.ACCEPTED ||
        callState.state == CallStateEnum.CONFIRMED ||
        callState.state == CallStateEnum.ENDED ||
        callState.state == CallStateEnum.FAILED) {
      _audioPlayer.stop();
    }

    if (callState.state == CallStateEnum.HOLD ||
        callState.state == CallStateEnum.UNHOLD) {
      _viewModel.setOnHold(callState.state == CallStateEnum.HOLD);
      _viewModel.updateCallState(callState.state);
      setState(() {});
      return;
    }

    if (callState.state == CallStateEnum.MUTED) {
      if (callState.audio!) {
        _viewModel.setAudioMuted(true);
      }
      if (callState.video! && !_viewModel.isVoiceOnly) {
        _viewModel.setVideoMuted(true);
      }
      setState(() {});
      return;
    }

    if (callState.state == CallStateEnum.UNMUTED) {
      if (callState.audio!) {
        _viewModel.setAudioMuted(false);
      }
      if (callState.video! && !_viewModel.isVoiceOnly) {
        _viewModel.setVideoMuted(false);
      }
      setState(() {});
      return;
    }

    if (callState.state != CallStateEnum.STREAM) {
      _viewModel.updateCallState(callState.state);
    }

    switch (callState.state) {
      case CallStateEnum.STREAM:
        _handleStreams(callState);
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _backToDialPad();
        break;
      case CallStateEnum.CONFIRMED:
        setState(() => _callConfirmed = true);
        _startTimer();
        break;
      default:
        break;
    }
  }

  void _handleStreams(CallState event) async {
    MediaStream? stream = event.stream;
    if (event.originator.toString().contains('local')) {
      if (_localRenderer != null) {
        _localRenderer!.srcObject = stream;
      }
      if (!kIsWeb &&
          (Platform.isAndroid || Platform.isIOS) && // Explicitly restrict to Mobile
          event.stream?.getAudioTracks().isNotEmpty == true) {
        try {
          // Helper.setSpeakerphoneOn(false); // Alternative global helper
          event.stream?.getAudioTracks().first.enableSpeakerphone(false);
        } catch (e) {
          debugPrint('Error enabling speakerphone: $e');
        }
      }
      _localStream = stream;
    }
    if (event.originator.toString().contains('remote')) {
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
      _remoteStream = stream;
    }
    setState(() {});
  }

  Future<void> _handleAccept() async {
    bool remoteHasVideo = widget.call.remote_has_video;
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': remoteHasVideo
          ? {
              'mandatory': <String, dynamic>{
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
            }
          : false
    };
    await navigator.mediaDevices.getUserMedia(mediaConstraints);

    await _viewModel.acceptCall(widget.call, hasVideo: remoteHasVideo);
  }

  void _switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
      setState(() {
        _mirror = !_mirror;
      });
    }
  }

  List<Widget> _buildNumPad() {
    final labels = [
      [
        {'1': ''},
        {'2': 'abc'},
        {'3': 'def'}
      ],
      [
        {'4': 'ghi'},
        {'5': 'jkl'},
        {'6': 'mno'}
      ],
      [
        {'7': 'pqrs'},
        {'8': 'tuv'},
        {'9': 'wxyz'}
      ],
      [
        {'*': ''},
        {'0': '+'},
        {'#': ''}
      ],
    ];

    return labels
        .map((row) => Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map((label) => ActionButton(
                          title: label.keys.first,
                          subTitle: label.values.first,
                          onPressed: () => _viewModel.sendDtmf(label.keys.first),
                          number: true,
                        ))
                    .toList())))
        .toList();
  }

  Widget _buildActionButtons() {
    final hangupBtn = ActionButton(
      title: "hangup",
      onPressed: () => _viewModel.hangup(),
      icon: Icons.call_end,
      fillColor: Colors.red,
    );

    final basicActions = <Widget>[];
    final advanceActions = <Widget>[];

    switch (_viewModel.callState) {
      case CallStateEnum.NONE:
      case CallStateEnum.CONNECTING:
        if (widget.call.direction.toString().toLowerCase().contains('incoming')) {
          basicActions.add(ActionButton(
            title: "Accept",
            fillColor: Colors.green,
            icon: Icons.phone,
            onPressed: () => _handleAccept(),
          ));
          basicActions.add(hangupBtn);
        } else {
          basicActions.add(hangupBtn);
        }
        break;
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        advanceActions.add(ActionButton(
          title: _viewModel.isAudioMuted ? 'unmute' : 'mute',
          icon: _viewModel.isAudioMuted ? Icons.mic_off : Icons.mic,
          checked: _viewModel.isAudioMuted,
          onPressed: () => _viewModel.toggleMuteAudio(),
        ));

        if (_viewModel.isVoiceOnly) {
          advanceActions.add(ActionButton(
            title: "keypad",
            icon: Icons.dialpad,
            onPressed: () => setState(() => _showNumPad = !_showNumPad),
          ));
        } else {
          advanceActions.add(ActionButton(
            title: "switch camera",
            icon: Icons.switch_video,
            onPressed: () => _switchCamera(),
          ));
        }

        if (!_viewModel.isVoiceOnly) {
          advanceActions.add(ActionButton(
            title: _viewModel.isVideoMuted ? "camera on" : 'camera off',
            icon: _viewModel.isVideoMuted ? Icons.videocam : Icons.videocam_off,
            checked: _viewModel.isVideoMuted,
            onPressed: () => _viewModel.toggleMuteVideo(),
          ));
        }

        basicActions.add(ActionButton(
          title: _viewModel.isOnHold ? 'unhold' : 'hold',
          icon: _viewModel.isOnHold ? Icons.play_arrow : Icons.pause,
          checked: _viewModel.isOnHold,
          onPressed: () => _viewModel.toggleHold(),
        ));

        basicActions.add(hangupBtn);

        if (_showNumPad) {
          basicActions.add(ActionButton(
            title: "back",
            icon: Icons.keyboard_arrow_down,
            onPressed: () => setState(() => _showNumPad = !_showNumPad),
          ));
        }
        break;
      default:
        basicActions.add(hangupBtn);
        break;
    }

    final actionWidgets = <Widget>[];

    if (_showNumPad) {
      actionWidgets.addAll(_buildNumPad());
    } else {
      if (advanceActions.isNotEmpty) {
        actionWidgets.add(
          Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: advanceActions),
          ),
        );
      }
    }

    actionWidgets.add(
      Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: basicActions),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.end,
      children: actionWidgets,
    );
  }

  Widget _buildContent() {
    Color? textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final stackWidgets = <Widget>[];

    if (!_viewModel.isVoiceOnly && _remoteStream != null) {
      stackWidgets.add(
        Center(
          child: RTCVideoView(
            _remoteRenderer!,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      );
    }

    if (!_viewModel.isVoiceOnly && _localStream != null) {
      stackWidgets.add(
        Positioned(
          top: 15,
          right: 15,
          child: SizedBox(
            width: MediaQuery.of(context).size.width / 4,
            height: MediaQuery.of(context).size.height / 4,
            child: RTCVideoView(
              _localRenderer!,
              mirror: _mirror,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        ),
      );
    }

    if (_viewModel.isVoiceOnly || !_callConfirmed) {
      stackWidgets.add(
        Positioned(
          top: MediaQuery.of(context).size.height / 8,
          left: 0,
          right: 0,
          child: Center(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    (_viewModel.isVoiceOnly ? 'VOICE CALL' : 'VIDEO CALL') +
                        (_viewModel.isOnHold ? ' PAUSED' : ''),
                    style: TextStyle(fontSize: 24, color: textColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    _viewModel.remoteIdentity ?? '',
                    style: TextStyle(fontSize: 18, color: textColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _timeLabel,
                    builder: (context, value, child) {
                      return Text(
                        _timeLabel.value,
                        style: TextStyle(fontSize: 14, color: textColor),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Stack(children: stackWidgets);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<CallViewModel>(
        builder: (context, viewModel, child) {
          // If Video Call, keep legacy Stack layout (or minimal update)
          if (!viewModel.isVoiceOnly) {
             return Scaffold(
              body: _buildContent(), // Keeps the Stack(_remoteRenderer, _localRenderer)
              floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
              floatingActionButton: Container(
                width: 320,
                padding: const EdgeInsets.only(bottom: 24.0),
                child: _buildActionButtons(),
              ),
            );
          }

          // New Audio Call Design
          final isIncoming = widget.call.direction.toString().toUpperCase().contains('INCOMING') && 
                            (viewModel.callState == CallStateEnum.CONNECTING || viewModel.callState == CallStateEnum.NONE);
          
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            body: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // Top Spacer
                   const Spacer(flex: 2),

                   // Avatar Area
                   // Mockup: Large circle with image or rings
                   Stack(
                     alignment: Alignment.center,
                     children: [
                       if (isIncoming)
                         // Simple ripple simulation
                         Container(
                           width: 200,
                           height: 200,
                           decoration: BoxDecoration(
                             color: const Color(0xFF00AA99).withValues(alpha: 0.1),
                             shape: BoxShape.circle,
                           ),
                         ),
                       Container(
                         width: 120,
                         height: 120,
                         decoration: BoxDecoration(
                           color: Colors.grey[200],
                           shape: BoxShape.circle,
                           border: Border.all(color: Colors.white, width: 4),
                           boxShadow: [
                             BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)
                           ]
                         ),
                         child: const Icon(Icons.person, size: 60, color: Colors.grey),
                       ),
                     ],
                   ),

                   const SizedBox(height: 30),

                   // Name & Status
                   Text(
                     viewModel.remoteIdentity ?? 'Unknown',
                     style: const TextStyle(
                       fontSize: 24,
                       fontWeight: FontWeight.bold,
                       color: Color(0xFF333333),
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     isIncoming ? 'Incoming Call...' : 'Mobile',
                     style: const TextStyle(fontSize: 16, color: Colors.grey),
                   ),

                   // Timer (Active Call only)
                   if (!isIncoming) ...[
                     const SizedBox(height: 20),
                     ValueListenableBuilder<String>(
                      valueListenable: _timeLabel,
                      builder: (context, value, child) {
                        return Text(
                          _timeLabel.value,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF00AA99), // Cyan from mockup
                          ),
                        );
                      },
                    ),
                   ],

                   const Spacer(flex: 3),

                   // Bottom Control Area
                   Container(
                     decoration: const BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                     ),
                     padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                     child: Column(
                       children: [
                         if (isIncoming)
                           _buildIncomingControls()
                         else
                           _buildActiveControls(viewModel),
                       ],
                     ),
                   )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlBtn(Icons.alarm, "Reminder", onTap: (){}),
            _buildControlBtn(Icons.message, "Message", onTap: (){}),
            _buildControlBtn(Icons.call_end, "Decline", color: Colors.red, textColor: Colors.red, onTap: () => _viewModel.hangup()),
          ],
        ),
        const SizedBox(height: 30),
        // "Slide to answer" - simulated with a large button for now
        GestureDetector(
          onTap: () => _handleAccept(),
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00AA99), Color(0xFF00C853)]),
              borderRadius: BorderRadius.circular(30),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call, color: Colors.white),
                SizedBox(width: 10),
                Text("Answer", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveControls(CallViewModel viewModel) {
    return Column(
      children: [
        // Grid of 6 buttons (3x2)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlBtn(
              viewModel.isAudioMuted ? Icons.mic_off : Icons.mic, 
              "Mute", 
              active: viewModel.isAudioMuted,
              onTap: () => viewModel.toggleMuteAudio()
            ),
            _buildControlBtn(Icons.pause, "Hold", active: viewModel.isOnHold, onTap: () => viewModel.toggleHold()),
            _buildControlBtn(Icons.dialpad, "Keypad", active: _showNumPad, onTap: () => setState(() => _showNumPad = !_showNumPad)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlBtn(Icons.person, "Contacts", onTap: (){
              // Navigate to Contacts View
              Navigator.of(context).pushNamed('/contacts'); // Assuming '/contacts' route exists, or use Routes.contacts
            }),
             _buildControlBtn(Icons.speaker_phone, "Speaker", active: viewModel.isSpeakerOn, onTap: () => viewModel.toggleSpeaker()), 
            _buildControlBtn(Icons.videocam, "Video", onTap: () {
               // Video toggle not yet fully supported in pure audio call
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video switching not available in this mode")));
            }),
          ],
        ),
         const SizedBox(height: 40),
         // Red End Call Button
         GestureDetector(
           onTap: () => _viewModel.hangup(),
           behavior: HitTestBehavior.opaque,
           child: Container(
             width: 72,
             height: 72,
             decoration: BoxDecoration(
               color: const Color(0xFFD50000),
               shape: BoxShape.circle,
               boxShadow: [
                 BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))
               ]
             ),
             child: const Icon(Icons.call_end, color: Colors.white, size: 32),
           ),
         )
      ],
    );
  }

  Widget _buildControlBtn(IconData icon, String label, {bool active = false, Color? color, Color? textColor, required VoidCallback onTap}) {
    final finalColor = active ? const Color(0xFF00AA99) : (color ?? Colors.grey[700]);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
              color: active ? const Color(0xFF00AA99).withValues(alpha: 0.1) : Colors.transparent,
            ),
            child: Icon(icon, color: finalColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: textColor ?? Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  void registrationStateChanged(RegistrationState state) {}

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {
    if (event.accept == null) return;
    if (event.reject == null) return;
    if (_viewModel.isVoiceOnly && (event.hasVideo ?? false)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Upgrade to video?'),
            content: Text('${_viewModel.remoteIdentity} is inviting you to video call'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  event.reject!.call({'status_code': 607});
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  event.accept!.call({});
                  setState(() {
                    widget.call.voiceOnly = false;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}

