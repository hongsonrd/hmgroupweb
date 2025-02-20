// http_client.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_authentication.dart';

class AuthenticatedHttpClient {
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    var tokenData = await AppAuthentication.generateToken();
    
    final mergedHeaders = {
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Authorization': 'Bearer ${tokenData['token']}',
      'X-Timestamp': tokenData['timestamp'] ?? '',
      ...?headers,
    };

    var response = await http.get(url, headers: mergedHeaders);

    if (response.statusCode == 401) {
      tokenData = await AppAuthentication.generateToken();
      mergedHeaders['Authorization'] = 'Bearer ${tokenData['token']}';
      mergedHeaders['X-Timestamp'] = tokenData['timestamp'] ?? '';
      response = await http.get(url, headers: mergedHeaders);
    }

    return response;
  }
  static Future<http.MultipartRequest> multipartRequest(String method, Uri url) async {
    var tokenData = await AppAuthentication.generateToken();
    
    var request = http.MultipartRequest(method, url);
    request.headers.addAll({
      'Accept': '*/*',
      'Authorization': 'Bearer ${tokenData['token']}',
      'X-Timestamp': tokenData['timestamp'] ?? ''
    });

    return request;
  }

  static Future<http.StreamedResponse> send(http.MultipartRequest request) async {
    var response = await request.send();

    if (response.statusCode == 401) {
      // Token expired, generate new one and retry
      var tokenData = await AppAuthentication.generateToken();
      request.headers['Authorization'] = 'Bearer ${tokenData['token']}';
      request.headers['X-Timestamp'] = tokenData['timestamp'] ?? '';
      response = await request.send();
    }

    return response;
  }
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool isBodyEncoded = false,
  }) async {
    var tokenData = await AppAuthentication.generateToken();
    
    final mergedHeaders = {
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Authorization': 'Bearer ${tokenData['token']}',
      'X-Timestamp': tokenData['timestamp'] ?? '',
      ...?headers,
    };

    final finalBody = isBodyEncoded ? body : (body != null ? json.encode(body) : null);

    var response = await http.post(
      url,
      headers: mergedHeaders,
      body: finalBody,
    );

    if (response.statusCode == 401) {
      tokenData = await AppAuthentication.generateToken();
      mergedHeaders['Authorization'] = 'Bearer ${tokenData['token']}';
      mergedHeaders['X-Timestamp'] = tokenData['timestamp'] ?? '';
      response = await http.post(
        url,
        headers: mergedHeaders,
        body: finalBody,
      );
    }

    return response;
  }
}