import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  Future<bool> signup(String name, String email, String password) async {
    // In a real app, this would make an API call.
    // Here we just save the user data locally to simulate a database.
    final prefs = await SharedPreferences.getInstance();
    
    // Check if user already exists (simulated)
    final existingData = prefs.getString(_userKey);
    if (existingData != null) {
      final Map<String, dynamic> users = jsonDecode(existingData);
      if (users.containsKey(email)) {
        return false; // User already exists
      }
    }

    // Save user data
    // We'll store a map of email -> user data to support multiple users in this simulation
    Map<String, dynamic> users = {};
    if (existingData != null) {
      users = jsonDecode(existingData);
    }
    
    users[email] = {
      'name': name,
      'email': email,
      'password': password, // NEVER store passwords in plain text in a real app!
    };

    await prefs.setString(_userKey, jsonEncode(users));
    
    // Auto login after signup
    await login(email, password);
    return true;
  }

  Future<bool> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getString(_userKey);
    
    if (existingData == null) return false;

    final Map<String, dynamic> users = jsonDecode(existingData);
    
    if (users.containsKey(email)) {
      final user = users[email];
      if (user['password'] == password) {
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString('current_user', email);
        return true;
      }
    }
    
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove('current_user');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('current_user');
    if (email == null) return null;

    final existingData = prefs.getString(_userKey);
    if (existingData == null) return null;

    final Map<String, dynamic> users = jsonDecode(existingData);
    return users[email];
  }
}
