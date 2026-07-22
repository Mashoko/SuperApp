import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../domain/usecases/save_destination.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../domain/repositories/dialpad_repository.dart';
import '../../../recents/data/models/recent_call.dart';
import '../../../../payments_client.dart';

class DialpadViewModel extends ChangeNotifier {
  final SaveDestination saveDestinationUseCase;
  final SIPUAHelper sipHelper;
  final OtpAuthService authService;
  final DialpadRepository repository;
  final PaymentsClient paymentsClient;

  DialpadViewModel(this.saveDestinationUseCase, this.sipHelper, this.authService, this.repository, this.paymentsClient);

  String _destination = '';
  String _registrationStatus = '';
  String _receivedMessage = '';
  
  // Balance properties
  String _voiceBalance = '';
  String _accountBalance = '';

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

  bool get isSipReady => sipHelper.connected && sipHelper.registered;

  Future<void> loadAccountInfo() async {
    final creds = await authService.getStoredCredentials();
    if (creds != null && creds['username'] != null) {
      final username = creds['username']!;
      final summary = await authService.fetchAccountSummary(username, password: creds['password']);
      if (summary != null) {
        final bal = summary['balance'];
        final balNum = bal is num ? bal.toDouble() : 0.0;
        _voiceBalance = _formatVoiceBalance(balNum);
        _scheduleNotify();
      }

      final resp = await paymentsClient.dealerAccountBalances(
        username: username,
        password: creds['password'] ?? '',
      );
      final ok = resp.status == Status.SUCCESSFUL || resp.status == Status.INFORMATION;
      _accountBalance = ok ? '\$${resp.balance.toStringAsFixed(2)}' : '';
      _scheduleNotify();
    }
  }

  void _scheduleNotify() {
    Future.microtask(notifyListeners);
  }
  // Recents
  List<RecentCall> _recents = [];
  List<RecentCall> get recents => _recents;


  
  Future<void> loadRecents() async {
    final result = await repository.getRecents();
    if (result is Success<List<RecentCall>>) {
      _recents = result.data;
      _scheduleNotify();
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

  String _formatVoiceBalance(double nanoseconds) {
    if (nanoseconds <= 0) return '0 m';
    final d = Duration(microseconds: (nanoseconds / 1000).round());
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes.remainder(60)} m';
    if (d.inMinutes >= 1) return '${d.inMinutes} m ${d.inSeconds.remainder(60)} s';
    return '${d.inSeconds} s';
  }
}

