import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../domain/usecases/save_destination.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../domain/repositories/dialpad_repository.dart';
import '../../../recents/data/models/recent_call.dart';

class DialpadViewModel extends ChangeNotifier {
  final SaveDestination saveDestinationUseCase;
  final SIPUAHelper sipHelper;
  final OtpAuthService authService;
  final DialpadRepository repository;

  DialpadViewModel(this.saveDestinationUseCase, this.sipHelper, this.authService, this.repository);

  String _destination = '';
  String _registrationStatus = '';
  String _receivedMessage = '';
  
  // Balance properties
  final String _voiceBalance = '1 hrs 35 mins'; // Placeholder per requirement
  String _accountBalance = '\$0.00';

  String get voiceBalance => _voiceBalance;
  String get accountBalance => _accountBalance;

  String get destination => _destination;
  String get registrationStatus => _registrationStatus;
  String get receivedMessage => _receivedMessage;

  void setDestination(String destination) {
    _destination = destination;
    notifyListeners();
  }

  void addDigit(String digit) {
    _destination += digit;
    notifyListeners();
  }

  void removeDigit() {
    if (_destination.isNotEmpty) {
      _destination = _destination.substring(0, _destination.length - 1);
      notifyListeners();
    }
  }

  void clearDestination() {
    _destination = '';
    notifyListeners();
  }

  Future<void> saveDestination(String destination) async {
    final result = await saveDestinationUseCase.call(destination);
    if (result is Success) {
      _destination = destination;
      notifyListeners();
    }
  }

  void updateRegistrationStatus(String status) {
    _registrationStatus = status;
    notifyListeners();
  }

  void updateReceivedMessage(String message) {
    _receivedMessage = message;
    notifyListeners();
  }

  RegistrationState get registrationState => sipHelper.registerState;

  Future<void> loadAccountInfo() async {
    final creds = await authService.getStoredCredentials();
    if (creds != null && creds['username'] != null) {
      final summary = await authService.fetchAccountSummary(creds['username']!);
      if (summary != null) {
        // Assuming balance is in the summary map as a double or string
        final bal = summary['balance'];
        _accountBalance = bal != null ? '\$${bal.toString()}' : '\$0.00';
        
        // Voice balance placeholder logic or real field if available
        // _voiceBalance = ... 
        notifyListeners();
      }
    }
  }
  // Recents
  List<RecentCall> _recents = [];
  List<RecentCall> get recents => _recents;


  
  Future<void> loadRecents() async {
    final result = await repository.getRecents();
    if (result is Success<List<RecentCall>>) {
      _recents = result.data;
      notifyListeners();
    }
  }

  Future<void> addToRecents(String number) async {
    final call = RecentCall(
      number: number,
      timestamp: DateTime.now(),
      direction: 'outgoing',
    );
    await addRecentCall(call);
  }

  Future<void> addRecentCall(RecentCall call) async {
     final result = await repository.addRecent(call);
     if (result is Success) {
       await loadRecents();
     }
  }
}

