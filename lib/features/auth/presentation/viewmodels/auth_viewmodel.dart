import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  
  AuthViewModel(this._authService);
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  Future<void> checkLoginStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      _currentUser = await _authService.getCurrentUser();
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final success = await _authService.login(email, password);
      if (success) {
        _currentUser = await _authService.getCurrentUser();
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid email or password';
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final success = await _authService.signup(name, email, password);
      if (success) {
        _currentUser = await _authService.getCurrentUser();
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'User already exists';
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
