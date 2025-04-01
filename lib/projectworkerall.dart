import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'http_client.dart';

class AllProjectsView extends StatefulWidget {
  const AllProjectsView({Key? key}) : super(key: key);

  @override
  _AllProjectsViewState createState() => _AllProjectsViewState();
}

class _AllProjectsViewState extends State<AllProjectsView> {
  bool _isLoading = true;
  List<String> _departments = [];
  List<String> _availableMonths = [];
  String? _selectedMonth;
  Map<String, List<Map<String, dynamic>>> _allProjectsData = {};
  Map<String, Map<String, String>> _staffNamesByDept = {};
  late String _username;
  List<String> _debugLogs = [];
  
  // Track modifications
  Map<String, Map<String, dynamic>> _modifiedRecords = {};
  Map<String, Map<String, dynamic>> _newRecords = {};
  final List<String> _congThuongChoices = ['X', 'P', 'XĐ', 'X/2', 'Ro', 'HT', 'NT', 'CĐ', 'NL', 'Ô', 'TS', '2X', '3X', 'HV', '2HV', '3HV', '2XĐ', 'QLDV'];
  
  @override
void initState() {
  super.initState();
  _username = Provider.of<UserCredentials>(context, listen: false).username;
  _initializeData();
}

Future<void> _initializeData() async {
  setState(() => _isLoading = true);
  try {
    // Load departments
    try {
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$_username'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> apiDepts = json.decode(response.body);
        setState(() {
          _departments = apiDepts.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      debugLog('Project API error: $e');
    }

    // Also get departments from local DB
    final dbHelper = DBHelper();
    final existingDepts = await dbHelper.rawQuery(
      'SELECT DISTINCT BoPhan FROM chamcongcn ORDER BY BoPhan'
    );
    _departments.addAll(existingDepts.map((e) => e['BoPhan'] as String));
    _departments = _departments.toSet().toList()..sort();
    
    // Always use current month since we're only showing recent days
    String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _availableMonths = [currentMonth];
    _selectedMonth = currentMonth;
    
    // Load data for all departments
    await _loadAllProjectsData();
  } catch (e) {
    debugLog('Init error: $e');
    _showError('Không thể tải dữ liệu');
  }
  setState(() => _isLoading = false);
}
Future<void> _copyFromYesterday() async {
  try {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sao chép từ hôm qua'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hệ thống sẽ sao chép giá trị "Công chữ", "NG thường" và "Part time" từ hôm qua sang ngày hôm nay.'),
            SizedBox(height: 12),
            Text('Lưu ý: Chức năng này sẽ thực hiện cho tất cả các dự án hiển thị. Vui lòng kiểm tra kỹ thông tin trước khi lưu.', 
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

    if (result != true) return;

    setState(() => _isLoading = true);
    
    debugLog('Starting copy from yesterday process...');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    final yesterdayDay = yesterday.day;
    
    debugLog('Today: $todayStr, Yesterday: $yesterdayStr (day $yesterdayDay)');
    
    if (_selectedMonth != DateFormat('yyyy-MM').format(today)) {
      setState(() => _isLoading = false);
      _showError('Chỉ có thể sao chép cho ngày hôm nay trong tháng hiện tại');
      return;
    }
    
    final dbHelper = DBHelper();
    
    int addedCount = 0;
    int updatedCount = 0;
    
    // Process each department separately
    for (String dept in _departments) {
      if (!_allProjectsData.containsKey(dept)) continue;
      
      // Get yesterday's records for this department
      final yesterdayRecords = await dbHelper.rawQuery('''
        SELECT * FROM chamcongcn 
        WHERE BoPhan = ? 
        AND strftime('%d', Ngay) = ?
        AND strftime('%m-%Y', Ngay) = ?
      ''', [
        dept, 
        yesterdayDay.toString().padLeft(2, '0'),
        DateFormat('MM-yyyy').format(yesterday)
      ]);
      
      debugLog('Found ${yesterdayRecords.length} records for yesterday in $dept');
      
      if (yesterdayRecords.isEmpty) continue;
      
      // Get today's records for this department
      final todayRecords = await dbHelper.rawQuery('''
        SELECT UID, MaNV FROM chamcongcn 
        WHERE BoPhan = ? AND strftime('%d', Ngay) = ?
        AND strftime('%m-%Y', Ngay) = ?
      ''', [
        dept, 
        today.day.toString().padLeft(2, '0'),
        DateFormat('MM-yyyy').format(today)
      ]);
      
      // Create a map of today's records by employee ID
      final Map<String, String> existingEmployeesToday = {
        for (var record in todayRecords) 
          record['MaNV'] as String: record['UID'] as String
      };
      
      // Process each employee's record
      for (final record in yesterdayRecords) {
        final empId = record['MaNV'] as String;
        final currentTime = DateFormat('HH:mm:ss').format(now);
        
        // Copy CongThuongChu, NgoaiGioThuong, and PartTime
        final congThuongChu = record['CongThuongChu'] ?? 'Ro';
        final ngoaiGioThuong = record['NgoaiGioThuong']?.toString() ?? '0';
        final partTime = record['PartTime']?.toString() ?? '0';
        
        // Check if employee already has a record for today
        if (existingEmployeesToday.containsKey(empId)) {
          final uid = existingEmployeesToday[empId]!;
          
          // Get the current record to update only specific fields
          final currentRecord = await dbHelper.rawQuery(
            'SELECT * FROM chamcongcn WHERE UID = ?', [uid]
          );
          
          if (currentRecord.isEmpty) continue;
          
          // Create updates with only the fields we want to change
          final updates = {
            'Gio': currentTime,
            'NguoiDung': _username,
            'CongThuongChu': congThuongChu,
            'NgoaiGioThuong': ngoaiGioThuong,
            'PartTime': partTime,
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
              debugLog('Updated record for $empId in $dept');
              
              // Update in memory data
              final idx = _allProjectsData[dept]!.indexWhere((r) => r['UID'] == uid);
              if (idx >= 0) {
                _allProjectsData[dept]![idx]['CongThuongChu'] = congThuongChu;
                _allProjectsData[dept]![idx]['NgoaiGioThuong'] = ngoaiGioThuong;
                _allProjectsData[dept]![idx]['PartTime'] = partTime;
              }
            }
          } catch (e) {
            debugLog('Error updating $empId: $e');
          }
        } else {
          // Create a new record for today
          final uid = Uuid().v4();
          final newRecord = {
            'UID': uid,
            'Ngay': todayStr,
            'Gio': currentTime,
            'NguoiDung': _username,
            'BoPhan': dept,
            'MaBP': dept,
            'PhanLoai': record['PhanLoai'] ?? '',
            'MaNV': empId,
            'CongThuongChu': congThuongChu,
            'NgoaiGioThuong': ngoaiGioThuong,
            'NgoaiGioKhac': '0',
            'NgoaiGiox15': '0',
            'NgoaiGiox2': '0',
            'HoTro': '0',
            'PartTime': partTime,
            'PartTimeSang': '0',
            'PartTimeChieu': '0',
            'CongLe': '0',
          };
          
          try {
            final response = await http.post(
              Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(newRecord)
            ).timeout(const Duration(seconds: 300));
            
            if (response.statusCode == 200) {
              final chamCongModel = ChamCongCNModel(
                uid: uid,
                maNV: empId,
                ngay: today,
                boPhan: dept,
                nguoiDung: _username,
                congThuongChu: congThuongChu as String,
                ngoaiGioThuong: double.tryParse(ngoaiGioThuong.toString()) ?? 0,
                ngoaiGioKhac: 0,
                ngoaiGiox15: 0,
                ngoaiGiox2: 0,
                hoTro: 0,
                partTime: int.tryParse(partTime.toString()) ?? 0,
                partTimeSang: 0,
                partTimeChieu: 0,
                congLe: 0,
              );
              await dbHelper.insertChamCongCN(chamCongModel);
              addedCount++;
              debugLog('Created new record for $empId in $dept');
              
              // Add to in-memory data
              if (_allProjectsData.containsKey(dept)) {
                _allProjectsData[dept]!.add(newRecord);
              } else {
                _allProjectsData[dept] = [newRecord];
              }
            }
          } catch (e) {
            debugLog('Error creating record for $empId: $e');
          }
        }
      }
    }
    
    // Refresh data
    await _loadAllProjectsData();
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        'Đã sao chép từ hôm qua: ${addedCount + updatedCount} nhân viên '
        '(thêm mới: $addedCount, cập nhật: $updatedCount). '
        'Vui lòng kiểm tra lại thông tin trước khi lưu.')
      )
    );
    
  } catch (e) {
    setState(() => _isLoading = false);
    debugLog('Error copying from yesterday: $e');
    _showError('Không thể sao chép dữ liệu từ hôm qua: ${e.toString()}');
  }
}
  Future<void> _loadAllProjectsData() async {
  if (_selectedMonth == null || _departments.isEmpty) return;
  
  setState(() {
    _modifiedRecords.clear();
    _newRecords.clear();
  });
  
  final dbHelper = DBHelper();
  Map<String, List<Map<String, dynamic>>> allData = {};
  Map<String, Map<String, String>> allStaffNames = {};
  
  // Get the three most recent days
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dayBeforeYesterday = today.subtract(const Duration(days: 2));
  
  // Format dates for SQL query
  final todayStr = DateFormat('yyyy-MM-dd').format(today);
  final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
  final dayBeforeYesterdayStr = DateFormat('yyyy-MM-dd').format(dayBeforeYesterday);
  
  debugLog('Loading data for dates: $todayStr, $yesterdayStr, $dayBeforeYesterdayStr');
  
  // Check if all three dates are in the selected month
  final List<String> datesToQuery = [];
  if (_selectedMonth == DateFormat('yyyy-MM').format(today)) {
    datesToQuery.add(todayStr);
  }
  if (_selectedMonth == DateFormat('yyyy-MM').format(yesterday)) {
    datesToQuery.add(yesterdayStr);
  }
  if (_selectedMonth == DateFormat('yyyy-MM').format(dayBeforeYesterday)) {
    datesToQuery.add(dayBeforeYesterdayStr);
  }
  
  // If no dates match the selected month, load all data for that month
  if (datesToQuery.isEmpty) {
    debugLog('No recent dates match the selected month, loading entire month data');
    
    for (String dept in _departments) {
      try {
        // Get all data for this department in the selected month
        final data = await dbHelper.rawQuery('''
          SELECT * FROM chamcongcn 
          WHERE BoPhan = ? AND strftime('%Y-%m', Ngay) = ?
          ORDER BY MaNV, Ngay DESC
        ''', [dept, _selectedMonth]);
        
        if (data.isNotEmpty) {
          allData[dept] = List<Map<String, dynamic>>.from(data.map((record) => {
            'UID': record['UID'] ?? '',
            'Ngay': record['Ngay'] ?? '',
            'Gio': record['Gio'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
            'NguoiDung': record['NguoiDung'] ?? _username,
            'BoPhan': record['BoPhan'] ?? dept,
            'MaBP': record['MaBP'] ?? dept,
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
        }
      } catch (e) {
        debugLog('Error loading data for $dept: $e');
      }
    }
  } else {
    // Build query for specific dates
    final placeholders = List.filled(datesToQuery.length, '?').join(',');
    
    debugLog('Loading data for specific dates: ${datesToQuery.join(", ")}');
    
    for (String dept in _departments) {
      try {
        // Get attendance data for this department - only for the specified dates
        final data = await dbHelper.rawQuery('''
          SELECT * FROM chamcongcn 
          WHERE BoPhan = ? AND date(Ngay) IN ($placeholders)
          ORDER BY MaNV, Ngay DESC
        ''', [dept, ...datesToQuery]);
        
        if (data.isNotEmpty) {
          allData[dept] = List<Map<String, dynamic>>.from(data.map((record) => {
            'UID': record['UID'] ?? '',
            'Ngay': record['Ngay'] ?? '',
            'Gio': record['Gio'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
            'NguoiDung': record['NguoiDung'] ?? _username,
            'BoPhan': record['BoPhan'] ?? dept,
            'MaBP': record['MaBP'] ?? dept,
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
        }
      } catch (e) {
        debugLog('Error loading data for $dept: $e');
      }
    }
  }
  
  // Load staff names for all departments with data
  for (String dept in allData.keys) {
    final employeeIds = allData[dept]!
        .map((record) => record['MaNV'] as String)
        .toSet()
        .toList();
    
    if (employeeIds.isNotEmpty) {
      final staffNames = await _loadStaffNamesForDept(employeeIds);
      allStaffNames[dept] = staffNames;
    }
  }
  
  setState(() {
    _allProjectsData = allData;
    _staffNamesByDept = allStaffNames;
  });
}
  
  Future<void> _saveChanges() async {
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
    setState(() => _isLoading = true);
    final dbHelper = DBHelper();
    
    // Prepare batch data
    final modifiedList = _modifiedRecords.values.toList();
    final newList = _newRecords.values.toList();
    
    debugLog('Sending batch request with ${modifiedList.length} updates and ${newList.length} additions');
    
    // Use the batch endpoint
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
      final resultString = result.toString();
      debugLog('Batch response: ${resultString.substring(0, resultString.length > 100 ? 100 : resultString.length)}...');
      
      // Process successful updates in local database
      if ((result['updated'] ?? 0) > 0 || (result['added'] ?? 0) > 0) {
        // Start parallel updates for the local database
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
                congThuongChu: record['CongThuongChu'] as String? ?? '',
                ngoaiGioThuong: double.tryParse(record['NgoaiGioThuong']?.toString() ?? '0') ?? 0,
                ngoaiGioKhac: double.tryParse(record['NgoaiGioKhac']?.toString() ?? '0') ?? 0,
                ngoaiGiox15: double.tryParse(record['NgoaiGiox15']?.toString() ?? '0') ?? 0,
                ngoaiGiox2: double.tryParse(record['NgoaiGiox2']?.toString() ?? '0') ?? 0,
                hoTro: int.tryParse(record['HoTro']?.toString() ?? '0') ?? 0,
                partTime: int.tryParse(record['PartTime']?.toString() ?? '0') ?? 0,
                partTimeSang: int.tryParse(record['PartTimeSang']?.toString() ?? '0') ?? 0,
                partTimeChieu: int.tryParse(record['PartTimeChieu']?.toString() ?? '0') ?? 0,
                congLe: double.tryParse(record['CongLe']?.toString() ?? '0') ?? 0,
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
      await _loadAllProjectsData();
      
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
        await _saveChangesIndividually();
      }
    }
  } finally {
    setState(() => _isLoading = false);
  }
}

// Add this method as a fallback for individual record saving
Future<void> _saveChangesIndividually() async {
  try {
    setState(() => _isLoading = true);
    final dbHelper = DBHelper();
    
    // Process modified records
    for (var entry in _modifiedRecords.entries) {
      final uid = entry.key;
      final record = entry.value;
      
      // Create a clean updates object with explicit type conversion
      final updates = {
        'Ngay': record['Ngay'],
        'Gio': record['Gio'],
        'NguoiDung': record['NguoiDung'],
        'BoPhan': record['BoPhan'],
        'MaBP': record['MaBP'],
        'PhanLoai': record['PhanLoai'],
        'MaNV': record['MaNV'],
        'CongThuongChu': record['CongThuongChu'] ?? '',
        'NgoaiGioThuong': record['NgoaiGioThuong'] ?? '0',
        'NgoaiGioKhac': record['NgoaiGioKhac'] ?? '0',
        'NgoaiGiox15': record['NgoaiGiox15'] ?? '0',
        'NgoaiGiox2': record['NgoaiGiox2'] ?? '0',
        'HoTro': record['HoTro'] ?? '0',
        'PartTime': record['PartTime'] ?? '0',
        'PartTimeSang': record['PartTimeSang'] ?? '0',
        'PartTimeChieu': record['PartTimeChieu'] ?? '0',
        'CongLe': record['CongLe'] ?? '0',
      };
      
      debugLog('Saving record with UID: $uid (individual)');
      
      final jsonData = json.encode(updates);
      
      final response = await http.put(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongsua/$uid'),
        headers: {'Content-Type': 'application/json'},
        body: jsonData
      ).timeout(const Duration(seconds: 300));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update record: ${response.body}');
      }

      // Update local database with the same data we sent to server
      await dbHelper.updateChamCongCN(uid, updates);
    }

    // Process new records if there are any
    for (var entry in _newRecords.entries) {
      final uid = entry.key;
      final record = entry.value;
      
      // Add to database if not already there
      final existingRecord = await dbHelper.rawQuery(
        'SELECT * FROM chamcongcn WHERE UID = ?', [uid]
      );
      
      if (existingRecord.isEmpty) {
        // Send to server first
        final response = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggui'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(record)
        ).timeout(const Duration(seconds: 300));
        
        if (response.statusCode != 200) {
          throw Exception('Failed to add new record: ${response.body}');
        }
        
        // Then add to local DB
        final chamCongModel = ChamCongCNModel(
          uid: uid,
          maNV: record['MaNV'] as String,
          ngay: DateTime.parse(record['Ngay'] as String),
          boPhan: record['BoPhan'] as String,
          nguoiDung: record['NguoiDung'] as String,
          congThuongChu: record['CongThuongChu'] as String? ?? '',
          ngoaiGioThuong: double.tryParse(record['NgoaiGioThuong']?.toString() ?? '0') ?? 0,
          ngoaiGioKhac: double.tryParse(record['NgoaiGioKhac']?.toString() ?? '0') ?? 0,
          ngoaiGiox15: double.tryParse(record['NgoaiGiox15']?.toString() ?? '0') ?? 0,
          ngoaiGiox2: double.tryParse(record['NgoaiGiox2']?.toString() ?? '0') ?? 0,
          hoTro: int.tryParse(record['HoTro']?.toString() ?? '0') ?? 0,
          partTime: int.tryParse(record['PartTime']?.toString() ?? '0') ?? 0,
          partTimeSang: int.tryParse(record['PartTimeSang']?.toString() ?? '0') ?? 0,
          partTimeChieu: int.tryParse(record['PartTimeChieu']?.toString() ?? '0') ?? 0,
          congLe: double.tryParse(record['CongLe']?.toString() ?? '0') ?? 0,
        );
        await dbHelper.insertChamCongCN(chamCongModel);
      }
    }

    setState(() {
      _modifiedRecords.clear();
      _newRecords.clear();
    });

    await _loadAllProjectsData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thay đổi thành công (cách thủ công)'))
      );
    }

  } catch (e) {
    debugLog('Error in individual save: $e');
    _showError('Lỗi khi lưu dữ liệu từng bản ghi: ${e.toString()}');
  } finally {
    setState(() => _isLoading = false);
  }
}
  
  Future<Map<String, String>> _loadStaffNamesForDept(List<String> employeeIds) async {
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

    return staffNames;
  }
  
  List<int> _getDaysInMonth() {
  if (_selectedMonth == null) return [];
  
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dayBeforeYesterday = today.subtract(const Duration(days: 2));
  
  final parts = _selectedMonth!.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  
  // If current month, only show the three most recent days
  if (_selectedMonth == DateFormat('yyyy-MM').format(today)) {
    final recentDays = <int>[];
    
    // Only add days that are within the current month
    if (today.month == month && today.year == year) {
      recentDays.add(today.day);
    }
    if (yesterday.month == month && yesterday.year == year) {
      recentDays.add(yesterday.day);
    }
    if (dayBeforeYesterday.month == month && dayBeforeYesterday.year == year) {
      recentDays.add(dayBeforeYesterday.day);
    }
    
    // If we have recent days, return them sorted in descending order
    if (recentDays.isNotEmpty) {
      recentDays.sort((a, b) => b.compareTo(a)); // Sort descending
      return recentDays;
    }
  }
  
  // Otherwise, show all days in the selected month
  final daysInMonth = DateTime(year, month + 1, 0).day;
  return List.generate(daysInMonth, (i) => daysInMonth - i); // Latest date first
}

  List<String> _getUniqueEmployeesForDept(String dept) {
    if (!_allProjectsData.containsKey(dept)) return [];
    
    final employees = _allProjectsData[dept]!
      .map((record) => record['MaNV'] as String)
      .toSet()
      .toList()..sort();
    
    return employees;
  }
  
  String? _getAttendanceForDay(String dept, String empId, int day, String columnType) {
    if (!_allProjectsData.containsKey(dept)) return null;
    
    final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
    final record = _allProjectsData[dept]!.firstWhere(
      (record) => 
        record['MaNV'] == empId && 
        record['Ngay'].split('T')[0] == dateStr,
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
  
  void _updateAttendance(String dept, String empId, int day, String columnType, String? value) {
    if (value == null) return;
    
    // Add debug log to track values being set
    debugLog('Updating $columnType for $empId on day $day to "$value" in dept $dept');
      
    // Validate and format based on column type
    String formattedValue;
    switch (columnType) {
      case 'CongThuongChu':
        formattedValue = value;
        break;
      
      // Integer-only fields
      case 'HoTro':
      case 'PartTime':
      case 'PartTimeSang':
      case 'PartTimeChieu':
        int? numValue = int.tryParse(value);
        if (numValue == null) return;
        formattedValue = numValue.toString();
        break;
      
      // Decimal fields
      case 'NgoaiGioThuong':
      case 'NgoaiGioKhac':
      case 'NgoaiGiox15':
      case 'NgoaiGiox2':
      case 'CongLe':
        double? numValue = double.tryParse(value);
        if (numValue == null) return;
        formattedValue = numValue.toString();
        break;
      
      default:
        return; // Unknown column type
    }

    final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';

    // Find or create record
    var record = _allProjectsData[dept]!.firstWhere(
      (r) => r['MaNV'] == empId && r['Ngay'].split('T')[0] == dateStr,
      orElse: () {
        final newUid = Uuid().v4();
        final newRecord = {
          'UID': newUid,
          'MaNV': empId,
          'Ngay': dateStr,
          'Gio': DateFormat('HH:mm:ss').format(DateTime.now()),
          'NguoiDung': _username,
          'BoPhan': dept,
          'MaBP': dept,
          'PhanLoai': '',
          'CongThuongChu': columnType == 'CongThuongChu' ? formattedValue : '',
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
        _allProjectsData[dept]!.add(newRecord);
        debugLog('Created new record for $empId on $dateStr with UID: $newUid');
        return newRecord;
      }
    );

    // Check if value actually changed to avoid unnecessary updates
    if (record[columnType]?.toString() != formattedValue) {
      setState(() {
        record[columnType] = formattedValue;
        final uid = record['UID'] as String;
        
        // Add to modified records if it's not a new record
        if (!_newRecords.containsKey(uid)) {
          _modifiedRecords[uid] = Map<String, dynamic>.from(record);
          debugLog('Added to modified records - UID: $uid, $columnType: $formattedValue');
        } else {
          // Update the new record if it already exists
          _newRecords[uid]![columnType] = formattedValue;
          debugLog('Updated new record - UID: $uid, $columnType: $formattedValue');
        }
      });
    }
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), 
        backgroundColor: Colors.red
      ));
    }
  }
  
  void debugLog(String message) {
  print(message);
  setState(() {
    _debugLogs.add("${DateTime.now().toString().substring(11, 19)}: $message");
    if (_debugLogs.length > 20) {
      _debugLogs.removeAt(0);
    }
  });
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Text('Tất cả dự án'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: DropdownButton<String>(
                value: _selectedMonth,
                items: _availableMonths.map((month) => DropdownMenuItem(
                  value: month,
                  child: Text(DateFormat('MM/yyyy').format(DateTime.parse('$month-01')))
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMonth = value;
                    _loadAllProjectsData();
                  });
                },
                style: TextStyle(color: Colors.white),
                dropdownColor: Theme.of(context).primaryColor,
                isExpanded: false,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.purple,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (_modifiedRecords.isNotEmpty || _newRecords.isNotEmpty)
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _saveChanges,
            tooltip: 'Lưu thay đổi',
          ),
      ],
    ),
    body: Stack(
      children: [
        _isLoading
          ? Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 8,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Công chữ & NG thường& PT'),
                      Tab(text: 'Hỗ trợ'),
                      //Tab(text: 'Part time'),
                      Tab(text: 'PT sáng'),
                      Tab(text: 'PT chiều'),
                      Tab(text: 'NG khác'),
                      Tab(text: 'NG x1.5'),
                      Tab(text: 'NG x2'),
                      Tab(text: 'Công lễ'),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: _copyFromYesterday,
                          child: Text('💚Như hôm qua'),
                        ),
                        Row(
                          children: [
                            if (_modifiedRecords.isNotEmpty || _newRecords.isNotEmpty)
                              Text(
                                'Có ${_modifiedRecords.length + _newRecords.length} thay đổi chưa lưu',
                                style: TextStyle(color: Colors.red),
                              ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: (_modifiedRecords.isNotEmpty || _newRecords.isNotEmpty) 
                                ? _saveChanges 
                                : null,
                              child: Text('❤️Lưu thay đổi'),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: (_modifiedRecords.isNotEmpty || _newRecords.isNotEmpty) 
                                ? _saveChanges 
                                : null,
                              child: Text('Mọi thắc mắc vui lòng liên hệ NV hỗ trợ'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCombinedTable(),
                        _buildAllProjectsTable('HoTro'),
                        //_buildAllProjectsTable('PartTime'),
                        _buildAllProjectsTable('PartTimeSang'),
                        _buildAllProjectsTable('PartTimeChieu'),
                        _buildAllProjectsTable('NgoaiGioKhac'),
                        _buildAllProjectsTable('NgoaiGiox15'),
                        _buildAllProjectsTable('NgoaiGiox2'),
                        _buildAllProjectsTable('CongLe'),
                      ],
                    ),
                  ),
                ],
              ),
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
      ],
    ),
  );
}
Widget _buildCombinedTable() {
  final days = _getDaysInMonth();
  
  // Only include departments with actual data
  final departmentsWithData = _departments
      .where((dept) => _allProjectsData.containsKey(dept) && _allProjectsData[dept]!.isNotEmpty)
      .toList();
  
  if (departmentsWithData.isEmpty) {
    return Center(child: Text('Không có dữ liệu cho tháng $_selectedMonth'));
  }
  
  return SingleChildScrollView(
    child: Column(
      children: departmentsWithData.map((dept) {
        final employees = _getUniqueEmployeesForDept(dept);
        if (employees.isEmpty) {
          return SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Department header
            Container(
              color: Colors.purple.shade100,
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                dept,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            // Project attendance table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(
                    label: Container(
                      width: 50,
                      child: Text('Mã NV'),
                    )
                  ),
                  DataColumn(
                    label: Container(
                      width: 50,
                      child: Text('Loại', overflow: TextOverflow.ellipsis),
                    )
                  ),
                  ...days.map((day) => DataColumn(label: Text(day.toString()))),
                ],
                rows: employees.expand((empId) {
                  return [
                    // Row for CongThuongChu
                    DataRow(
                      cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(empId, style: TextStyle(color: Colors.black)), 
                              Text(
                                _staffNamesByDept[dept]?[empId] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black, 
                                  fontWeight: FontWeight.bold, 
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text('Công chữ', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...days.map((day) {
                          final attendance = _getAttendanceForDay(dept, empId, day, 'CongThuongChu') ?? 'Ro';
                          final canEdit = _canEditDay(day);
                          
                          return DataCell(
                            DropdownButton<String>(
                              value: _congThuongChoices.contains(_extractCongThuongChuBase(attendance)) 
                                ? _extractCongThuongChuBase(attendance) 
                                : 'Ro',
                              items: _congThuongChoices.map((choice) =>
                                DropdownMenuItem(value: choice, child: Text(choice))
                              ).toList(),
                              onChanged: canEdit ? (value) {
                                if (value != null) {
                                  final phanLoaiValue = _calculatePhanLoaiFromCongThuong(value);
                                  _updateAttendanceWithPhanLoai(dept, empId, day, 'CongThuongChu', value, phanLoaiValue);
                                }
                              } : null,
                            ),
                          );
                        }),
                      ],
                    ),
                    // Row for NgoaiGioThuong
                    DataRow(
                      color: MaterialStateProperty.all(Colors.grey.shade100),
                      cells: [
                        DataCell(Text('')), // Empty for employee name
                        DataCell(Text('NG thường', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...days.map((day) {
                          final attendance = _getAttendanceForDay(dept, empId, day, 'NgoaiGioThuong') ?? '0';
                          final canEdit = _canEditDay(day);
                          
                          return DataCell(
                            SizedBox(
                              width: 50,
                              child: TextFormField(
                                initialValue: attendance,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.right,
                                enabled: canEdit,
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    _updateAttendance(dept, empId, day, 'NgoaiGioThuong', '0');
                                    return;
                                  }
                                  
                                  // Decimal fields - allow digits and one decimal point
                                  value = value.replaceAll(RegExp(r'[^\d.]'), '');
                                  // Ensure only one decimal point
                                  final parts = value.split('.');
                                  if (parts.length > 2) {
                                    value = parts[0] + '.' + parts.sublist(1).join('');
                                  }
                                  
                                  _updateAttendance(dept, empId, day, 'NgoaiGioThuong', value);
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
                    ),
                    // Add Part Time Row
                    DataRow(
                      color: MaterialStateProperty.all(Colors.grey.shade50),
                      cells: [
                        DataCell(Text('')), // Empty for employee name
                        DataCell(Text('Part time', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...days.map((day) {
                          final attendance = _getAttendanceForDay(dept, empId, day, 'PartTime') ?? '0';
                          final canEdit = _canEditDay(day);
                          
                          return DataCell(
                            SizedBox(
                              width: 50,
                              child: TextFormField(
                                initialValue: attendance,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                enabled: canEdit,
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    _updateAttendance(dept, empId, day, 'PartTime', '0');
                                    return;
                                  }
                                  
                                  // Integer-only fields - remove non-digits
                                  value = value.replaceAll(RegExp(r'[^\d]'), '');
                                  
                                  _updateAttendance(dept, empId, day, 'PartTime', value);
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
                    ),
                  ];
                }).toList(),
              ),
            ),
            // Divider between projects
            Divider(thickness: 2, height: 32),
          ],
        );
      }).toList(),
    ),
  );
}
String _extractCongThuongChuBase(String value) {
  if (value.endsWith('+P')) {
    return value.substring(0, value.length - 2);
  } else if (value.endsWith('+P/2')) {
    return value.substring(0, value.length - 4);
  }
  return value;
}

String _calculatePhanLoaiFromCongThuong(String congThuongChu) {
  bool hasPlusP = congThuongChu.endsWith('+P');
  bool hasPlusPHalf = congThuongChu.endsWith('+P/2');
  String baseValue = _extractCongThuongChuBase(congThuongChu);
  
  String phanLoaiValue = '0.0';
  
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
  }
  
  // Adjust for +P and +P/2 suffixes
  if (hasPlusP || hasPlusPHalf) {
    double phanLoaiDouble = double.tryParse(phanLoaiValue) ?? 0.0;
    if (hasPlusP) {
      phanLoaiDouble += 1.0;
    } else if (hasPlusPHalf) {
      phanLoaiDouble += 0.5;
    }
    phanLoaiValue = phanLoaiDouble.toStringAsFixed(1);
  }
  
  return phanLoaiValue;
}
void _updateAttendanceWithPhanLoai(String dept, String empId, int day, String columnType, String value, String phanLoaiValue) {
  debugLog('Updating $columnType for $empId on day $day to "$value" with PhanLoai: $phanLoaiValue in dept $dept');
  
  final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';

  // Find or create record
  var record = _allProjectsData[dept]!.firstWhere(
    (r) => r['MaNV'] == empId && r['Ngay'].split('T')[0] == dateStr,
    orElse: () {
      final newUid = Uuid().v4();
      final newRecord = {
        'UID': newUid,
        'MaNV': empId,
        'Ngay': dateStr,
        'Gio': DateFormat('HH:mm:ss').format(DateTime.now()),
        'NguoiDung': _username,
        'BoPhan': dept,
        'MaBP': dept,
        'PhanLoai': phanLoaiValue,
        'CongThuongChu': columnType == 'CongThuongChu' ? value : '',
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
      _allProjectsData[dept]!.add(newRecord);
      debugLog('Created new record for $empId on $dateStr with UID: $newUid and PhanLoai: $phanLoaiValue');
      return newRecord;
    }
  );

  // Check if value actually changed to avoid unnecessary updates
  if (record[columnType]?.toString() != value || record['PhanLoai']?.toString() != phanLoaiValue) {
    setState(() {
      record[columnType] = value;
      record['PhanLoai'] = phanLoaiValue;
      
      final uid = record['UID'] as String;
      
      // Add to modified records if it's not a new record
      if (!_newRecords.containsKey(uid)) {
        _modifiedRecords[uid] = Map<String, dynamic>.from(record);
        debugLog('Added to modified records - UID: $uid, $columnType: $value, PhanLoai: $phanLoaiValue');
      } else {
        // Update the new record if it already exists
        _newRecords[uid]![columnType] = value;
        _newRecords[uid]!['PhanLoai'] = phanLoaiValue;
        debugLog('Updated new record - UID: $uid, $columnType: $value, PhanLoai: $phanLoaiValue');
      }
    });
  }
}

  Widget _buildAllProjectsTable(String columnType) {
    final days = _getDaysInMonth();
    
    // Only include departments with actual data
    final departmentsWithData = _departments
        .where((dept) => _allProjectsData.containsKey(dept) && _allProjectsData[dept]!.isNotEmpty)
        .toList();
    
    if (departmentsWithData.isEmpty) {
      return Center(child: Text('Không có dữ liệu cho tháng $_selectedMonth'));
    }
    
    return SingleChildScrollView(
      child: Column(
        children: departmentsWithData.map((dept) {
          final employees = _getUniqueEmployeesForDept(dept);
          if (employees.isEmpty) {
            return SizedBox.shrink();
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Department header
              Container(
                color: Colors.purple.shade100,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  dept,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              // Project attendance table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Mã NV')),
                    ...days.map((day) => DataColumn(label: Text(day.toString()))),
                  ],
                  rows: employees.map((empId) {
                    return DataRow(
                      cells: [
                        DataCell(
  Container(
    width: 50,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          empId, 
          style: TextStyle(color: Colors.black),
          overflow: TextOverflow.ellipsis,
        ), 
        Text(
          _staffNamesByDept[dept]?[empId] ?? '',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black, 
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  ),
),
                        ...days.map((day) {
                          final attendance = _getAttendanceForDay(dept, empId, day, columnType) ?? 
                            (columnType == 'CongThuongChu' ? 'Ro' : '0');
                          final canEdit = _canEditDay(day);
                          
                          return DataCell(
                            columnType == 'CongThuongChu'
                              ? DropdownButton<String>(
                                  value: attendance,
                                  items: _congThuongChoices.map((choice) =>
                                    DropdownMenuItem(value: choice, child: Text(choice))
                                  ).toList(),
                                  onChanged: canEdit ? (value) {
                                    if (value != null) {
                                      _updateAttendance(dept, empId, day, columnType, value);
                                    }
                                  } : null,
                                )
                              : SizedBox(
                                  width:50,
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
                                        _updateAttendance(dept, empId, day, columnType, '0');
                                        return;
                                      }
                                      
                                      // Handle input validation based on column type
                                      if (columnType == 'HoTro' || 
                                          columnType == 'PartTime' || 
                                          columnType == 'PartTimeSang' || 
                                          columnType == 'PartTimeChieu') {
                                        // Integer-only fields - remove non-digits
                                        value = value.replaceAll(RegExp(r'[^\d]'), '');
                                      } else {
                                        // Decimal fields - allow digits and one decimal point
                                        value = value.replaceAll(RegExp(r'[^\d.]'), '');
                                        // Ensure only one decimal point
                                        final parts = value.split('.');
                                        if (parts.length > 2) {
                                          value = parts[0] + '.' + parts.sublist(1).join('');
                                        }
                                      }
                                      
                                      _updateAttendance(dept, empId, day, columnType, value);
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
              // Divider between projects
              Divider(thickness: 2, height: 32),
            ],
          );
        }).toList(),
      ),
    );
  }
}