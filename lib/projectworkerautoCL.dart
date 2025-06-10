import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'export_helper.dart';
import 'projectworkerphep.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'projectworkerautoCLthang.dart';
import 'package:sqflite/sqflite.dart';
import 'http_client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'user_credentials.dart';
class ProjectWorkerAuto extends StatefulWidget {
  final String selectedBoPhan;
  final String username;
  
  const ProjectWorkerAuto({
    Key? key, 
    required this.selectedBoPhan,
    required this.username,
  }) : super(key: key);
  
  @override
  _ProjectWorkerAutoState createState() => _ProjectWorkerAutoState();
}

class _ProjectWorkerAutoState extends State<ProjectWorkerAuto> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _attendanceData = [];
  List<String> _departments = [];
  String? _selectedDepartment;
  String? _selectedMonth;
  Map<String, String> _staffNames = {};
  List<String> _availableMonths = [];
  final List<String> _congThuongChoices = ['X', 'P', 'XĐ', 'X/2', 'Ro', 'HT', 'NT', 'CĐ', 'NL', 'Ô', 'TS', '2X', '3X', 'HV', '2HV', '3HV', '2XĐ', '3X/4', 'P/2', 'QLDV'];
  Map<String, Color> _staffColors = {};
  DateTime? _lastSyncTime;
  Map<String, dynamic> _syncStats = {};

  @override
  void initState() {
    super.initState();
    _selectedDepartment = widget.selectedBoPhan;
    _initializeData();
  }
@override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndAutoSync();
  }
  Future<void> _checkAndAutoSync() async {
    // Auto-sync if last sync was more than 1 hour ago or never synced
    if (_lastSyncTime == null || 
        DateTime.now().difference(_lastSyncTime!).inHours >= 1) {
      await _syncChamCongCNThang(silent: true);
    }
  }
  Future<void> _updateSyncStats() async {
    final dbHelper = DBHelper();
    final db = await dbHelper.database;
    
    try {
      // 1. Get records count for current month
      final monthRecordsResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM ChamCongCNThang WHERE GiaiDoan LIKE ?",
        ['${_selectedMonth}%']
      );
      final monthRecordsCount = monthRecordsResult.first['count'] as int;
      
      // 2. Get unique projects for current month
      final uniqueProjectsResult = await db.rawQuery(
        "SELECT COUNT(DISTINCT BoPhan) as count FROM ChamCongCNThang WHERE GiaiDoan LIKE ?",
        ['${_selectedMonth}%']
      );
      final uniqueProjectsCount = uniqueProjectsResult.first['count'] as int;
      
      // 3. Get last update date
      final lastUpdateResult = await db.rawQuery(
        "SELECT MAX(NgayCapNhat) as latestDate FROM ChamCongCNThang"
      );
      final lastUpdateDate = lastUpdateResult.first['latestDate'] as String?;
      
      // 4. Get staff count for current project
      final staffCountResult = await db.rawQuery(
        "SELECT COUNT(DISTINCT MaNV) as count FROM ChamCongCNThang WHERE BoPhan = ? AND GiaiDoan LIKE ?",
        [_selectedDepartment, '${_selectedMonth}%']
      );
      final staffCount = staffCountResult.first['count'] as int;
      
      setState(() {
        _syncStats = {
          'monthRecords': monthRecordsCount,
          'uniqueProjects': uniqueProjectsCount,
          'lastUpdate': lastUpdateDate != null 
              ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(lastUpdateDate))
              : 'Chưa có dữ liệu',
          'projectStaffCount': staffCount,
        };
      });
    } catch (e) {
      print('Error updating sync stats: $e');
    }
  }
  Future<void> _initializeData() async {
  setState(() => _isLoading = true);
  try {
    final dbHelper = DBHelper();
    
    // Load departments/projects first
    await _loadDepartments();
    
    // Add departments from the database
    final existingDepts = await dbHelper.rawQuery(
      'SELECT DISTINCT BoPhan FROM chamcongcn ORDER BY BoPhan'
    );
    final dbDepartments = existingDepts.map((e) => e['BoPhan'] as String).toList();
    
    // Combine and deduplicate
    _departments.addAll(dbDepartments);
    _departments = _departments.toSet().toList()..sort();
    
    // Ensure selected department is valid
    if (_selectedDepartment != null && !_departments.contains(_selectedDepartment)) {
      _selectedDepartment = _departments.isNotEmpty ? _departments.first : null;
    }
    
    // Get available months
    final months = await dbHelper.rawQuery(
      r"SELECT DISTINCT strftime('%Y-%m', Ngay) as month FROM chamcongcn ORDER BY month DESC"
    );
    _availableMonths = months.map((e) => e['month'] as String).toList();
    
    String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    if (!_availableMonths.contains(currentMonth)) {
      _availableMonths.insert(0, currentMonth);
    }
    _selectedMonth = _availableMonths.first;
    
    await _loadAttendanceData();
    await _updateSyncStats();
  } catch (e) {
    print('Init error: $e');
    _showError('Không thể tải dữ liệu');
  }
  setState(() => _isLoading = false);
}

// Add this new method to handle department loading with proper username access
Future<void> _loadDepartments() async {
  try {
    // Get username from UserCredentials provider
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username.toLowerCase(); // Convert to lowercase to match API expectation
    
    print('Loading departments for username: $username'); // Debug print
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$username'),
      headers: {'Content-Type': 'application/json'},
    );
    
    print('API Response Status: ${response.statusCode}'); // Debug print
    print('API Response Body: ${response.body}'); // Debug print
    
    if (response.statusCode == 200) {
      final List<dynamic> apiDepts = json.decode(response.body);
      setState(() {
        _departments = apiDepts.map((e) => e.toString()).toList();
      });
      print('Loaded ${_departments.length} departments from API: $_departments');
    } else {
      print('API returned status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to load departments: ${response.statusCode}');
    }
  } catch (e) {
    print('Project API error: $e');
    // Don't initialize as empty list, let it stay as initialized
    if (_departments.isEmpty) {
      _showError('Không thể tải danh sách dự án. Vui lòng kiểm tra kết nối mạng.');
    }
  }
}

  Future<void> _loadAttendanceData() async {
    if (_selectedMonth == null || _selectedDepartment == null) return;
    setState(() => _isLoading = true);
    
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
          'Ngay': record['Ngay'] ?? '',
          'Gio': record['Gio'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
          'NguoiDung': record['NguoiDung'] ?? widget.username,
          'BoPhan': record['BoPhan'] ?? _selectedDepartment,
          'MaBP': record['MaBP'] ?? _selectedDepartment,
          'PhanLoai': record['PhanLoai']?.toString() ?? '',
          'MaNV': record['MaNV'] ?? '',
          'CongThuongChu': record['CongThuongChu'] ?? 'Ro',
          'NgoaiGioThuong': record['NgoaiGioThuong']?.toString() ?? '0',
          'NgoaiGioKhac': record['NgoaiGioKhac']?.toString() ?? '0',
          'NgoaiGiox15': record['NgoaiGiox15']?.toString() ?? '0',
          'NgoaiGiox2': record['NgoaiGiox2']?.toString() ?? '0',
          'HoTro': record['HoTro']?.toString() ?? '0',
          'PartTime': record['PartTime'].toString() ?? '0',
          'PartTimeSang': record['PartTimeSang'].toString() ?? '0',
          'PartTimeChieu': record['PartTimeChieu'].toString() ?? '0',
          'CongLe': record['CongLe']?.toString() ?? '0',
        }));
      });
      
      final employeeIds = _getUniqueEmployees();
      await _loadStaffNames(employeeIds);
      
    } catch (e) {
      print('Error loading attendance data: $e');
      _showError('Không thể tải dữ liệu chấm công');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadStaffNames(List<String> employeeIds) async {
    if (employeeIds.isEmpty) return;
    
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
  }

  Future<void> _generateAutomaticLeave() async {
  // Show confirmation dialog before proceeding
  final bool? proceed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Tạo phép tự động'),
        content: Text(
          'Quá trình này sẽ tự động tính toán và tạo phép cho nhân viên dựa trên dữ liệu hiện có. Để đảm bảo chính xác vui lòng:\n1. Đồng bộ danh sách công nhân mới nhất (bước 5 chọn Có khi bấm Đồng bộ)\n2.Đảm bảo mã công nhân chính xác\n3.Hiện tại đã chấm xong ngày 28 tháng hiện tại\n4.Chỉ được tạo phép tự động trước ngày mùng 2 của tháng kế tiếp\n5.Thời gian xử lý tự động có thể hơi lâu tuỳ vào số lượng NV '
          'Tiếp tục?'
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectWorkerPhep(
          //selectedBoPhan: _selectedDepartment ?? '',
          username: widget.username,
          selectedMonth: _selectedMonth ?? '',
        ),
      ),
    );
    
    if (result == true) {
      // If successful, reload the attendance data
      await _loadAttendanceData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã tạo phép tự động thành công'))
      );
    }
  } catch (e) {
    print('Error generating automatic leave: $e');
    _showError('Lỗi khi tạo phép tự động: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _exportPdf() async {
  setState(() => _isLoading = true);
  
  try {
    await ExportHelper.exportToPdf(
      selectedDepartment: _selectedDepartment ?? '',
      selectedMonth: _selectedMonth ?? '',
      allEmployees: _getUniqueEmployees(),
      staffNames: _staffNames,
      getEmployeesWithValueInColumn: _getEmployeesWithValueInColumn,
      getDaysInMonth: _getDaysInMonth,
      getAttendanceForDay: _getAttendanceForDay,
      calculateSummary: _calculateSummary,
      context: context,
    );
  } catch (e) {
    print('PDF export error: $e');
    _showError('Lỗi khi xuất PDF: $e');
  }
  
  setState(() => _isLoading = false);
}

Future<void> _exportExcel() async {
  setState(() => _isLoading = true);
  
  try {
    await ExportHelper.exportToExcel(
      selectedDepartment: _selectedDepartment ?? '',
      selectedMonth: _selectedMonth ?? '',
      allEmployees: _getUniqueEmployees(),
      staffNames: _staffNames,
      getEmployeesWithValueInColumn: _getEmployeesWithValueInColumn,
      getDaysInMonth: _getDaysInMonth,
      getAttendanceForDay: _getAttendanceForDay,
      calculateSummary: _calculateSummary,
      context: context,
    );
  } catch (e) {
    print('Excel export error: $e');
    _showError('Lỗi khi xuất Excel: $e');
  }
  
  setState(() => _isLoading = false);
}

  List<String> _getUniqueEmployees() {
    final employees = _attendanceData
      .map((record) => record['MaNV'] as String)
      .toSet()
      .toList()..sort();
    
    return employees;
  }

  // Get employees that have non-default values in specific column
  List<String> _getEmployeesWithValueInColumn(String columnType) {
    // Get all unique days in the month
    final days = _getDaysInMonth();
    // Get all employees
    final allEmployees = _getUniqueEmployees();
    
    // For CongThuongChu, also check NgoaiGioThuong values
    if (columnType == 'CongThuongChu') {
      return allEmployees.where((empId) {
        for (var day in days) {
          final congValue = _getAttendanceForDay(empId, day, 'CongThuongChu');
          final ngoaiGioValue = _getAttendanceForDay(empId, day, 'NgoaiGioThuong');
          
          if ((congValue != null && congValue != 'Ro') || 
              (ngoaiGioValue != null && ngoaiGioValue != '0')) {
            return true;
          }
        }
        return false;
      }).toList();
    }
    
    // For other columns, just check the specific column
    return allEmployees.where((empId) {
      for (var day in days) {
        final value = _getAttendanceForDay(empId, day, columnType);
        if (value != null && value != '0') {
          return true;
        }
      }
      return false;
    }).toList();
  }

  List<int> _getDaysInMonth() {
    if (_selectedMonth == null) return [];
    final parts = _selectedMonth!.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return List.generate(daysInMonth, (i) => i + 1);
  }

  String? _getAttendanceForDay(String empId, int day, String columnType) {
    final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
    final record = _attendanceData.firstWhere(
      (record) => 
        record['MaNV'] == empId && 
        record['Ngay'].split('T')[0] == dateStr,
      orElse: () => {},
    );
    return record[columnType]?.toString() ?? (columnType == 'CongThuongChu' ? 'Ro' : '0');
  }

  Map<String, dynamic> _calculateSummary(String empId) {
  if (_selectedMonth == null) return {};
  double tongHV = 0;
double tongDem = 0;
double tongCD = 0;

  final days = _getDaysInMonth();
  
  // ====== For Chữ & Giờ thường section ======
  // 1. CongThuongChu row
  double congChu_regularDays12 = 0; // Based on PhanLoai
  double congChu_permissionDays12 = 0; // P or +P or P/2 or +P/2
  double congChu_htDays12 = 0; // HT
  
  double congChu_regularDays34 = 0;
  double congChu_permissionDays34 = 0;
  double congChu_htDays34 = 0;
  
  // Add new variables for days 26+
  double congChu_regularDays5plus = 0;
  double congChu_permissionDays5plus = 0;
  double congChu_htDays5plus = 0;
  
  // 2. NgoaiGioThuong row
  double ngThuong_days12 = 0; // NgoaiGioThuong/8
  double ngThuong_days34 = 0;
  double ngThuong_days5plus = 0;
  
  // ====== For Hỗ trợ section ======
  double hoTro_days12 = 0;
  double hoTro_days34 = 0;
  double hoTro_days5plus = 0;
  
  // ====== For Part time section ======
  double partTime_days12 = 0;
  double partTime_days34 = 0;
  double partTime_days5plus = 0;
  
  // ====== For PT sáng section ======
  double ptSang_days12 = 0;
  double ptSang_days34 = 0;
  double ptSang_days5plus = 0;
  
  // ====== For PT chiều section ======
  double ptChieu_days12 = 0;
  double ptChieu_days34 = 0;
  double ptChieu_days5plus = 0;
  
  // ====== For NG khác section ======
  double ngKhac_days12 = 0;
  double ngKhac_days34 = 0;
  double ngKhac_days5plus = 0;
  
  // ====== For NG x1.5 section ======
  double ng15_days12 = 0;
  double ng15_days34 = 0;
  double ng15_days5plus = 0;
  
  // ====== For NG x2 section ======
  double ng2_days12 = 0;
  double ng2_days34 = 0;
  double ng2_days5plus = 0;
  
  // ====== For Công lễ section ======
  double congLe_days12 = 0;
  double congLe_days34 = 0;
  double congLe_days5plus = 0;

  // Process each day in the month
  for (int day = 1; day <= days.length; day++) {
    final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
    
    // Find attendance record for this employee on this day
    final recordList = _attendanceData.where(
      (record) => 
        record['MaNV'] == empId && 
        record['Ngay'].split('T')[0] == dateStr
    ).toList();
    
    if (recordList.isEmpty) continue;
    final record = recordList.first;

    // Get values from record
    final congThuongChu = record['CongThuongChu'] ?? 'Ro';
    final phanLoai = record['PhanLoai']?.toString() ?? '';
    final ngoaiGioThuong = double.tryParse(record['NgoaiGioThuong']?.toString() ?? '0') ?? 0;
    final ngoaiGioKhac = double.tryParse(record['NgoaiGioKhac']?.toString() ?? '0') ?? 0;
    final ngoaiGiox15 = double.tryParse(record['NgoaiGiox15']?.toString() ?? '0') ?? 0;
    final ngoaiGiox2 = double.tryParse(record['NgoaiGiox2']?.toString() ?? '0') ?? 0;
    final hoTro = double.tryParse(record['HoTro']?.toString() ?? '0') ?? 0;
    final partTime = double.tryParse(record['PartTime']?.toString() ?? '0') ?? 0;
    final partTimeSang = double.tryParse(record['PartTimeSang']?.toString() ?? '0') ?? 0;
    final partTimeChieu = double.tryParse(record['PartTimeChieu']?.toString() ?? '0') ?? 0;
    final congLe = double.tryParse(record['CongLe']?.toString() ?? '0') ?? 0;

    // Process base CongThuongChu value
    final baseCongThuongChu = _extractCongThuongChuBase(congThuongChu);
    
double hvValue = 0;
if (baseCongThuongChu == 'HV') {
  hvValue = 1.0;
} else if (baseCongThuongChu == '2HV') {
  hvValue = 2.0;
} else if (baseCongThuongChu == '3HV') {
  hvValue = 3.0;
}
tongHV += hvValue;
if (baseCongThuongChu == 'CĐ') {
  tongCD += 1.0;
}
if (baseCongThuongChu == 'XĐ' || baseCongThuongChu == '2XĐ') {
  // Count XĐ as 1.0 and 2XĐ as 2.0
  tongDem += baseCongThuongChu.startsWith('2') ? 2.0 : 1.0;
}
    // Check if it has +P or +P/2 suffix
    final bool hasFullPermission = congThuongChu.endsWith('+P');
    final bool hasHalfPermission = congThuongChu.endsWith('+P/2');

    // Get PhanLoai value for regular days calculation
    double phanLoaiValue = 0;
    if (phanLoai.isNotEmpty) {
      try {
        phanLoaiValue = double.parse(phanLoai);
      } catch (e) {
        print("Error parsing PhanLoai: $e");
      }
    }

    // Calculate values for each day based on day group
    if (day <= 15) {
      // ==== Days 1-15 ====
      
      // Processing for first half (same as original code)
      // 1. CongThuongChu row
      if (phanLoaiValue > 0) {
        congChu_regularDays12 += phanLoaiValue;
      }
      
      if (baseCongThuongChu == 'P') {
        congChu_permissionDays12 += 1.0;
      } else if (baseCongThuongChu == 'P/2') {
        congChu_permissionDays12 += 0.5;
      }
      
      if (hasFullPermission) {
        congChu_permissionDays12 += 1.0;
      } else if (hasHalfPermission) {
        congChu_permissionDays12 += 0.5;
      }
      
      if (baseCongThuongChu == 'HT') {
        congChu_htDays12 += 1.0;
      }
      
      // 2. NgoaiGioThuong row
      if (ngoaiGioThuong > 0) {
        ngThuong_days12 += ngoaiGioThuong / 8;
      }
      
      // ---- Hỗ trợ section ----
      if (hoTro > 0) {
        hoTro_days12 += hoTro / 8;
      }
      
      // ---- Part time section ----
      if (partTime > 0) {
        partTime_days12 += partTime;
      }
      
      // ---- PT sáng section ----
      if (partTimeSang > 0) {
        ptSang_days12 += partTimeSang;
      }
      
      // ---- PT chiều section ----
      if (partTimeChieu > 0) {
        ptChieu_days12 += partTimeChieu;
      }
      
      // ---- NG khác section ----
      if (ngoaiGioKhac > 0) {
        ngKhac_days12 += ngoaiGioKhac / 8;
      }
      
      // ---- NG x1.5 section ----
      if (ngoaiGiox15 > 0) {
        ng15_days12 += ngoaiGiox15 / 8;
      }
      
      // ---- NG x2 section ----
      if (ngoaiGiox2 > 0) {
        ng2_days12 += ngoaiGiox2 / 8;
      }
      
      // ---- Công lễ section ----
      if (congLe > 0) {
        congLe_days12 += congLe / 8;
      }
      
    } else if (day <= 25) {
      // ==== Days 16-25 ====
      
      // Modified to only include days 16-25 in the "Tuan 3+4" calculations
      // 1. CongThuongChu row
      if (phanLoaiValue > 0) {
        congChu_regularDays34 += phanLoaiValue;
      }
      
      if (baseCongThuongChu == 'P') {
        congChu_permissionDays34 += 1.0;
      } else if (baseCongThuongChu == 'P/2') {
        congChu_permissionDays34 += 0.5;
      }
      
      if (hasFullPermission) {
        congChu_permissionDays34 += 1.0;
      } else if (hasHalfPermission) {
        congChu_permissionDays34 += 0.5;
      }
      
      if (baseCongThuongChu == 'HT') {
        congChu_htDays34 += 1.0;
      }
      
      // 2. NgoaiGioThuong row
      if (ngoaiGioThuong > 0) {
        ngThuong_days34 += ngoaiGioThuong / 8;
      }
      
      // ---- Hỗ trợ section ----
      if (hoTro > 0) {
        hoTro_days34 += hoTro / 8;
      }
      
      // ---- Part time section ----
      if (partTime > 0) {
        partTime_days34 += partTime;
      }
      
      // ---- PT sáng section ----
      if (partTimeSang > 0) {
        ptSang_days34 += partTimeSang;
      }
      
      // ---- PT chiều section ----
      if (partTimeChieu > 0) {
        ptChieu_days34 += partTimeChieu;
      }
      
      // ---- NG khác section ----
      if (ngoaiGioKhac > 0) {
        ngKhac_days34 += ngoaiGioKhac / 8;
      }
      
      // ---- NG x1.5 section ----
      if (ngoaiGiox15 > 0) {
        ng15_days34 += ngoaiGiox15 / 8;
      }
      
      // ---- NG x2 section ----
      if (ngoaiGiox2 > 0) {
        ng2_days34 += ngoaiGiox2 / 8;
      }
      
      // ---- Công lễ section ----
      if (congLe > 0) {
        congLe_days34 += congLe / 8;
      }
    } else {
      // ==== Days 26+ ====
      
      // Add accounting for days 26+
      // 1. CongThuongChu row
      if (phanLoaiValue > 0) {
        congChu_regularDays5plus += phanLoaiValue;
      }
      
      if (baseCongThuongChu == 'P') {
        congChu_permissionDays5plus += 1.0;
      } else if (baseCongThuongChu == 'P/2') {
        congChu_permissionDays5plus += 0.5;
      }
      
      if (hasFullPermission) {
        congChu_permissionDays5plus += 1.0;
      } else if (hasHalfPermission) {
        congChu_permissionDays5plus += 0.5;
      }
      
      if (baseCongThuongChu == 'HT') {
        congChu_htDays5plus += 1.0;
      }
      
      // 2. NgoaiGioThuong row
      if (ngoaiGioThuong > 0) {
        ngThuong_days5plus += ngoaiGioThuong / 8;
      }
      
      // ---- Hỗ trợ section ----
      if (hoTro > 0) {
        hoTro_days5plus += hoTro / 8;
      }
      
      // ---- Part time section ----
      if (partTime > 0) {
        partTime_days5plus += partTime;
      }
      
      // ---- PT sáng section ----
      if (partTimeSang > 0) {
        ptSang_days5plus += partTimeSang;
      }
      
      // ---- PT chiều section ----
      if (partTimeChieu > 0) {
        ptChieu_days5plus += partTimeChieu;
      }
      
      // ---- NG khác section ----
      if (ngoaiGioKhac > 0) {
        ngKhac_days5plus += ngoaiGioKhac / 8;
      }
      
      // ---- NG x1.5 section ----
      if (ngoaiGiox15 > 0) {
        ng15_days5plus += ngoaiGiox15 / 8;
      }
      
      // ---- NG x2 section ----
      if (ngoaiGiox2 > 0) {
        ng2_days5plus += ngoaiGiox2 / 8;
      }
      
      // ---- Công lễ section ----
      if (congLe > 0) {
        congLe_days5plus += congLe / 8;
      }
    }
  }
  
  // Calculate totals for each section - include all days in total
    // For Tuan 1+2 - reduce by P1+2
congChu_regularDays12 = congChu_regularDays12 - congChu_permissionDays12;
if (congChu_regularDays12 < 0) congChu_regularDays12 = 0;

// For Tuan 3+4 - reduce by P3+4
congChu_regularDays34 = congChu_regularDays34 - congChu_permissionDays34;
if (congChu_regularDays34 < 0) congChu_regularDays34 = 0;
  // Chữ & Giờ thường - CongThuongChu row
    final double congChu_totalPermission = congChu_permissionDays12 + congChu_permissionDays34 + congChu_permissionDays5plus;

  final double congChu_totalRegular = congChu_regularDays12 + congChu_regularDays34 + congChu_regularDays5plus;
  final double congChu_totalHT = congChu_htDays12 + congChu_htDays34 + congChu_htDays5plus;
  
  // Chữ & Giờ thường - NgoaiGioThuong row
  final double ngThuong_total = ngThuong_days12 + ngThuong_days34 + ngThuong_days5plus;
  
  // Other sections
  final double hoTro_total = hoTro_days12 + hoTro_days34 + hoTro_days5plus;
  final double partTime_total = partTime_days12 + partTime_days34 + partTime_days5plus;
  final double ptSang_total = ptSang_days12 + ptSang_days34 + ptSang_days5plus;
  final double ptChieu_total = ptChieu_days12 + ptChieu_days34 + ptChieu_days5plus;
  final double ngKhac_total = ngKhac_days12 + ngKhac_days34 + ngKhac_days5plus;
  final double ng15_total = ng15_days12 + ng15_days34 + ng15_days5plus;
  final double ng2_total = ng2_days12 + ng2_days34 + ng2_days5plus;
  final double congLe_total = congLe_days12 + congLe_days34 + congLe_days5plus;
  
  // Return formatted values with the same structure as before
  return {
    // ==== Chữ & Giờ thường section - CongThuongChu row ====
    'tuan12': _formatNumberValue(congChu_regularDays12),
    'p12': _formatNumberValue(congChu_permissionDays12),
    'ht12': _formatNumberValue(congChu_htDays12),
    'tuan34': _formatNumberValue(congChu_regularDays34),
    'p34': _formatNumberValue(congChu_permissionDays34),
    'ht34': _formatNumberValue(congChu_htDays34),
    'cong': _formatNumberValue(congChu_totalRegular),
    'phep': _formatNumberValue(congChu_totalPermission),
    'ht': _formatNumberValue(congChu_totalHT),
    
    // Added data for days 26+ if you want to display it
    'tuan5plus': _formatNumberValue(congChu_regularDays5plus),
    'p5plus': _formatNumberValue(congChu_permissionDays5plus),
    'ht5plus': _formatNumberValue(congChu_htDays5plus),
    
    // ==== Ngày 1-15 for other sections ====
    'ng_days12': _formatNumberValue(ngThuong_days12),
    'hotro_days12': _formatNumberValue(hoTro_days12),
    'pt_days12': _formatNumberValue(partTime_days12),
    'pts_days12': _formatNumberValue(ptSang_days12),
    'ptc_days12': _formatNumberValue(ptChieu_days12),
    'ngk_days12': _formatNumberValue(ngKhac_days12),
    'ng15_days12': _formatNumberValue(ng15_days12),
    'ng2_days12': _formatNumberValue(ng2_days12),
    'congle_days12': _formatNumberValue(congLe_days12),
    
    // ==== Ngày 16-25 for other sections ====
    'ng_days34': _formatNumberValue(ngThuong_days34),
    'hotro_days34': _formatNumberValue(hoTro_days34),
    'pt_days34': _formatNumberValue(partTime_days34),
    'pts_days34': _formatNumberValue(ptSang_days34),
    'ptc_days34': _formatNumberValue(ptChieu_days34),
    'ngk_days34': _formatNumberValue(ngKhac_days34),
    'ng15_days34': _formatNumberValue(ng15_days34),
    'ng2_days34': _formatNumberValue(ng2_days34),
    'congle_days34': _formatNumberValue(congLe_days34),
    
    // ==== Ngày 26+ for other sections if you need them ====
    'ng_days5plus': _formatNumberValue(ngThuong_days5plus),
    'hotro_days5plus': _formatNumberValue(hoTro_days5plus),
    'pt_days5plus': _formatNumberValue(partTime_days5plus),
    'pts_days5plus': _formatNumberValue(ptSang_days5plus),
    'ptc_days5plus': _formatNumberValue(ptChieu_days5plus),
    'ngk_days5plus': _formatNumberValue(ngKhac_days5plus),
    'ng15_days5plus': _formatNumberValue(ng15_days5plus),
    'ng2_days5plus': _formatNumberValue(ng2_days5plus),
    'congle_days5plus': _formatNumberValue(congLe_days5plus),
    
    // ==== Totals for other sections ====
    'ng_total': _formatNumberValue(ngThuong_total),
    'hotro_total': _formatNumberValue(hoTro_total),
    'pt_total': _formatNumberValue(partTime_total),
    'pts_total': _formatNumberValue(ptSang_total),
    'ptc_total': _formatNumberValue(ptChieu_total),
    'ngk_total': _formatNumberValue(ngKhac_total),
    'ng15_total': _formatNumberValue(ng15_total),
    'ng2_total': _formatNumberValue(ng2_total),
    'congle_total': _formatNumberValue(congLe_total),
    
    // Placeholder for other values
    'le': _formatNumberValue(congLe_total),
    'hv': _formatNumberValue(tongHV),
    'dem': _formatNumberValue(tongDem),
'cd': _formatNumberValue(tongCD),
  };
}
double _calculateDailyTotal(int day) {
  double total = 0.0;
  
  // Get all employees
  final allEmployees = _getUniqueEmployees();
  
  for (var empId in allEmployees) {
    final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
    
    // Find attendance record for this employee on this day
    final records = _attendanceData.where(
      (record) => 
        record['MaNV'] == empId && 
        record['Ngay'].split('T')[0] == dateStr
    ).toList();
    
    if (records.isEmpty) continue;
    final record = records.first;
    
    // Get PhanLoai value
    double phanLoaiValue = 0;
    if (record['PhanLoai'] != null && record['PhanLoai'].toString().isNotEmpty) {
      try {
        phanLoaiValue = double.parse(record['PhanLoai'].toString());
      } catch (e) {
        print("Error parsing PhanLoai: $e");
      }
    }
    
    // Get all NgoaiGio fields and divide by 8
    final ngoaiGioThuong = double.tryParse(record['NgoaiGioThuong']?.toString() ?? '0') ?? 0;
    final ngoaiGioKhac = double.tryParse(record['NgoaiGioKhac']?.toString() ?? '0') ?? 0;
    final ngoaiGiox15 = double.tryParse(record['NgoaiGiox15']?.toString() ?? '0') ?? 0;
    final ngoaiGiox2 = double.tryParse(record['NgoaiGiox2']?.toString() ?? '0') ?? 0;
    
    final ngoaiGioTotal = (ngoaiGioThuong + ngoaiGioKhac + ngoaiGiox15 + ngoaiGiox2) / 8;
    
    // Add to total
    total += phanLoaiValue + ngoaiGioTotal;
  }
  
  return total;
}
Widget _buildRegularSection(String columnType, String sectionTitle) {
  final days = _getDaysInMonth();
  final employees = _getEmployeesWithValueInColumn(columnType);
  
  if (employees.isEmpty) {
    return SizedBox.shrink();
  }
  
  String days12Key, days34Key, totalKey;
  bool showPermissionColumns = false;
  bool isNgoaiGioThuongRow = false;
  bool showLeColumn = false;
  
  switch (columnType) {
    case 'NgoaiGioThuong':
      days12Key = 'ng_days12';
      days34Key = 'ng_days34';
      totalKey = 'ng_total';
      isNgoaiGioThuongRow = true;
      break;
    case 'HoTro':
      days12Key = 'hotro_days12';
      days34Key = 'hotro_days34';
      totalKey = 'hotro_total';
      break;
    case 'PartTime':
      days12Key = 'pt_days12';
      days34Key = 'pt_days34';
      totalKey = 'pt_total';
      break;
    case 'PartTimeSang':
      days12Key = 'pts_days12';
      days34Key = 'pts_days34';
      totalKey = 'pts_total';
      break;
    case 'PartTimeChieu':
      days12Key = 'ptc_days12';
      days34Key = 'ptc_days34';
      totalKey = 'ptc_total';
      break;
    case 'NgoaiGioKhac':
      days12Key = 'ngk_days12';
      days34Key = 'ngk_days34';
      totalKey = 'ngk_total';
      break;
    case 'NgoaiGiox15':
      days12Key = 'ng15_days12';
      days34Key = 'ng15_days34';
      totalKey = 'ng15_total';
      break;
    case 'NgoaiGiox2':
      days12Key = 'ng2_days12';
      days34Key = 'ng2_days34';
      totalKey = 'ng2_total';
      break;
    case 'CongLe':
      days12Key = 'congle_days12';
      days34Key = 'congle_days34';
      totalKey = 'congle_total';
      break;
    case 'CongThuongChu':
      days12Key = 'tuan12';
      days34Key = 'tuan34';
      totalKey = 'cong';
      showPermissionColumns = true;
      showLeColumn = true;
      break;
    default:
      days12Key = 'tuan12';
      days34Key = 'tuan34';
      totalKey = 'cong';
  }
  
  // Create a scroll controller
  final ScrollController horizontalController = ScrollController();
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          sectionTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
      ),
      
      // Add scroll controls
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: () {
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
                    double newOffset = (horizontalController.offset - 300);
                    if (newOffset < 0) newOffset = 0;
                    horizontalController.animateTo(
                      newOffset,
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
                    double newOffset = (horizontalController.offset + 300);
                    if (horizontalController.hasClients) {
                      double maxScroll = horizontalController.position.maxScrollExtent;
                      if (newOffset > maxScroll) newOffset = maxScroll;
                      horizontalController.animateTo(
                        newOffset,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
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
                if (horizontalController.hasClients) {
                  horizontalController.animateTo(
                    horizontalController.position.maxScrollExtent,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
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
      
      SingleChildScrollView(
        controller: horizontalController,
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade300),
            verticalInside: BorderSide(color: Colors.grey.shade300),
            bottom: BorderSide(color: Colors.grey.shade300),
            right: BorderSide(color: Colors.grey.shade300),
            left: BorderSide(color: Colors.grey.shade300),
            top: BorderSide(color: Colors.grey.shade300),
          ),
          columnWidths: {
            0: FixedColumnWidth(120),
            1: FixedColumnWidth(60),
            2: FixedColumnWidth(60),
            3: FixedColumnWidth(60),
            4: FixedColumnWidth(60),
            5: FixedColumnWidth(60),
            6: FixedColumnWidth(60),
            7: FixedColumnWidth(60),
            8: FixedColumnWidth(60),
            9: FixedColumnWidth(60),
            10: FixedColumnWidth(60),
            11: FixedColumnWidth(60),
            12: FixedColumnWidth(60),
            13: FixedColumnWidth(60),
            for (int i = 0; i < days.length; i++)
              i + 14: FixedColumnWidth(60),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Rest of your table code (unchanged)
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                TableCell(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(''))),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: Container(
                    color: Colors.blue.shade100,
                    child: Center(child: Text('Ngày 1-15', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(child: Container(color: Colors.blue.shade100, child: Text(''))),
                TableCell(child: Container(color: Colors.blue.shade100, child: Text(''))),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: Container(
                    color: Colors.green.shade100,
                    child: Center(child: Text('Ngày 16-25', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(child: Container(color: Colors.green.shade100, child: Text(''))),
                TableCell(child: Container(color: Colors.green.shade100, child: Text(''))),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: Container(
                    color: Colors.orange.shade100,
                    child: Center(child: Text('Tổng tháng', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
                TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
                TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
                TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
                TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
                TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
                ...days.map((_) => TableCell(child: Text(''))),
              ],
            ),
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Mã NV', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.blue.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('Tuần 1+2', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.blue.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('P1+2', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.blue.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('HT1+2', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.green.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('Tuần 3+4', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.green.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('P3+4', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.green.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('HT3+4', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.orange.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('Công', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.orange.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('Phép', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.orange.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('Lễ', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.orange.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('HV', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.orange.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('Đêm', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.orange.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('CĐ', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                TableCell(
                  child: Container(
                    color: Colors.orange.shade100,
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text('HT', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
                 ...days.map((day) => TableCell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              _formatNumberValue(_calculateDailyTotal(day)),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              day.toString(), 
              style: TextStyle(fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    )),
  ],
),
            for (var empId in employees) ...[
              TableRow(
                decoration: BoxDecoration(
                  color: _staffColors[empId] ?? Colors.transparent,
                ),
                children: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(empId, style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _staffNames[empId] ?? '',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (columnType == 'CongThuongChu')
                            Text(
                              'Công chữ',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          if (columnType == 'NgoaiGioThuong')
                            Text(
                              'NG thường',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ...(() {
                    final summary = _calculateSummary(empId);
                    return [
                      // Tuần 1+2
                      TableCell(
                        child: Container(
                          color: Colors.blue.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(summary[days12Key] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                      // P1+2
                      TableCell(
                        child: Container(
                          color: Colors.blue.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(
                            showPermissionColumns ? (summary['p12'] ?? '') : '',
                            style: TextStyle(fontWeight: FontWeight.bold)
                          )),
                        ),
                      ),
                      // HT1+2
                      TableCell(
                        child: Container(
                          color: Colors.blue.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(summary['ht12'] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                      // Tuần 3+4
                      TableCell(
                        child: Container(
                          color: Colors.green.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(summary[days34Key] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                      // P3+4
                      TableCell(
                        child: Container(
                          color: Colors.green.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(
                            showPermissionColumns ? (summary['p34'] ?? '') : '',
                            style: TextStyle(fontWeight: FontWeight.bold)
                          )),
                        ),
                      ),
                      // HT3+4
                      TableCell(
                        child: Container(
                          color: Colors.green.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(summary['ht34'] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                      // Công
                      TableCell(
                        child: Container(
                          color: Colors.orange.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(summary[totalKey] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                      // Phép
                      TableCell(
                        child: Container(
                          color: Colors.orange.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(
                            showPermissionColumns ? (summary['phep'] ?? '') : '',
                            style: TextStyle(fontWeight: FontWeight.bold)
                          )),
                        ),
                      ),
                      // Lễ
                      TableCell(
                        child: Container(
                          color: Colors.orange.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(
                            showLeColumn ? (summary['le'] ?? '') : '',
                            style: TextStyle(fontWeight: FontWeight.bold)
                          )),
                        ),
                      ),
                      // HV
                      TableCell(
                        child: Container(
                          color: Colors.orange.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(
                            showPermissionColumns ? (summary['hv'] ?? '') : '',
                            style: TextStyle(fontWeight: FontWeight.bold)
                          )),
                        ),
                      ),
                      // Đêm
                      TableCell(
                        child: Container(
                          color: Colors.orange.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(
                            showPermissionColumns ? (summary['dem'] ?? '') : '',
                            style: TextStyle(fontWeight: FontWeight.bold)
                          )),
                        ),
                      ),
                      // CĐ
                      TableCell(
                        child: Container(
                          color: Colors.orange.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(
                            showPermissionColumns ? (summary['cd'] ?? '') : '',
                            style: TextStyle(fontWeight: FontWeight.bold)
                          )),
                        ),
                      ),
                      // HT
                      TableCell(
                        child: Container(
                          color: Colors.orange.shade50,
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text(
                            summary['ht'] ?? '',
                            style: TextStyle(fontWeight: FontWeight.bold)
                          )),
                        ),
                      ),
                    ];
                  })(),
                  ...days.map((day) {
                    final value = _getAttendanceForDay(empId, day, columnType);
                    final displayValue = (value == '0' || value == 'Ro') ? '' : value;
                    return TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: Text(
                            displayValue ?? '',
                            style: TextStyle(
                              color: (displayValue != null && displayValue.isNotEmpty) ? Colors.blue : null,
                              fontWeight: (displayValue != null && displayValue.isNotEmpty) ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              if (empId != employees.last)
                TableRow(
                  children: [
                    TableCell(child: SizedBox(height: 4)),
                    ...List.generate(13, (index) => TableCell(child: SizedBox(height: 4))),
                    ...days.map((_) => TableCell(child: SizedBox(height: 4))),
                  ],
                ),
            ],
          ],
        ),
      ),
      Divider(thickness: 1, height: 32),
    ],
  );
}
  String _formatNumberValue(double value) {
  if (value == value.toInt()) {
    // Display as integer if it's a whole number
    return value.toInt().toString();
  } else {
    // Display with 1 decimal place if it has fractional part
    return value.toStringAsFixed(1);
  }
}
// Extract the base CongThuongChu value without permission suffixes
String _extractCongThuongChuBase(String? value) {
  if (value == null) return 'Ro';
  if (value.endsWith('+P')) {
    return value.substring(0, value.length - 2);
  } else if (value.endsWith('+P/2')) {
    return value.substring(0, value.length - 4);
  }
  return value;
}

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red)
      );
    }
  }

  Widget _buildChuGioThuongSection() {
 final days = _getDaysInMonth();
 final employees = _getEmployeesWithValueInColumn('CongThuongChu');
 
 if (employees.isEmpty) {
   return SizedBox.shrink();
 }
 
 final ScrollController horizontalController = ScrollController();
 
 return Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
     Padding(
       padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
       child: Text(
         'Chữ & Giờ thường',
         style: TextStyle(
           fontSize: 18,
           fontWeight: FontWeight.bold,
           color: Colors.purple,
         ),
       ),
     ),
     
     Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           ElevatedButton.icon(
             onPressed: () {
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
                   double newOffset = (horizontalController.offset - 300);
                   if (newOffset < 0) newOffset = 0;
                   horizontalController.animateTo(
                     newOffset,
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
                   double newOffset = (horizontalController.offset + 300);
                   if (horizontalController.hasClients) {
                     double maxScroll = horizontalController.position.maxScrollExtent;
                     if (newOffset > maxScroll) newOffset = maxScroll;
                     horizontalController.animateTo(
                       newOffset,
                       duration: Duration(milliseconds: 300),
                       curve: Curves.easeOut,
                     );
                   }
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
               if (horizontalController.hasClients) {
                 horizontalController.animateTo(
                   horizontalController.position.maxScrollExtent,
                   duration: Duration(milliseconds: 300),
                   curve: Curves.easeOut,
                 );
               }
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
     
     SingleChildScrollView(
       controller: horizontalController,
       scrollDirection: Axis.horizontal,
       child: Table(
         border: TableBorder(
           horizontalInside: BorderSide(color: Colors.grey.shade300),
           verticalInside: BorderSide(color: Colors.grey.shade300),
           bottom: BorderSide(color: Colors.grey.shade300),
           right: BorderSide(color: Colors.grey.shade300),
           left: BorderSide(color: Colors.grey.shade300),
           top: BorderSide(color: Colors.grey.shade300),
         ),
         columnWidths: {
           0: FixedColumnWidth(120),
           1: FixedColumnWidth(60),
           2: FixedColumnWidth(60),
           3: FixedColumnWidth(60),
           4: FixedColumnWidth(60),
           5: FixedColumnWidth(60),
           6: FixedColumnWidth(60),
           7: FixedColumnWidth(60),
           8: FixedColumnWidth(60),
           9: FixedColumnWidth(60),
           10: FixedColumnWidth(60),
           11: FixedColumnWidth(60),
           12: FixedColumnWidth(60),
           13: FixedColumnWidth(60),
           for (int i = 0; i < days.length; i++)
             i + 14: FixedColumnWidth(60),
         },
         defaultVerticalAlignment: TableCellVerticalAlignment.middle,
         children: [
           TableRow(
             decoration: BoxDecoration(color: Colors.grey.shade200),
             children: [
               TableCell(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(''))),
               TableCell(
                 verticalAlignment: TableCellVerticalAlignment.fill,
                 child: Container(
                   color: Colors.blue.shade100,
                   child: Center(child: Text('Ngày 1-15', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(child: Container(color: Colors.blue.shade100, child: Text(''))),
               TableCell(child: Container(color: Colors.blue.shade100, child: Text(''))),
               TableCell(
                 verticalAlignment: TableCellVerticalAlignment.fill,
                 child: Container(
                   color: Colors.green.shade100,
                   child: Center(child: Text('Ngày 16-25', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(child: Container(color: Colors.green.shade100, child: Text(''))),
               TableCell(child: Container(color: Colors.green.shade100, child: Text(''))),
               TableCell(
                 verticalAlignment: TableCellVerticalAlignment.fill,
                 child: Container(
                   color: Colors.orange.shade100,
                   child: Center(child: Text('Tổng tháng', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
               TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
               TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
               TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
               TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
               TableCell(child: Container(color: Colors.orange.shade100, child: Text(''))),
               ...days.map((_) => TableCell(child: Text(''))),
             ],
           ),
           TableRow(
             decoration: BoxDecoration(color: Colors.grey.shade200),
             children: [
               TableCell(
                 child: Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: Text('Mã NV', style: TextStyle(fontWeight: FontWeight.bold)),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.blue.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('Tuần 1+2', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.blue.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('P1+2', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.blue.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('HT1+2', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.green.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('Tuần 3+4', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.green.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('P3+4', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.green.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('HT3+4', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.orange.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('Công', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.orange.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('Phép', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.orange.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('Lễ', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.orange.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('HV', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.orange.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('Đêm', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.orange.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('CĐ', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               TableCell(
                 child: Container(
                   color: Colors.orange.shade100,
                   padding: EdgeInsets.all(8.0),
                   child: Center(child: Text('HT', style: TextStyle(fontWeight: FontWeight.bold))),
                 ),
               ),
               ...days.map((day) => TableCell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              _formatNumberValue(_calculateDailyTotal(day)),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              day.toString(), 
              style: TextStyle(fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    )),
  ],
),
           for (var empId in employees) ...[
             TableRow(
               decoration: BoxDecoration(
                 color: _staffColors[empId] ?? Colors.transparent,
               ),
               children: [
                 TableCell(
                   child: Padding(
                     padding: const EdgeInsets.all(8.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(empId, style: TextStyle(fontWeight: FontWeight.bold)),
                         Text(
                           _staffNames[empId] ?? '',
                           style: TextStyle(
                             fontSize: 12,
                             color: Colors.grey[600],
                           ),
                         ),
                         Text(
                           'Công chữ',
                           style: TextStyle(
                             fontSize: 10,
                             color: Colors.grey[700],
                             fontStyle: FontStyle.italic,
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),
                 ...(() {
                   final summary = _calculateSummary(empId);
                   return [
                     TableCell(
                       child: Container(
                         color: Colors.blue.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['tuan12'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.blue.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['p12'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.blue.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['ht12'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.green.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['tuan34'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.green.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['p34'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.green.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['ht34'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.orange.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['cong'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.orange.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['phep'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.orange.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['le'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.orange.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['hv'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.orange.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['dem'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.orange.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['cd'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.orange.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(
                           child: Text(
                             summary['ht'] ?? '',
                             style: TextStyle(fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                     ),
                   ];
                 })(),
                 ...days.map((day) {
                   final value = _getAttendanceForDay(empId, day, 'CongThuongChu');
                   final displayValue = (value == 'Ro') ? '' : value;
                   
                   return TableCell(
                     child: Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: Center(
                         child: Text(
                           displayValue ?? '',
                           style: TextStyle(
                             color: (displayValue != null && displayValue.isNotEmpty) 
                               ? Colors.blue 
                               : null,
                             fontWeight: (displayValue != null && displayValue.isNotEmpty) 
                               ? FontWeight.bold 
                               : null,
                           ),
                         ),
                       ),
                     ),
                   );
                 }),
               ],
             ),
             TableRow(
               decoration: BoxDecoration(
                 color: _staffColors[empId] != null 
                   ? _staffColors[empId]!.withOpacity(0.7) 
                   : Colors.grey.shade50,
               ),
               children: [
                 TableCell(
                   child: Padding(
                     padding: const EdgeInsets.all(8.0),
                     child: Text(
                       'NG thường',
                       style: TextStyle(
                         fontSize: 10,
                         color: Colors.grey[700],
                         fontStyle: FontStyle.italic,
                       ),
                     ),
                   ),
                 ),
                 ...(() {
                   final summary = _calculateSummary(empId);
                   
                   return [
                     TableCell(
                       child: Container(
                         color: Colors.blue.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(child: Text(summary['ng_days12'] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.blue.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Text(''),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.blue.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Text(''),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.green.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(child: Text(summary['ng_days34'] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.green.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Text(''),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.green.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Text(''),
                       ),
                     ),
                     TableCell(
                       child: Container(
                         color: Colors.orange.shade50,
                         padding: EdgeInsets.all(8.0),
                         child: Center(child: Text(summary['ng_total'] ?? '', style: TextStyle(fontWeight: FontWeight.bold))),
                       ),
                     ),
                     ...List.generate(6, (index) => 
                       TableCell(
                         child: Container(
                           color: Colors.orange.shade50,
                           padding: EdgeInsets.all(8.0),
                           child: Text(''),
                         ),
                       )
                     ),
                   ];
                 })(),
                 ...days.map((day) {
                   final value = _getAttendanceForDay(empId, day, 'NgoaiGioThuong');
                   final displayValue = (value == '0') ? '' : value;
                   
                   return TableCell(
                     child: Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: Center(
                         child: Text(
                           displayValue ?? '',
                           style: TextStyle(
                             color: (displayValue != null && displayValue.isNotEmpty) 
                               ? Colors.blue 
                               : null,
                             fontWeight: (displayValue != null && displayValue.isNotEmpty) 
                               ? FontWeight.bold 
                               : null,
                           ),
                         ),
                       ),
                     ),
                   );
                 }),
               ],
             ),
             if (empId != employees.last)
               TableRow(
                 children: [
                   TableCell(
                     child: SizedBox(height: 4),
                   ),
                   ...List.generate(13, (index) => 
                     TableCell(
                       child: SizedBox(height: 4),
                     )
                   ),
                   ...days.map((_) => TableCell(
                     child: SizedBox(height: 4),
                   )),
                 ],
               ),
           ],
         ],
       ),
     ),
     Divider(thickness: 1, height: 32),
   ],
 );
}

  Widget _buildCombinedView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChuGioThuongSection(),
          _buildRegularSection('HoTro', 'Hỗ trợ'),
          _buildRegularSection('PartTime', 'Part time'),
          _buildRegularSection('PartTimeSang', 'PT sáng'),
          _buildRegularSection('PartTimeChieu', 'PT chiều'),
          _buildRegularSection('NgoaiGioKhac', 'NG khác'),
          _buildRegularSection('NgoaiGiox15', 'NG x1.5'),
          _buildRegularSection('NgoaiGiox2', 'NG x2'),
          _buildRegularSection('CongLe', 'Công lễ'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: Colors.green,
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
),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton(
                         onPressed: _generateAutomaticLeave,
                          child: Text('Tạo Phép tự động'),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _exportPdf,
                          child: Text('Xuất PDF'),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _exportExcel,
                          child: Text('Xuất Excel'),
                        ),
                         SizedBox(width: 10),
                         SizedBox(width: 10),
        ElevatedButton(
          onPressed: _exportExcelAllProjects,
          child: Text('Xuất Excel 100%'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectWorkerAutoCLThang(
                  selectedBoPhan: _selectedDepartment ?? '',
                  username: widget.username,
                  selectedMonth: _selectedMonth ?? '',
                ),
              ),
            );
          },
          child: Text('Tạo tổng hợp tháng'),
                    style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
          ),
        ),
        SizedBox(width: 10),
        ElevatedButton(
          onPressed: _syncChamCongCNThang,
          child: Text('Đồng bộ lại 100%'),
        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin đồng bộ:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                'Số bản ghi tháng này', 
                                '${_syncStats['monthRecords'] ?? 0}'
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                'Số dự án', 
                                '${_syncStats['uniqueProjects'] ?? 0}'
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                'Cập nhật lần cuối', 
                                '${_syncStats['lastUpdate'] ?? "Chưa cập nhật"}'
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                'Nhân viên dự án hiện tại', 
                                '${_syncStats['projectStaffCount'] ?? 0}'
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _buildCombinedView(),
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
  Future<void> _exportExcelAllProjects() async {
  setState(() => _isLoading = true);
  
  try {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Đang xuất Excel cho tất cả dự án'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Vui lòng đợi trong giây lát...')
            ],
          ),
        );
      },
    );
    
    // Get all departments that have data for the selected month
    final dbHelper = DBHelper();
    final projectsWithData = await dbHelper.rawQuery('''
      SELECT DISTINCT BoPhan FROM chamcongcn 
      WHERE strftime('%Y-%m', Ngay) = ?
      ORDER BY BoPhan
    ''', [_selectedMonth]);
    
    final projectsList = projectsWithData.map((p) => p['BoPhan'] as String).toList();
    
    // Close progress dialog
    Navigator.of(context).pop();
    
    if (projectsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tìm thấy dự án nào có dữ liệu cho tháng $_selectedMonth'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }
    
    // Use the helper to export all projects
    await ExportHelper.exportAllProjectsToExcel(
      projects: projectsList,
      selectedMonth: _selectedMonth ?? '',
      loadProjectData: (project) async {
        setState(() {
          _selectedDepartment = project;
        });
        await _loadAttendanceData();
      },
      getUniqueEmployees: _getUniqueEmployees,
      getStaffNames: () => _staffNames,
      getEmployeesWithValueInColumn: _getEmployeesWithValueInColumn,
      getDaysInMonth: _getDaysInMonth,
      getAttendanceForDay: _getAttendanceForDay,
      calculateSummary: _calculateSummary,
      context: context,
    );
    
  } catch (e) {
    print('Excel all projects export error: $e');
    _showError('Lỗi khi xuất Excel tất cả dự án: $e');
    
    // Make sure dialog is closed in case of error
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
  
  setState(() => _isLoading = false);
}
  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _syncChamCongCNThang({bool silent = false}) async {
    // Skip confirmation if in silent mode
    bool proceed = silent;
    
    if (!silent) {
      proceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Đồng bộ dữ liệu'),
            content: Text(
              'Quá trình này sẽ đồng bộ toàn bộ dữ liệu tổng hợp chấm công từ máy chủ. '
              'Tiếp tục?'
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
      ) ?? false;
    }
    
    if (!proceed) return;
    
    if (!silent) {
      setState(() => _isLoading = true);
    }
    
    try {
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongcnthangfull'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Process and insert data into the database
        final dbHelper = DBHelper();
        
        // Begin transaction
        final db = await dbHelper.database;
        await db.transaction((txn) async {
          final batch = txn.batch();
          
          // First clear existing data
          batch.execute('DELETE FROM ChamCongCNThang');
          
          // Insert new data
          for (var item in data) {
            // Rename fields to match SQLite column names
            final modifiedItem = Map<String, dynamic>.from(item);
            
            if (modifiedItem.containsKey('Tuan_1va2')) modifiedItem['Tuan1va2'] = modifiedItem.remove('Tuan_1va2');
            if (modifiedItem.containsKey('Phep_1va2')) modifiedItem['Phep1va2'] = modifiedItem.remove('Phep_1va2');
            if (modifiedItem.containsKey('HT_1va2')) modifiedItem['HT1va2'] = modifiedItem.remove('HT_1va2');
            if (modifiedItem.containsKey('Tuan_3va4')) modifiedItem['Tuan3va4'] = modifiedItem.remove('Tuan_3va4');
            if (modifiedItem.containsKey('Phep_3va4')) modifiedItem['Phep3va4'] = modifiedItem.remove('Phep_3va4');
            if (modifiedItem.containsKey('HT_3va4')) modifiedItem['HT3va4'] = modifiedItem.remove('HT_3va4');
            
            // Convert to ChamCongCNThangModel and insert
            final model = ChamCongCNThangModel.fromMap(modifiedItem);
            batch.insert(
              'ChamCongCNThang', 
              model.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace
            );
          }
          
          await batch.commit(noResult: true);
        });
        
        // Update last sync time
        setState(() {
          _lastSyncTime = DateTime.now();
        });
        
        // Update sync stats
        await _updateSyncStats();
        
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đồng bộ dữ liệu thành công'), backgroundColor: Colors.green)
          );
        }
      } else {
        if (!silent) {
          _showError('Lỗi khi đồng bộ dữ liệu: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error syncing data: $e');
      if (!silent) {
        _showError('Lỗi khi đồng bộ dữ liệu: $e');
      }
    } finally {
      if (!silent) {
        setState(() => _isLoading = false);
      }
    }
  }
}