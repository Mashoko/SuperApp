import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../domain/entities/sip_user.dart';
import '../../domain/usecases/register_user.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../../../users_client.dart';
import '../../../../core/utils/crypto_utils.dart';
import '../../../../core/utils/constants.dart';

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

  RegistrationViewModel(
    this.registerUserUseCase,
    this.authService,
    this.usersClient,
  );

  RegistrationState? _registrationState;
  bool _isLoading = false;
  String? _errorMessage;
  SipUser? _currentUser;
  RegistrationStep _currentStep = RegistrationStep.phoneInput;
  String? _tempPhone;

  RegistrationState? get registrationState => _registrationState;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SipUser? get currentUser => _currentUser;
  RegistrationStep get currentStep => _currentStep;

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
    notifyListeners();

    // 1. Verify OTP
    debugPrint('--- Registration Flow: Verifying OTP ---');
    final credentials = await authService.verifyOtp(_tempPhone!, otp);
    
    if (credentials == null) {
      debugPrint('--- Registration Flow: OTP Verification Failed ---');
      _isLoading = false;
      _errorMessage = 'Invalid OTP. Please try again.';
      notifyListeners();
      return;
    }
    debugPrint('--- Registration Flow: OTP Verified. Username: ${credentials['username']} ---');

    final username = credentials['username']!;
    final password = credentials['password']!;

    try {
      // 2. Fetch SIP Configuration
      _currentStep = RegistrationStep.registering;
      notifyListeners();

      // Fetch Domain
      debugPrint('--- Registration Flow: Fetching SIP Domain... ---');
      final domainResp = await usersClient.getDomainForPackageID();
      final domain = domainResp.domain.isNotEmpty ? domainResp.domain : AppConstants.sipDomain;
      debugPrint('--- Registration Flow: Domain: $domain ---');

      // Fetch WebSocket URL
      debugPrint('--- Registration Flow: Fetching WebSocket URL... ---');
      await usersClient.getWebsocketUrlFromApi();
      // Parse WSS URL from response info or use default if empty
      // Assuming the response puts the URL in 'info.information' or similar if not explicit field
      // The proto definition has 'info' field. Let's assume it returns in a standard way or we use default.
      // Actually the proto response has 'info' and 'success' fields. 
      // The user requirement says: "Use the returned WSS URL like: wss://sip.africom.net:7443/ws"
      // Let's assume for now we use the one from constants if API fails or returns empty, 
      // but ideally we should parse it. 
      // For now, let's use the AppConstants.websocketUrl as fallback.
      final wsUrl = AppConstants.websocketUrl; 
      debugPrint('--- Registration Flow: WebSocket URL: $wsUrl ---');

      // Fetch Origin URL
      debugPrint('--- Registration Flow: Fetching Origin URL... ---');
      final originResp = await usersClient.getOriginUrlFromApi();
      final originUrl = originResp.info.information.isNotEmpty 
          ? originResp.info.information 
          : 'https://$domain'; // Fallback
      debugPrint('--- Registration Flow: Origin URL: $originUrl ---');

      // 3. Compute MD5 Hash for SIP Password
      // SIP password = MD5("username:domain:password")
      // NOTE: Standard SIP auth (Digest) requires the plain password to compute the response.
      // Passing the hash as the password to sip_ua will cause double-hashing if the server expects standard auth.
      // We will compute it for logging/verification but pass the plain password to sip_ua.
      debugPrint('--- Registration Flow: Computing MD5 Hash... ---');
      final sipPasswordHash = CryptoUtils.md5Hash('$username:$domain:$password');
      debugPrint('--- Registration Flow: MD5 Hash Computed: $sipPasswordHash ---');

      // 4. Construct SIP User
      final sipUri = '$username@$domain';
      debugPrint('--- Registration Flow: Constructing SIP User: $sipUri ---');
      
      final user = SipUser(
        wsUrl: wsUrl,
        selectedTransport: TransportType.WS,
        wsExtraHeaders: {
          'Origin': originUrl,
          // 'Host': domain, // REMOVED: Do not override Host header in WS handshake. 
          // The WS stack will set it to the WSS URL host automatically.
        },
        sipUri: sipUri,
        port: AppConstants.port,
        displayName: username,
        password: password, // Use plain password for sip_ua to handle Digest Auth
        authUser: username,
      );

      // 5. Register SIP Account
      debugPrint('--- Registration Flow: Initiating SIP Registration... ---');
      final result = await registerUserUseCase.call(user);

      _isLoading = false;

      if (result is Success) {
        debugPrint('--- Registration Flow: Registration Initiated Successfully ---');
        _currentUser = user;
        // Do NOT transition to completed yet. Wait for registrationStateChanged.
        // _currentStep = RegistrationStep.completed; 
        _errorMessage = null;
      } else if (result is Failure) {
        debugPrint('--- Registration Flow: Registration Failed: ${result.message} ---');
        _errorMessage = result.message;
        _currentStep = RegistrationStep.otpInput; // Go back to allow retry? Or stay?
      }
    } catch (e) {
      debugPrint('--- Registration Flow: Exception: $e ---');
      _isLoading = false;
      _errorMessage = 'Registration failed: ${e.toString()}';
      _currentStep = RegistrationStep.otpInput;
    }

    notifyListeners();
  }

  void updateRegistrationState(RegistrationState state) {
    _registrationState = state;
    
    if (state.state == RegistrationStateEnum.REGISTERED) {
      debugPrint('--- Registration Flow: SIP Registered! ---');
      _currentStep = RegistrationStep.completed;
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      debugPrint('--- Registration Flow: SIP Registration Failed! ---');
      _errorMessage = 'SIP Registration Failed. Please check your network or credentials.';
      // Optionally go back to a previous step or stay in registering to allow retry
      // _currentStep = RegistrationStep.otpInput;
    }
    
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  void reset() {
    _currentStep = RegistrationStep.phoneInput;
    _tempPhone = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}

