// projectcongnhanllv2.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'projectcongnhanllv2choices.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';

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

class TaskScheduleManager {
  static const String _storageKey = 'task_schedules_v2';
  static const String _lastSyncKey = 'task_schedules_last_sync_v2';
  static const String _qrLookupStorageKey = 'qr_lookup_data_v2';
  static const String _qrLookupLastSyncKey = 'qr_lookup_last_sync_v2';

  static Future<bool> hasEverSynced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_lastSyncKey) && prefs.containsKey(_qrLookupLastSyncKey);
  }

  // Sync both task schedules and QR lookup data with username
  static Future<void> syncTaskSchedules(String baseUrl, String username) async {
    try {
      // Sync task schedules with username
      final scheduleResponse = await http.get(
        Uri.parse('$baseUrl/lichcnall/$username'),
      );

      if (scheduleResponse.statusCode != 200) {
        throw Exception('Failed to sync task schedules: ${scheduleResponse.statusCode}');
      }

      // Sync QR lookup data with username
      final qrResponse = await http.get(
        Uri.parse('$baseUrl/lichcnallqr/$username'),
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
      if (lookup.qrvalue.toLowerCase() == username.toLowerCase()) {
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

  // Format weekdays for display
  static String formatWeekdays(String weekdays) {
    if (weekdays.trim().isEmpty) return 'Tất cả các ngày';
    
    final days = weekdays.split(',').map((d) => d.trim()).toList();
    final dayNames = <String>[];
    
    for (final day in days) {
      switch (day) {
        case '0':
          dayNames.add('CN');
          break;
        case '1':
          dayNames.add('T2');
          break;
        case '2':
          dayNames.add('T3');
          break;
        case '3':
          dayNames.add('T4');
          break;
        case '4':
          dayNames.add('T5');
          break;
        case '5':
          dayNames.add('T6');
          break;
        case '6':
          dayNames.add('T7');
          break;
      }
    }
    return dayNames.join(', ');
  }
}

class PositionTaskListDialog extends StatelessWidget {
  final String projectName;
  final String positionName;
  final List<TaskScheduleModel> taskSchedules;
  final List<QRLookupModel> qrLookups;

  final String currentUser;                 
  final String baseUrl;                     
  final Map<String, VolumeEntryModel> volumeByTaskId; 

  const PositionTaskListDialog({
    Key? key,
    required this.projectName,
    required this.positionName,
    required this.taskSchedules,
    required this.qrLookups,
    required this.currentUser,
    required this.baseUrl,
    required this.volumeByTaskId,
  }) : super(key: key);

  Color _getPositionColor() {
    return Colors.indigo;
  }
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    
    // Get tasks for this position
    final positionTasks = taskSchedules.where((task) {
      final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, qrLookups);
      return userMapping['projectName'] == projectName && 
             userMapping['positionName'] == positionName;
    }).toList();

    // Sort tasks by start time
    positionTasks.sort((a, b) => a.start.compareTo(b.start));

    return Dialog(
      child: Container(
        width: isDesktop ? 700 : MediaQuery.of(context).size.width * 0.95,
        height: isDesktop ? 600 : MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getPositionColor(),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lịch làm việc',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$positionName - $projectName',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${positionTasks.length} nhiệm vụ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Task list
            Expanded(
              child: positionTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Không có nhiệm vụ nào cho vị trí này',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: positionTasks.length,
                      itemBuilder: (context, index) {
                        final task = positionTasks[index];
                        final positionColor = _getPositionColor();
                        final hasHistory = volumeByTaskId.containsKey(task.taskId);
                        final existingEntry = volumeByTaskId[task.taskId];
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Time and weekday header
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: positionColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: positionColor),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: positionColor,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            '${TaskScheduleManager.formatScheduleTime(task.start)} - ${TaskScheduleManager.formatScheduleTime(task.end)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: positionColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Spacer(),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        TaskScheduleManager.formatWeekdays(task.weekday),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                // Task description
                                Text(
                                  task.task,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                // Task details
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                   TextButton.icon(
                onPressed: () async {
                  final result = await showDialog<VolumeEntryModel>(
                    context: context,
                    builder: (ctx) => VolumeEntryDialog(
                      baseUrl: baseUrl,
                      taskId: task.taskId,
                      taskTitle: task.task,
                      currentUser: currentUser,
                      initialEntry: existingEntry,
                    ),
                  );

                  if (result != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(hasHistory ? 'Đã cập nhật khối lượng' : 'Đã ghi khối lượng')),
                    );
                    Navigator.of(context).pop();
                  }
                },
                icon: Icon(hasHistory ? Icons.edit : Icons.playlist_add),
                label: Text(hasHistory ? 'Sửa' : 'Điền khối lượng'),
              ),
              if (task.vitri.isNotEmpty)
                _buildDetailChip(
                  icon: Icons.location_on,
                  label: task.vitri,
                  color: Colors.green,
                ),
              if (existingEntry != null)
                _buildDetailChip(
                  icon: Icons.calculate,
                  label: 'KL: ${existingEntry.khoiLuong} ${existingEntry.donViTinh}',
                  color: Colors.deepPurple,
                ),
            ],
          ),
        ],
      ),
    ),
  );
},
                    ),
            ),
            // Footer with summary
            if (positionTasks.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tổng ${positionTasks.length} nhiệm vụ cho vị trí $positionName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
class VolumeEntryDialog extends StatefulWidget {
  final String baseUrl;
  final String taskId;
  final String taskTitle;
  final String currentUser;
  final VolumeEntryModel? initialEntry; 

  const VolumeEntryDialog({
    super.key,
    required this.baseUrl,
    required this.taskId,
    required this.taskTitle,
    required this.currentUser,
    this.initialEntry,
  });

  @override
  State<VolumeEntryDialog> createState() => _VolumeEntryDialogState();
}

class _VolumeEntryDialogState extends State<VolumeEntryDialog> {
  String? _selectedMainType;
  String? _selectedMaterial;
  String _selectedUnit = kUnits.first;
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool _mainTypeCollapsed = false; // collapse main type chips after picking

  List<String> get _orderedMainTypes => buildOrderedMainTypes();

  List<String> get _materialOptions {
    if (_selectedMainType == null) return const [];
    return kMaterialOptionsByMainType[_selectedMainType!] ?? const [];
  }

  bool get _requireMaterial => _materialOptions.isNotEmpty;

  bool get _unitStepEnabled {
    if (_selectedMainType == null) return false;
    if (_requireMaterial && _selectedMaterial == null) return false;
    return true;
  }

  bool get _quantityStepEnabled => _unitStepEnabled && _selectedUnit.isNotEmpty;

  bool get _canSubmit {
    if (_selectedMainType == null) return false;
    if (_requireMaterial && _selectedMaterial == null) return false;
    if (_selectedUnit.isEmpty) return false;
    final val = double.tryParse(_qtyCtrl.text.trim());
    if (val == null || val <= 0) return false;
    return true;
  }
@override
void initState() {
  super.initState();
  if (widget.initialEntry != null) {
    final e = widget.initialEntry!;
    _selectedMainType = e.loaiLamSachChinh.isEmpty ? null : e.loaiLamSachChinh;
    _selectedMaterial  = e.chatLieu.isEmpty ? null : e.chatLieu;
    _selectedUnit      = e.donViTinh.isEmpty ? kUnits.first : e.donViTinh;
    _qtyCtrl.text      = e.khoiLuong == 0 ? '' : e.khoiLuong.toString();
    _noteCtrl.text     = e.ghiChu;
    _mainTypeCollapsed = _selectedMainType != null; 
  }
}

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

 Future<void> _submit() async {
  final now = DateTime.now();
  final autoId = widget.initialEntry?.autoId ?? now.millisecondsSinceEpoch.toString();

  final body = {
    'autoId': autoId,
    'taskId': widget.taskId,
    'taskTitle': widget.taskTitle,
    'date': '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
    'user': widget.currentUser,
    'loaiLamSachChinh': _selectedMainType ?? '',
    'chatLieu': _materialOptions.isNotEmpty ? (_selectedMaterial ?? '') : '',
    'donViTinh': _selectedUnit,
    'khoiLuong': double.tryParse(_qtyCtrl.text.trim()) ?? 0.0,
    'ghiChu': _noteCtrl.text.trim(),
  };

  final uri = Uri.parse('${widget.baseUrl}/lichcnkhoiluong');

  try {
    if (kDebugMode) {
      debugPrint('[KL] POST $uri');
      debugPrint('[KL] request: ${json.encode(body)}');
    }

    final resp = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: json.encode(body))
        .timeout(const Duration(seconds: 15));

    if (kDebugMode) {
      debugPrint('[KL] status: ${resp.statusCode}');
      debugPrint('[KL] response: ${resp.body}');
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      VolumeEntryModel model;
      try {
        final m = json.decode(resp.body);
        Map<String, dynamic> saved;
        if (m is Map && m['saved'] is Map) {
          saved = Map<String, dynamic>.from(m['saved'] as Map);
        } else if (m is Map && m['insertedData'] is Map) {
          saved = Map<String, dynamic>.from(m['insertedData'] as Map);
        } else if (m is Map) {
          saved = Map<String, dynamic>.from(m);
        } else {
          saved = body;
        }
        model = VolumeEntryModel.fromMap(saved);
      } catch (_) {
        model = VolumeEntryModel.fromMap(body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(model);
      return;
    }

    // Non-2xx
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gửi thất bại (${resp.statusCode})'), backgroundColor: Colors.red),
    );
    if (kDebugMode) {
      debugPrint('[KL] error body: ${resp.body}');
    }
  } on TimeoutException catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hết thời gian chờ máy chủ (timeout)'), backgroundColor: Colors.red),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi kết nối: $e'), backgroundColor: Colors.red),
    );
    if (kDebugMode) {
      debugPrint('[KL] exception: $e');
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width > 560 ? 560.0 : MediaQuery.of(context).size.width * 0.95;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom, // respect keyboard
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.playlist_add_check),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Điền khối lượng',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.taskTitle, style: TextStyle(color: Colors.grey[700])),
              ),
              const SizedBox(height: 12),

              // SCROLLABLE CONTENT
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1) Loại làm sạch chính
                      Text('Loại làm sạch chính',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                      const SizedBox(height: 8),

                      if (_selectedMainType == null || !_mainTypeCollapsed) ...[
                        Wrap(
                          children: _orderedMainTypes.map((label) {
                            final selected = _selectedMainType == label;
                            return SingleChoiceChip(
                              label: label,
                              selected: selected,
                              onTap: () {
                                setState(() {
                                  _selectedMainType = label;
                                  _selectedMaterial = null;
                                  _mainTypeCollapsed = true; // collapse after choosing
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ] else ...[
                        // Collapsed view: show selection + "Thay đổi"
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedMainType!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _mainTypeCollapsed = false),
                                child: const Text('Thay đổi'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 2) Chất liệu (only if main type picked AND requires material)
                      if (_selectedMainType != null && _requireMaterial) ...[
                        Text('Chất liệu',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedMaterial,
                          hint: const Text('Chọn chất liệu'),
                          items: _materialOptions
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedMaterial = val),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3) Đơn vị tính (only after the above is satisfied)
                      if (_unitStepEnabled) ...[
                        Text('Đơn vị tính',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedUnit,
                          items: kUnits
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedUnit = val ?? kUnits.first),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 4) Khối lượng (only after unit chosen)
                      if (_quantityStepEnabled) ...[
                        Text('Khối lượng',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: 'Ví dụ: 12.5',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 5) Ghi chú (optional — shows when quantity step is enabled)
                      if (_quantityStepEnabled) ...[
                        Text('Ghi chú',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Ghi chú thêm (tuỳ chọn)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer submit
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Gửi'),
                      onPressed: _canSubmit ? _submit : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class VolumeEntryModel {
  final String autoId;
  final String taskId;
  final String date;
  final String time;
  final String user;
  final String loaiLamSachChinh;
  final String chatLieu;
  final String donViTinh;
  final double khoiLuong;
  final String ghiChu;

  VolumeEntryModel({
    required this.autoId,
    required this.taskId,
    required this.date,
    required this.time,
    required this.user,
    required this.loaiLamSachChinh,
    required this.chatLieu,
    required this.donViTinh,
    required this.khoiLuong,
    required this.ghiChu,
  });

  factory VolumeEntryModel.fromMap(Map<String, dynamic> map) {
    return VolumeEntryModel(
      autoId: (map['autoId'] ?? map['AutoId'] ?? map['UID'] ?? '').toString(),
      taskId: (map['taskId'] ?? map['TaskId'] ?? '').toString(),
      date: (map['date'] ?? map['Date'] ?? '').toString(),
      time: (map['time'] ?? map['Time'] ?? '').toString(),
      user: (map['user'] ?? map['User'] ?? map['Username'] ?? '').toString(),
      loaiLamSachChinh: (map['loaiLamSachChinh'] ?? map['Loai'] ?? '').toString(),
      chatLieu: (map['chatLieu'] ?? map['ChatLieu'] ?? '').toString(),
      donViTinh: (map['donViTinh'] ?? map['DVT'] ?? '').toString(),
      khoiLuong: double.tryParse((map['khoiLuong'] ?? map['KhoiLuong'] ?? '0').toString()) ?? 0,
      ghiChu: (map['ghiChu'] ?? map['GhiChu'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'autoId': autoId,
    'taskId': taskId,
    'date': date,
    'time': time,
    'user': user,
    'loaiLamSachChinh': loaiLamSachChinh,
    'chatLieu': chatLieu,
    'donViTinh': donViTinh,
    'khoiLuong': khoiLuong,
    'ghiChu': ghiChu,
  };
}
