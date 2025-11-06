// chat_ai_network.dart - Network operations and data processing for ChatAI
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http_parser/http_parser.dart';
import 'chat_ai_custom.dart';
import 'chat_ai_case.dart';
import 'chat_ai_convert.dart';

// Data models
class CreditBalance {
  final double currentToken;
  final double startingToken;
  final double percentRemaining;
  final bool canUse;

  CreditBalance({
    required this.currentToken,
    required this.startingToken,
    required this.percentRemaining,
    required this.canUse,
  });

  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    return CreditBalance(
      currentToken: (json['currentToken'] ?? 0).toDouble(),
      startingToken: (json['startingToken'] ?? 250000).toDouble(),
      percentRemaining: (json['percentRemaining'] ?? 100).toDouble(),
      canUse: json['canUse'] ?? true,
    );
  }
}

class ChatSession {
  final String id;
  String title;
  List<ChatMessage> messages;
  List<Map<String, dynamic>> history;
  final DateTime createdAt;
  DateTime lastUpdated;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.history,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'history': history,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
    history: List<Map<String, dynamic>>.from(json['history'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final List<String>? attachedFiles;
  final String? generatedImageData;
  final String? generatedVideoUrl;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.attachedFiles,
    this.generatedImageData,
    this.generatedVideoUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'attachedFiles': attachedFiles,
    'generatedImageData': generatedImageData,
    'generatedVideoUrl': generatedVideoUrl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    role: json['role'],
    content: json['content'],
    attachedFiles: json['attachedFiles'] != null ? List<String>.from(json['attachedFiles']) : null,
    generatedImageData: json['generatedImageData'],
    generatedVideoUrl: json['generatedVideoUrl'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

// Mixin for network operations
mixin ChatAINetworkMixin<T extends StatefulWidget> on State<T> {
  // Abstract properties that must be provided by the state class
  String get username;
  String get apiBaseUrl;
  List<ChatSession> get sessions;
  set sessions(List<ChatSession> value);
  ChatSession? get currentSession;
  set currentSession(ChatSession? value);
  List<ChatMessage> get messages;
  set messages(List<ChatMessage> value);
  bool get isStreaming;
  set isStreaming(bool value);
  String get currentStreamingMessage;
  set currentStreamingMessage(String value);
  String? get currentStreamingImage;
  set currentStreamingImage(String? value);
  String? get currentStreamingVideo;
  set currentStreamingVideo(String? value);
  CreditBalance? get creditBalance;
  set creditBalance(CreditBalance? value);
  bool get isLoadingCredit;
  set isLoadingCredit(bool value);
  String get selectedModel;
  String get mode;
  String? get selectedCaseType;
  CaseFileData? get caseFileData;
  List<File> get selectedFiles;
  String get imageRatio;
  String? get selectedProfessionalId;
  List<AIProfessional> get customProfessionals;
  TextEditingController get messageController;

  // Methods that need to be implemented
  void showErrorMessage(String message);
  void scrollToBottom();
  void setAvatarState(dynamic state);
  String getSystemPrompt(String model);

  Future<void> loadUserData(void Function(String) setUsername) async {
    final prefs = await SharedPreferences.getInstance();
    final userObj = prefs.getString('current_user');

    if (userObj != null && userObj.isNotEmpty) {
      try {
        final userData = json.decode(userObj);
        setUsername(userData['username'] ?? '');
      } catch (e) {
        setUsername(userObj);
      }
    }
  }

  Future<void> loadCreditBalance() async {
    if (username.isEmpty) return;

    isLoadingCredit = true;

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/aichat/credit/$username'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        creditBalance = CreditBalance.fromJson(data);
      } else {
        print('Failed to load credit: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading credit: $e');
    } finally {
      isLoadingCredit = false;
    }
  }

  Future<void> loadSessions() async {
    if (username.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString('chat_sessions_$username');

      if (sessionsJson != null) {
        final List<dynamic> sessionsList = json.decode(sessionsJson);
        sessions = sessionsList.map((s) => ChatSession.fromJson(s)).toList();

        if (sessions.isNotEmpty) {
          currentSession = sessions.first;
          messages = currentSession!.messages;
        }
      }
    } catch (e) {
      print('Error loading sessions: $e');
    }
  }

  Future<void> saveSessions() async {
    if (username.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = json.encode(sessions.map((s) => s.toJson()).toList());
      await prefs.setString('chat_sessions_$username', sessionsJson);
    } catch (e) {
      print('Error saving sessions: $e');
    }
  }

  Future<void> saveImageToDevice(String imageData, bool isBase64) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        showErrorMessage('Cần cấp quyền lưu trữ để lưu ảnh');
        return;
      }

      dynamic imageBytes;
      if (isBase64) {
        final base64String = imageData.contains(',')
            ? imageData.split(',')[1]
            : imageData;
        imageBytes = base64Decode(base64String);
      } else {
        final response = await http.get(Uri.parse(imageData));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        } else {
          showErrorMessage('Không thể tải ảnh');
          return;
        }
      }

      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: 'ai_image_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result['isSuccess'] == true) {
        showErrorMessage('✅ Đã lưu ảnh thành công');
      } else {
        showErrorMessage('Không thể lưu ảnh');
      }
    } catch (e) {
      showErrorMessage('Lỗi: $e');
      print('Error saving image: $e');
    }
  }

  Future<void> saveVideoToDevice(String videoUrl) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        showErrorMessage('Cần cấp quyền lưu trữ để lưu video');
        return;
      }

      showErrorMessage('Đang tải video...');

      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode == 200) {
        final videoBytes = response.bodyBytes;

        final result = await ImageGallerySaver.saveFile(
          videoUrl,
          name: 'ai_video_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (result['isSuccess'] == true) {
          showErrorMessage('✅ Đã lưu video thành công');
        } else {
          showErrorMessage('Không thể lưu video');
        }
      } else {
        showErrorMessage('Không thể tải video');
      }
    } catch (e) {
      showErrorMessage('Lỗi: $e');
      print('Error saving video: $e');
    }
  }

  // Note: sendMessage method is too large and complex to include here
  // It should be implemented in the main state class, but can call
  // helper methods from this mixin for specific tasks
}
