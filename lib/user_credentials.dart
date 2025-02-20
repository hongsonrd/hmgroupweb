// lib/user_credentials.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserCredentials extends ChangeNotifier {
  String _username = '';
  String _password = '';

  String get username => _username;
  String get password => _password;

  UserCredentials() {
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? '';
    _password = prefs.getString('password') ?? '';
    notifyListeners();
  }

  Future<void> setCredentials(String username, String password) async {
    _username = username.toLowerCase();
    _password = password.toLowerCase();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _username);
    await prefs.setString('password', _password);
    
    notifyListeners();
  }

  Future<void> clearCredentials() async {
    _username = '';
    _password = '';
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    
    notifyListeners();
  }
}