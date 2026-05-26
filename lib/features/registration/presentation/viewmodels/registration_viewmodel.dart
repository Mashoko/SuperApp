import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../domain/entities/sip_user.dart';
import '../../domain/usecases/register_user.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../../../users_client.dart';
import '../../../../core/utils/crypto_utils.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/sip_utils.dart';

enum RegistrationStep {
  phoneInput,
  otpInput,
  registering,
  completed,
}

class RegistrationViewModel extends ChangeNotifier {
  final RegisterUser registerUserUseCase;
  final OtpAuthService authService;
  final UsersClient usersClient;
  final SIPUAHelper sipHelper;

  RegistrationViewModel(
    this.registerUserUseCase,
    this.authService,
    this.usersClient,
    this.sipHelper,
  );

  RegistrationState? _registrationState;
  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;
  SipUser? _currentUser;
  RegistrationStep _currentStep = RegistrationStep.phoneInput;
  String? _tempPhone;
  Timer? _registrationTimeout;

  RegistrationState? get registrationState => _registrationState;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  SipUser? get currentUser => _currentUser;
  RegistrationStep get currentStep => _currentStep;

  @override
  void dispose() {
    _registrationTimeout?.cancel();
    super.dispose();
  }

  // Step 1: Send OTP
  Future<void> sendOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    debugPrint('--- Registration Flow: Sending OTP to $phone ---');
    final success = await authService.sendWhatsappOtp(phone);

    _isLoading = false;
    if (success) {
      debugPrint('--- Registration Flow: OTP Sent Successfully ---');
      _tempPhone = phone;
      _currentStep = RegistrationStep.otpInput;
    } else {
      debugPrint('--- Registration Flow: Failed to Send OTP ---');
      _errorMessage = 'Failed to send OTP. Please try again.';
    }
    notifyListeners();
  }

  // Step 2: Verify OTP and Register
  Future<void> verifyOtp(String otp) async {
    if (_tempPhone == null) {
      _errorMessage = 'Phone number missing. Please restart.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    debugPrint('--- Registration Flow: Verifying OTP ---');
    final credentials = await authService.verifyOtp(_tempPhone!, otp);

    if (credentials == null) {
      debugPrint('--- Registration Flow: OTP Verification Failed ---');
      _isLoading = false;
      _errorMessage = 'Invalid OTP. Please try again.';
      notifyListeners();
      return;
    }
    debugPrint(
        '--- Registration Flow: OTP Verified. Username: ${credentials['username']} ---');

    final username = credentials['username']!;
    final password = credentials['password']!;

    try {
      _currentStep = RegistrationStep.registering;
      _statusMessage = 'Connecting to phone service...';
      notifyListeners();

      debugPrint('--- Registration Flow: Fetching SIP config... ---');
      final sipConfig = await SipUtils.fetchSipConfig(usersClient);
      final domain = sipConfig.domain;
      final wsUrl = sipConfig.wsUrl;
      final originUrl = sipConfig.originUrl;
      debugPrint('--- Registration Flow: Domain: $domain ---');
      debugPrint('--- Registration Flow: WebSocket URL: $wsUrl ---');
      debugPrint('--- Registration Flow: Origin URL: $originUrl ---');

      debugPrint('--- Registration Flow: Computing MD5 Hash... ---');
      final sipPasswordHash =
          CryptoUtils.md5Hash('$username:$domain:$password');
      debugPrint('--- Registration Flow: MD5 Hash Computed: $sipPasswordHash ---');

      final sipUri = '$username@$domain';
      debugPrint('--- Registration Flow: Constructing SIP User: $sipUri ---');

      final user = SipUser(
        wsUrl: wsUrl,
        selectedTransport: TransportType.WS,
        wsExtraHeaders: {
          'Origin': originUrl,
        },
        sipUri: sipUri,
        port: AppConstants.port,
        displayName: username,
        password: password,
        authUser: username,
      );

      debugPrint('--- Registration Flow: Initiating SIP Registration... ---');
      final result = await registerUserUseCase.call(user);

      _isLoading = false;

      if (result is Success) {
        debugPrint('--- Registration Flow: Registration Initiated Successfully ---');
        _currentUser = user;
        _errorMessage = null;
        _statusMessage = 'Registering your line...';
        _beginSipRegistrationWatch();
      } else if (result is Failure) {
        debugPrint(
            '--- Registration Flow: Registration Failed: ${result.message} ---');
        _errorMessage = result.message;
        _currentStep = RegistrationStep.otpInput;
      }
    } catch (e) {
      debugPrint('--- Registration Flow: Exception: $e ---');
      _isLoading = false;
      _errorMessage = 'Registration failed: ${e.toString()}';
      _currentStep = RegistrationStep.otpInput;
    }

    notifyListeners();
  }

  void _beginSipRegistrationWatch() {
    _registrationTimeout?.cancel();

    if (sipHelper.registered) {
      _completeSipRegistration();
      return;
    }

    _registrationTimeout = Timer(const Duration(seconds: 45), () {
      if (_currentStep != RegistrationStep.registering) return;
      _errorMessage ??=
          'Phone service setup is taking too long. Check your network, then tap Retry.';
      _statusMessage = 'Connection timed out.';
      notifyListeners();
    });
  }

  void _completeSipRegistration() {
    _registrationTimeout?.cancel();
    _currentStep = RegistrationStep.completed;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> retrySipRegistration() async {
    final user = _currentUser;
    if (user == null) {
      _errorMessage = 'Missing account details. Please verify OTP again.';
      _currentStep = RegistrationStep.otpInput;
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _statusMessage = 'Retrying phone service connection...';
    _currentStep = RegistrationStep.registering;
    notifyListeners();

    final result = await registerUserUseCase.call(user);
    if (result is Success) {
      _beginSipRegistrationWatch();
    } else if (result is Failure) {
      _errorMessage = result.message;
      notifyListeners();
    }
  }

  void skipToApp() {
    _registrationTimeout?.cancel();
    _currentStep = RegistrationStep.completed;
    _statusMessage = null;
    notifyListeners();
  }

  void updateRegistrationState(RegistrationState state) {
    _registrationState = state;

    if (state.state == RegistrationStateEnum.REGISTERED) {
      debugPrint('--- Registration Flow: SIP Registered! ---');
      _completeSipRegistration();
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      debugPrint('--- Registration Flow: SIP Registration Failed! ---');
      if (_currentStep == RegistrationStep.registering) {
        _errorMessage =
            'Could not register for calls. Check your network and tap Retry, or continue to the app.';
        _statusMessage = 'Phone registration failed.';
        notifyListeners();
      }
    }
  }

  void updateTransportState(TransportState state) {
    if (_currentStep != RegistrationStep.registering) return;

    switch (state.state) {
      case TransportStateEnum.CONNECTING:
        _statusMessage = 'Connecting to phone server...';
        break;
      case TransportStateEnum.CONNECTED:
        _statusMessage = 'Connected. Registering your line...';
        break;
      case TransportStateEnum.DISCONNECTED:
        _statusMessage = 'Disconnected from phone server.';
        if (state.cause != null) {
          _errorMessage =
              'Could not connect to the phone server. Check your network and tap Retry.';
        }
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _registrationTimeout?.cancel();
    _currentStep = RegistrationStep.phoneInput;
    _tempPhone = null;
    _errorMessage = null;
    _statusMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
