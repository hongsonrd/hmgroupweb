// checklist_network.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class ChecklistQueueItem {
  final String id;
  final String checklistId;
  final String projectName;
  final String reportType;
  final String reportInOut;
  final Set<String> taskIds;
  final String note;
  final String? localImagePath;
  final DateTime createdAt;
  final int retryCount;
  final String? errorMessage;
  final String userId;

  ChecklistQueueItem({
    required this.id,
    required this.checklistId,
    required this.projectName,
    required this.reportType,
    required this.reportInOut,
    required this.taskIds,
    required this.note,
    this.localImagePath,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'checklistId': checklistId,
      'projectName': projectName,
      'reportType': reportType,
      'reportInOut': reportInOut,
      'taskIds': taskIds.toList(),
      'note': note,
      'localImagePath': localImagePath,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'userId': userId,
    };
  }

  factory ChecklistQueueItem.fromMap(Map<String, dynamic> map) {
    return ChecklistQueueItem(
      id: map['id'],
      checklistId: map['checklistId'],
      projectName: map['projectName'],
      reportType: map['reportType'],
      reportInOut: map['reportInOut'],
      taskIds: Set<String>.from(map['taskIds'] ?? []),
      note: map['note'] ?? '',
      localImagePath: map['localImagePath'],
      createdAt: DateTime.parse(map['createdAt']),
      retryCount: map['retryCount'] ?? 0,
      errorMessage: map['errorMessage'],
      userId: map['userId'] ?? '',
    );
  }

  ChecklistQueueItem copyWith({
    int? retryCount,
    String? errorMessage,
  }) {
    return ChecklistQueueItem(
      id: id,
      checklistId: checklistId,
      projectName: projectName,
      reportType: reportType,
      reportInOut: reportInOut,
      taskIds: taskIds,
      note: note,
      localImagePath: localImagePath,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      userId: userId,
    );
  }
}

class ChecklistNetworkManager {
  static final ChecklistNetworkManager _instance = ChecklistNetworkManager._internal();
  factory ChecklistNetworkManager() => _instance;
  ChecklistNetworkManager._internal();

  static const String _queueKey = 'checklist_queue';
  static const int maxRetries = 3;
  Timer? _periodicTimer;
  String? _baseUrl;

  void initialize(String baseUrl) {
    _baseUrl = baseUrl;
  }

  void startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      processQueue();
    });
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
  }

  Future<bool> hasNetworkConnection() async {
    try {
      final result = await http.get(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> queueChecklistReport({
    required String checklistId,
    required String projectName,
    required String reportType,
    required String reportInOut,
    required Set<String> taskIds,
    String note = '',
    XFile? image,
    required String userId,
    DateTime? customTimestamp,
  }) async {
    final id = 'checklist_${const Uuid().v4()}';
    String? localImagePath;

    // Save image locally if provided
    if (image != null) {
      localImagePath = await _saveImageToLocal(image.path);
    }

    final queueItem = ChecklistQueueItem(
      id: id,
      checklistId: checklistId,
      projectName: projectName,
      reportType: reportType,
      reportInOut: reportInOut,
      taskIds: taskIds,
      note: note,
      localImagePath: localImagePath,
      createdAt: customTimestamp ?? DateTime.now(), 
      userId: userId,
    );

    await _addToQueue(queueItem);

    // Try to send immediately if network is available
    if (await hasNetworkConnection()) {
      try {
        print('Attempting immediate send for checklist report...');
        await _sendChecklistReport(queueItem);
        await _removeFromQueue(queueItem.id);
        print('Immediate send successful, removed from queue');
        
        // Clean up local image
        if (localImagePath != null) {
          await _deleteLocalImage(localImagePath);
        }
      } catch (e) {
        print('Immediate send failed: $e');
        if (_shouldDiscardError(e)) {
          print('Discarding checklist item ${queueItem.id} due to non-recoverable error: $e');
          await _removeFromQueue(queueItem.id);
          
          if (localImagePath != null) {
            await _deleteLocalImage(localImagePath);
          }
        } else {
          print('Will retry later: $e');
        }
      }
    } else {
      print('No network connection, item queued for later');
    }
  }

  Future<void> processQueue() async {
    if (!await hasNetworkConnection()) {
      print('No network connection for queue processing');
      return;
    }

    final queue = await _getQueue();
    if (queue.isEmpty) return;

    print('Processing ${queue.length} items in checklist queue');

    for (final item in queue) {
      try {
        print('Attempting to send checklist item ${item.id}');
        await _sendChecklistReport(item);
        await _removeFromQueue(item.id);
        print('Successfully sent and removed checklist item ${item.id}');
        
        // Clean up local image
        if (item.localImagePath != null) {
          await _deleteLocalImage(item.localImagePath!);
        }
      } catch (e) {
        print('Failed to send checklist item ${item.id}: $e');
        if (_shouldDiscardError(e)) {
          print('Discarding checklist item ${item.id} due to non-recoverable error: $e');
          await _removeFromQueue(item.id);
          
          if (item.localImagePath != null) {
            await _deleteLocalImage(item.localImagePath!);
          }
        } else {
          final updatedItem = item.copyWith(
            retryCount: item.retryCount + 1,
            errorMessage: e.toString(),
          );
          
          if (updatedItem.retryCount >= maxRetries) {
            print('Max retries reached for checklist item ${item.id}, removing from queue');
            await _removeFromQueue(item.id);
            if (item.localImagePath != null) {
              await _deleteLocalImage(item.localImagePath!);
            }
          } else {
            print('Updating retry count for checklist item ${item.id} to ${updatedItem.retryCount}');
            await _updateQueueItem(updatedItem);
          }
        }
      }
    }
  }

  Future<void> _sendChecklistReport(ChecklistQueueItem item) async {
  if (_baseUrl == null) throw Exception('Base URL not initialized');

  final timestamp = item.createdAt; // Use the original creation time
  final reportId = 'r${timestamp.millisecondsSinceEpoch}';
  final fd = '${timestamp.year.toString().padLeft(4, '0')}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  final ft = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

  print('Sending checklist report with userId: ${item.userId}');

  final req = http.MultipartRequest('POST', Uri.parse('$_baseUrl/checklistsubmit/'));
  req.fields.addAll({
    'reportId': reportId,
    'checklistId': item.checklistId,
    'projectName': item.projectName,
    'reportType': item.reportType,
    'reportDate': fd,
    'reportTime': ft,
    'userId': item.userId,
    'reportTaskList': item.taskIds.join('/'),
    'reportNote': item.note,
    'reportInOut': item.reportInOut,
  });

    if (item.localImagePath != null && File(item.localImagePath!).existsSync()) {
      req.files.add(await http.MultipartFile.fromPath(
        'reportImage', 
        item.localImagePath!,
        filename: path.basename(item.localImagePath!),
      ));
    }

    final res = await req.send().timeout(const Duration(seconds: 30));
    final body = await res.stream.bytesToString();
    
    print('Checklist submit response: ${res.statusCode} - $body');
    
    if (!(res.statusCode == 200 || res.statusCode == 201)) {
      throw Exception('Submit failed (${res.statusCode}) $body');
    }
  }

  bool _shouldDiscardError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Server errors that should be discarded
    if (errorString.contains('500') || 
        errorString.contains('server returned 500') ||
        errorString.contains('internal server error') ||
        errorString.contains('server returned 400') ||
        errorString.contains('server returned 401') ||
        errorString.contains('server returned 403') ||
        errorString.contains('server returned 404') ||
        errorString.contains('server returned 422')) {
      return true;
    }
    
    // Keep network errors for retry
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('no internet') ||
        errorString.contains('socket')) {
      return false;
    }
    
    return true; // Discard unknown errors by default
  }

  Future<String> _saveImageToLocal(String imagePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'checklist_${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final localPath = '${appDir.path}/$fileName';
    
    final originalFile = File(imagePath);
    await originalFile.copy(localPath);
    
    return localPath;
  }

  Future<void> _deleteLocalImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting local image: $e');
    }
  }

  Future<List<ChecklistQueueItem>> _getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList(_queueKey) ?? [];
    
    return queueJson.map((item) {
      try {
        return ChecklistQueueItem.fromMap(json.decode(item));
      } catch (e) {
        print('Error parsing checklist queue item: $e');
        return null;
      }
    }).where((item) => item != null).cast<ChecklistQueueItem>().toList();
  }

  Future<void> _addToQueue(ChecklistQueueItem item) async {
    final queue = await _getQueue();
    queue.add(item);
    await _saveQueue(queue);
  }

  Future<void> _removeFromQueue(String itemId) async {
    final queue = await _getQueue();
    queue.removeWhere((item) => item.id == itemId);
    await _saveQueue(queue);
  }

  Future<void> _updateQueueItem(ChecklistQueueItem updatedItem) async {
    final queue = await _getQueue();
    final index = queue.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      queue[index] = updatedItem;
      await _saveQueue(queue);
    }
  }

  Future<void> _saveQueue(List<ChecklistQueueItem> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = queue.map((item) => json.encode(item.toMap())).toList();
    await prefs.setStringList(_queueKey, queueJson);
  }

  Future<int> getQueueLength() async {
    final queue = await _getQueue();
    return queue.length;
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  void dispose() {
    _periodicTimer?.cancel();
  }
}