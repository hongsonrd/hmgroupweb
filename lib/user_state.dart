import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserState extends ChangeNotifier {
  static final UserState _instance = UserState._internal();
  factory UserState() => _instance;
  UserState._internal();

  bool _isAuthenticated = false;
  String? _chamCong;
  String? _updateResponse1;
  String? _updateResponse2;
  String? _updateResponse3;
  String? _updateResponse4;
  Map<String, dynamic>? _currentUser;
  String _defaultScreen = 'Chụp ảnh';
  String? _loginResponse;
  String _queryType = '1';

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get chamCong => _chamCong;
  String? get updateResponse1 => _updateResponse1;
  String? get updateResponse2 => _updateResponse2;
  String? get updateResponse3 => _updateResponse3;
  String? get updateResponse4 => _updateResponse4;
  Map<String, dynamic>? get currentUser => _currentUser;
  String get defaultScreen => _defaultScreen;
  String? get loginResponse => _loginResponse;
  String get queryType => _queryType;
Future<Map<String, String>?> getStoredToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('auth_token');
  String? timestamp = prefs.getString('token_timestamp');
  
  if (token == null || timestamp == null) {
    return null;
  }
  
  return {
    'token': token,
    'timestamp': timestamp
  };
}

Future<bool> verifyStoredToken() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('auth_token');
  String? timestamp = prefs.getString('token_timestamp');
  
  if (token == null || timestamp == null) {
    return false;
  }
  
  final tokenTime = int.parse(timestamp);
  if (DateTime.now().millisecondsSinceEpoch - tokenTime > 3600000) {
    return false;
  }
  
  return true;
}
  Future<void> setUpdateResponses(String response1, String response2, String response3, String response4, String chamCong) async {
    _updateResponse1 = response1;
    _updateResponse2 = response2;
    _updateResponse3 = response3;
    _updateResponse4 = response4;
    _chamCong = chamCong;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('update_response1', response1);
    await prefs.setString('update_response2', response2);
    await prefs.setString('update_response3', response3);
    print('Saving project data: $response4');
    await prefs.setString('update_response4', response4);
    await prefs.setString('cham_cong', chamCong);
    notifyListeners();
  }

  Future<void> loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('current_user');
    _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    
    if (userData != null) {
      _currentUser = json.decode(userData);
      _queryType = _currentUser?['queryType'] ?? '1';
      _chamCong = prefs.getString('cham_cong');
      _updateResponse1 = prefs.getString('update_response1') ?? '';
      _updateResponse2 = prefs.getString('update_response2') ?? '';
      _updateResponse3 = prefs.getString('update_response3') ?? '';
      _updateResponse4 = prefs.getString('update_response4') ?? '';
      _defaultScreen = prefs.getString('default_screen') ?? 'Chụp ảnh';
    }
    notifyListeners();
  }

  Future<void> setUser(Map<String, dynamic> user) async {
    _currentUser = user;
    _isAuthenticated = true;
    _queryType = user['queryType'] ?? '1';
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', json.encode(user));
    await prefs.setBool('is_authenticated', true);
    notifyListeners();
  }

  Future<void> setDefaultScreen(String screen) async {
    _defaultScreen = screen;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_screen', screen);
    notifyListeners();
  }

  Future<void> setLoginResponse(String response) async {
    _loginResponse = response;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_response', response);
    notifyListeners();
  }

  Future<void> clearUser() async {
    _currentUser = null;
    _isAuthenticated = false;
    _loginResponse = null;
    _updateResponse1 = null;
    _updateResponse2 = null;
    _updateResponse3 = null;
    _updateResponse4 = null;
    _chamCong = null;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('login_response');
    await prefs.remove('update_response1');
    await prefs.remove('update_response2');
    await prefs.remove('update_response3');
    await prefs.remove('update_response4');
    await prefs.remove('cham_cong');
    notifyListeners();
  }
}