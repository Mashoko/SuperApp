
import 'package:flutter/foundation.dart';
import 'package:mvvm_sip_demo/models/utility_bills/bill_payment.dart';
import 'package:mvvm_sip_demo/models/utility_bills/bill_type.dart';
import 'package:mvvm_sip_demo/services/utility_bills_service.dart';

class UtilityBillsViewModel extends ChangeNotifier {
  final UtilityBillsService _service;

  UtilityBillsViewModel(this._service);

  bool _isLoading = false;
  String? _errorMessage;
  List<UtilityBillPayment> _payments = [];
  UtilityBillPayment? _lastPayment;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<UtilityBillPayment> get payments => _payments;
  UtilityBillPayment? get lastPayment => _lastPayment;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  Future<void> loadPayments(String userId) async {
    try {
      _setLoading(true);
      _setError(null);
      _payments = _service.getPayments(userId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load payments: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _pay({
    required String userId,
    required UtilityBillType type,
    required String provider,
    required String accountOrMeter,
    required double amount,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      final payment = _service.payBill(
        userId: userId,
        billType: type,
        provider: provider,
        accountOrMeter: accountOrMeter,
        amount: amount,
      );
      _lastPayment = payment;
      _payments = _service.getPayments(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Payment failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> payElectricity({
    required String userId,
    required String provider,
    required String meterNumber,
    required double amount,
  }) {
    return _pay(
      userId: userId,
      type: UtilityBillType.electricity,
      provider: provider,
      accountOrMeter: meterNumber,
      amount: amount,
    );
  }

  Future<bool> payWater({
    required String userId,
    required String provider,
    required String accountNumber,
    required double amount,
  }) {
    return _pay(
      userId: userId,
      type: UtilityBillType.water,
      provider: provider,
      accountOrMeter: accountNumber,
      amount: amount,
    );
  }

  Future<bool> payInternet({
    required String userId,
    required String provider,
    required String accountNumber,
    required double amount,
  }) {
    return _pay(
      userId: userId,
      type: UtilityBillType.internet,
      provider: provider,
      accountOrMeter: accountNumber,
      amount: amount,
    );
  }

  Future<bool> payAirtime({
    required String userId,
    required String network,
    required String phoneNumber,
    required double amount,
  }) {
    return _pay(
      userId: userId,
      type: UtilityBillType.airtime,
      provider: network,
      accountOrMeter: phoneNumber,
      amount: amount,
    );
  }
}
