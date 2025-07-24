import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'export_helper.dart';
import 'projectworkerphep.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'projectworkerpc.dart';
import 'http_client.dart';
import 'package:table_sticky_headers/table_sticky_headers.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedDepartment = widget.selectedBoPhan;
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final dbHelper = DBHelper();
      
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

      final existingDepts = await dbHelper.rawQuery(
        'SELECT DISTINCT BoPhan FROM chamcongcn ORDER BY BoPhan'
      );
      _departments.addAll(existingDepts.map((e) => e['BoPhan'] as String));
      _departments = _departments.toSet().toList()..sort();
      
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
    } catch (e) {
      print('Init error: $e');
      _showError('Không thể tải dữ liệu');
    }
    setState(() => _isLoading = false);
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

    final Map<String, String> fetchedNames = {
      for (var row in result) row['MaNV'] as String: row['Ho_ten'] as String
    };

    final Map<String, String> staffNames = {
      for (var id in employeeIds) id: fetchedNames[id] ?? "???"
    };

    setState(() {
      _staffNames = staffNames;
    });
  }

  Future<void> _generateAutomaticLeave() async {
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
            username: widget.username,
            selectedMonth: _selectedMonth ?? '',
          ),
        ),
      );
      
      if (result == true) {
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

  List<String> _getEmployeesWithValueInColumn(String columnType) {
    final days = _getDaysInMonth();
    final allEmployees = _getUniqueEmployees();
    
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

  void _updateWeekData(
    double phanLoaiValue, String baseCongThuongChu, bool hasFullPermission, bool hasHalfPermission,
    double ngoaiGioThuong, double hoTro, double partTime, double partTimeSang, double partTimeChieu,
    double ngoaiGioKhac, double ngoaiGiox15, double ngoaiGiox2, double congLe,
    Function regularUpdate, Function permissionP, Function permissionPHalf,
    Function permissionFull, Function permissionHalf, Function htUpdate,
    Function ngUpdate, Function hoTroUpdate, Function partTimeUpdate,
    Function ptSangUpdate, Function ptChieuUpdate, Function ngKhacUpdate,
    Function ng15Update, Function ng2Update, Function congLeUpdate,
  ) {
    if (phanLoaiValue > 0) regularUpdate();
    if (baseCongThuongChu == 'P') permissionP();
    if (baseCongThuongChu == 'P/2') permissionPHalf();
    if (hasFullPermission) permissionFull();
    if (hasHalfPermission) permissionHalf();
    if (baseCongThuongChu == 'HT') htUpdate();
    if (ngoaiGioThuong > 0) ngUpdate();
    if (hoTro > 0) hoTroUpdate();
    if (partTime > 0) partTimeUpdate();
    if (partTimeSang > 0) ptSangUpdate();
    if (partTimeChieu > 0) ptChieuUpdate();
    if (ngoaiGioKhac > 0) ngKhacUpdate();
    if (ngoaiGiox15 > 0) ng15Update();
    if (ngoaiGiox2 > 0) ng2Update();
    if (congLe > 0) congLeUpdate();
  }

  Map<String, dynamic> _calculateSummary(String empId) {
    if (_selectedMonth == null) return {};
    double tongHV = 0;
    double tongDem = 0;
    double tongCD = 0;

    final days = _getDaysInMonth();
    
    double congChu_regularDays1 = 0, congChu_permissionDays1 = 0, congChu_htDays1 = 0;
    double congChu_regularDays2 = 0, congChu_permissionDays2 = 0, congChu_htDays2 = 0;
    double congChu_regularDays3 = 0, congChu_permissionDays3 = 0, congChu_htDays3 = 0;
    double congChu_regularDays4 = 0, congChu_permissionDays4 = 0, congChu_htDays4 = 0;
    
    double ngThuong_days1 = 0, ngThuong_days2 = 0, ngThuong_days3 = 0, ngThuong_days4 = 0;
    double hoTro_days1 = 0, hoTro_days2 = 0, hoTro_days3 = 0, hoTro_days4 = 0;
    double partTime_days1 = 0, partTime_days2 = 0, partTime_days3 = 0, partTime_days4 = 0;
    double ptSang_days1 = 0, ptSang_days2 = 0, ptSang_days3 = 0, ptSang_days4 = 0;
    double ptChieu_days1 = 0, ptChieu_days2 = 0, ptChieu_days3 = 0, ptChieu_days4 = 0;
    double ngKhac_days1 = 0, ngKhac_days2 = 0, ngKhac_days3 = 0, ngKhac_days4 = 0;
    double ng15_days1 = 0, ng15_days2 = 0, ng15_days3 = 0, ng15_days4 = 0;
    double ng2_days1 = 0, ng2_days2 = 0, ng2_days3 = 0, ng2_days4 = 0;
    double congLe_days1 = 0, congLe_days2 = 0, congLe_days3 = 0, congLe_days4 = 0;

    for (int day = 1; day <= days.length; day++) {
      final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
      
      final recordList = _attendanceData.where(
        (record) => 
          record['MaNV'] == empId && 
          record['Ngay'].split('T')[0] == dateStr
      ).toList();
      
      if (recordList.isEmpty) continue;
      final record = recordList.first;

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
        tongDem += baseCongThuongChu.startsWith('2') ? 2.0 : 1.0;
      }

      final bool hasFullPermission = congThuongChu.endsWith('+P');
      final bool hasHalfPermission = congThuongChu.endsWith('+P/2');

      double phanLoaiValue = 0;
      if (phanLoai.isNotEmpty) {
        try {
          phanLoaiValue = double.parse(phanLoai);
        } catch (e) {
          print("Error parsing PhanLoai: $e");
        }
      }

      if (day <= 7) {
        _updateWeekData(
          phanLoaiValue, baseCongThuongChu, hasFullPermission, hasHalfPermission,
          ngoaiGioThuong, hoTro, partTime, partTimeSang, partTimeChieu,
          ngoaiGioKhac, ngoaiGiox15, ngoaiGiox2, congLe,
          () => congChu_regularDays1 += phanLoaiValue,
          () => congChu_permissionDays1 += 1.0,
          () => congChu_permissionDays1 += 0.5,
          () => congChu_permissionDays1 += 1.0,
          () => congChu_permissionDays1 += 0.5,
          () => congChu_htDays1 += 1.0,
          () => ngThuong_days1 += ngoaiGioThuong / 8,
          () => hoTro_days1 += hoTro / 8,
          () => partTime_days1 += partTime,
          () => ptSang_days1 += partTimeSang,
          () => ptChieu_days1 += partTimeChieu,
          () => ngKhac_days1 += ngoaiGioKhac / 8,
          () => ng15_days1 += ngoaiGiox15 / 8,
          () => ng2_days1 += ngoaiGiox2 / 8,
          () => congLe_days1 += congLe / 8,
        );
      } else if (day <= 15) {
        _updateWeekData(
          phanLoaiValue, baseCongThuongChu, hasFullPermission, hasHalfPermission,
          ngoaiGioThuong, hoTro, partTime, partTimeSang, partTimeChieu,
          ngoaiGioKhac, ngoaiGiox15, ngoaiGiox2, congLe,
          () => congChu_regularDays2 += phanLoaiValue,
          () => congChu_permissionDays2 += 1.0,
          () => congChu_permissionDays2 += 0.5,
          () => congChu_permissionDays2 += 1.0,
          () => congChu_permissionDays2 += 0.5,
          () => congChu_htDays2 += 1.0,
          () => ngThuong_days2 += ngoaiGioThuong / 8,
          () => hoTro_days2 += hoTro / 8,
          () => partTime_days2 += partTime,
          () => ptSang_days2 += partTimeSang,
          () => ptChieu_days2 += partTimeChieu,
          () => ngKhac_days2 += ngoaiGioKhac / 8,
          () => ng15_days2 += ngoaiGiox15 / 8,
          () => ng2_days2 += ngoaiGiox2 / 8,
          () => congLe_days2 += congLe / 8,
        );
      } else if (day <= 22) {
        _updateWeekData(
          phanLoaiValue, baseCongThuongChu, hasFullPermission, hasHalfPermission,
          ngoaiGioThuong, hoTro, partTime, partTimeSang, partTimeChieu,
          ngoaiGioKhac, ngoaiGiox15, ngoaiGiox2, congLe,
          () => congChu_regularDays3 += phanLoaiValue,
          () => congChu_permissionDays3 += 1.0,
          () => congChu_permissionDays3 += 0.5,
          () => congChu_permissionDays3 += 1.0,
          () => congChu_permissionDays3 += 0.5,
          () => congChu_htDays3 += 1.0,
          () => ngThuong_days3 += ngoaiGioThuong / 8,
          () => hoTro_days3 += hoTro / 8,
          () => partTime_days3 += partTime,
          () => ptSang_days3 += partTimeSang,
          () => ptChieu_days3 += partTimeChieu,
          () => ngKhac_days3 += ngoaiGioKhac / 8,
          () => ng15_days3 += ngoaiGiox15 / 8,
          () => ng2_days3 += ngoaiGiox2 / 8,
          () => congLe_days3 += congLe / 8,
        );
      } else {
        _updateWeekData(
          phanLoaiValue, baseCongThuongChu, hasFullPermission, hasHalfPermission,
          ngoaiGioThuong, hoTro, partTime, partTimeSang, partTimeChieu,
          ngoaiGioKhac, ngoaiGiox15, ngoaiGiox2, congLe,
          () => congChu_regularDays4 += phanLoaiValue,
          () => congChu_permissionDays4 += 1.0,
          () => congChu_permissionDays4 += 0.5,
          () => congChu_permissionDays4 += 1.0,
          () => congChu_permissionDays4 += 0.5,
          () => congChu_htDays4 += 1.0,
          () => ngThuong_days4 += ngoaiGioThuong / 8,
          () => hoTro_days4 += hoTro / 8,
          () => partTime_days4 += partTime,
          () => ptSang_days4 += partTimeSang,
          () => ptChieu_days4 += partTimeChieu,
          () => ngKhac_days4 += ngoaiGioKhac / 8,
          () => ng15_days4 += ngoaiGiox15 / 8,
          () => ng2_days4 += ngoaiGiox2 / 8,
          () => congLe_days4 += congLe / 8,
        );
      }
    }
    
    congChu_regularDays1 = congChu_regularDays1 - congChu_permissionDays1;
    if (congChu_regularDays1 < 0) congChu_regularDays1 = 0;

    congChu_regularDays2 = congChu_regularDays2 - congChu_permissionDays2;
    if (congChu_regularDays2 < 0) congChu_regularDays2 = 0;

    congChu_regularDays3 = congChu_regularDays3 - congChu_permissionDays3;
    if (congChu_regularDays3 < 0) congChu_regularDays3 = 0;

    congChu_regularDays4 = congChu_regularDays4 - congChu_permissionDays4;
    if (congChu_regularDays4 < 0) congChu_regularDays4 = 0;

    final double congChu_totalPermission = congChu_permissionDays1 + congChu_permissionDays2 + congChu_permissionDays3 + congChu_permissionDays4;
    final double congChu_totalRegular = congChu_regularDays1 + congChu_regularDays2 + congChu_regularDays3 + congChu_regularDays4;
    final double congChu_totalHT = congChu_htDays1 + congChu_htDays2 + congChu_htDays3 + congChu_htDays4;
    
    final double ngThuong_total = ngThuong_days1 + ngThuong_days2 + ngThuong_days3 + ngThuong_days4;
    final double hoTro_total = hoTro_days1 + hoTro_days2 + hoTro_days3 + hoTro_days4;
    final double partTime_total = partTime_days1 + partTime_days2 + partTime_days3 + partTime_days4;
    final double ptSang_total = ptSang_days1 + ptSang_days2 + ptSang_days3 + ptSang_days4;
    final double ptChieu_total = ptChieu_days1 + ptChieu_days2 + ptChieu_days3 + ptChieu_days4;
    final double ngKhac_total = ngKhac_days1 + ngKhac_days2 + ngKhac_days3 + ngKhac_days4;
    final double ng15_total = ng15_days1 + ng15_days2 + ng15_days3 + ng15_days4;
    final double ng2_total = ng2_days1 + ng2_days2 + ng2_days3 + ng2_days4;
    final double congLe_total = congLe_days1 + congLe_days2 + congLe_days3 + congLe_days4;
    
    return {
      'tuan1': _formatNumberValue(congChu_regularDays1),
      'p1': _formatNumberValue(congChu_permissionDays1),
     'ht1': _formatNumberValue(congChu_htDays1),
     'tuan2': _formatNumberValue(congChu_regularDays2),
     'p2': _formatNumberValue(congChu_permissionDays2),
     'ht2': _formatNumberValue(congChu_htDays2),
     'tuan3': _formatNumberValue(congChu_regularDays3),
     'p3': _formatNumberValue(congChu_permissionDays3),
     'ht3': _formatNumberValue(congChu_htDays3),
     'tuan4': _formatNumberValue(congChu_regularDays4),
     'p4': _formatNumberValue(congChu_permissionDays4),
     'ht4': _formatNumberValue(congChu_htDays4),
     'cong': _formatNumberValue(congChu_totalRegular),
     'phep': _formatNumberValue(congChu_totalPermission),
     'ht': _formatNumberValue(congChu_totalHT),
     
     'ng_days1': _formatNumberValue(ngThuong_days1),
     'hotro_days1': _formatNumberValue(hoTro_days1),
     'pt_days1': _formatNumberValue(partTime_days1),
     'pts_days1': _formatNumberValue(ptSang_days1),
     'ptc_days1': _formatNumberValue(ptChieu_days1),
     'ngk_days1': _formatNumberValue(ngKhac_days1),
     'ng15_days1': _formatNumberValue(ng15_days1),
     'ng2_days1': _formatNumberValue(ng2_days1),
     'congle_days1': _formatNumberValue(congLe_days1),
     
     'ng_days2': _formatNumberValue(ngThuong_days2),
     'hotro_days2': _formatNumberValue(hoTro_days2),
     'pt_days2': _formatNumberValue(partTime_days2),
     'pts_days2': _formatNumberValue(ptSang_days2),
     'ptc_days2': _formatNumberValue(ptChieu_days2),
     'ngk_days2': _formatNumberValue(ngKhac_days2),
     'ng15_days2': _formatNumberValue(ng15_days2),
     'ng2_days2': _formatNumberValue(ng2_days2),
     'congle_days2': _formatNumberValue(congLe_days2),
     
     'ng_days3': _formatNumberValue(ngThuong_days3),
     'hotro_days3': _formatNumberValue(hoTro_days3),
     'pt_days3': _formatNumberValue(partTime_days3),
     'pts_days3': _formatNumberValue(ptSang_days3),
     'ptc_days3': _formatNumberValue(ptChieu_days3),
     'ngk_days3': _formatNumberValue(ngKhac_days3),
     'ng15_days3': _formatNumberValue(ng15_days3),
     'ng2_days3': _formatNumberValue(ng2_days3),
     'congle_days3': _formatNumberValue(congLe_days3),
     
     'ng_days4': _formatNumberValue(ngThuong_days4),
     'hotro_days4': _formatNumberValue(hoTro_days4),
     'pt_days4': _formatNumberValue(partTime_days4),
     'pts_days4': _formatNumberValue(ptSang_days4),
     'ptc_days4': _formatNumberValue(ptChieu_days4),
     'ngk_days4': _formatNumberValue(ngKhac_days4),
     'ng15_days4': _formatNumberValue(ng15_days4),
     'ng2_days4': _formatNumberValue(ng2_days4),
     'congle_days4': _formatNumberValue(congLe_days4),
     
     'ng_total': _formatNumberValue(ngThuong_total),
     'hotro_total': _formatNumberValue(hoTro_total),
     'pt_total': _formatNumberValue(partTime_total),
     'pts_total': _formatNumberValue(ptSang_total),
     'ptc_total': _formatNumberValue(ptChieu_total),
     'ngk_total': _formatNumberValue(ngKhac_total),
     'ng15_total': _formatNumberValue(ng15_total),
     'ng2_total': _formatNumberValue(ng2_total),
     'congle_total': _formatNumberValue(congLe_total),
     
     'le': _formatNumberValue(congLe_total),
     'hv': _formatNumberValue(tongHV),
     'dem': _formatNumberValue(tongDem),
     'cd': _formatNumberValue(tongCD),
   };
 }

 double _calculateDailyTotal(int day) {
   double total = 0.0;
   
   final allEmployees = _getUniqueEmployees();
   
   for (var empId in allEmployees) {
     final dateStr = '$_selectedMonth-${day.toString().padLeft(2, '0')}';
     
     final records = _attendanceData.where(
       (record) => 
         record['MaNV'] == empId && 
         record['Ngay'].split('T')[0] == dateStr
     ).toList();
     
     if (records.isEmpty) continue;
     final record = records.first;
     
     double phanLoaiValue = 0;
     if (record['PhanLoai'] != null && record['PhanLoai'].toString().isNotEmpty) {
       try {
         phanLoaiValue = double.parse(record['PhanLoai'].toString());
       } catch (e) {
         print("Error parsing PhanLoai: $e");
       }
     }
     
     final ngoaiGioThuong = double.tryParse(record['NgoaiGioThuong']?.toString() ?? '0') ?? 0;
     final ngoaiGioKhac = double.tryParse(record['NgoaiGioKhac']?.toString() ?? '0') ?? 0;
     final ngoaiGiox15 = double.tryParse(record['NgoaiGiox15']?.toString() ?? '0') ?? 0;
     final ngoaiGiox2 = double.tryParse(record['NgoaiGiox2']?.toString() ?? '0') ?? 0;
     
     final ngoaiGioTotal = (ngoaiGioThuong + ngoaiGioKhac + ngoaiGiox15 + ngoaiGiox2) / 8;
     
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
  
  // Determine summary keys based on column type
  String days1Key, days2Key, days3Key, days4Key, totalKey;
  bool showPermissionColumns = false;
  bool showLeColumn = false;
  
  switch (columnType) {
    case 'NgoaiGioThuong':
      days1Key = 'ng_days1';
      days2Key = 'ng_days2';
      days3Key = 'ng_days3';
      days4Key = 'ng_days4';
      totalKey = 'ng_total';
      break;
    case 'HoTro':
      days1Key = 'hotro_days1';
      days2Key = 'hotro_days2';
      days3Key = 'hotro_days3';
      days4Key = 'hotro_days4';
      totalKey = 'hotro_total';
      break;
    case 'PartTime':
      days1Key = 'pt_days1';
      days2Key = 'pt_days2';
      days3Key = 'pt_days3';
      days4Key = 'pt_days4';
      totalKey = 'pt_total';
      break;
    case 'PartTimeSang':
      days1Key = 'pts_days1';
      days2Key = 'pts_days2';
      days3Key = 'pts_days3';
      days4Key = 'pts_days4';
      totalKey = 'pts_total';
      break;
    case 'PartTimeChieu':
      days1Key = 'ptc_days1';
      days2Key = 'ptc_days2';
      days3Key = 'ptc_days3';
      days4Key = 'ptc_days4';
      totalKey = 'ptc_total';
      break;
    case 'NgoaiGioKhac':
      days1Key = 'ngk_days1';
      days2Key = 'ngk_days2';
      days3Key = 'ngk_days3';
      days4Key = 'ngk_days4';
      totalKey = 'ngk_total';
      break;
    case 'NgoaiGiox15':
      days1Key = 'ng15_days1';
      days2Key = 'ng15_days2';
      days3Key = 'ng15_days3';
      days4Key = 'ng15_days4';
      totalKey = 'ng15_total';
      break;
    case 'NgoaiGiox2':
      days1Key = 'ng2_days1';
      days2Key = 'ng2_days2';
      days3Key = 'ng2_days3';
      days4Key = 'ng2_days4';
      totalKey = 'ng2_total';
      break;
    case 'CongLe':
      days1Key = 'congle_days1';
      days2Key = 'congle_days2';
      days3Key = 'congle_days3';
      days4Key = 'congle_days4';
      totalKey = 'congle_total';
      break;
    default:
      days1Key = 'tuan1';
      days2Key = 'tuan2';
      days3Key = 'tuan3';
      days4Key = 'tuan4';
      totalKey = 'cong';
  }
  
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
      
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Text(
          'Sử dụng cử chỉ vuốt để di chuyển bảng',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
      
      Container(
        height: 400,
        child: StickyHeadersTable(
          columnsLength: days.length + 17, // +17 for summary columns
          rowsLength: employees.length,
          
          // Column headers
          columnsTitleBuilder: (i) {
            if (i >= 0 && i <= 16) {
              // Summary columns
              final summaryHeaders = [
                'Tuần 1', 'P1', 'HT1', 'Tuần 2', 'P2', 'HT2', 'Tuần 3', 'P3', 'HT3',
                'Tuần 4', 'P4', 'HT4', 'Công', 'Phép', 'Lễ', 'HV', 'Đêm'
              ];
              
              Color bgColor;
              if (i < 3) bgColor = Colors.blue.shade100;
              else if (i < 6) bgColor = Colors.green.shade100;
              else if (i < 9) bgColor = Colors.yellow.shade100;
              else if (i < 12) bgColor = Colors.red.shade100;
              else bgColor = Colors.orange.shade100;
              
              return Container(
                height: 60,
                width: 60,
                color: bgColor,
                alignment: Alignment.center,
                child: Text(
                  summaryHeaders[i],
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              );
            } else {
              // Day columns
              final dayIndex = i - 17;
              return Container(
                height: 60,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: Text(
                  days[dayIndex].toString(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              );
            }
          },
          
          // Row headers (employee info) - Much wider
          rowsTitleBuilder: (i) {
            final empId = employees[i];
            return Container(
              width: 200, // Much wider for staff names
              color: _staffColors[empId] ?? Colors.grey.shade100,
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    empId,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    _staffNames[empId] ?? '',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 3, // Allow more lines for long names
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
          
          // Content cells
          contentCellBuilder: (i, j) {
            final empId = employees[j];
            
            if (i >= 0 && i <= 16) {
              // Summary columns
              final summary = _calculateSummary(empId);
              final summaryKeys = [
                days1Key, 'p1', 'ht1', days2Key, 'p2', 'ht2', days3Key, 'p3', 'ht3',
                days4Key, 'p4', 'ht4', totalKey, 'phep', 'le', 'hv', 'dem'
              ];
              
              String value = summary[summaryKeys[i]] ?? '';
              
              Color bgColor;
              if (i < 3) bgColor = Colors.blue.shade50;
              else if (i < 6) bgColor = Colors.green.shade50;
              else if (i < 9) bgColor = Colors.yellow.shade50;
              else if (i < 12) bgColor = Colors.red.shade50;
              else bgColor = Colors.orange.shade50;
              
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: bgColor,
                ),
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            } else {
              // Data columns
              final dayIndex = i - 17;
              final day = days[dayIndex];
              final value = _getAttendanceForDay(empId, day, columnType) ?? '0';
              final displayValue = (value == '0') ? '' : value;
              
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: _staffColors[empId]?.withOpacity(0.1) ?? Colors.white,
                ),
                alignment: Alignment.center,
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: displayValue.isNotEmpty ? Colors.blue : Colors.grey,
                    fontWeight: displayValue.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              );
            }
          },
          
          // Legend cell
          legendCell: Container(
            color: Colors.purple,
            alignment: Alignment.center,
            child: Text(
              'Nhân viên',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          
          // Cell dimensions
          cellDimensions: CellDimensions.uniform(
            width: 85,
            height: 40,
          ),
        ),
      ),
      
      Divider(thickness: 1, height: 32),
    ],
  );
}
 String _formatNumberValue(double value) {
   if (value == value.toInt()) {
     return value.toInt().toString();
   } else {
     return value.toStringAsFixed(1);
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
        child: Text(
          'Sử dụng cử chỉ vuốt để di chuyển bảng',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
      
      Container(
        height: 600,
        child: StickyHeadersTable(
          columnsLength: days.length + 18, // +1 for row type + 17 for summary columns
          rowsLength: employees.length * 2, // 2 rows per employee
          
          // Column headers
          columnsTitleBuilder: (i) {
            if (i == 0) {
              // Row type column
              return Container(
                height: 80,
                width: 100,
                color: Colors.purple.shade100,
                alignment: Alignment.center,
                child: Text(
                  'Loại',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              );
            } else if (i >= 1 && i <= 17) {
              // Summary columns
              final summaryHeaders = [
                'Tuần 1', 'P1', 'HT1', 'Tuần 2', 'P2', 'HT2', 'Tuần 3', 'P3', 'HT3',
                'Tuần 4', 'P4', 'HT4', 'Công', 'Phép', 'Lễ', 'HV', 'Đêm'
              ];
              final headerIndex = i - 1;
              
              Color bgColor;
              if (headerIndex < 3) bgColor = Colors.blue.shade100;
              else if (headerIndex < 6) bgColor = Colors.green.shade100;
              else if (headerIndex < 9) bgColor = Colors.yellow.shade100;
              else if (headerIndex < 12) bgColor = Colors.red.shade100;
              else bgColor = Colors.orange.shade100;
              
              return Container(
                height: 80,
                width: 60,
                color: bgColor,
                alignment: Alignment.center,
                child: Text(
                  summaryHeaders[headerIndex],
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              );
            } else {
              // Day columns
              final dayIndex = i - 18;
              return Container(
                height: 80,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatNumberValue(_calculateDailyTotal(days[dayIndex])),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      days[dayIndex].toString(),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              );
            }
          },
          
          // Row headers (employee info only) - Much wider
          rowsTitleBuilder: (i) {
            final employeeIndex = i ~/ 2;
            final rowType = i % 2;
            final empId = employees[employeeIndex];
            
            if (rowType == 0) {
              // First row - Employee info
              return Container(
                width: 200, // Much wider for staff names
                color: _staffColors[empId] ?? Colors.grey.shade100,
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      empId,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      _staffNames[empId] ?? '',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      maxLines: 3, // Allow more lines for long names
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            } else {
              // Second row - Empty but with same background
              return Container(
                width: 200, // Much wider
                color: (_staffColors[empId] ?? Colors.grey.shade100).withOpacity(0.7),
                padding: EdgeInsets.all(8),
              );
            }
          },
          
          // Content cells
          contentCellBuilder: (i, j) {
            final employeeIndex = j ~/ 2;
            final rowType = j % 2;
            final empId = employees[employeeIndex];
            
            if (i == 0) {
              // First column - Row type labels
              String rowLabel;
              Color textColor;
              
              if (rowType == 0) {
                rowLabel = 'Công chữ';
                textColor = Colors.blue;
              } else {
                rowLabel = 'NG thường';
                textColor = Colors.orange;
              }
              
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                alignment: Alignment.center,
                child: Text(
                  rowLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            } else if (i >= 1 && i <= 17) {
              // Summary columns
              final summary = _calculateSummary(empId);
              final summaryKeys = [
                'tuan1', 'p1', 'ht1', 'tuan2', 'p2', 'ht2', 'tuan3', 'p3', 'ht3',
                'tuan4', 'p4', 'ht4', 'cong', 'phep', 'le', 'hv', 'dem'
              ];
              final summaryNGKeys = [
                'ng_days1', '', '', 'ng_days2', '', '', 'ng_days3', '', '',
                'ng_days4', '', '', 'ng_total', '', '', '', ''
              ];
              
              final keyIndex = i - 1;
              String value = '';
              
              if (rowType == 0) {
                // Công chữ row
                value = summary[summaryKeys[keyIndex]] ?? '';
              } else {
                // NG thường row
                value = summary[summaryNGKeys[keyIndex]] ?? '';
              }
              
              Color bgColor;
              if (keyIndex < 3) bgColor = Colors.blue.shade50;
              else if (keyIndex < 6) bgColor = Colors.green.shade50;
              else if (keyIndex < 9) bgColor = Colors.yellow.shade50;
              else if (keyIndex < 12) bgColor = Colors.red.shade50;
              else bgColor = Colors.orange.shade50;
              
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: bgColor,
                ),
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            } else {
              // Data columns
              final dayIndex = i - 18;
              final day = days[dayIndex];
              
              String value;
              Color textColor = Colors.black;
              
              if (rowType == 0) {
                // Công chữ row
                value = _getAttendanceForDay(empId, day, 'CongThuongChu') ?? 'Ro';
                value = (value == 'Ro') ? '' : value;
                textColor = Colors.blue;
              } else {
                // NG thường row
                value = _getAttendanceForDay(empId, day, 'NgoaiGioThuong') ?? '0';
                value = (value == '0') ? '' : value;
                textColor = Colors.orange;
              }
              
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: _staffColors[empId]?.withOpacity(0.1) ?? Colors.white,
                ),
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: TextStyle(
                    color: value.isNotEmpty ? textColor : Colors.grey,
                    fontWeight: value.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              );
            }
          },
          
          // Legend cell
          legendCell: Container(
            color: Colors.purple,
            alignment: Alignment.center,
            child: Text(
              'Nhân viên',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          
          // Cell dimensions
          cellDimensions: CellDimensions.uniform(
            width: 85,
            height: 40,
          ),
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
       backgroundColor: Colors.purple,
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
                         onPressed: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (context) => ProjectWorkerPC(
                                 username: widget.username,
                               ),
                             ),
                           );
                         },
                         child: Text('Tạo phụ cấp'),
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
                     ],
                   ),
                 ),
               ),
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Text(
                   'Chế độ xem dữ liệu - ${_selectedDepartment ?? ""}',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
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
}