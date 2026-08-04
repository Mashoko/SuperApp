import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import '../viewmodels/dialpad_viewmodel.dart';
import '../../../../core/di/inject.dart';
import '../../../../core/routes.dart';
import '../../../../core/theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/sip_utils.dart';
import '../../../call/presentation/views/call_view.dart';
import '../../../recents/presentation/views/recents_view.dart';
import '../../../contacts/presentation/views/contacts_view.dart';
import '../widgets/dialer_gradient_background.dart';
import '../widgets/dialer_glass_nav.dart';

enum _DialerSection { keypad, recents, contacts }

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

  _DialerSection _section = _DialerSection.keypad;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<DialpadViewModel>();
    _sipHelper = getIt<SIPUAHelper>();
    _sipHelper.addSipUaHelperListener(this);
    _updateRegistrationStatus();
    _viewModel.loadAccountInfo();
    _viewModel.loadRecents();
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

  Color _sipStatusColor(DialpadViewModel viewModel) {
    if (viewModel.isSipReady) return Colors.green;
    if (_sipHelper.connecting) {
      return Colors.orange;
    }
    return Colors.red;
  }

  Future<void> _handleCall(bool voiceOnly) async {
    final dest = _textController.text;
    if (dest.isEmpty) {
      _showAlert('Target is empty.', 'Please enter a SIP URI or username!');
      return;
    }

    await _viewModel.saveDestination(dest);

    final result = await SipUtils.placeOutgoingCall(
      _sipHelper,
      dest,
      voiceOnly: voiceOnly,
    );
    if (result is Failure && mounted) {
      _showAlert('Cannot place call', result.message);
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

  void _onNavTabSelected(int index) {
    setState(() {
      _section =
          index == 1 ? _DialerSection.contacts : _DialerSection.recents;
    });
  }

  void _onMarketPlaceTap() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(Routes.shopping);
  }

  Widget _buildBody(DialpadViewModel viewModel) {
    switch (_section) {
      case _DialerSection.keypad:
        return _buildDialpadScreen(viewModel);
      case _DialerSection.recents:
        return const RecentsView();
      case _DialerSection.contacts:
        return ContactsView(darkTheme: true, onNumberCopied: _onNumberCopiedFromContacts);
    }
  }

  void _onNumberCopiedFromContacts() {
    setState(() {
      _textController.text = _viewModel.destination;
      _section = _DialerSection.keypad;
    });
  }

  Widget _buildTopBar(DialpadViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _GhostIconButton(
            icon: Icons.search,
            onTap: () {
              // Search functionality or focus search bar
            },
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _sipStatusColor(viewModel),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        "Voice Bal: ${viewModel.voiceBalance}",
                        key: ValueKey<String>('voice_${viewModel.voiceBalance}'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    "Balance: ${viewModel.accountBalance}",
                    key: ValueKey<String>('account_${viewModel.accountBalance}'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert, color: Colors.white70, size: 22),
            ),
            color: const Color(0xFF1E1E2E),
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
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'account',
                child: Text('Account', style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'about',
                child: Text('About', style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialpadScreen(DialpadViewModel viewModel) {
    final hasDigits = _textController.text.isNotEmpty;
    return Column(
      children: [
        const SizedBox(height: 12),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            hasDigits ? _textController.text : 'Enter number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.2,
              color: hasDigits ? Colors.white : Colors.white38,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: _buildNumPadGrid()),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _handleCall(true),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: WunzaColors.dialerCallGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WunzaColors.blueAccent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call, color: Colors.white, size: 32),
                ),
              ),
              if (hasDigits) ...[
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _handleBackSpace(),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: WunzaColors.dialerKeypadFill,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.backspace_outlined,
                        color: Colors.white54, size: 22),
                  ),
                ),
              ],
            ],
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
            backgroundColor: Colors.transparent,
            body: DialerGradientBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: GlassPanelContainer(
                        child: Column(
                          children: [
                            _buildTopBar(viewModel),
                            Expanded(child: _buildBody(viewModel)),
                          ],
                        ),
                      ),
                    ),
                    DialerGlassNav(
                      activeIndex:
                          _section == _DialerSection.contacts ? 1 : 0,
                      onTabSelected: _onNavTabSelected,
                      onMarketPlaceTap: _onMarketPlaceTap,
                    ),
                  ],
                ),
              ),
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
        padding: const EdgeInsets.symmetric(vertical: 8.0),
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
      borderRadius: BorderRadius.circular(44),
      child: Container(
        height: 72,
        width: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: WunzaColors.dialerKeypadFill,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
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
    if (mounted) setState(() {});
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

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}
