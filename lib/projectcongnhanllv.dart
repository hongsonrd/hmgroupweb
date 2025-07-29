// projectcongnhanllv.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TaskScheduleModel {
  final String taskId;
  final String duan;
  final String vitri;
  final String weekday;
  final String start;
  final String end;
  final String tuan;
  final String thang;
  final String ngaybc;
  final String task;
  final String username;

  TaskScheduleModel({
    required this.taskId,
    required this.duan,
    required this.vitri,
    required this.weekday,
    required this.start,
    required this.end,
    required this.tuan,
    required this.thang,
    required this.ngaybc,
    required this.task,
    required this.username,
  });

  factory TaskScheduleModel.fromMap(Map<String, dynamic> map) {
    return TaskScheduleModel(
      taskId: map['TASKID']?.toString() ?? '',
      duan: map['DUAN']?.toString() ?? '',
      vitri: map['VITRI']?.toString() ?? '',
      weekday: map['WEEKDAY']?.toString() ?? '',
      start: map['START']?.toString() ?? '',
      end: map['END']?.toString() ?? '',
      tuan: map['TUAN']?.toString() ?? '',
      thang: map['THANG']?.toString() ?? '',
      ngaybc: map['NGAYBC']?.toString() ?? '',
      task: map['TASK']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'TASKID': taskId,
      'DUAN': duan,
      'VITRI': vitri,
      'WEEKDAY': weekday,
      'START': start,
      'END': end,
      'TUAN': tuan,
      'THANG': thang,
      'NGAYBC': ngaybc,
      'TASK': task,
      'username': username,
    };
  }
}
class TaskScheduleManager {
  static const String _storageKey = 'task_schedules';
  static const String _lastSyncKey = 'task_schedules_last_sync';
  static const String _qrLookupStorageKey = 'qr_lookup_data';
  static const String _qrLookupLastSyncKey = 'qr_lookup_last_sync';

  static Future<bool> hasEverSynced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_lastSyncKey) && prefs.containsKey(_qrLookupLastSyncKey);
  }

  // Sync both task schedules and QR lookup data
  static Future<void> syncTaskSchedules(String baseUrl) async {
    try {
      // Sync task schedules
      final scheduleResponse = await http.get(
        Uri.parse('$baseUrl/lichcnall'),
      );

      if (scheduleResponse.statusCode != 200) {
        throw Exception('Failed to sync task schedules: ${scheduleResponse.statusCode}');
      }

      // Sync QR lookup data
      final qrResponse = await http.get(
        Uri.parse('$baseUrl/lichcnallqr'),
      );

      if (qrResponse.statusCode != 200) {
        throw Exception('Failed to sync QR lookup data: ${qrResponse.statusCode}');
      }

      // Process task schedules
      final List<dynamic> scheduleData = json.decode(scheduleResponse.body);
      final taskSchedules = scheduleData.map((item) => TaskScheduleModel.fromMap(item)).toList();
      
      // Process QR lookup data
      final List<dynamic> qrData = json.decode(qrResponse.body);
      final qrLookups = qrData.map((item) => QRLookupModel.fromMap(item)).toList();
      
      await _saveTaskSchedules(taskSchedules);
      await _saveQRLookups(qrLookups);
      await _updateLastSyncTime();
    } catch (e) {
      throw Exception('Error syncing task schedules: $e');
    }
  }

  static Future<void> _saveTaskSchedules(List<TaskScheduleModel> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesJson = schedules.map((s) => s.toMap()).toList();
    await prefs.setString(_storageKey, json.encode(schedulesJson));
  }

  static Future<void> _saveQRLookups(List<QRLookupModel> lookups) async {
    final prefs = await SharedPreferences.getInstance();
    final lookupsJson = lookups.map((l) => l.toMap()).toList();
    await prefs.setString(_qrLookupStorageKey, json.encode(lookupsJson));
  }

  static Future<List<TaskScheduleModel>> getTaskSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesString = prefs.getString(_storageKey);
    
    if (schedulesString == null) return [];
    
    final List<dynamic> schedulesJson = json.decode(schedulesString);
    return schedulesJson.map((json) => TaskScheduleModel.fromMap(json)).toList();
  }

  static Future<List<QRLookupModel>> getQRLookups() async {
    final prefs = await SharedPreferences.getInstance();
    final lookupsString = prefs.getString(_qrLookupStorageKey);
    
    if (lookupsString == null) return [];
    
    final List<dynamic> lookupsJson = json.decode(lookupsString);
    return lookupsJson.map((json) => QRLookupModel.fromMap(json)).toList();
  }

  static Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastSyncKey, now);
    await prefs.setInt(_qrLookupLastSyncKey, now);
  }

  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  // Get project name and position name from username using QR lookup
  static Map<String, String> getUserProjectAndPosition(
    String username,
    List<QRLookupModel> qrLookups,
  ) {
    for (final lookup in qrLookups) {
      if (lookup.qrvalue == username) {
        return {
          'projectName': lookup.bpvalue,
          'positionName': lookup.vtvalue,
        };
      }
    }
    return {
      'projectName': '',
      'positionName': '',
    };
  }

  // Get tasks for a specific project and date using the lookup system
  static List<TaskScheduleModel> getTasksForProjectAndDate(
    List<TaskScheduleModel> allTasks,
    String projectName,
    DateTime date,
    List<QRLookupModel> qrLookups,
  ) {
    final weekday = date.weekday % 7; // Convert to 0=Sunday, 1=Monday, etc.
    
    return allTasks.where((task) {
      // Get the actual project name from the task's username
      final userMapping = getUserProjectAndPosition(task.username, qrLookups);
      final taskProjectName = userMapping['projectName'];
      
      if (taskProjectName != projectName) return false;
      
      // If weekday is empty, task applies to all days
      if (task.weekday.trim().isEmpty) return true;
      
      // Check if the current weekday is in the task's weekday list
      final taskWeekdays = task.weekday.split(',').map((w) => w.trim()).toList();
      return taskWeekdays.contains(weekday.toString());
    }).toList();
  }

  // Get tasks for a specific position using the lookup system
  static List<TaskScheduleModel> getTasksForPosition(
    List<TaskScheduleModel> projectTasks,
    String positionName,
    List<QRLookupModel> qrLookups,
  ) {
    return projectTasks.where((task) {
      final userMapping = getUserProjectAndPosition(task.username, qrLookups);
      return userMapping['positionName'] == positionName;
    }).toList();
  }

  static String formatScheduleTime(String timeString) {
    try {
      if (timeString.length >= 5) {
        return timeString.substring(0, 5); // Return HH:MM format
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  static int calculateTimeDifference(String reportTime, String scheduleTime) {
    try {
      final reportParts = reportTime.split(':');
      final scheduleParts = scheduleTime.split(':');
      
      if (reportParts.length >= 2 && scheduleParts.length >= 2) {
        final reportMinutes = int.parse(reportParts[0]) * 60 + int.parse(reportParts[1]);
        final scheduleMinutes = int.parse(scheduleParts[0]) * 60 + int.parse(scheduleParts[1]);
        
        return reportMinutes - scheduleMinutes;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Updated analysis method with QR lookup support
  static Map<String, dynamic> analyzeTaskCompletion(
    List<TaskScheduleModel> dayTasks,
    List<dynamic> workerReports, // TaskHistoryModel list
    String positionName,
    List<QRLookupModel> qrLookups,
  ) {
    final positionTasks = getTasksForPosition(dayTasks, positionName, qrLookups);
    final completedTasks = <String>[];
    final missedTasks = <String>[];
    
    for (final task in positionTasks) {
      bool isCompleted = false;
      
      for (final report in workerReports) {
        if (report.chiTiet2 != null && report.chiTiet2!.contains(task.task)) {
          isCompleted = true;
          completedTasks.add(task.taskId);
          break;
        }
      }
      
      if (!isCompleted) {
        missedTasks.add(task.taskId);
      }
    }
    
    final totalTasks = positionTasks.length;
    final completionRate = totalTasks > 0 ? (completedTasks.length.toDouble() / totalTasks.toDouble() * 100.0) : 0.0;
    
    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks.length,
      'missedTasks': missedTasks.length,
      'completionRate': completionRate,
      'positionTasks': positionTasks,
      'completedTaskIds': completedTasks,
      'missedTaskIds': missedTasks,
    };
  }

  // Get all unique project names from QR lookup data
  static List<String> getAllProjectNames(List<QRLookupModel> qrLookups) {
    final projectNames = qrLookups
        .map((lookup) => lookup.bpvalue)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
    projectNames.sort();
    return projectNames;
  }

  // Get all positions for a specific project
  static List<String> getPositionsForProject(
    String projectName,
    List<QRLookupModel> qrLookups,
  ) {
    final positions = qrLookups
        .where((lookup) => lookup.bpvalue == projectName)
        .map((lookup) => lookup.vtvalue)
        .where((position) => position.trim().isNotEmpty)
        .toSet()
        .toList();
    positions.sort();
    return positions;
  }
}
class QRLookupModel {
  final String id;
  final String qrvalue;
  final String bpvalue;
  final String vtvalue;

  QRLookupModel({
    required this.id,
    required this.qrvalue,
    required this.bpvalue,
    required this.vtvalue,
  });

  factory QRLookupModel.fromMap(Map<String, dynamic> map) {
    return QRLookupModel(
      id: map['id']?.toString() ?? '',
      qrvalue: map['qrvalue']?.toString() ?? '',
      bpvalue: map['bpvalue']?.toString() ?? '',
      vtvalue: map['vtvalue']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'qrvalue': qrvalue,
      'bpvalue': bpvalue,
      'vtvalue': vtvalue,
    };
  }
}
