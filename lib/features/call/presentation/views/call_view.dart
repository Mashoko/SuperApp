import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import '../viewmodels/call_viewmodel.dart';
import '../../domain/entities/phone_call_state.dart';
import '../../../../core/di/inject.dart';
import '../../../../core/services/proximity_screen_controller.dart';
import '../../../../core/services/proximity_sensor_gateway.dart';
import '../../../../core/utils/sip_utils.dart';
import '../../../../shared/widgets/action_button.dart';

class CallView extends StatefulWidget {
  final Call call;
  const CallView({super.key, required this.call});

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView>
    with SingleTickerProviderStateMixin
    implements SipUaHelperListener {
  late CallViewModel _viewModel;
  late SIPUAHelper _sipHelper;
  late final ProximityScreenController _proximityController;

  // ── WebRTC ─────────────────────────────────────────────────────────────────
  RTCVideoRenderer? _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer? _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final bool _mirror = true;
  bool _showNumPad = false;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  PhoneCallState? _lastAudioState;

  // ── Pulse animation ────────────────────────────────────────────────────────
  late AnimationController _pulseController;

  // ── End-screen timer ───────────────────────────────────────────────────────
  Timer? _endScreenTimer;
  String _finalDuration = '00:00';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _viewModel = getIt<CallViewModel>();
    _sipHelper = getIt<SIPUAHelper>();
    _proximityController =
        ProximityScreenController(getIt<ProximitySensorGateway>());

    _sipHelper.addSipUaHelperListener(this);
    _initRenderers();

    // Set call on ViewModel — this determines the initial PhoneCallState.
    _viewModel.setRemoteIdentity(widget.call.remote_identity ?? '');
    _viewModel.setCall(widget.call);

    // Subscribe to ViewModel changes to sync audio and animation.
    _viewModel.addListener(_onViewModelChanged);
    _onViewModelChanged(); // Sync immediately after setCall.
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.resetForDispose();
    _pulseController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _proximityController.dispose();
    _endScreenTimer?.cancel();
    _sipHelper.removeSipUaHelperListener(this);
    _disposeRenderers();
    _cleanUp();
    super.dispose();
  }

  // ── Audio sync ─────────────────────────────────────────────────────────────

  void _onViewModelChanged() {
    final state = _viewModel.phoneState;

    // Sync animation.
    if (state.isPreConnect) {
      if (!_pulseController.isAnimating) _pulseController.repeat();
    } else {
      if (_pulseController.isAnimating) _pulseController.stop();
    }

    // Sync proximity screen-off. Must run on every change (including
    // speaker toggling, which doesn't change `state`), so this sits above
    // the audio-state early-return below rather than inside the switch.
    final shouldMonitorProximity = state == PhoneCallState.connected &&
        _viewModel.isVoiceOnly &&
        !_viewModel.isSpeakerOn;
    _proximityController.setActive(shouldMonitorProximity);

    // Sync audio — only change if state changed.
    if (_lastAudioState == state) return;
    _lastAudioState = state;

    switch (state) {
      case PhoneCallState.incoming:
        // Ringtone for incoming calls.
        _playAudio('sounds/ringtone.mp3', loop: true);

      case PhoneCallState.ringing:
        // Ringback tone — we hear this while the remote device rings.
        // Uses the same file; swap in a dedicated ringback.mp3 if available.
        _playAudio('sounds/ringtone.mp3', loop: true);

      case PhoneCallState.connected:
      case PhoneCallState.ended:
      case PhoneCallState.missed:
      case PhoneCallState.declined:
      case PhoneCallState.failed:
        _stopAudio();
        if (state.isTerminal) _handleTerminalState(state);

      default:
        break;
    }
  }

  void _playAudio(String asset, {bool loop = true}) async {
    _audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    await _audioPlayer.play(AssetSource(asset));
  }

  void _stopAudio() {
    _audioPlayer.stop();
  }

  // ── Terminal state handling ────────────────────────────────────────────────

  void _handleTerminalState(PhoneCallState state) {
    _finalDuration = _viewModel.callDuration;
    // Show the end screen for 2 seconds then auto-pop.
    _endScreenTimer?.cancel();
    _endScreenTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // ── WebRTC helpers ─────────────────────────────────────────────────────────

  void _initRenderers() async {
    await _localRenderer?.initialize();
    await _remoteRenderer?.initialize();
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
    final stream = _localStream;
    _localStream = null;
    SipUtils.safeDisposeMediaStream(stream);
  }

  // ── SipUaHelperListener ────────────────────────────────────────────────────

  @override
  void callStateChanged(Call call, CallState callState) {
    if (call != widget.call) return;

    // Streams are a media concern handled here in the view.
    if (callState.state == CallStateEnum.STREAM) {
      _handleStreams(callState);
      return;
    }

    // Everything else: delegate state machine to the ViewModel.
    _viewModel.onSipStateChanged(
        call, callState, call.direction.toString());
  }

  void _handleStreams(CallState event) async {
    final stream = event.stream;
    if (event.originator.toString().contains('local')) {
      if (_localRenderer != null) _localRenderer!.srcObject = stream;
      if (!kIsWeb &&
          (Platform.isAndroid || Platform.isIOS) &&
          stream?.getAudioTracks().isNotEmpty == true) {
        try {
          stream?.getAudioTracks().first.enableSpeakerphone(false);
        } catch (e) {
          debugPrint('Error configuring speakerphone: $e');
        }
      }
      _localStream = stream;
    }
    if (event.originator.toString().contains('remote')) {
      if (_remoteRenderer != null) _remoteRenderer!.srcObject = stream;
      _remoteStream = stream;
    }
    if (mounted) setState(() {});
  }

  // ── Incoming call accept ───────────────────────────────────────────────────

  Future<void> _handleAccept() async {
    final remoteHasVideo = widget.call.remote_has_video;
    final constraints = <String, dynamic>{
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
          : false,
    };
    await navigator.mediaDevices.getUserMedia(constraints);
    await _viewModel.acceptCall(widget.call, hasVideo: remoteHasVideo);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<CallViewModel>(
        builder: (context, viewModel, _) {
          if (!viewModel.isVoiceOnly) {
            return _buildVideoCallScaffold(viewModel);
          }
          return _buildVoiceCallScaffold(viewModel);
        },
      ),
    );
  }

  // ── Video call (legacy stack layout) ──────────────────────────────────────

  Widget _buildVideoCallScaffold(CallViewModel viewModel) {
    return Scaffold(
      body: _buildVideoContent(viewModel),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildActionButtons(viewModel),
        ),
      ),
    );
  }

  Widget _buildVideoContent(CallViewModel viewModel) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final stackWidgets = <Widget>[];

    if (_remoteStream != null) {
      stackWidgets.add(Center(
        child: RTCVideoView(
          _remoteRenderer!,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ));
    }

    if (_localStream != null) {
      stackWidgets.add(Positioned(
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
      ));
    }

    // Overlay text for non-connected states.
    if (viewModel.phoneState != PhoneCallState.connected ||
        _remoteStream == null) {
      stackWidgets.add(Positioned(
        top: MediaQuery.of(context).size.height / 8,
        left: 0,
        right: 0,
        child: Center(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  viewModel.phoneState.statusLabel(isOnHold: viewModel.isOnHold),
                  style: TextStyle(fontSize: 20, color: textColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  viewModel.remoteIdentity ?? '',
                  style: TextStyle(fontSize: 18, color: textColor),
                ),
              ),
              if (viewModel.phoneState.showTimer)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    viewModel.callDuration,
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    return Stack(children: stackWidgets);
  }

  // ── Voice call (redesigned) ────────────────────────────────────────────────

  Widget _buildVoiceCallScaffold(CallViewModel viewModel) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            _buildAvatarSection(viewModel),
            const SizedBox(height: 28),
            _buildIdentitySection(viewModel),
            const Spacer(flex: 3),
            _buildBottomSheet(viewModel),
          ],
        ),
      ),
    );
  }

  // ── Avatar with pulse rings ─────────────────────────────────────────────────

  Widget _buildAvatarSection(CallViewModel viewModel) {
    final animate = viewModel.phoneState.isPreConnect;
    final Color pulseColor = _pulseColorFor(viewModel.phoneState);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value; // 0.0 → 1.0 repeating

        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              if (animate)
                Opacity(
                  opacity: ((1.0 - t) * 0.25).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1.0 + t * 0.9,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: pulseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              // Inner pulse ring
              if (animate)
                Opacity(
                  opacity: ((1.0 - t) * 0.35).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1.0 + t * 0.5,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: pulseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              // Avatar circle
              child!,
            ],
          ),
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
            ),
          ],
        ),
        child: const Icon(Icons.person, size: 60, color: Colors.grey),
      ),
    );
  }

  Color _pulseColorFor(PhoneCallState state) {
    switch (state) {
      case PhoneCallState.incoming:
        return const Color(0xFF00C853); // green
      case PhoneCallState.ringing:
        return const Color(0xFFFF8F00); // amber
      default:
        return const Color(0xFF00AA99); // teal
    }
  }

  // ── Identity + status + timer ──────────────────────────────────────────────

  Widget _buildIdentitySection(CallViewModel viewModel) {
    final state = viewModel.phoneState;
    final statusColor = _statusColorFor(state);

    return Column(
      children: [
        // Contact name
        Text(
          viewModel.remoteIdentity ?? 'Unknown',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 10),

        // Dynamic status label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            state.statusLabel(isOnHold: viewModel.isOnHold),
            key: ValueKey(state),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: statusColor,
              letterSpacing: 0.3,
            ),
          ),
        ),

        // Timer — only visible when connected
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: state.showTimer
              ? Padding(
                  key: const ValueKey('timer'),
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    viewModel.callDuration,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF00AA99),
                      letterSpacing: 1.5,
                    ),
                  ),
                )
              : state.isTerminal
                  ? Padding(
                      key: const ValueKey('ended'),
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Duration: $_finalDuration',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('spacer'), height: 0),
        ),
      ],
    );
  }

  Color _statusColorFor(PhoneCallState state) {
    switch (state) {
      case PhoneCallState.calling:   return const Color(0xFF00AA99);
      case PhoneCallState.ringing:   return const Color(0xFFFF8F00);
      case PhoneCallState.incoming:  return const Color(0xFF00C853);
      case PhoneCallState.connected: return const Color(0xFF00AA99);
      case PhoneCallState.ended:     return Colors.grey;
      case PhoneCallState.missed:    return Colors.red;
      case PhoneCallState.declined:  return Colors.red;
      case PhoneCallState.failed:    return Colors.red;
      case PhoneCallState.idle:      return Colors.grey;
    }
  }

  // ── Bottom sheet (controls) ─────────────────────────────────────────────────

  Widget _buildBottomSheet(CallViewModel viewModel) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: _buildActionButtons(viewModel),
    );
  }

  Widget _buildActionButtons(CallViewModel viewModel) {
    final state = viewModel.phoneState;

    if (state == PhoneCallState.incoming) {
      return _buildIncomingControls();
    }

    if (state.isTerminal) {
      return const SizedBox.shrink();
    }

    if (state == PhoneCallState.connected) {
      return _buildActiveControls(viewModel);
    }

    // calling / ringing: just a cancel button
    return _buildCallingControls();
  }

  Widget _buildCallingControls() {
    return Center(
      child: GestureDetector(
        onTap: () => _viewModel.hangup(),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFD50000),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.call_end, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _controlBtn(Icons.alarm, 'Remind me', onTap: () {}),
            _controlBtn(Icons.message_outlined, 'Message', onTap: () {}),
            _controlBtn(Icons.call_end, 'Decline',
                color: Colors.red,
                labelColor: Colors.red,
                onTap: () => _viewModel.hangup()),
          ],
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => _handleAccept(),
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00AA99), Color(0xFF00C853)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C853).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Text('Answer',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
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
        if (_showNumPad)
          _buildNumPad()
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlBtn(
                viewModel.isAudioMuted ? Icons.mic_off : Icons.mic,
                'Mute',
                active: viewModel.isAudioMuted,
                onTap: () => viewModel.toggleMuteAudio(),
              ),
              _controlBtn(
                viewModel.isOnHold ? Icons.play_arrow : Icons.pause,
                viewModel.isOnHold ? 'Unhold' : 'Hold',
                active: viewModel.isOnHold,
                onTap: () => viewModel.toggleHold(),
              ),
              _controlBtn(Icons.dialpad, 'Keypad',
                  active: _showNumPad,
                  onTap: () => setState(() => _showNumPad = true)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlBtn(Icons.contacts_outlined, 'Contacts',
                  onTap: () => Navigator.of(context).pushNamed('/contacts')),
              _controlBtn(
                viewModel.isSpeakerOn
                    ? Icons.volume_up
                    : Icons.volume_down_outlined,
                'Speaker',
                active: viewModel.isSpeakerOn,
                onTap: () => viewModel.toggleSpeaker(),
              ),
              _controlBtn(Icons.videocam_outlined, 'Video', onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Video not available in audio mode')));
              }),
            ],
          ),
        ],
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: _showNumPad
              ? MainAxisAlignment.spaceEvenly
              : MainAxisAlignment.center,
          children: [
            if (_showNumPad)
              _controlBtn(Icons.keyboard_arrow_down, 'Hide',
                  onTap: () => setState(() => _showNumPad = false)),
            GestureDetector(
              onTap: () => _viewModel.hangup(),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFD50000),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.call_end, color: Colors.white, size: 32),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumPad() {
    final labels = [
      [
        {'1': ''},
        {'2': 'ABC'},
        {'3': 'DEF'},
      ],
      [
        {'4': 'GHI'},
        {'5': 'JKL'},
        {'6': 'MNO'},
      ],
      [
        {'7': 'PQRS'},
        {'8': 'TUV'},
        {'9': 'WXYZ'},
      ],
      [
        {'*': ''},
        {'0': '+'},
        {'#': ''},
      ],
    ];

    return Column(
      children: labels
          .map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row
                      .map((label) => ActionButton(
                            title: label.keys.first,
                            subTitle: label.values.first,
                            onPressed: () =>
                                _viewModel.sendDtmf(label.keys.first),
                            number: true,
                          ))
                      .toList(),
                ),
              ))
          .toList(),
    );
  }

  Widget _controlBtn(
    IconData icon,
    String label, {
    bool active = false,
    Color? color,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    final iconColor =
        active ? const Color(0xFF00AA99) : (color ?? Colors.grey[700]!);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
              color: active
                  ? const Color(0xFF00AA99).withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
                color: labelColor ?? Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Unused SipUaHelperListener overrides ──────────────────────────────────

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
    if (event.accept == null || event.reject == null) return;
    if (_viewModel.isVoiceOnly && (event.hasVideo ?? false)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Upgrade to video?'),
          content: Text(
              '${_viewModel.remoteIdentity} wants to start a video call'),
          actions: [
            TextButton(
              child: const Text('Decline'),
              onPressed: () {
                event.reject!.call({'status_code': 607});
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              child: const Text('Accept'),
              onPressed: () {
                event.accept!.call({});
                _viewModel.setVoiceOnly(false);
                setState(() => widget.call.voiceOnly = false);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      );
    }
  }
}
