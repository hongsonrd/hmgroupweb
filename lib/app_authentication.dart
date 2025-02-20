// app_authentication.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AppAuthentication {
  static const String _tokenKey = 'auth_token';
  static const String _timestampKey = 'auth_timestamp';
  
  static Future<Map<String, String>> getTokenData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString(_tokenKey) ?? '',
      'timestamp': prefs.getString(_timestampKey) ?? ''
    };
  }

  static Future<Map<String, String>> generateToken() async {
    final timestamp = DateTime.now().toIso8601String();
    final key = 'your_secret_key'; // Replace with actual secret key
    
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(timestamp));
    final token = base64.encode(digest.bytes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_timestampKey, timestamp);

    return {
      'token': token,
      'timestamp': timestamp
    };
  }

  static Future<bool> isTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_timestampKey);
    if (timestamp == null) return true;

    final tokenTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    return now.difference(tokenTime).inHours >= 1;
  }
}