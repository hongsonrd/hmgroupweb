import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'projectworkerall.dart';
import 'projectworkerauto.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'http_client.dart';

import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' ;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectWorker extends StatefulWidget {
 final String selectedBoPhan;
 const ProjectWorker({Key? key, required this.selectedBoPhan}) : super(key: key);
 @override
 _ProjectWorkerState createState() => _ProjectWorkerState();
}

class _ProjectWorkerState extends State<ProjectWorker> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _attendanceData = [];
  List<String> _departments = [];
  List<String> _availableMonths = [];
  String? _selectedDepartment;
  String? _selectedMonth;
  Map<String, Map<String, dynamic>> _modifiedRecords = {};
  Map<String, Map<String, dynamic>> _newRecords = {};
  final List<String> _congThuongChoices = ['X', 'P', 'XĐ', 'X/2', 'Ro', 'HT', 'NT', 'CĐ', 'NL', 'Ô', 'TS', '2X', '3X', 'HV', '2HV', '3HV', '2XĐ', '3X/4', 'P/2', 'QLDV'];
  late String _username;
  Map<String, String> _staffNames = {};
  List<String> _debugLogs = [];
bool _showDebugOverlay = false;
Map<String, Color> _staffColors = {};
List<Color> _availableColors = [
  Colors.yellow.shade100,
  Colors.blue.shade100,
  Colors.green.shade100,
  Colors.red.shade100,
];
bool _showColorDialog = false;
String? _staffToColor;
DateTime? _lastSyncTime;
final Duration _syncThreshold = Duration(hours: 6);
bool _isSyncNeeded() {
  if (_lastSyncTime == null) return true;
  final now = DateTime.now();
  final difference = now.difference(_lastSyncTime!);
  if (difference > _syncThreshold) return true;
  final lastSyncHour = _lastSyncTime!.hour;
  final currentHour = now.hour;
  if (_lastSyncTime!.day != now.day) return true;
  if (lastSyncHour < 12 && currentHour >= 12 && currentHour < 17) return true;
  if (lastSyncHour < 17 && currentHour >= 17) return true;
  return false;
}
Future<void> _syncDataFromServer() async {
  try {
    setState(() => _isLoading = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Đang đồng bộ dữ liệu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Vui lòng đợi trong giây lát...'),
          ],
        ),
      ),
    );
    
    debugLog('Starting data synchronization from server...');
    final dbHelper = DBHelper();
    
    // Fetch all attendance data from server
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcn/$_username'),
    );
    
    if (response.statusCode == 200) {
      debugLog('Received data from server. Processing...');
      
      final List<dynamic> chamCongCNData = json.decode(response.body);
      for (var data in chamCongCNData) {
  if (data is Map<String, dynamic> && data.containsKey('HoTro')) {
    debugLog('Server data HoTro value: ${data['HoTro']} for MaNV: ${data['MaNV']}');
  }
}

      // Clear existing table and insert new data
      await dbHelper.clearTable('chamcongcn');
      
      final chamCongCNModels = chamCongCNData.map((data) {
        try {
          return ChamCongCNModel.fromMap(data as Map<String, dynamic>);
        } catch (e) {
          debugLog('Error converting record: $e');
          throw e;
        }
      }).toList();
      
      await dbHelper.batchInsertChamCongCN(chamCongCNModels);
      
      // Update last sync time
      _lastSyncTime = DateTime.now();
      
      // Save last sync time to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());
      
      debugLog('Synchronization completed successfully');
      
      // Reload attendance data
      await _loadAttendanceData();
      
      // Remove loading dialog
      if (mounted) Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã đồng bộ dữ liệu từ máy chủ thành công'))
      );
    } else {
      throw Exception('Failed to load data from server');
    }
  } catch (e) {
    debugLog('Sync error: $e');
    if (mounted) Navigator.of(context).pop();
    _showError('Không thể đồng bộ dữ liệu: ${e.toString()}');
  } finally {
    setState(() => _isLoading = false);
  }
}
  @override
  void initState() {
    super.initState();
    _selectedDepartment = widget.selectedBoPhan;
    _username = Provider.of<UserCredentials>(context, listen: false).username;
      _loadLastSyncTime();
    _initializeData();
      _loadStaffColors();
  }
  Future<void> _loadLastSyncTime() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('last_sync_time');
    
    if (lastSyncStr != null) {
      _lastSyncTime = DateTime.parse(lastSyncStr);
      debugLog('Last sync time loaded: $_lastSyncTime');
    }
    
    // Check if sync is needed and perform it
    if (_isSyncNeeded()) {
      debugLog('Sync needed based on time threshold');
      // Slight delay to ensure UI is built
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) _syncDataFromServer();
      });
    }
  } catch (e) {
    debugLog('Error loading last sync time: $e');
  }
}
  Future<void> _loadStaffColors() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final colorKey = 'staff_colors_${_selectedDepartment}';
    final colorData = prefs.getString(colorKey);
    
    if (colorData != null) {
      final Map<String, dynamic> jsonData = json.decode(colorData);
      
      setState(() {
        _staffColors = jsonData.map((key, value) => 
          MapEntry(key, Color(int.parse(value.toString()))));
      });
      
      debugLog('Loaded staff colors for $_selectedDepartment: ${_staffColors.length}');
    } else {
      setState(() {
        _staffColors = {}; // Reset colors when changing departments
      });
    }
  } catch (e) {
    debugLog('Error loading staff colors: $e');
  }
}

Future<void> _saveStaffColors() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    final Map<String, int> colorData = 
      _staffColors.map((key, value) => MapEntry(key, value.value));
    
    final colorKey = 'staff_colors_${_selectedDepartment}';
    await prefs.setString(colorKey, json.encode(colorData));
    
    debugLog('Saved staff colors for $_selectedDepartment: ${_staffColors.length}');
  } catch (e) {
    debugLog('Error saving staff colors: $e');
  }
}
Widget _buildColorPickerDialog() {
  return AlertDialog(
    title: Text('Chọn màu cho ${_staffToColor ?? ''}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(_availableColors.length, (index) {
          return InkWell(
            onTap: () {
              if (_staffToColor != null) {
                setState(() {
                  _staffColors[_staffToColor!] = _availableColors[index];
                  _showColorDialog = false;
                });
                _saveStaffColors();
              }
            },
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              height: 40,
              decoration: BoxDecoration(
                color: _availableColors[index],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: Text('Màu ${index + 1}')),
            ),
          );
        }),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            if (_staffToColor != null && _staffColors.containsKey(_staffToColor)) {
              setState(() {
                _staffColors.remove(_staffToColor);
                _showColorDialog = false;
              });
              _saveStaffColors();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: Text('Xóa màu', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () {
          setState(() {
            _showColorDialog = false;
          });
        },
        child: Text('Đóng'),
      ),
    ],
  );
}

  Future<void> _loadStaffNames(List<String> employeeIds) async {
  final dbHelper = DBHelper();
  final placeholders = List.filled(employeeIds.length, '?').join(',');
  final result = await dbHelper.rawQuery(
    'SELECT MaNV, Ho_ten FROM staffbio WHERE MaNV IN ($placeholders)',
    employeeIds,
  );

  // Convert database results to a Map
  final Map<String, String> fetchedNames = {
    for (var row in result) row['MaNV'] as String: row['Ho_ten'] as String
  };

  // Assign "???" to unmatched IDs
  final Map<String, String> staffNames = {
    for (var id in employeeIds) id: fetchedNames[id] ?? "???"
  };

  setState(() {
    _staffNames = staffNames;
  });

  debugLog('Loaded staff names: $_staffNames');
}

// Add this method to your _ProjectWorkerState class
Future<void> _addPreviousEmployees() async {
  try {
    debugLog('Starting to add previous employees...');
    
    // Get current employee IDs to avoid duplicates
    final currentEmployeeIds = _getUniqueEmployees();
    debugLog('Current employees: $currentEmployeeIds');
    
    // Query database for all employees from previous records
    final dbHelper = DBHelper();
    final previousEmployees = await dbHelper.rawQuery('''
      SELECT DISTINCT MaNV FROM chamcongcn 
      WHERE BoPhan = ? 
      ORDER BY MaNV
    ''', [_selectedDepartment]);
    
    final List<String> previousEmployeeIds = previousEmployees
        .map((record) => record['MaNV'] as String)
        .where((id) => !currentEmployeeIds.contains(id)) // Filter out existing employees
        .toList();
    
    debugLog('Found ${previousEmployeeIds.length} employees to add');
    
    if (previousEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nhân viên mới để thêm'))
      );
      return;
    }
    
    // Create new records for each employee
    final now = DateTime.now();
    final currentDate = now.toIso8601String().split('T')[0];
    final currentTime = DateFormat('HH:mm:ss').format(now);
    
    int addedCount = 0;
    for (final empId in previousEmployeeIds) {
      final uid = Uuid().v4();
      final newRecord = {
        'UID': uid,
        'Ngay': currentDate,
        'Gio': currentTime,
        'NguoiDung': _username,
        'BoPhan': _selectedDepartment,
        'MaBP': _selectedDepartment,
        'PhanLoai': '',
        'MaNV': empId,
        'CongThuongChu': 'Ro', // Default value
        'NgoaiGioThuong': '0',
        'NgoaiGioKhac': '0',
        'NgoaiGiox15': '0',
        'NgoaiGiox2': '0',
        'HoTro': '0',
        'PartTime': '0',
        'PartTimeSang': '0',
        'PartTimeChieu': '0',
        'CongLe': '0',
      };

      try {
        // Send to server
        debugLog('Sending new employee record: $empId');
        final response = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newRecord)
        ).timeout(const Duration(seconds: 300));

        if (response.statusCode == 200) {
          // Add to local database
          final chamCongModel = ChamCongCNModel(
            uid: uid,
            maNV: empId,
            ngay: DateTime.parse(currentDate),
            boPhan: _selectedDepartment!,
            nguoiDung: _username,
            congThuongChu: 'Ro',
            ngoaiGioThuong: 0,
            ngoaiGioKhac: 0,
            ngoaiGiox15: 0,
            ngoaiGiox2: 0,
            hoTro: 0,
            partTime: 0,
            partTimeSang: 0,
            partTimeChieu: 0,
            congLe: 0,
          );
          await dbHelper.insertChamCongCN(chamCongModel);
          addedCount++;
          debugLog('Successfully added employee: $empId');
        } else {
          debugLog('Failed to add employee: $empId - Status: ${response.statusCode}');
        }
      } catch (e) {
        debugLog('Error adding employee $empId: $e');
      }
    }
    
    if (addedCount > 0) {
      // Reload data
      await _loadAttendanceData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm $addedCount nhân viên từ dữ liệu trước'))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể thêm nhân viên'))
      );
    }
  } catch (e) {
    debugLog('Error in _addPreviousEmployees: $e');
    _showError('Không thể thêm nhân viên: ${e.toString()}');
  }
}
void debugLog(String message) {
  // Use raw print instead of calling debugLog again
  print(message);
  
  if (_showDebugOverlay) {
    setState(() {
      _debugLogs.add("${DateTime.now().toString().substring(11, 19)}: $message");
      if (_debugLogs.length > 20) {
        _debugLogs.removeAt(0);
      }
    });
  }
}
  Future<void> _loadProjects() async {
    try {
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$_username'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _departments = data.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      debugLog('Error loading projects: $e');
    }
  }

Future<void> _initializeData() async {
 setState(() => _isLoading = true);
 try {
   try {
     final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$_username'),
        headers: {'Content-Type': 'application/json'},
      );
     debugLog('Project API Response: ${response.statusCode} - ${response.body}');
     if (response.statusCode == 200) {
       final List<dynamic> apiDepts = json.decode(response.body);
       setState(() {
         _departments = apiDepts.map((e) => e.toString()).toList();
       });
     }
   } catch (e) {
     debugLog('Project API error: $e');
   }

   final dbHelper = DBHelper();
   final existingDepts = await dbHelper.rawQuery(
     'SELECT DISTINCT BoPhan FROM chamcongcn ORDER BY BoPhan'
   );
   _departments.addAll(existingDepts.map((e) => e['BoPhan'] as String));
   _departments = _departments.toSet().toList()..sort();
   debugLog('Final departments: $_departments');

final months = await dbHelper.rawQuery(
  r"SELECT DISTINCT strftime('%Y-%m', Ngay) as month FROM chamcongcn ORDER BY month DESC"
);
   _availableMonths = months.map((e) => e['month'] as String).toList();
   
   String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
   if (!_availableMonths.contains(currentMonth)) {
     _availableMonths.insert(0, currentMonth);
   }
   _selectedMonth = _availableMonths.first;
   debugLog('Months: $_availableMonths, Selected: $_selectedMonth');
   
   await _loadAttendanceData();
 } catch (e) {
   debugLog('Init error: $e');
   _showError('Không thể tải dữ liệu');
 }
 setState(() => _isLoading = false);
}
Future<void> _saveChanges() async {
  FocusScope.of(context).unfocus();
  
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        child: Container(
          padding: EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Đang lưu...', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final dbHelper = DBHelper();
    
    // Prepare data for batch request
    final modifiedList = _modifiedRecords.values.toList();
    final newList = _newRecords.values.toList();
    
    debugLog('Sending batch request with ${modifiedList.length} updates and ${newList.length} additions');
    
    // Use the new batch endpoint
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongbatch'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'updates': modifiedList,
        'additions': newList,
      }),
    ).timeout(const Duration(seconds: 300));
    
    if (response.statusCode == 200 || response.statusCode == 400) {
      final result = json.decode(response.body);
debugLog('Batch response: ${result.toString().substring(0, result.toString().length > 100 ? 100 : result.toString().length)}...');
      
      // Process successful updates in local database
      if (result['updated'] > 0 || result['added'] > 0) {
        // Start a batch update for the local database
        await Future.wait([
          // Process updates
          Future(() async {
            for (var record in modifiedList) {
              final uid = record['UID'] as String;
              final updates = Map<String, dynamic>.from(record);
              updates.remove('UID');
              await dbHelper.updateChamCongCN(uid, updates);
              debugLog('Updated local record with UID: $uid');
            }
          }),
          
          // Process additions
          Future(() async {
            for (var record in newList) {
              final chamCongModel = ChamCongCNModel(
                uid: record['UID'] as String,
                maNV: record['MaNV'] as String,
                ngay: DateTime.parse(record['Ngay'] as String),
                boPhan: record['BoPhan'] as String,
                nguoiDung: record['NguoiDung'] as String,
                congThuongChu: record['CongThuongChu'] as String,
                ngoaiGioThuong: double.tryParse(record['NgoaiGioThuong'].toString()) ?? 0,
                ngoaiGioKhac: double.tryParse(record['NgoaiGioKhac'].toString()) ?? 0,
                ngoaiGiox15: double.tryParse(record['NgoaiGiox15'].toString()) ?? 0,
                ngoaiGiox2: double.tryParse(record['NgoaiGiox2'].toString()) ?? 0,
                hoTro: int.tryParse(record['HoTro'].toString()) ?? 0,
                partTime: int.tryParse(record['PartTime'].toString()) ?? 0,
                partTimeSang: int.tryParse(record['PartTimeSang'].toString()) ?? 0,
                partTimeChieu: int.tryParse(record['PartTimeChieu'].toString()) ?? 0,
                congLe: double.tryParse(record['CongLe'].toString()) ?? 0,
              );
              await dbHelper.insertChamCongCN(chamCongModel);
              debugLog('Inserted local record with UID: ${record['UID']}');
            }
          }),
        ]);
      }
      
      // Check for any errors
      if (result['errors'] != null && (result['errors'] as List).isNotEmpty) {
        debugLog('Batch had ${(result['errors'] as List).length} errors: ${result['errors']}');
      }
      
      // Clear tracking collections
      setState(() {
        _modifiedRecords.clear();
        _newRecords.clear();
      });
      
      // Refresh the UI to reflect changes
      await _loadAttendanceData();
      
      // Close loading dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show success message
      if (mounted) {
        final updatedCount = result['updated'] ?? 0;
        final addedCount = result['added'] ?? 0;
        final errorCount = result['errors'] != null ? (result['errors'] as List).length : 0;
        
        String message = 'Đã lưu ${updatedCount + addedCount} thay đổi thành công';
        if (errorCount > 0) {
          message += ' (${errorCount} lỗi)';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: errorCount > 0 ? Colors.orange : null,
          )
        );
      }
    } else {
      throw Exception('Failed to save changes: ${response.body}');
    }
  } catch (e) {
    // Close loading dialog on error
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
    debugLog('Error in batch save: $e');
    _showError('Lỗi khi lưu: ${e.toString()}');
    
    // If the batch save failed completely, fall back to individual saves
    if (_modifiedRecords.isNotEmpty || _newRecords.isNotEmpty) {
      final shouldFallback = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Lưu không thành công'),
          content: Text('Bạn có muốn thử lưu từng bản ghi riêng biệt không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Không'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Có'),
            ),
          ],
        ),
      ) ?? false;
      
      if (shouldFallback) {
        debugLog('Falling back to individual saves');
        // Call the original save method (which you would need to rename)
        await _saveChangesIndividually();
      }
    }
  }
}

Future<void> _saveChangesIndividually() async {
  FocusScope.of(context).unfocus();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        child: Container(
          padding: EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24, 
                width: 24, 
                child: CircularProgressIndicator(strokeWidth: 2)
              ),
              SizedBox(width: 12),
              Text('Đang lưu...', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final dbHelper = DBHelper();
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugLog('Running on desktop platform');
      debugLog('Modified: ${_modifiedRecords.length}, New: ${_newRecords.length}');
    }
    
    for (var entry in _modifiedRecords.entries) {
      final record = entry.value;
      final uid = record['UID'] as String;
      final updates = Map<String, dynamic>.from(record);
      updates.remove('UID');
      debugLog('Sending modified record: $uid');
      final response = await http.put(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongsua/$uid'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates)
      ).timeout(const Duration(seconds: 300));
      if (response.statusCode != 200) {
        throw Exception('Failed to update: ${response.body}');
      }
      await dbHelper.updateChamCongCN(uid, updates);
      final hotroValue = entry.value['HoTro'];
  debugLog('After saving to DB - UID: ${entry.key}, HoTro value: $hotroValue');
    }
    
    for (var entry in _newRecords.entries) {
      final uid = entry.key;
      final record = entry.value;
      debugLog('Sending new record: $uid');
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(record)
      ).timeout(const Duration(seconds: 300));
      if (response.statusCode != 200) {
        throw Exception('Failed to add: ${response.body}');
      }
      final chamCongModel = ChamCongCNModel(
        uid: record['UID'] as String,
        maNV: record['MaNV'] as String,
        ngay: DateTime.parse(record['Ngay'] as String),
        boPhan: record['BoPhan'] as String,
        nguoiDung: record['NguoiDung'] as String,
        congThuongChu: record['CongThuongChu'] as String,
        ngoaiGioThuong: double.tryParse(record['NgoaiGioThuong'].toString()) ?? 0,
        ngoaiGioKhac: double.tryParse(record['NgoaiGioKhac'].toString()) ?? 0,
        ngoaiGiox15: double.tryParse(record['NgoaiGiox15'].toString()) ?? 0,
        ngoaiGiox2: double.tryParse(record['NgoaiGiox2'].toString()) ?? 0,
        hoTro: int.tryParse(record['HoTro'].toString()) ?? 0,
        partTime: int.tryParse(record['PartTime'].toString()) ?? 0,
        partTimeSang: int.tryParse(record['PartTimeSang'].toString()) ?? 0,
        partTimeChieu: int.tryParse(record['PartTimeChieu'].toString()) ?? 0,
        congLe: double.tryParse(record['CongLe'].toString()) ?? 0,
      );
      await dbHelper.insertChamCongCN(chamCongModel);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _modifiedRecords.clear();
      _newRecords.clear();
    });
    await _loadAttendanceData();
    
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thay đổi thành công'))
      );
    }
  } catch (e) {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    debugLog('Error: $e');
    _showError('Lỗi khi lưu: ${e.toString()}');
  }
}
Future<void> _addNewEmployee() async {
  try {
    String? maNV;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thêm nhân viên mới'),
        content: TextField(
          decoration: InputDecoration(labelText: 'Mã nhân viên'),
          textCapitalization: TextCapitalization.characters,
          onChanged: (value) => maNV = value.toUpperCase(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              if (maNV?.isNotEmpty == true) {
                Navigator.of(context).pop({'MaNV': maNV!});
              }
            },
            child: Text('Thêm'),
          ),
        ],
      ),
    );

    if (result != null) {
      final now = DateTime.now();
      final uid = Uuid().v4();
      final newRecord = {
        'UID': uid,
        'Ngay': now.toIso8601String().split('T')[0],
        'Gio': DateFormat('HH:mm:ss').format(now),
        'NguoiDung': _username,
        'BoPhan': _selectedDepartment,
        'MaBP': _selectedDepartment,
        'PhanLoai': '',
        'MaNV': result['MaNV'],
        'CongThuongChu': '',
        'NgoaiGioThuong': '0',
        'NgoaiGioKhac': '0',
        'NgoaiGiox15': '0',
        'NgoaiGiox2': '0',
        'HoTro': '0',
        'PartTime': '0',
        'PartTimeSang': '0',
        'PartTimeChieu': '0',
        'CongLe': '0',
      };

      // Immediately sync new record
      try {
        final response = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newRecord)
        );

        if (response.statusCode == 200) {
          // Add to local database
          final chamCongModel = ChamCongCNModel(
            uid: newRecord['UID'] as String,
            maNV: newRecord['MaNV'] as String,
            ngay: DateTime.parse(newRecord['Ngay'] as String),
            boPhan: newRecord['BoPhan'] as String,
            nguoiDung: newRecord['NguoiDung'] as String,
            congThuongChu: newRecord['CongThuongChu'] as String,
            ngoaiGioThuong: double.tryParse(newRecord['NgoaiGioThuong'].toString()) ?? 0,
            ngoaiGioKhac: double.tryParse(newRecord['NgoaiGioKhac'].toString()) ?? 0,
            ngoaiGiox15: double.tryParse(newRecord['NgoaiGiox15'].toString()) ?? 0,
            ngoaiGiox2: double.tryParse(newRecord['NgoaiGiox2'].toString()) ?? 0,
            hoTro: int.tryParse(newRecord['HoTro'].toString()) ?? 0,
            partTime: int.tryParse(newRecord['PartTime'].toString()) ?? 0,
            partTimeSang: int.tryParse(newRecord['PartTimeSang'].toString()) ?? 0,
            partTimeChieu: int.tryParse(newRecord['PartTimeChieu'].toString()) ?? 0,
            congLe: double.tryParse(newRecord['CongLe'].toString()) ?? 0,
          );
          final dbHelper = DBHelper();
          await dbHelper.insertChamCongCN(chamCongModel);
          
          // Reload data
          await _loadAttendanceData();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm nhân viên mới thành công'))
          );
        } else {
          throw Exception('Failed to add new employee');
        }
      } catch (e) {
        debugLog('Error adding new employee: $e');
        _showError('Không thể thêm nhân viên mới: ${e.toString()}');
      }
    }
  } catch (e) {
    _showError('Không thể thêm nhân viên mới');
  }
}
 void _showError(String message) {
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
   }
 }

 List<int> _getDaysInMonth() {
   if (_selectedMonth == null) return [];
   final parts = _selectedMonth!.split('-');
   final year = int.parse(parts[0]);
   final month = int.parse(parts[1]);
   if (_selectedMonth == DateFormat('yyyy-MM').format(DateTime.now())) {
     final today = DateTime.now().day;
     return List.generate(today, (i) => today - i);
   } else {
     final daysInMonth = DateTime(year, month + 1, 0).day;
     return List.generate(daysInMonth, (i) => i + 1);
   }
 }
Future<void> _deleteEmployee() async {
  try {
    // Show dialog to select employee to delete
    final employees = _getUniqueEmployees();
    
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nhân viên nào để xoá'))
      );
      return;
    }
    
    String? selectedEmployee;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn nhân viên để xoá'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final empId = employees[index];
              return ListTile(
                title: Text(empId),
                subtitle: Text(_staffNames[empId] ?? ''),
                onTap: () {
                  Navigator.of(context).pop(empId);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Huỷ'),
          ),
        ],
      ),
    );
    
    if (result == null) return;
    
    selectedEmployee = result;
    
    // Check if employee's total PhanLoai is 0
    double totalPhanLoai = 0;
    
    // Calculate total PhanLoai for this employee in this project and month
    final employeeRecords = _attendanceData.where((record) => 
      record['MaNV'] == selectedEmployee
    ).toList();
    
    for (var record in employeeRecords) {
      double phanLoai = double.tryParse(record['PhanLoai']?.toString() ?? '0') ?? 0;
      totalPhanLoai += phanLoai;
    }
    
    // Round to handle floating point precision issues
    totalPhanLoai = double.parse(totalPhanLoai.toStringAsFixed(2));
    
    debugLog('Total PhanLoai for $selectedEmployee: $totalPhanLoai');
    
    if (totalPhanLoai > 0) {
      // Cannot delete - show warning
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xoá nhân viên $selectedEmployee vì có PhanLoai > 0 (${totalPhanLoai.toStringAsFixed(1)}). Vui lòng liên hệ Admin.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        )
      );
      return;
    }
    
    // Confirm deletion
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xoá'),
        content: Text('Bạn có chắc muốn xoá nhân viên $selectedEmployee (${_staffNames[selectedEmployee] ?? ''}) khỏi dự án này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xoá', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmDelete != true) return;
    
    setState(() => _isLoading = true);
    
    // Delete all records for this employee
    final dbHelper = DBHelper();
    
    // Get all UIDs for this employee's records
    final records = _attendanceData.where((record) => 
      record['MaNV'] == selectedEmployee
    ).toList();
    
    final uids = records.map((r) => r['UID'] as String).toList();
    
    debugLog('Deleting ${uids.length} records for employee $selectedEmployee');
    
    // Delete from server
    for (var uid in uids) {
      try {
        final response = await http.delete(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongxoa/$uid'),
        ).timeout(const Duration(seconds: 300));
        
        if (response.statusCode == 200) {
          debugLog('Successfully deleted record with UID: $uid from server');
        } else {
          debugLog('Failed to delete record with UID: $uid from server. Status: ${response.statusCode}');
          throw Exception('Failed to delete record from server');
        }
      } catch (e) {
        debugLog('Error deleting record from server: $e');
        throw e;
      }
    }
    
    // Delete from local database
    for (var uid in uids) {
      // Use executeDelete or another appropriate method based on DBHelper implementation
      await dbHelper.rawQuery(
        'DELETE FROM chamcongcn WHERE UID = ?',
        [uid]
      );
      debugLog('Deleted record with UID: $uid from local database');
      
      // Remove from tracking collections if present
      _modifiedRecords.remove(uid);
      _newRecords.remove(uid);
    }
    
    // Remove from attendance data in memory
    setState(() {
      _attendanceData.removeWhere((record) => record['MaNV'] == selectedEmployee);
    });
    
    // Reload data
    await _loadAttendanceData();
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xoá nhân viên $selectedEmployee khỏi dự án này'))
    );
    
  } catch (e) {
    setState(() => _isLoading = false);
    debugLog('Error in _deleteEmployee: $e');
    _showError('Không thể xoá nhân viên: ${e.toString()}');
  }
}
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.purple,
      title: Row(
        children: [
          Expanded(
  flex: 3, // Give more space to the project dropdown
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: DropdownButtonHideUnderline(
      child: DropdownSearch<String>(
        items: _departments,
        selectedItem: _selectedDepartment,
        onChanged: (value) {
          setState(() {
            _selectedDepartment = value;
            _loadAttendanceData();
            _loadStaffColors();
          });
        },
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            hintText: "Chọn dự án",
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        popupProps: PopupProps.dialog(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: "Tìm kiếm dự án...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          title: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Text(
                'Chọn dự án',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
),
          SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedMonth,
              items: _availableMonths.map((month) => DropdownMenuItem(
                value: month,
                child: Text(DateFormat('MM/yyyy').format(DateTime.parse('$month-01')))
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMonth = value;
                  _loadAttendanceData();
                });
              },
              style: TextStyle(color: Colors.white),
              dropdownColor: Theme.of(context).primaryColor,
              isExpanded: true,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.sync, color: Colors.white),
          onPressed: _syncDataFromServer,
          tooltip: 'Đồng bộ dữ liệu',
        ),
      ],
    ),
    body: Stack(
      children: [
        _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
            children: [
              Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ElevatedButton(
          onPressed: _addNewEmployee, 
          child: Text('➕ NV mới')
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: (_modifiedRecords.isNotEmpty || _newRecords.isNotEmpty) 
            ? _saveChanges 
            : null,
          child: Text('❤️Lưu thay đổi'),
        ),
        ElevatedButton(
          onPressed: _copyFromYesterday,
          child: Text('💚Như hôm qua'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AllProjectsView(),
              ),
            );
          },
          child: Text('💙Chấm tất cả'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _addPreviousEmployees,
          child: Text('➕ NV như trước')
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _deleteEmployee,
          child: Text('🗑️ Xoá CN'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProjectWorkerAuto(
                  selectedBoPhan: _selectedDepartment ?? '',
                  username: _username,
                ),
              ),
            );
          },
          child: Text('⚙️ TH tháng'),
        ),
      ],
    ),
  ),
),
              Expanded(
                child: DefaultTabController(
                  length: 10,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        tabs: [
                          Tab(text: 'Chữ & Giờ thường'),
                          //Tab(text: 'NG thường'),
                          Tab(text: 'Hỗ trợ'),
                          Tab(text: 'Part time'),
                          Tab(text: 'PT sáng'),
                          Tab(text: 'PT chiều'),
                          Tab(text: 'NG khác'),
                          Tab(text: 'NG x1.5'),
                          Tab(text: 'NG x2'),
                          Tab(text: 'Công lễ'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildAttendanceTable('CongThuongChu'),
                            //_buildAttendanceTable('NgoaiGioThuong'),
                            _buildAttendanceTable('HoTro'),
                            _buildAttendanceTable('PartTime'),
                            _buildAttendanceTable('PartTimeSang'),
                            _buildAttendanceTable('PartTimeChieu'),
                            _buildAttendanceTable('NgoaiGioKhac'),
                            _buildAttendanceTable('NgoaiGiox15'),
                            _buildAttendanceTable('NgoaiGiox2'),
                            _buildAttendanceTable('CongLe'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Đang xử lý...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_showColorDialog)
          Center(child: _buildColorPickerDialog()),
        if (_showDebugOverlay)
          Positioned(
            bottom: 20,
            left: 710,
            right: 20,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                itemCount: _debugLogs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    _debugLogs[index],
                    style: TextStyle(color: Colors.white, fontSize: 8),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
Future<void> _copyFromYesterday() async {
  // Show warning dialog first
  final shouldContinue = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Sao chép từ hôm qua'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hệ thống sẽ chỉ sao chép giá trị "Công chữ" và "NG thường" từ hôm qua sang ngày hôm nay.'),
          SizedBox(height: 12),
          Text('Lưu ý: Vui lòng kiểm tra kỹ thông tin trước khi lưu.', 
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Tiếp tục'),
        ),
      ],
    ),
  );

  if (shouldContinue != true) return;

  setState(() => _isLoading = true);
  try {
    debugLog('Starting copy from yesterday process...');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    final yesterdayDay = yesterday.day;
    
    debugLog('Today: $todayStr, Yesterday: $yesterdayStr (day $yesterdayDay)');
    debugLog('Selected department: $_selectedDepartment, Month: $_selectedMonth');
    
    if (_selectedMonth != DateFormat('yyyy-MM').format(today)) {
      setState(() => _isLoading = false);
      _showError('Chỉ có thể sao chép cho ngày hôm nay trong tháng hiện tại');
      return;
    }
    
    final dbHelper = DBHelper();
    final dateFormats = await dbHelper.rawQuery(
      'SELECT MaNV, Ngay FROM chamcongcn WHERE BoPhan = ? ORDER BY Ngay DESC LIMIT 5',
      [_selectedDepartment]
    );
    debugLog('Sample date formats in DB: ${dateFormats.map((r) => "${r['MaNV']}: ${r['Ngay']}")}');
    
    final yesterdayRecords = await dbHelper.rawQuery('''
      SELECT * FROM chamcongcn 
      WHERE BoPhan = ? 
      AND strftime('%d', Ngay) = ?
      AND strftime('%m-%Y', Ngay) = ?
    ''', [
      _selectedDepartment, 
      yesterdayDay.toString().padLeft(2, '0'),
      DateFormat('MM-yyyy').format(yesterday)
    ]);
    
    debugLog('Found ${yesterdayRecords.length} records for yesterday (day $yesterdayDay)');
    
    if (yesterdayRecords.isEmpty) {
      setState(() => _isLoading = false);
      _showError('Không có dữ liệu chấm công cho ngày hôm qua (ngày $yesterdayDay)');
      return;
    }
    
    final todayRecords = await dbHelper.rawQuery('''
      SELECT MaNV, UID FROM chamcongcn 
      WHERE BoPhan = ? AND strftime('%d', Ngay) = ?
      AND strftime('%m-%Y', Ngay) = ?
    ''', [
      _selectedDepartment, 
      today.day.toString().padLeft(2, '0'),
      DateFormat('MM-yyyy').format(today)
    ]);
    
    // Create a map instead of just a set for easier UID lookup
    final Map<String, String> existingEmployeesToday = {
      for (var r in todayRecords) r['MaNV'] as String: r['UID'] as String
    };
    debugLog('Employees already with records today: ${existingEmployeesToday.keys}');
    
    int addedCount = 0;
    int updatedCount = 0;
    
    for (final record in yesterdayRecords) {
      final empId = record['MaNV'] as String;
      final currentTime = DateFormat('HH:mm:ss').format(now);
      
      // Only copy CongThuongChu and NgoaiGioThuong
      final congThuongChu = record['CongThuongChu'] ?? 'Ro';
      final ngoaiGioThuong = record['NgoaiGioThuong']?.toString() ?? '0';
      
      if (existingEmployeesToday.containsKey(empId)) {
        debugLog('Updating only CongThuongChu and NgoaiGioThuong for employee: $empId');
        
        final uid = existingEmployeesToday[empId]!;
        
        // Only update specific fields
        final updates = {
          'Gio': currentTime,
          'NguoiDung': _username,
          'CongThuongChu': congThuongChu,
          'NgoaiGioThuong': ngoaiGioThuong,
        };
        
        try {
          final response = await http.put(
            Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongsua/$uid'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(updates)
          ).timeout(const Duration(seconds: 300));
          
          if (response.statusCode == 200) {
            await dbHelper.updateChamCongCN(uid, updates);
            updatedCount++;
            debugLog('Successfully updated CongThuongChu and NgoaiGioThuong for $empId (UID: $uid)');
          } else {
            debugLog('Server returned error for update: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          debugLog('Error during update for $empId: $e');
        }
      } else {
        debugLog('Creating new record with only CongThuongChu and NgoaiGioThuong for employee: $empId');
        final uid = Uuid().v4();
        
        final recordData = {
          'UID': uid,
          'Ngay': todayStr,
          'Gio': currentTime,
          'NguoiDung': _username,
          'BoPhan': _selectedDepartment,
          'MaBP': _selectedDepartment,
          'PhanLoai': record['PhanLoai'] ?? '',
          'MaNV': empId,
          'CongThuongChu': congThuongChu,
          'NgoaiGioThuong': ngoaiGioThuong,
          'NgoaiGioKhac': '0',
          'NgoaiGiox15': '0',
          'NgoaiGiox2': '0',
          'HoTro': '0',
          'PartTime': '0',
          'PartTimeSang': '0',
          'PartTimeChieu': '0',
          'CongLe': '0',
        };
        
        try {
          final response = await http.post(
            Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(recordData)
          ).timeout(const Duration(seconds: 300));
          
          if (response.statusCode == 200) {
            final chamCongModel = ChamCongCNModel(
              uid: uid,
              maNV: empId,
              ngay: today,
              boPhan: _selectedDepartment!,
              nguoiDung: _username,
              congThuongChu: congThuongChu as String,
              ngoaiGioThuong: double.tryParse(ngoaiGioThuong) ?? 0,
              ngoaiGioKhac: 0,
              ngoaiGiox15: 0,
              ngoaiGiox2: 0,
              hoTro: 0,
              partTime: 0,
              partTimeSang: 0,
              partTimeChieu: 0,
              congLe: 0,
            );
            await dbHelper.insertChamCongCN(chamCongModel);
            addedCount++;
            debugLog('Successfully created new record for $empId (UID: $uid)');
          } else {
            debugLog('Server returned error for creation: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          debugLog('Error during creation for $empId: $e');
        }
      }
    }
    
    await _loadAttendanceData();
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép từ hôm qua: ${addedCount + updatedCount} nhân viên (thêm mới: $addedCount, cập nhật: $updatedCount). Vui lòng kiểm tra lại dữ liệu trước khi lưu.'))
    );
    
  } catch (e) {
    setState(() => _isLoading = false);
    debugLog('Error copying from yesterday: $e');
    _showError('Không thể sao chép dữ liệu từ hôm qua: ${e.toString()}');
  }
}
String _extractCongThuongChuBase(String? value) {
  if (value == null) return 'Ro';
  if (value.endsWith('+P')) {
    return value.substring(0, value.length - 2);
  } else if (value.endsWith('+P/2')) {
    return value.substring(0, value.length - 4);
  }
  return value;
}
Widget _buildCombinedTable() {
 final days = _getDaysInMonth();
 final employees = _getUniqueEmployees();
 
 return SingleChildScrollView(
   scrollDirection: Axis.horizontal,
   child: SingleChildScrollView(
     child: Table(
       border: TableBorder.all(color: Colors.grey.shade300),
       columnWidths: {
         0: FixedColumnWidth(100),
         for (int i = 0; i < days.length; i++) 
           i + 1: FixedColumnWidth(70),
       },
       children: [
         TableRow(
           decoration: BoxDecoration(
             color: Colors.grey.shade200,
           ),
           children: [
             TableCell(
               child: Padding(
                 padding: const EdgeInsets.all(8.0),
                 child: Row(
                   children: [
                     Text('Mã NV', style: TextStyle(fontWeight: FontWeight.bold)),
                     SizedBox(width: 4),
                     InkWell(
                       onTap: () {
                         showDialog(
                           context: context,
                           builder: (context) => AlertDialog(
                             title: Text('Đánh dấu nhân viên'),
                             content: Text('Nhấn vào tên nhân viên để chọn màu đánh dấu.'),
                             actions: [
                               TextButton(
                                 onPressed: () => Navigator.pop(context),
                                 child: Text('Đóng'),
                               ),
                             ],
                           ),
                         );
                       },
                       child: Icon(Icons.color_lens, size: 16),
                     ),
                   ],
                 ),
               ),
             ),
             for (var day in days)
               TableCell(
                 child: Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: Text(day.toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                 ),
               ),
           ],
         ),
         
         for (var empId in employees) ...[
           TableRow(
             decoration: BoxDecoration(
               color: _staffColors[empId],
             ),
             children: [
               TableCell(
  verticalAlignment: TableCellVerticalAlignment.middle,
  child: Padding(
    padding: const EdgeInsets.all(8.0),
    child: InkWell(
      onTap: () {
        setState(() {
          _staffToColor = empId;
          _showColorDialog = true;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(empId, style: TextStyle(color: Colors.black)),
          Text(
            _staffNames[empId] ?? '',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('Công chữ', style: TextStyle(fontSize: 10)),
        ],
      ),
    ),
  ),
),
               for (var day in days)
                 TableCell(
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         DropdownButton<String>(
                           value: _congThuongChoices.contains(_extractCongThuongChuBase(_getAttendanceForDay(empId, day, 'CongThuongChu'))) 
    ? _extractCongThuongChuBase(_getAttendanceForDay(empId, day, 'CongThuongChu')) 
    : _congThuongChoices.first,
                           items: _congThuongChoices.map((choice) =>
                             DropdownMenuItem(
                               value: choice, 
                               child: Text(
                                 choice,
                                 style: TextStyle(
                                   color: (choice != 'Ro') ? Colors.blue : null,
                                   fontWeight: (choice != 'Ro') ? FontWeight.bold : null,
                                 ),
                               ),
                             )
                           ).toList(),
                           onChanged: _canEditDay(day) 
    ? (value) {
        final currentValue = _getAttendanceForDay(empId, day, 'CongThuongChu') ?? 'Ro';
        if (currentValue.endsWith('+P')) {
          _updateAttendance(empId, day, 'CongThuongChu', value! + '+P');
        } else if (currentValue.endsWith('+P/2')) {
          _updateAttendance(empId, day, 'CongThuongChu', value! + '+P/2');
        } else {
          _updateAttendance(empId, day, 'CongThuongChu', value);
        }
      }
    : null,
                           isExpanded: true,
                           isDense: true,
                           style: TextStyle(
                             color: (_getAttendanceForDay(empId, day, 'CongThuongChu') != 'Ro') 
                                 ? Colors.blue 
                                 : null,
                             fontWeight: (_getAttendanceForDay(empId, day, 'CongThuongChu') != 'Ro')
                                 ? FontWeight.bold
                                 : null,
                           ),
                         ),
                         if ((_getAttendanceForDay(empId, day, 'CongThuongChu') ?? 'Ro').endsWith('+P') || 
    (_getAttendanceForDay(empId, day, 'CongThuongChu') ?? 'Ro').endsWith('+P/2'))
  Padding(
    padding: const EdgeInsets.only(top: 2.0),
    child: Text(
      _getAttendanceForDay(empId, day, 'CongThuongChu') ?? 'Ro',
      style: TextStyle(
        fontSize: 10,
        color: Colors.purple,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
                       ],
                     ),
                   ),
                 ),
             ],
           ),
           
           TableRow(
             decoration: BoxDecoration(
               color: _staffColors[empId] != null 
                   ? _staffColors[empId]!.withOpacity(0.7)
                   : Colors.grey.shade100,
             ),
             children: [
               TableCell(
                 child: Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: Text('NG thường', 
                     style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                 ),
               ),
               for (var day in days)
                 TableCell(
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4.0),
                     child: SizedBox(
                       height: 40,
                       child: TextFormField(
                         initialValue: _getAttendanceForDay(empId, day, 'NgoaiGioThuong'),
                         keyboardType: TextInputType.numberWithOptions(decimal: true),
                         textAlign: TextAlign.right,
                         enabled: _canEditDay(day),
                         style: TextStyle(
                           color: (_getAttendanceForDay(empId, day, 'NgoaiGioThuong') != '0') 
                               ? Colors.blue 
                               : Colors.grey.shade800,
                           fontWeight: (_getAttendanceForDay(empId, day, 'NgoaiGioThuong') != '0')
                               ? FontWeight.bold
                               : FontWeight.normal,
                         ),
                         onChanged: (value) {
                           if (value.isEmpty) {
                             _updateAttendance(empId, day, 'NgoaiGioThuong', '0');
                             return;
                           }
                           value = value.replaceAll(RegExp(r'[^\d.]'), '');
                           _updateAttendance(empId, day, 'NgoaiGioThuong', value);
                         },
                         decoration: InputDecoration(
                           isDense: true,
                           contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                           border: OutlineInputBorder(),
                           filled: true,
                           fillColor: (_getAttendanceForDay(empId, day, 'NgoaiGioThuong') != '0')
                               ? Colors.blue.withOpacity(0.1)
                               : Colors.white.withOpacity(0.7),
                         ),
                       ),
                     ),
                   ),
                 ),
             ],
           ),
           
           if (empId != employees.last)
             TableRow(
               children: [
                 for (int i = 0; i <= days.length; i++)
                   TableCell(
                     child: Container(
                       height: 4,
                       color: Colors.grey.shade200,
                     ),
                   ),
               ],
             ),
         ],
       ],
     ),
   ),
 );
}
  Widget _buildAttendanceTable(String columnType) {
 if (columnType == "CongThuongChu") {
   return _buildCombinedTable();
 }
 
 final days = _getDaysInMonth();
 final employees = _getUniqueEmployees();
 
 return SingleChildScrollView(
   scrollDirection: Axis.horizontal,
   child: SingleChildScrollView(
     child: DataTable(
       columns: [
         DataColumn(label: Row(
           children: [
             Text('Mã NV'),
             SizedBox(width: 4),
             InkWell(
               onTap: () {
                 showDialog(
                   context: context,
                   builder: (context) => AlertDialog(
                     title: Text('Đánh dấu nhân viên'),
                     content: Text('Nhấn vào tên nhân viên để chọn màu đánh dấu.'),
                     actions: [
                       TextButton(
                         onPressed: () => Navigator.pop(context),
                         child: Text('Đóng'),
                       ),
                     ],
                   ),
                 );
               },
               child: Icon(Icons.color_lens, size: 16),
             ),
           ],
         )),
         ...days.map((day) => DataColumn(label: Text(day.toString()))),
       ],
       rows: employees.map((empId) {
         final bgColor = _staffColors[empId];
         
         return DataRow(
           color: bgColor != null ? 
             MaterialStateProperty.all(bgColor) : 
             null,
           cells: [
             DataCell(
  InkWell(
    onTap: () {
      setState(() {
        _staffToColor = empId;
        _showColorDialog = true;
      });
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(empId, style: TextStyle(color: Colors.black)),
        Text(
          _staffNames[empId] ?? '',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  ),
),
             ...days.map((day) {
               final attendance = _getAttendanceForDay(empId, day, columnType);
               final defaultValue = columnType == 'CongThuongChu' ? 'Ro' : '0';
               final value = attendance ?? defaultValue;
               final canEdit = _canEditDay(day);
               
               return DataCell(
                 columnType == 'CongThuongChu'
                   ? DropdownButton<String>(
                       value: _congThuongChoices.contains(_extractCongThuongChuBase(attendance ?? 'Ro')) 
    ? _extractCongThuongChuBase(attendance ?? 'Ro') 
    : _congThuongChoices.first,
                       items: _congThuongChoices.map((choice) =>
                         DropdownMenuItem(value: choice, child: Text(choice))
                       ).toList(),
                       onChanged: canEdit ? (newValue) {
    if ((attendance ?? 'Ro').endsWith('+P')) {
      _updateAttendance(empId, day, columnType, newValue! + '+P');
    } else if ((attendance ?? 'Ro').endsWith('+P/2')) {
      _updateAttendance(empId, day, columnType, newValue! + '+P/2');
    } else {
      _updateAttendance(empId, day, columnType, newValue);
    }
} : null,
                     )
                   : SizedBox(
                       width: 60,
                       child: TextFormField(
                         initialValue: attendance,
                         keyboardType: columnType == 'HoTro' || 
                                    columnType == 'PartTime' || 
                                    columnType == 'PartTimeSang' || 
                                    columnType == 'PartTimeChieu' 
                           ? TextInputType.number 
                           : TextInputType.numberWithOptions(decimal: true),
                         textAlign: TextAlign.right,
                         enabled: canEdit,
                         onChanged: (value) {
                           if (value.isEmpty) {
                             _updateAttendance(empId, day, columnType, '0');
                             return;
                           }
                           value = value.replaceAll(RegExp(r'[^\d.]'), '');
                           _updateAttendance(empId, day, columnType, value);
                         },
                         decoration: InputDecoration(
                           isDense: true,
                           contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                         ),
                       ),
                     ),
               );
             }),
           ],
         );
       }).toList(),
     ),
   ),
 );
}
void _updatePhanLoaiForMonth(String empId, String phanLoaiValue) {
  debugLog('Starting PhanLoai update for employee $empId with value $phanLoaiValue');
  
  // First, update all records for the employee who triggered the update
  List<Map<String, dynamic>> employeeRecords = _attendanceData.where((record) => 
    record['MaNV'] == empId
  ).toList();
  
  debugLog('Found ${employeeRecords.length} records for employee $empId');
  
  // Update this employee's records
  for (var record in employeeRecords) {
    final uid = record['UID'] as String;
    final currentPhanLoai = record['PhanLoai']?.toString() ?? '';
    
    record['PhanLoai'] = phanLoaiValue;
    debugLog('Updated PhanLoai to $phanLoaiValue for employee $empId record with UID: $uid');
    
    // Add to modified records
    if (!_newRecords.containsKey(uid)) {
      if (!_modifiedRecords.containsKey(uid)) {
        _modifiedRecords[uid] = Map<String, dynamic>.from(record);
      } else {
        _modifiedRecords[uid]!['PhanLoai'] = phanLoaiValue;
      }
    } else {
      _newRecords[uid]!['PhanLoai'] = phanLoaiValue;
    }
  }
  
  // Now, find all records for other employees in the same project with blank/null PhanLoai
  // and update them based on their CongThuongChu values
  List<Map<String, dynamic>> otherRecords = _attendanceData.where((record) => 
    record['MaNV'] != empId && 
    (record['PhanLoai'] == null || record['PhanLoai'].toString().isEmpty)
  ).toList();
  
  debugLog('Found ${otherRecords.length} records for other employees with blank PhanLoai');
  
  // Group by employee ID to process each employee only once
  Map<String, List<Map<String, dynamic>>> employeeGroups = {};
  for (var record in otherRecords) {
    String id = record['MaNV'] as String;
    if (!employeeGroups.containsKey(id)) {
      employeeGroups[id] = [];
    }
    employeeGroups[id]!.add(record);
  }
  
  // Process each employee group
  employeeGroups.forEach((otherEmpId, records) {
    // Get the appropriate PhanLoai value based on the CongThuongChu of each record
    for (var record in records) {
      final congThuongChu = record['CongThuongChu'] as String? ?? 'Ro';
      String newPhanLoai = '0.0';
      
      if (congThuongChu == '3X') {
        newPhanLoai = '3.0';
      } else if (congThuongChu == '2X' || congThuongChu == '2XĐ') {
        newPhanLoai = '2.0';
      } else if (['X', 'P', 'XĐ', 'CĐ', 'NL'].contains(congThuongChu)) {
        newPhanLoai = '1.0';
      } else if (congThuongChu == '3X/4') {
        newPhanLoai = '0.75';
      } else if (['X/2', 'P/2'].contains(congThuongChu)) {
        newPhanLoai = '0.5';
      }
      
      final uid = record['UID'] as String;
      record['PhanLoai'] = newPhanLoai;
      debugLog('Auto-updated PhanLoai to $newPhanLoai for employee $otherEmpId based on CongThuongChu: $congThuongChu');
      
      // Add to modified records
      if (!_newRecords.containsKey(uid)) {
        if (!_modifiedRecords.containsKey(uid)) {
          _modifiedRecords[uid] = Map<String, dynamic>.from(record);
        } else {
          _modifiedRecords[uid]!['PhanLoai'] = newPhanLoai;
        }
      } else {
        _newRecords[uid]!['PhanLoai'] = newPhanLoai;
      }
    }
  });
  
  debugLog('Completed PhanLoai update for all employees in the project');
}
Future<String> _getStaffName(String maNV) async {
  final dbHelper = DBHelper();
  final result = await dbHelper.rawQuery(
    'SELECT HoTen FROM staffbio WHERE MaNV = ?',
    [maNV]
  );
  return result.isNotEmpty ? result.first['HoTen'] as String : '';
}
void _updateAttendance(String empId, int day, String columnType, String? value) {
  if (value == null) return;
  
  debugLog('Updating attendance for $empId on day $day, column $columnType to value: $value');
  
  // Validate and format based on column type
  String formattedValue;
  String? phanLoaiValue;
  switch (columnType) {
    case 'CongThuongChu':
      formattedValue = value;
      bool hasPlusP = value.endsWith('+P');
      bool hasPlusPHalf = value.endsWith('+P/2');
      String baseValue = _extractCongThuongChuBase(value);
      if (baseValue == '3X') {
        phanLoaiValue = '3.0';
      } else if (baseValue == '2X' || baseValue == '2XĐ') {
        phanLoaiValue = '2.0';
      } else if (['X', 'P', 'XĐ', 'CĐ', 'NL'].contains(baseValue)) {
        phanLoaiValue = '1.0';
      } else if (baseValue == '3X/4') {
        phanLoaiValue = '0.75';
      } else if (['X/2', 'P/2'].contains(baseValue)) {
        phanLoaiValue = '0.5';
      } else if (['Ro', 'HT', 'NT', 'Ô', 'TS', 'QLDV', 'HV', '2HV', '3HV'].contains(baseValue)) {
        phanLoaiValue = '0.0';
      } else {
        phanLoaiValue = '0.0';
      }
      if (phanLoaiValue != null) {
        double phanLoaiDouble = double.tryParse(phanLoaiValue) ?? 0.0;
        if (hasPlusP) {
          phanLoaiDouble += 1.0;
        } else if (hasPlusPHalf) {
          phanLoaiDouble += 0.5;
        }
        phanLoaiValue = phanLoaiDouble.toStringAsFixed(1);
      }
      debugLog('Calculated PhanLoai value: $phanLoaiValue for CongThuongChu: $value');
      break;
    
    // ALL numeric fields should accept decimals
    case 'NgoaiGioThuong':
    case 'NgoaiGioKhac':
    case 'NgoaiGiox15':
    case 'NgoaiGiox2':
    case 'CongLe':
    case 'HoTro':
  double? numValue = double.tryParse(value);
  if (numValue == null) return;
  // Convert to integer before saving
  formattedValue = numValue.round().toString();
  debugLog('Converting to integer value: $formattedValue');
  break;
    case 'PartTime':
    case 'PartTimeSang':
    case 'PartTimeChieu':
      double? numValue = double.tryParse(value);
      if (numValue == null) return;
      
      // Preserve the exact decimal value as entered by user
      formattedValue = value;
      debugLog('Preserved decimal value: $formattedValue');
      break;
    
    default:
      return;
  }

  final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
  debugLog('Date for record: $dateStr');

  // Find or create record
  var record = _attendanceData.firstWhere(
    (r) => r['MaNV'] == empId && r['Ngay'].split('T')[0] == dateStr,
    orElse: () {
      final newUid = Uuid().v4();
      debugLog('Creating new record with UID: $newUid');
      final newPhanLoai = columnType == 'CongThuongChu' ? phanLoaiValue : '0.0';

      // Create a new record with proper defaults
      final newRecord = {
        'UID': newUid,
        'MaNV': empId,
        'Ngay': dateStr,
        'Gio': DateFormat('HH:mm:ss').format(DateTime.now()),
        'NguoiDung': _username,
        'BoPhan': _selectedDepartment,
        'MaBP': _selectedDepartment,
        'PhanLoai': newPhanLoai,
        'CongThuongChu': 'Ro',
        'NgoaiGioThuong': '0',
        'NgoaiGioKhac': '0',
        'NgoaiGiox15': '0',
        'NgoaiGiox2': '0',
        'HoTro': '0',
        'PartTime': '0',
        'PartTimeSang': '0',
        'PartTimeChieu': '0',
        'CongLe': '0',
      };
      
      _newRecords[newUid] = Map<String, dynamic>.from(newRecord);
      _attendanceData.add(newRecord);
      return newRecord;
    }
  );

  // Only update the specific field that was changed
  setState(() {
    // Store the original values for debugging
    final oldValue = record[columnType];
    
    // Update only the specific field
    record[columnType] = formattedValue;
    if (columnType == 'CongThuongChu' && phanLoaiValue != null) {
      record['PhanLoai'] = phanLoaiValue;
      debugLog('Updated PhanLoai to $phanLoaiValue based on CongThuongChu: $formattedValue');
    }
    
    final uid = record['UID'] as String;
    
    if (_newRecords.containsKey(uid)) {
      _newRecords[uid]![columnType] = formattedValue;
      if (columnType == 'CongThuongChu' && phanLoaiValue != null) {
        _newRecords[uid]!['PhanLoai'] = phanLoaiValue;
      }
    } else {
      if (!_modifiedRecords.containsKey(uid)) {
        _modifiedRecords[uid] = Map<String, dynamic>.from(record);
      } else {
        _modifiedRecords[uid]![columnType] = formattedValue;
        if (columnType == 'CongThuongChu' && phanLoaiValue != null) {
          _modifiedRecords[uid]!['PhanLoai'] = phanLoaiValue;
        }
      }
    }
    
    // If we need to fix ALL records for this employee in this month
    if (columnType == 'CongThuongChu' && phanLoaiValue != null) {
      // Find all other records for this employee in this month
      final otherRecords = _attendanceData.where((r) => 
        r['MaNV'] == empId && 
        r['UID'] != uid &&
        r['Ngay'].toString().startsWith(_selectedMonth!)
      ).toList();
      
      for (var otherRecord in otherRecords) {
        final otherUid = otherRecord['UID'] as String;
        final otherCongThuongChu = otherRecord['CongThuongChu'] as String? ?? 'Ro';
        String otherPhanLoai = '0.0';
        
        // Calculate the correct PhanLoai based on the existing CongThuongChu value
        if (otherCongThuongChu == '3X') {
          otherPhanLoai = '3.0';
        } else if (otherCongThuongChu == '2X' || otherCongThuongChu == '2XĐ') {
          otherPhanLoai = '2.0';
        } else if (['X', 'P', 'XĐ', 'CĐ', 'NL'].contains(otherCongThuongChu)) {
          otherPhanLoai = '1.0';
        } else if (otherCongThuongChu == '3X/4') {
          otherPhanLoai = '0.75';
        } else if (['X/2', 'P/2'].contains(otherCongThuongChu)) {
          otherPhanLoai = '0.5';
        } else if (['Ro', 'HT', 'NT', 'Ô', 'TS', 'QLDV', 'HV', '2HV', '3HV'].contains(otherCongThuongChu)) {
          otherPhanLoai = '0.0';
        }
        
        otherRecord['PhanLoai'] = otherPhanLoai;
        debugLog('Fixed PhanLoai for other record: $otherUid to $otherPhanLoai based on CongThuongChu: $otherCongThuongChu');
        
        // Update tracking collections
        if (_newRecords.containsKey(otherUid)) {
          _newRecords[otherUid]!['PhanLoai'] = otherPhanLoai;
        } else if (!_modifiedRecords.containsKey(otherUid)) {
          _modifiedRecords[otherUid] = Map<String, dynamic>.from(otherRecord);
        } else {
          _modifiedRecords[otherUid]!['PhanLoai'] = otherPhanLoai;
        }
      }
    }
  });
}
List<String> _getUniqueEmployees() {
  final Set<String> uniqueEmpIds = _attendanceData
    .map((record) => record['MaNV'] as String)
    .toSet();
  
  final employees = List<String>.from(uniqueEmpIds);
  if (_staffColors.isNotEmpty) {
    employees.sort((a, b) {
      final colorA = _staffColors[a]?.value ?? 0;
      final colorB = _staffColors[b]?.value ?? 0;
      
      if (colorA == colorB) {
        return a.compareTo(b); 
      }
      return colorB - colorA; 
    });
  }
  
  return employees;
}
String? _getAttendanceForDay(String empId, int day, String columnType) {
  final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
  final record = _attendanceData.firstWhere(
    (record) => 
      record['MaNV'] == empId && 
      record['Ngay'].split('T')[0] == dateStr,  // Compare just the date part
    orElse: () => {},
  );
  return record[columnType]?.toString() ?? (columnType == 'CongThuongChu' ? 'Ro' : '0');
}
bool _canEditDay(int day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(Duration(days: 1));
  final checkDate = DateTime.parse('$_selectedMonth-${day.toString().padLeft(2, '0')}');
  // Allow editing current date
  if (checkDate.isAtSameMomentAs(today)) return true;
  // Allow editing yesterday if before 9am
  if (checkDate.isAtSameMomentAs(yesterday) && now.hour < 9) return true;
  
  return false;
}
Future<void> _fixAllPhanLoaiValues() async {
  debugLog('Starting to fix all PhanLoai values...');
  
  int updatedCount = 0;
  
  for (var record in _attendanceData) {
    final uid = record['UID'] as String;
    final congThuongChu = record['CongThuongChu'] as String? ?? 'Ro';
    
    // Check for special suffixes
    bool hasPlusP = congThuongChu.endsWith('+P');
    bool hasPlusPHalf = congThuongChu.endsWith('+P/2');
    String baseValue = _extractCongThuongChuBase(congThuongChu);
    
    // Calculate base PhanLoai
    String correctPhanLoai = '0.0';
    
    if (baseValue == '3X') {
      correctPhanLoai = '3.0';
    } else if (baseValue == '2X' || baseValue == '2XĐ') {
      correctPhanLoai = '2.0';
    } else if (['X', 'P', 'XĐ', 'CĐ', 'NL'].contains(baseValue)) {
      correctPhanLoai = '1.0';
    } else if (baseValue == '3X/4') {
      correctPhanLoai = '0.75';
    } else if (['X/2', 'P/2'].contains(baseValue)) {
      correctPhanLoai = '0.5';
    } else {
      correctPhanLoai = '0.0';
    }
    
    // Adjust for special suffixes
    double phanLoaiDouble = double.tryParse(correctPhanLoai) ?? 0.0;
    if (hasPlusP) {
      phanLoaiDouble += 1.0;
    } else if (hasPlusPHalf) {
      phanLoaiDouble += 0.5;
    }
    correctPhanLoai = phanLoaiDouble.toStringAsFixed(1);
    
    final currentPhanLoai = record['PhanLoai']?.toString() ?? '';
    
    // Check if PhanLoai needs updating
    if (currentPhanLoai != correctPhanLoai) {
      record['PhanLoai'] = correctPhanLoai;
      updatedCount++;
      
      // Add to modified records to be saved
      if (!_newRecords.containsKey(uid)) {
        if (!_modifiedRecords.containsKey(uid)) {
          _modifiedRecords[uid] = Map<String, dynamic>.from(record);
        } else {
          _modifiedRecords[uid]!['PhanLoai'] = correctPhanLoai;
        }
      } else {
        _newRecords[uid]!['PhanLoai'] = correctPhanLoai;
      }
      
      debugLog('Fixed PhanLoai for UID $uid: $currentPhanLoai -> $correctPhanLoai (CongThuongChu: $congThuongChu)');
    }
  }
  if (updatedCount > 0) {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã cập nhật $updatedCount giá trị PhanLoai'))
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tất cả giá trị PhanLoai đã đúng'))
    );
  }
  debugLog('Completed fixing PhanLoai values. Updated: $updatedCount records');
}
Future<void> _loadAttendanceData() async {
  if (_selectedMonth == null || _selectedDepartment == null) return;
  try {
    final dbHelper = DBHelper();
    final data = await dbHelper.rawQuery('''
      SELECT * FROM chamcongcn 
      WHERE BoPhan = ? AND strftime('%Y-%m', Ngay) = ?
      ORDER BY Ngay
    ''', [_selectedDepartment, _selectedMonth]);
    
    setState(() {
      _attendanceData = List<Map<String, dynamic>>.from(data.map((record) => {
        'UID': record['UID'] ?? '',
        'Ngay': record['Ngay'] ?? '',
        'Gio': record['Gio'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
        'NguoiDung': record['NguoiDung'] ?? _username,
        'BoPhan': record['BoPhan'] ?? _selectedDepartment,
        'MaBP': record['MaBP'] ?? _selectedDepartment,
        'PhanLoai': record['PhanLoai']?.toString() ?? '',
        'MaNV': record['MaNV'] ?? '',
        'CongThuongChu': record['CongThuongChu'] ?? 'Ro',
        'NgoaiGioThuong': record['NgoaiGioThuong']?.toString() ?? '0',
        'NgoaiGioKhac': record['NgoaiGioKhac']?.toString() ?? '0',
        'NgoaiGiox15': record['NgoaiGiox15']?.toString() ?? '0',
        'NgoaiGiox2': record['NgoaiGiox2']?.toString() ?? '0',
        'HoTro': (record['HoTro'] != null) ? record['HoTro'].toString() : '0',

        'PartTime': record['PartTime']?.toString() ?? '0',
        'PartTimeSang': record['PartTimeSang']?.toString() ?? '0',
        'PartTimeChieu': record['PartTimeChieu']?.toString() ?? '0',
        'CongLe': record['CongLe']?.toString() ?? '0',
      }));
    });
    
    final employeeIds = _getUniqueEmployees();
    await _loadStaffNames(employeeIds);
    
    // Auto-fix PhanLoai values when loading data
    //await _fixAllPhanLoaiValues();
    
  } catch (e) {
    debugLog('Error loading attendance data: $e');
    _showError('Không thể tải dữ liệu chấm công');
  }
}
}