import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/models/calling/call.dart';
import 'package:mvvm_sip_demo/services/calling_service.dart';

class CallingViewModel extends ChangeNotifier {
  final CallingService _service;

  CallingViewModel(this._service);

  List<Call> _activeCalls = [];
  List<Call> _callHistory = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = false;
  String? _errorMessage;

  List<Call> get activeCalls => _activeCalls;
  List<Call> get callHistory => _callHistory;
  Map<String, dynamic> get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  Future<void> initiateCall(String callerId, String receiverId, {String callType = 'voice'}) async {
    try {
      _setLoading(true);
      _setError(null);
      _service.initiateCall(callerId, receiverId, callType: callType);
      await loadActiveCalls();
      notifyListeners();
    } catch (e) {
      _setError('Failed to initiate call: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      _setLoading(true);
      _setError(null);
      _service.answerCall(callId);
      await loadActiveCalls();
      notifyListeners();
    } catch (e) {
      _setError('Failed to answer call: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      _setLoading(true);
      _setError(null);
      _service.rejectCall(callId);
      await loadActiveCalls();
      await loadCallHistory();
      notifyListeners();
    } catch (e) {
      _setError('Failed to reject call: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> endCall(String callId) async {
    try {
      _setLoading(true);
      _setError(null);
      _service.endCall(callId);
      await loadActiveCalls();
      await loadCallHistory();
      notifyListeners();
    } catch (e) {
      _setError('Failed to end call: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadActiveCalls() async {
    try {
      _activeCalls = _service.getActiveCalls();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load active calls: $e');
    }
  }

  Future<void> loadCallHistory({String? userId}) async {
    try {
      _callHistory = _service.getCallHistory(userId: userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load call history: $e');
    }
  }

  Future<void> loadStatistics(String userId) async {
    try {
      _statistics = _service.getCallStatistics(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load statistics: $e');
    }
  }
}

