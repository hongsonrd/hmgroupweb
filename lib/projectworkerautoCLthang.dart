import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'dart:core';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'http_client.dart';

class ProjectWorkerAutoCLThang extends StatefulWidget {
  final String selectedBoPhan;
  final String username;
  final String selectedMonth;
  
  const ProjectWorkerAutoCLThang({
    Key? key, 
    required this.selectedBoPhan,
    required this.username,
    required this.selectedMonth,
  }) : super(key: key);
  
  @override
  _ProjectWorkerAutoCLThangState createState() => _ProjectWorkerAutoCLThangState();
}

class _ProjectWorkerAutoCLThangState extends State<ProjectWorkerAutoCLThang> {
  bool _isLoading = false;
  List<String> _departments = [];
  String? _selectedDepartment;
  String? _selectedMonth;
  List<String> _availableMonths = [];
  List<Map<String, dynamic>> _monthlyData = [];
  bool _isEditingAllowed = false;
  final Map<String, TextEditingController> _controllers = {};
  Map<String, bool> _modifiedRows = {};
  Map<String, DateTime> _lastEditTimes = {};
final _editableGroupFields = ['CongChuanToiDa', 'MucLuongThang', 'MucLuongNgoaiGio', 'MucLuongNgoaiGio2'];
bool _isBatchUpdating = false;
  // Define editable fields
  final List<String> _editableFields = [
    'GhiChu', 'CongChuanToiDa',
    'UngLan1', 'UngLan2', 'ThanhToan3', 'TruyLinh', 
    'TruyThu', 'Khac', 'MucLuongThang', 'MucLuongNgoaiGio', 'MucLuongNgoaiGio2'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDepartment = widget.selectedBoPhan;
    _selectedMonth = widget.selectedMonth;
    _checkEditingPermission();
    _initializeData();
  }

  void _checkEditingPermission() {
    if (_selectedMonth == null) return;
    
    try {
      // Parse the selected month
      final selectedMonthDate = DateTime.parse('${_selectedMonth!}-01');
      
      // Calculate the next month date
      final nextMonth = DateTime(
        selectedMonthDate.month == 12 ? selectedMonthDate.year + 1 : selectedMonthDate.year,
        selectedMonthDate.month == 12 ? 1 : selectedMonthDate.month + 1,
        1
      );
      
      // Calculate the cutoff date (8th day of next month)
      final cutoffDate = DateTime(nextMonth.year, nextMonth.month, 8);
      
      // Check if current date is before or on the cutoff date
      _isEditingAllowed = DateTime.now().isBefore(cutoffDate) || 
                         DateTime.now().isAtSameMomentAs(cutoffDate);
    } catch (e) {
      print('Error checking editing permission: $e');
      _isEditingAllowed = false;
    }
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final dbHelper = DBHelper();
      
      // Load all departments
      try {
        final response = await AuthenticatedHttpClient.get(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/${widget.username}'),
          headers: {'Content-Type': 'application/json'},
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> apiDepts = json.decode(response.body);
          setState(() {
            _departments = apiDepts.map((e) => e.toString()).toList();
          });
        }
      } catch (e) {
        print('Project API error: $e');
      }

      // Add departments from the database
      final existingDepts = await dbHelper.rawQuery(
        'SELECT DISTINCT BoPhan FROM ChamCongCNThang ORDER BY BoPhan'
      );
      _departments.addAll(existingDepts.map((e) => e['BoPhan'] as String));
      _departments = _departments.toSet().toList()..sort();
      
      // Add "All" option at the beginning
      if (!_departments.contains('Tất cả')) {
        _departments.insert(0, 'Tất cả');
      }
      
      // Get available months from ChamCongCNThang
      final months = await dbHelper.rawQuery(
        "SELECT DISTINCT substr(GiaiDoan, 1, 7) as month FROM ChamCongCNThang ORDER BY month DESC"
      );
      _availableMonths = months.map((e) => e['month'] as String).toList();
      
      String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      if (!_availableMonths.contains(currentMonth)) {
        _availableMonths.insert(0, currentMonth);
      }
      
      if (_selectedMonth == null || !_availableMonths.contains(_selectedMonth)) {
        _selectedMonth = _availableMonths.first;
      }
      
      await _loadMonthlyData();
      
    } catch (e) {
      print('Init error: $e');
      _showError('Không thể tải dữ liệu');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMonthlyData() async {
    if (_selectedMonth == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final dbHelper = DBHelper();
      
      String query;
      List<dynamic> args;
      
      if (_selectedDepartment == 'Tất cả') {
        // Query for all departments
        query = '''
          SELECT * FROM ChamCongCNThang 
          WHERE GiaiDoan LIKE ? 
          ORDER BY BoPhan, MaNV
        ''';
        args = ['${_selectedMonth}%'];
      } else {
        // Query for specific department
        query = '''
          SELECT * FROM ChamCongCNThang 
          WHERE GiaiDoan LIKE ? AND BoPhan = ? 
          ORDER BY MaNV
        ''';
        args = ['${_selectedMonth}%', _selectedDepartment];
      }
      
      final data = await dbHelper.rawQuery(query, args);
      
      // Clear old controllers
      _controllers.forEach((_, controller) => controller.dispose());
      _controllers.clear();
      _modifiedRows.clear();
      
      // Set up text controllers for each editable field
      for (var row in data) {
  for (var field in _editableFields) {
    String key = '${row['UID']}_$field';
    _controllers[key] = TextEditingController(
      text: row[field]?.toString() ?? ''
    );
    
    // Add listener to detect changes
    _controllers[key]!.addListener(() {
      setState(() {
        _modifiedRows[row['UID'].toString()] = true;
      });
      
      // If this is a group field, check if we should show the popup
      if (_editableGroupFields.contains(field) && !_isBatchUpdating) {
        // Track edit time to prevent multiple popups
        final now = DateTime.now();
        if (_lastEditTimes[key] == null || 
            now.difference(_lastEditTimes[key]!).inSeconds >= 2) {
          _lastEditTimes[key] = now;
          
          // Use Future.delayed to wait for user to finish typing
          Future.delayed(Duration(milliseconds: 1000), () {
            // Only show popup if this was the last edit
            if (_lastEditTimes[key] != null && 
                now.isAtSameMomentAs(_lastEditTimes[key]!)) {
              _showApplyToAllPopup(row, field, _controllers[key]!.text);
            }
          });
        }
      }
    });
  }
}
      
      setState(() {
        _monthlyData = List<Map<String, dynamic>>.from(data);
        _checkEditingPermission();
      });
      
    } catch (e) {
      print('Error loading monthly data: $e');
      _showError('Không thể tải dữ liệu tháng');
    }
    
    setState(() => _isLoading = false);
  }
Future<void> _showApplyToAllPopup(Map<String, dynamic> row, String field, String value) async {
  // Skip if empty value or not a valid number
  if (value.isEmpty) return;
  
  double? numValue;
  try {
    numValue = double.parse(value);
  } catch (e) {
    return; // Not a valid number
  }
  
  final boPhan = row['BoPhan'];
  final fieldName = {
    'CongChuanToiDa': 'Công chuẩn tối đa',
    'MucLuongThang': 'Mức lương tháng',
    'MucLuongNgoaiGio': 'Mức lương ngoài giờ',
    'MucLuongNgoaiGio2': 'Mức lương ngoài giờ 2'
  }[field] ?? field;
  
  final bool? result = await showDialog<bool>(
    context: context, 
    builder: (context) => AlertDialog(
      title: Text('Áp dụng cho tất cả'),
      content: Text('Bạn có muốn áp dụng giá trị "$value" cho trường "$fieldName" của tất cả nhân viên thuộc bộ phận "$boPhan" không?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Không'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Có'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
            backgroundColor: Colors.blue.withOpacity(0.1),
          ),
        ),
      ],
    ),
  );
  
  if (result == true) {
    // User confirmed, apply to all records with same BoPhan
    await _applyValueToAllInBoPhan(boPhan, field, numValue);
  }
}
Future<void> _applyValueToAllInBoPhan(String boPhan, String field, double value) async {
  setState(() {
    _isLoading = true;
    _isBatchUpdating = true;
  });
  
  try {
    for (var record in _monthlyData) {
      if (record['BoPhan'] == boPhan) {
        final recordId = record['UID'].toString();
        final controllerKey = '${recordId}_$field';
        
        if (_controllers.containsKey(controllerKey)) {
          _controllers[controllerKey]!.text = value.toString();
          _modifiedRows[recordId] = true;
        }
      }
    }
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã áp dụng giá trị cho tất cả nhân viên thuộc bộ phận "$boPhan"'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('Error applying value to all: $e');
    _showError('Lỗi khi áp dụng giá trị: $e');
  } finally {
    setState(() {
      _isLoading = false;
      _isBatchUpdating = false;
    });
  }
}
  Future<void> _saveData() async {
  if (!_isEditingAllowed) {
    _showError('Không thể chỉnh sửa dữ liệu sau ngày 8 của tháng tiếp theo');
    return;
  }
  
  setState(() => _isLoading = true);
  
  try {
    // Only update modified rows
    List<Map<String, dynamic>> updatedRows = [];
    
    for (var row in _monthlyData) {
      final rowId = row['UID'].toString();
      
      // Skip if not modified
      if (!_modifiedRows.containsKey(rowId) || !_modifiedRows[rowId]!) {
        continue;
      }
      
      // Create update object with UID
      Map<String, dynamic> updates = {'UID': rowId};
      
      // Add all editable fields to update object
      for (var field in _editableFields) {
        String key = '${rowId}_$field';
        if (_controllers.containsKey(key)) {
          var value = _controllers[key]!.text;
          
          // For numeric fields, ensure we have a valid number
          if (field != 'GhiChu') {
            try {
              updates[field] = double.parse(value);
            } catch (e) {
              updates[field] = 0;
            }
          } else {
            updates[field] = value;
          }
        }
      }
      
      // Add additional required fields from the original row
      updates['MaNV'] = row['MaNV'];
      updates['BoPhan'] = row['BoPhan'];
      
      // Only add if we have changes
      if (updates.length > 1) { // More than just UID
        updatedRows.add(updates);
      }
    }
    
    if (updatedRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không có dữ liệu nào thay đổi'), backgroundColor: Colors.blue)
      );
      setState(() => _isLoading = false);
      return;
    }
    
    // Convert to JSON string
    final jsonBody = json.encode(updatedRows);
    print('Sending updated rows: $jsonBody');
    
    // Use standard http post with proper Content-Type
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcnthangsua'),
      headers: {
        'Content-Type': 'application/json',
        // Add any authentication headers if needed
      },
      body: jsonBody,
    );
    
    print('Server response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200) {
      // Success - update local DB
      final dbHelper = DBHelper();
      final currentDate = DateTime.now().toIso8601String().split('T')[0];
      
      for (var update in updatedRows) {
        String uid = update['UID'];
        Map<String, dynamic> values = Map.from(update);
        values.remove('UID'); // Remove UID from values for update
        
        // Set NgayCapNhat to today's date in local DB
        values['NgayCapNhat'] = currentDate;
        
        await dbHelper.update(
          'ChamCongCNThang',
          values,
          where: 'UID = ?',
          whereArgs: [uid],
        );
      }
      
      // Clear modified flags
      _modifiedRows.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu dữ liệu thành công'), backgroundColor: Colors.green)
      );
      
      // Reload data to show updated values
      await _loadMonthlyData();
    } else {
      _showError('Lỗi khi cập nhật dữ liệu: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Error saving data: $e');
    _showError('Lỗi khi lưu dữ liệu: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
// Add this method to your _ProjectWorkerAutoCLThangState class
Future<void> _deleteSelectedRecords(List<Map<String, dynamic>> records) async {
  if (!_isEditingAllowed) {
    _showError('Không thể xóa dữ liệu sau ngày 8 của tháng tiếp theo');
    return;
  }
  
  // Confirm deletion
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa ${records.length} bản ghi đã chọn?\n'
          'Hành động này không thể hoàn tác.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Xóa'),
          ),
        ],
      );
    },
  );
  
  if (confirm != true) return;
  
  setState(() => _isLoading = true);
  
  try {
    // Extract UIDs from selected records
    final List<String> uids = records.map((r) => r['UID'].toString()).toList();
    
    // Prepare request payload
    final payload = {
      'uids': uids,
      'username': widget.username,
    };
    
    // Send delete request to API
    final response = await http.delete(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcnthangxoa'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    
    if (response.statusCode == 200) {
      // Delete from local database
      final dbHelper = DBHelper();
      
      for (var uid in uids) {
        await dbHelper.delete(
          'ChamCongCNThang',
          where: 'UID = ?',
          whereArgs: [uid],
        );
      }
      
      // Reload data
      await _loadMonthlyData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa ${records.length} bản ghi'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showError('Lỗi khi xóa dữ liệu: ${response.statusCode}');
    }
  } catch (e) {
    print('Error deleting data: $e');
    _showError('Lỗi khi xóa dữ liệu: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
  Future<void> _createAutoData() async {
  if (!_isEditingAllowed) {
    _showError('Không thể tạo dữ liệu sau ngày 8 của tháng tiếp theo');
    return;
  }
  
  final bool? proceed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Tạo dữ liệu tự động'),
        content: Text(
          'Chức năng này sẽ tạo và cập nhật dữ liệu tổng hợp tháng dựa trên dữ liệu chấm công. Tiếp tục?\n⚠️ 1. Phần này sẽ chạy lại cho tất cả\n ⚠️ 2. Đảm bảo đã đồng bộ hết dữ liệu chấm công, nhân viên trước khi bắt đầu \n⚠️ 3. Chỉ chạy được cho tháng hiện tại cho tới trước ngày 8 tháng kế tiếp'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Tiếp tục'),
          ),
        ],
      );
    },
  );
  
  if (proceed != true) return;
  
  setState(() => _isLoading = true);
  
  try {
    final dbHelper = DBHelper();
    final db = await dbHelper.database;
    
    if (_selectedMonth == null) {
      _showError('Vui lòng chọn tháng');
      setState(() => _isLoading = false);
      return;
    }
    
    // 1. Parse the month information
    final parts = _selectedMonth!.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    
    // First date of the month
    final firstDateOfMonth = DateTime(year, month, 1);
    final giaiDoan = DateFormat('yyyy-MM-dd').format(firstDateOfMonth);
    
    // Last date of the month
    final lastDateOfMonth = DateTime(year, month + 1, 0);
    final daysInMonth = lastDateOfMonth.day;
    
    // 2. Calculate standard workdays (exclude Sundays)
    int congChuanToiDa = daysInMonth;
    // Subtract Sundays
    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(year, month, day);
      if (currentDate.weekday == DateTime.sunday) {
        congChuanToiDa--;
      }
    }
    
    // Get the current date for NgayCapNhat
    final ngayCapNhat = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // 3. Get all ChamCongCN records for this month
    final startDateStr = DateFormat('yyyy-MM-dd').format(DateTime(year, month, 1));
    final endDateStr = DateFormat('yyyy-MM-dd').format(DateTime(year, month, daysInMonth));
    
    final chamCongCNRecordsQuery = await dbHelper.rawQuery(
      "SELECT * FROM chamcongcn WHERE Ngay BETWEEN ? AND ? ORDER BY MaNV, Ngay",
      [startDateStr, endDateStr]
    );
    
    // Convert query result to list of maps
    final List<Map<String, dynamic>> chamCongCNRecords = List<Map<String, dynamic>>.from(chamCongCNRecordsQuery);
    
    // 4. Group records by MaNV and BoPhan
Map<String, Map<String, List<Map<String, dynamic>>>> groupedRecords = {};

for (var record in chamCongCNRecords) {
  final maNV = record['MaNV'] as String?;
  final boPhan = record['BoPhan'] as String?;
  
  // Skip if missing key data
  if ((maNV?.isEmpty ?? true) || (boPhan?.isEmpty ?? true)) continue;
  
  // Initialize nested maps if needed
  if (!groupedRecords.containsKey(maNV)) {
    groupedRecords[maNV!] = {};
  }
  
  if (!groupedRecords[maNV]!.containsKey(boPhan)) {
    groupedRecords[maNV]![boPhan!] = [];
  } else {
    // Force unwrap boPhan since we already know it exists in the map
    groupedRecords[maNV]![boPhan!]!.add(record);
    continue;
  }
  
  // This line only runs if we just created the list
  groupedRecords[maNV]![boPhan]!.add(record);
}
    
    // 5. Get existing ChamCongCNThang records for this month
    final existingRecordsQuery = await dbHelper.rawQuery(
  "SELECT * FROM ChamCongCNThang WHERE GiaiDoan LIKE ?",
  ['$_selectedMonth%']
);
    
    final existingRecords = List<Map<String, dynamic>>.from(existingRecordsQuery);
    
    // Create a map of existing records for faster lookup
    Map<String, Map<String, Map<String, dynamic>>> existingRecordsMap = {};
    
    for (var record in existingRecords) {
      final maNV = record['MaNV'] as String;
      final boPhan = record['BoPhan'] as String;
      
      if (!existingRecordsMap.containsKey(maNV)) {
        existingRecordsMap[maNV] = {};
      }
      
      existingRecordsMap[maNV]![boPhan] = record;
    }
    
    // Department filter if specific department is selected
    List<String> departments = [];
    if (_selectedDepartment != null && _selectedDepartment != 'Tất cả') {
      departments = [_selectedDepartment!];
    } else {
      // Get all unique departments from ChamCongCN records
      for (var staffMap in groupedRecords.values) {
        departments.addAll(staffMap.keys);
      }
      departments = departments.toSet().toList();
    }
    
    // 6. Process each employee and department combination
    List<Map<String, dynamic>> recordsToInsert = [];
    List<Map<String, dynamic>> recordsToUpdate = [];
    List<String> recordsToDelete = [];
    
    for (var maNV in groupedRecords.keys) {
      for (var boPhan in departments) {
        // Skip if this employee doesn't have records for this department
        if (!groupedRecords[maNV]!.containsKey(boPhan)) continue;
        
        final departmentRecords = groupedRecords[maNV]![boPhan]!;
        
        // Calculate values for this employee and department
        double tuan1va2 = 0;
        double phep1va2 = 0;
        double ht1va2 = 0;
        
        double tuan3va4 = 0;
        double phep3va4 = 0;
        double ht3va4 = 0;
        
        double tuan5plus = 0;
        double phep5plus = 0;
        double ht5plus = 0;
        
        double tongCong = 0;
        double tongPhep = 0;
        double tongLe = 0;
        double tongNgoaiGio = 0;
        double tongHV = 0;
        double tongDem = 0;
        double tongCD = 0;
        double tongHT = 0;
        
        for (var record in departmentRecords) {
  final recordDateStr = record['Ngay'] as String;
  final recordDate = DateTime.parse(recordDateStr.split('T')[0]);
  final day = recordDate.day;
  
  // Extract values
  final congThuongChu = record['CongThuongChu'] as String? ?? 'Ro';
  double phanLoaiValue = 0;
  try {
    final phanLoai = record['PhanLoai'] as String? ?? '0';
    phanLoaiValue = double.tryParse(phanLoai) ?? 0;
  } catch (e) {
    // Ignore parsing errors
  }
  
  // Calculate Phep values
  double phepValue = 0;
  if (congThuongChu.startsWith('P') && !congThuongChu.startsWith('P/2')) {
    phepValue += 1.0;
  } else if (congThuongChu.startsWith('P/2')) {
    phepValue += 0.5;
  }
  
  // Check for +P or +P/2 suffix
  if (congThuongChu.endsWith('+P')) {
    phepValue += 1.0;
  } else if (congThuongChu.endsWith('+P/2')) {
    phepValue += 0.5;
  }
          
          // Check for HT value
          double htValue = 0;
          if (congThuongChu == 'HT') {
            htValue = 1.0;
          }
          
          // Calculate ngoai gio values
          double ngoaiGioValue = 0;
          try {
            final ngoaiGioThuong = double.tryParse(record['NgoaiGioThuong']?.toString() ?? '0') ?? 0;
            final ngoaiGioKhac = double.tryParse(record['NgoaiGioKhac']?.toString() ?? '0') ?? 0;
            ngoaiGioValue = (ngoaiGioThuong + ngoaiGioKhac) / 8.0;
          } catch (e) {
            // Ignore parsing errors
          }
          
          // Calculate other totals
          double ngoaiGiox15 = 0;
          try {
            ngoaiGiox15 = (double.tryParse(record['NgoaiGiox15']?.toString() ?? '0') ?? 0) / 8.0;
          } catch (e) {
            // Ignore parsing errors
          }
          
          double ngoaiGiox2 = 0;
          try {
            ngoaiGiox2 = (double.tryParse(record['NgoaiGiox2']?.toString() ?? '0') ?? 0) / 8.0;
          } catch (e) {
            // Ignore parsing errors
          }
          
          double congLe = 0;
          try {
            congLe = (double.tryParse(record['CongLe']?.toString() ?? '0') ?? 0) / 8.0;
          } catch (e) {
            // Ignore parsing errors
          }
          
          // Add values to the appropriate period
            if (day <= 15) {
    tuan1va2 += phanLoaiValue + ngoaiGioValue - phep1va2;
    phep1va2 += phepValue;
    ht1va2 += htValue;
  } else if (day <= 25) {
    tuan3va4 += phanLoaiValue + ngoaiGioValue- phep3va4;
    phep3va4 += phepValue;
    ht3va4 += htValue;
  } else {
    tuan5plus += phanLoaiValue + ngoaiGioValue-phep5plus;
    phep5plus += phepValue;
    ht5plus += htValue;
  }
  
  // Add to totals
  tongCong += phanLoaiValue + ngoaiGioValue -tongPhep;
  tongPhep += phepValue;
  tongLe += congLe;
  tongNgoaiGio += ngoaiGioValue;
  tongHT += htValue;
}

        // Get TenNV (employee name) from staffbio
        String tenNV = "";
        final staffResult = await dbHelper.rawQuery(
          "SELECT Ho_ten FROM staffbio WHERE MaNV = ?",
          [maNV]
        );
        
        if (staffResult.isNotEmpty) {
          tenNV = staffResult.first['Ho_ten'] as String;
        }
        
        // Calculate UngLan1 based on tuan1va2 value
        double ungLan1 = 0;
        if (tuan1va2 >= 10 && tuan1va2 < 13) {
          ungLan1 = 1500000;
        } else if (tuan1va2 >= 13) {
          ungLan1 = 1700000;
        }
        
        // Calculate UngLan2 based on total for first 25 days
        double ungLan2 = 0;
if (tuan3va4 < 6) {
  ungLan2 = 0;
} else if (tuan3va4 < 8) {
  ungLan2 = 1600000;
} else {
  ungLan2 = 1800000;
}
        double totalFirst25 = tuan1va2 + tuan3va4;
        // Add your UngLan2 calculation logic here
        
        // Check if this combination already exists in ChamCongCNThang
        bool recordExists = existingRecordsMap.containsKey(maNV) && 
                          existingRecordsMap[maNV]!.containsKey(boPhan);
        
        // Create the record object with the correct field names for the local database
Map<String, dynamic> recordData = {
  'UID': recordExists ? existingRecordsMap[maNV]![boPhan]!['UID'] : _generateUUID(),
  'GiaiDoan': giaiDoan,
  //'NgayCapNhat': ngayCapNhat,
  'MaNV': maNV,
  'BoPhan': boPhan,
  'MaBP': boPhan,
  'CongChuanToiDa': congChuanToiDa,
  'Tuan_1va2': tuan1va2,     // Correct field name for local DB
  'Phep_1va2': phep1va2,     // Correct field name for local DB
  'HT_1va2': ht1va2,         // Correct field name for local DB
  'Tuan_3va4': tuan3va4,     // Correct field name for local DB
  'Phep_3va4': phep3va4,     // Correct field name for local DB
  'HT_3va4': ht3va4,         // Correct field name for local DB
  'Tong_Cong': tongCong,
  'Tong_Phep': tongPhep,
  'Tong_Le': tongLe,
  'Tong_NgoaiGio': tongNgoaiGio,
  'Tong_HV': tongHV,
  'Tong_Dem': tongDem,
  'Tong_CD': tongCD,
  'Tong_HT': tongHT,
  'TongLuong': 0, 
  'UngLan1': ungLan1,
  'UngLan2': ungLan2,
  'ThanhToan3': 0,
  'TruyLinh': 0,
  'TruyThu': 0,
  'Khac': 0,
  'MucLuongThang': 0,
  'MucLuongNgoaiGio': 0,
  'MucLuongNgoaiGio2': 0,
  'GhiChu': ''
};
        
        if (recordExists) {
          // Update existing record
          final existingRecord = existingRecordsMap[maNV]![boPhan]!;
          recordData['UID'] = existingRecord['UID'];
          recordsToUpdate.add(recordData);
        } else {
          // Insert new record with a new UUID
          recordData['UID'] = _generateUUID();
          recordsToInsert.add(recordData);
        }
      }
    }
    
    // 7. Find records to delete (entries in ChamCongCNThang that don't have matching ChamCongCN records)
    for (var maNV in existingRecordsMap.keys) {
      for (var boPhan in existingRecordsMap[maNV]!.keys) {
        bool hasMatchingRecords = groupedRecords.containsKey(maNV) && 
                               groupedRecords[maNV]!.containsKey(boPhan);
        
        if (!hasMatchingRecords) {
          recordsToDelete.add(existingRecordsMap[maNV]![boPhan]!['UID'] as String);
        }
      }
    }
    
    // 8. Execute database operations
    await db.transaction((txn) async {
      // Insert new records
      for (var record in recordsToInsert) {
        await txn.insert('ChamCongCNThang', record);
      }
      
      // Update existing records
      for (var record in recordsToUpdate) {
        final uid = record['UID'];
        Map<String, dynamic> values = Map.from(record);
        values.remove('UID');
        
        await txn.update(
          'ChamCongCNThang',
          values,
          where: 'UID = ?',
          whereArgs: [uid],
        );
      }
      
      // Delete records
      for (var uid in recordsToDelete) {
        await txn.delete(
          'ChamCongCNThang',
          where: 'UID = ?',
          whereArgs: [uid],
        );
      }
    });
    
    // 9. Sync changes with the server
    List<Map<String, dynamic>> allUpdatedRecords = [...recordsToInsert, ...recordsToUpdate];
    if (allUpdatedRecords.isNotEmpty) {
      await _syncUpdatedRecordsWithServer(allUpdatedRecords);
    }
    
    if (recordsToDelete.isNotEmpty) {
      await _syncDeletedRecordsWithServer(recordsToDelete);
    }
    
    // 10. Reload data and show success message
    await _loadMonthlyData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cập nhật thành công: ${recordsToInsert.length} mới, ${recordsToUpdate.length} cập nhật, ${recordsToDelete.length} xóa'
        ),
        backgroundColor: Colors.green,
      ),
    );
    
  } catch (e) {
    print('Error creating auto data: $e');
    _showError('Lỗi khi tạo dữ liệu tự động: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}

// Helper method to generate a UUID
String _generateUUID() {
  final random = math.Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
    RegExp(r'[xy]'),
    (match) {
      final r = (timestamp + random.nextInt(16)) % 16;
      final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
      return v.toRadixString(16);
    }
  );
}

Future<void> _syncUpdatedRecordsWithServer(List<Map<String, dynamic>> records) async {
  try {
    List<Map<String, dynamic>> serverRecords = records.map((record) {
      Map<String, dynamic> serverRecord = {
        'UID': record['UID'],
        //'NgayCapNhat': record['NgayCapNhat'],
        'GiaiDoan': record['GiaiDoan'],
        'MaNV': record['MaNV'],
        'BoPhan': record['BoPhan'],
        'MaBP': record['MaBP'],
        'CongChuanToiDa': record['CongChuanToiDa'],
        '1va2_Tuan': record['Tuan_1va2'],     // Convert field name for server
        '1va2_Phep': record['Phep_1va2'],     // Convert field name for server
        '1va2_HT': record['HT_1va2'],         // Convert field name for server
        '3va4_Tuan': record['Tuan_3va4'],     // Convert field name for server
        '3va4_Phep': record['Phep_3va4'],     // Convert field name for server
        '3va4_HT': record['HT_3va4'],         // Convert field name for server
        'Tong_Cong': record['Tong_Cong'],
        'Tong_Phep': record['Tong_Phep'],
        'Tong_Le': record['Tong_Le'],
        'Tong_NgoaiGio': record['Tong_NgoaiGio'],
        'Tong_HV': record['Tong_HV'],
        'Tong_Dem': record['Tong_Dem'],
        'Tong_CD': record['Tong_CD'],
        'Tong_HT': record['Tong_HT'],
        'TongLuong': record['TongLuong'], 
        'UngLan1': record['UngLan1'],
        'UngLan2': record['UngLan2'],
        'ThanhToan3': record['ThanhToan3'],
        'TruyLinh': record['TruyLinh'],
        'TruyThu': record['TruyThu'],
        'Khac': record['Khac'],
        'MucLuongThang': record['MucLuongThang'],
        'MucLuongNgoaiGio': record['MucLuongNgoaiGio'],
        'MucLuongNgoaiGio2': record['MucLuongNgoaiGio2'],
        'GhiChu': record['GhiChu']
      };
      return serverRecord;
    }).toList();

    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcnthangsua'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(serverRecords),
    );
    
    if (response.statusCode != 200) {
      print('Server sync error: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Error syncing with server: $e');
  }
}

Future<void> _syncDeletedRecordsWithServer(List<String> uids) async {
  try {
    print('Sending UIDs for deletion: $uids');
    
    final response = await http.delete(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcnthangxoa'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'uids': uids}),
    );
    
    if (response.statusCode != 200) {
      print('Server delete sync error: ${response.statusCode} - ${response.body}');
    } else {
      print('Successfully deleted records on server: ${response.body}');
    }
  } catch (e) {
    print('Error syncing deletions with server: $e');
  }
}

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red)
      );
    }
  }
Future<void> _exportToExcel() async {
  setState(() => _isLoading = true);
  
  try {
    // Create a new Excel document
    final excel = Excel.createExcel();
    final sheet = excel['Monthly Data'];
    
    // Define column titles with names that are more user-friendly
    final Map<String, String> columnTitles = {
      'MaNV': 'Mã NV',
      'TenNV': 'Tên NV',
      'BoPhan': 'Bộ phận',
      //'NgayCapNhat': 'Ngày cập nhật',
      'Tuan1va2': 'Tuần 1-2',
      'Phep1va2': 'Phép 1-2',
      'HT1va2': 'HT 1-2',
      'Tuan3va4': 'Tuần 3-4',
      'Phep3va4': 'Phép 3-4',
      'HT3va4': 'HT 3-4',
      'Tong_Cong': 'Công',
      'Tong_Phep': 'Phép',
      'Tong_Le': 'Lễ',
      'Tong_NgoaiGio': 'Ngoài giờ',
      'Tong_HV': 'HV',
      'Tong_Dem': 'Đêm',
      'Tong_CD': 'CĐ',
      'Tong_HT': 'HT',
      'TongLuong': 'Tổng lương',
      'UngLan1': 'Ứng lần 1',
      'UngLan2': 'Ứng lần 2',
      'ThanhToan3': 'Thanh toán 3',
      'TruyLinh': 'Truy lĩnh',
      'TruyThu': 'Truy thu',
      'Khac': 'Khác',
      'MucLuongThang': 'Mức lương tháng',
      'MucLuongNgoaiGio': 'Mức lương ngoài giờ',
      'MucLuongNgoaiGio2': 'Mức lương ngoài giờ 2',
      'GhiChu': 'Ghi chú',
    };
    
    // Define columns to show (same as in the UI)
    final List<String> columnsToShow = [
      'MaNV', 'TenNV', 'BoPhan', 'CongChuanToiDa',
      'Tuan1va2', 'Phep1va2', 'HT1va2',
      'Tuan3va4', 'Phep3va4', 'HT3va4',
      'Tong_Cong', 'Tong_Phep', 'Tong_Le', 'Tong_NgoaiGio',
      'Tong_HV', 'Tong_Dem', 'Tong_CD', 'Tong_HT',
      'TongLuong', 'UngLan1', 'UngLan2', 'ThanhToan3',
      'TruyLinh', 'TruyThu', 'Khac',
      'MucLuongThang', 'MucLuongNgoaiGio', 'MucLuongNgoaiGio2',
      'GhiChu'
    ];

    // Add header row
    List<String> headerRow = columnsToShow.map((col) => columnTitles[col] ?? col).toList();
    sheet.appendRow(headerRow);
    
    // Style the header row
    for (int i = 0; i < headerRow.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = CellStyle(
        backgroundColorHex: "#CCCCCC",
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    }
    
    // Fetch employee names from staffbio table
    final dbHelper = DBHelper();
    Map<String, String> employeeNames = {};
    
    // Get all MaNV values from _monthlyData
    final List<String> allMaNVs = _monthlyData.map((row) => row['MaNV'].toString()).toList();
    
    // Batch query to get all employee names at once
    if (allMaNVs.isNotEmpty) {
      final staffResults = await dbHelper.rawQuery(
        "SELECT MaNV, Ho_ten FROM staffbio WHERE MaNV IN (${allMaNVs.map((_) => '?').join(', ')})",
        allMaNVs
      );
      
      for (var staff in staffResults) {
        employeeNames[staff['MaNV'].toString()] = staff['Ho_ten'].toString();
      }
    }
    
    // Add data rows
    for (int rowIndex = 0; rowIndex < _monthlyData.length; rowIndex++) {
      final dataRow = _monthlyData[rowIndex];
      List<dynamic> excelRow = [];
      
      for (final column in columnsToShow) {
        var value = dataRow[column];
        
        // For TenNV column, use the employee name from our map
        if (column == 'TenNV') {
          value = employeeNames[dataRow['MaNV'].toString()] ?? '';
        }
        
        // Format date for NgayCapNhat
        if (column == 'NgayCapNhat' && value != null) {
          try {
            value = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(value.toString()));
          } catch (e) {
            // Keep original value if parsing fails
          }
        }
        
        excelRow.add(value ?? '');
      }
      
      sheet.appendRow(excelRow);
    }
    
    // Save the excel file
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'ChamCongThang_${_selectedMonth ?? ""}_${_selectedDepartment ?? ""}_$dateStr.xlsx';
    final filePath = '${directory.path}/$fileName';
    
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Chấm công tháng ${_selectedMonth ?? ""} - ${_selectedDepartment ?? ""}',
      );
    } else {
      throw Exception('Failed to encode Excel file');
    }
    
  } catch (e) {
    print('Error exporting to Excel: $e');
    _showError('Lỗi khi xuất file Excel: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
  @override
  void dispose() {
    // Dispose all text controllers
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Row(
          children: [
            Expanded(
              flex: 3,
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
                        _loadMonthlyData();
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
              flex: 2,
              child: DropdownButton<String>(
                value: _selectedMonth,
                items: _availableMonths.map((month) => DropdownMenuItem(
                  value: month,
                  child: Text(DateFormat('MM/yyyy').format(DateTime.parse('$month-01')))
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMonth = value;
                    _loadMonthlyData();
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
      ),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : Column(
              children: [
                // Button Row
                Padding(
  padding: const EdgeInsets.all(8.0),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      ElevatedButton.icon(
        icon: Icon(Icons.save),
        onPressed: _isEditingAllowed ? _saveData : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
        ),
        label: Text('Lưu'),
      ),
      ElevatedButton.icon(
        icon: Icon(Icons.autorenew),
        onPressed: _isEditingAllowed ? _createAutoData : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
        ),
        label: Text('Tạo tự động'),
      ),
      ElevatedButton.icon(
        icon: Icon(Icons.file_download),
        onPressed: _monthlyData.isNotEmpty ? _exportToExcel : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
        ),
        label: Text('Xuất Excel'),
      ),
    ],
  ),
),
                
                // Status Message for Editing
                if (!_isEditingAllowed)
                  Container(
                    color: Colors.orange.shade100,
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Chỉnh sửa chỉ được phép đến ngày 8 của tháng tiếp theo',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Tổng hợp tháng - ${_selectedDepartment ?? ""}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                Expanded(
                  child: _monthlyData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 50, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Không có dữ liệu cho tháng này',
                              style: TextStyle(
                                fontSize: 16, 
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 16),
                            if (_isEditingAllowed)
                              ElevatedButton(
                                onPressed: _createAutoData,
                                child: Text('Tạo dữ liệu mới'),
                              ),
                          ],
                        ),
                      )
                    : _buildSimpleDataTable(),
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
        ],
      ),
    );
  }
  Widget _buildSimpleDataTable() {
  final Map<String, String> columnTitles = {
    'MaNV': 'Mã NV',
    'TenNV': 'Tên NV',
    'BoPhan': 'Bộ phận',
    //'NgayCapNhat': 'Ngày cập nhật',
    'Tuan1va2': 'Tuần 1-2',
    'Phep1va2': 'Phép 1-2',
    'HT1va2': 'HT 1-2',
    'Tuan3va4': 'Tuần 3-4',
    'Phep3va4': 'Phép 3-4',
    'HT3va4': 'HT 3-4',
    'Tong_Cong': 'Công',
    'Tong_Phep': 'Phép',
    'Tong_Le': 'Lễ',
    'Tong_NgoaiGio': 'Ngoài giờ',
    'Tong_HV': 'HV',
    'Tong_Dem': 'Đêm',
    'Tong_CD': 'CĐ',
    'Tong_HT': 'HT',
    'TongLuong': 'Tổng lương',
    'UngLan1': 'Ứng lần 1',
    'UngLan2': 'Ứng lần 2',
    'ThanhToan3': 'Thanh toán 3',
    'TruyLinh': 'Truy lĩnh',
    'TruyThu': 'Truy thu',
    'Khac': 'Khác',
    'MucLuongThang': 'Mức lương tháng',
    'MucLuongNgoaiGio': 'Mức lương ngoài giờ',
    'MucLuongNgoaiGio2': 'Mức lương ngoài giờ 2',
    'GhiChu': 'Ghi chú',
  };
  
  final List<String> columnsToShow = [
    'MaNV', 'TenNV', 'BoPhan', 'CongChuanToiDa',
    'Tuan1va2', 'Phep1va2', 'HT1va2',
    'Tuan3va4', 'Phep3va4', 'HT3va4',
    'Tong_Cong', 'Tong_Phep', 'Tong_Le', 'Tong_NgoaiGio',
    'Tong_HV', 'Tong_Dem', 'Tong_CD', 'Tong_HT',
    'TongLuong', 'UngLan1', 'UngLan2', 'ThanhToan3',
    'TruyLinh', 'TruyThu', 'Khac',
    'MucLuongThang', 'MucLuongNgoaiGio', 'MucLuongNgoaiGio2',
    'GhiChu'
  ];
  
  // Create scroll controllers
  final ScrollController horizontalController = ScrollController();
  
  // Add scroll buttons for desktop
  return Column(
    children: [
      // Horizontal scroll controls
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // Scroll to start
                horizontalController.animateTo(
                  0,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              icon: Icon(Icons.first_page),
              label: Text('Đầu bảng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Scroll left
                    horizontalController.animateTo(
                      (horizontalController.offset - 300).clamp(0, horizontalController.position.maxScrollExtent),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  icon: Icon(Icons.arrow_back),
                  label: Text('Trái'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Scroll right
                    horizontalController.animateTo(
                      (horizontalController.offset + 300).clamp(0, horizontalController.position.maxScrollExtent),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  icon: Icon(Icons.arrow_forward),
                  label: Text('Phải'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            ElevatedButton.icon(
              onPressed: () {
                // Scroll to end
                horizontalController.animateTo(
                  horizontalController.position.maxScrollExtent,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              icon: Icon(Icons.last_page),
              label: Text('Cuối bảng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
      
      // Table with both scroll directions
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 60,
              dataRowHeight: 60,
              columnSpacing: 10,
              horizontalMargin: 10,
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
              dataRowColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return Theme.of(context).colorScheme.primary.withOpacity(0.08);
                }
                return Colors.white;
              }),
              border: TableBorder.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
              columns: columnsToShow.map((column) => 
                DataColumn(
                  label: Expanded(
                    child: Text(
                      columnTitles[column] ?? column,
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              ).toList(),
              rows: _monthlyData.map((row) {
                return DataRow(
                  color: _modifiedRows[row['UID'].toString()] == true
                      ? MaterialStateProperty.all(Colors.yellow.shade50)
                      : null,
                  cells: columnsToShow.map((column) {
                    if (_editableFields.contains(column) && _isEditingAllowed) {
                      return DataCell(
                        TextField(
                          controller: _controllers['${row['UID']}_$column'],
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            border: OutlineInputBorder(),
                          ),
                          style: TextStyle(color: Colors.blue.shade700),
                          keyboardType: column == 'GhiChu' 
                              ? TextInputType.text 
                              : TextInputType.numberWithOptions(decimal: true),
                        ),
                        showEditIcon: true,
                      );
                    }
                    
                    String displayValue = '';
                    if (column == 'NgayCapNhat' && row[column] != null) {
                      try {
                        displayValue = DateFormat('dd/MM/yyyy HH:mm')
                            .format(DateTime.parse(row[column].toString()));
                      } catch (e) {
                        displayValue = row[column].toString();
                      }
                    } else if (column.startsWith('Tong_') || 
                               column == 'TongLuong' || 
                               column.startsWith('Ung') || 
                               column.startsWith('ThanhToan') ||
                               column.startsWith('Truy') ||
                               column == 'Khac' ||
                               column.startsWith('MucLuong')) {
                      if (row[column] != null) {
                        try {
                          final number = double.parse(row[column].toString());
                          displayValue = NumberFormat('#,##0.##').format(number);
                        } catch (e) {
                          displayValue = row[column].toString();
                        }
                      }
                    } else {
                      displayValue = row[column]?.toString() ?? '';
                    }
                    
                    return DataCell(
                      SelectableText(
                        displayValue,
                        style: TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ],
  );
}
}