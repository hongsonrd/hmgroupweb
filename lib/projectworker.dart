import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'projectworkerall.dart';

import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'http_client.dart';
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
    final List<String> _congThuongChoices = ['X', 'P', 'XĐ', 'X/2', 'Ro', 'HT', 'NT', 'CĐ', 'NL', 'Ô', 'TS', '2X', '3X', 'HV', '2HV', '3HV', '2XĐ', 'QLDV'];
  late String _username;
  Map<String, String> _staffNames = {};
  List<String> _debugLogs = [];
bool _showDebugOverlay = true;
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
Future<void> _exportToExcel() async {
  try {
    debugLog('Starting Excel export...');
    
    // Create a new Excel document
    final excel = Excel.createExcel();
    
    // Remove the default sheet
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }
    
    // Create sheets for each attendance type
    final attendanceTypes = [
      'CongThuongChu', 
      'NgoaiGioThuong', 
      'HoTro', 
      'PartTime', 
      'PartTimeSang', 
      'PartTimeChieu',
      'NgoaiGioKhac', 
      'NgoaiGiox15', 
      'NgoaiGiox2', 
      'CongLe'
    ];
    
    final translatedTypes = {
      'CongThuongChu': 'Công chữ',
      'NgoaiGioThuong': 'NG thường',
      'HoTro': 'Hỗ trợ',
      'PartTime': 'Part time',
      'PartTimeSang': 'PT sáng',
      'PartTimeChieu': 'PT chiều',
      'NgoaiGioKhac': 'NG khác',
      'NgoaiGiox15': 'NG x1.5',
      'NgoaiGiox2': 'NG x2',
      'CongLe': 'Công lễ'
    };
    
    final days = _getDaysInMonth();
    final employees = _getUniqueEmployees();
    
    // Create a sheet for each attendance type
    for (String type in attendanceTypes) {
      final sheetName = translatedTypes[type] ?? type;
      final sheet = excel[sheetName];
      
      // Add header row with days
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Mã NV';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = 'Tên NV';
      
      for (int i = 0; i < days.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: i + 2, 
          rowIndex: 0
        )).value = days[i].toString();
      }
      
      // Populate data rows
      for (int i = 0; i < employees.length; i++) {
        final empId = employees[i];
        
        // Employee ID and name
        sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: 0, 
          rowIndex: i + 1
        )).value = empId;
        
        sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: 1, 
          rowIndex: i + 1
        )).value = _staffNames[empId] ?? '';
        
        // Attendance values for each day
        for (int j = 0; j < days.length; j++) {
          final day = days[j];
          final value = _getAttendanceForDay(empId, day, type);
          
          sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: j + 2, 
            rowIndex: i + 1
          )).value = value ?? '';
        }
      }
      
      // Auto-size columns
      for (int i = 0; i < days.length + 2; i++) {
  //sheet.setColumnWidth(i, 15);
}
    }
    
    // Create the Excel file
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception("Failed to generate Excel file");
    }
    
    // Save the file
    final fileName = 'BangChamCong_${_selectedDepartment}_${_selectedMonth}.xlsx';
    
    if (kIsWeb) {
      // For web, we need a different approach
      debugLog('Web platform detected, using different export method');
      _showError('Xuất file Excel không được hỗ trợ trên web');
      return;
    }
    
    // Get the directory to save the file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    
    // Write the file
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    
    // Share the file
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Bảng chấm công $_selectedMonth',
      text: 'Bảng chấm công $_selectedDepartment tháng $_selectedMonth',
    );
    
    debugLog('Excel file created at: $filePath');
    
  } catch (e) {
    debugLog('Error creating Excel file: $e');
    _showError('Không thể xuất file Excel: ${e.toString()}');
  }
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
        ).timeout(const Duration(seconds: 30));

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
  try {
    final dbHelper = DBHelper();
    
    // Desktop-specific debugging
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugLog('Running on desktop platform');
      debugLog('Modified records count: ${_modifiedRecords.length}');
      debugLog('New records count: ${_newRecords.length}');
    }
    
    // First process existing modified records
    for (var entry in _modifiedRecords.entries) {
      final record = entry.value;
      final uid = record['UID'] as String;
      
      final updates = Map<String, dynamic>.from(record);
      updates.remove('UID');
      
      debugLog('Sending modified record to server with UID: $uid');
      debugLog('Request body: ${json.encode(updates)}');
      
      final response = await http.put(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongsua/$uid'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates)
      ).timeout(const Duration(seconds: 30));
      
      debugLog('Server response for modified record $uid: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update record: ${response.body}');
      }

      await dbHelper.updateChamCongCN(uid, updates);
      debugLog('Local database updated for modified UID: $uid');
    }
    
    // Then process new records
    for (var entry in _newRecords.entries) {
      final uid = entry.key;
      final record = entry.value;
      
      debugLog('Sending new record to server with UID: $uid');
      debugLog('Request body: ${json.encode(record)}');
      
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(record)
      ).timeout(const Duration(seconds: 30));
      
      debugLog('Server response for new record $uid: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode != 200) {
        throw Exception('Failed to add new record: ${response.body}');
      }
      
      // Convert to model and save to local DB
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
      debugLog('Local database updated for new UID: $uid');
    }

    // Add a small delay before refreshing data
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _modifiedRecords.clear();
      _newRecords.clear();
      debugLog('Cleared records caches');
    });

    debugLog('Loading fresh attendance data...');
    await _loadAttendanceData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thay đổi thành công'))
      );
    }

  } catch (e) {
    debugLog('Error in _saveChanges: $e');
    _showError('Lỗi khi lưu dữ liệu: ${e.toString()}');
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
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.purple,
      title: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              value: _selectedDepartment,
              items: _departments.map((dept) => 
                DropdownMenuItem(value: dept, child: Text(dept))
              ).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDepartment = value;
                  _loadAttendanceData();
                });
              },
              style: TextStyle(color: Colors.white),
              dropdownColor: Theme.of(context).primaryColor,
              isExpanded: true,
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
  child: Text('💙Xem tất cả'),
),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _addPreviousEmployees,
          child: Text('➕ NV như trước')
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _exportToExcel,
          child: Text('💛Xuất file'),
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
                          Tab(text: 'Công chữ'),
                          Tab(text: 'NG thường'),
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
                            _buildAttendanceTable('NgoaiGioThuong'),
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
          ).timeout(const Duration(seconds: 30));
          
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
          ).timeout(const Duration(seconds: 30));
          
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
  Widget _buildAttendanceTable(String columnType) {
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
                      Text(empId),
                      Text(
                        _staffNames[empId] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
        value: _congThuongChoices.contains(attendance) ? attendance : _congThuongChoices.first,
        items: _congThuongChoices.map((choice) =>
          DropdownMenuItem(value: choice, child: Text(choice))
        ).toList(),
        onChanged: canEdit ? (value) => _updateAttendance(empId, day, columnType, value) : null,
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
            // Remove any non-numeric characters except decimal point
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
  switch (columnType) {
    case 'CongThuongChu':
      formattedValue = value;
      break;
    
    // ALL numeric fields should accept decimals
    case 'NgoaiGioThuong':
    case 'NgoaiGioKhac':
    case 'NgoaiGiox15':
    case 'NgoaiGiox2':
    case 'CongLe':
    case 'HoTro':
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
      return; // Unknown column type
  }

  final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
  debugLog('Date for record: $dateStr');

  // Find or create record
  var record = _attendanceData.firstWhere(
    (r) => r['MaNV'] == empId && r['Ngay'].split('T')[0] == dateStr,
    orElse: () {
      final newUid = Uuid().v4();
      debugLog('Creating new record with UID: $newUid');
      final newRecord = {
        'UID': newUid,
        'MaNV': empId,
        'Ngay': dateStr,
        'Gio': DateFormat('HH:mm:ss').format(DateTime.now()),
        'NguoiDung': _username,
        'BoPhan': _selectedDepartment,
        'MaBP': _selectedDepartment,
        'PhanLoai': '',
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
      _newRecords[newUid] = newRecord;
      _attendanceData.add(newRecord);
      return newRecord;
    }
  );

  setState(() {
  record[columnType] = formattedValue;
  final uid = record['UID'] as String;
  debugLog('Updated record UID: $uid, field: $columnType, value: $formattedValue');
  
  if (_newRecords.containsKey(uid)) {
    // Update the record in the newRecords collection
    _newRecords[uid]![columnType] = formattedValue;
    debugLog('Updated new record (not yet sent to server)');
  } else {
    // Add to modified records
    _modifiedRecords[uid] = Map<String, dynamic>.from(record);
    debugLog('Added to modified records. Total modified: ${_modifiedRecords.length}');
  }
});
}
 List<String> _getUniqueEmployees() {
  final employees = _attendanceData
    .map((record) => record['MaNV'] as String)
    .toSet()
    .toList();
  
  // Sort by color if coloring is active
  if (_staffColors.isNotEmpty) {
    employees.sort((a, b) {
      final colorA = _staffColors[a]?.value ?? 0;
      final colorB = _staffColors[b]?.value ?? 0;
      
      if (colorA == colorB) {
        return a.compareTo(b); // If same color, sort alphabetically
      }
      return colorB - colorA; // Sort by color (descending)
    });
  } else {
    employees.sort(); // Default alphabetical sort
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
Future<void> _loadAttendanceData() async {
  if (_selectedMonth == null || _selectedDepartment == null) return;
  try {
    final dbHelper = DBHelper();
    final data = await dbHelper.rawQuery('''
      SELECT * FROM chamcongcn 
      WHERE BoPhan = ? AND strftime('%Y-%m', Ngay) = ?
      ORDER BY MaNV, Ngay
    ''', [_selectedDepartment, _selectedMonth]);
    
    setState(() {
      _attendanceData = List<Map<String, dynamic>>.from(data.map((record) => {
        'UID': record['UID'] ?? '',
        'Ngay': record['Ngay'] ?? '',  // Keep the original date format
        'Gio': record['Gio'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
        'NguoiDung': record['NguoiDung'] ?? _username,
        'BoPhan': record['BoPhan'] ?? _selectedDepartment,
        'MaBP': record['MaBP'] ?? _selectedDepartment,
        'PhanLoai': record['PhanLoai'] ?? '',
        'MaNV': record['MaNV'] ?? '',
        'CongThuongChu': record['CongThuongChu'] ?? '',
        'NgoaiGioThuong': record['NgoaiGioThuong']?.toString() ?? '0',
        'NgoaiGioKhac': record['NgoaiGioKhac']?.toString() ?? '0',
        'NgoaiGiox15': record['NgoaiGiox15']?.toString() ?? '0',
        'NgoaiGiox2': record['NgoaiGiox2']?.toString() ?? '0',
        'HoTro': record['HoTro']?.toString() ?? '0',
        'PartTime': record['PartTime']?.toString() ?? '0',
        'PartTimeSang': record['PartTimeSang']?.toString() ?? '0',
        'PartTimeChieu': record['PartTimeChieu']?.toString() ?? '0',
        'CongLe': record['CongLe']?.toString() ?? '0',
      }));
    });
  final employeeIds = _getUniqueEmployees();
    await _loadStaffNames(employeeIds);
  } catch (e) {
    debugLog('Error loading attendance data: $e');
    _showError('Không thể tải dữ liệu chấm công');
  }
}
}