import 'package:flutter/foundation.dart';
import '../../models/payment_method.dart';
import '../../models/pm_transaction.dart';

class PaymentMethodsViewModel extends ChangeNotifier {
  final List<PaymentMethod> _methods = [];
  final List<PmTransaction> _transactions = [];

  List<PaymentMethod> get methods => List.unmodifiable(_methods);
  List<PmTransaction> get transactions => List.unmodifiable(_transactions);

  PaymentMethod? get defaultMethod =>
      _methods.where((m) => m.status == MethodStatus.defaultMethod).firstOrNull;

  String get subtitle {
    if (_methods.isEmpty) return 'No methods linked';
    final count = _methods.length;
    return '$count method${count != 1 ? 's' : ''} linked';
  }

  void addMethod(PaymentMethod method) {
    // First method added automatically becomes the default.
    final incoming = _methods.isEmpty
        ? method.copyWith(status: MethodStatus.defaultMethod)
        : method;
    _methods.add(incoming);
    notifyListeners();
  }

  void removeMethod(String id) {
    _methods.removeWhere((m) => m.id == id);
    // If no default remains, promote the first available method.
    if (_methods.isNotEmpty &&
        _methods.every((m) => m.status != MethodStatus.defaultMethod)) {
      _methods[0] = _methods[0].copyWith(status: MethodStatus.defaultMethod);
    }
    notifyListeners();
  }

  void setDefault(String id) {
    for (int i = 0; i < _methods.length; i++) {
      final m = _methods[i];
      final newStatus = m.id == id
          ? MethodStatus.defaultMethod
          : (m.status == MethodStatus.defaultMethod
              ? MethodStatus.verified
              : m.status);
      _methods[i] = m.copyWith(status: newStatus);
    }
    notifyListeners();
  }

  void recordTransaction(PmTransaction tx) {
    _transactions.insert(0, tx);
    notifyListeners();
  }
}
