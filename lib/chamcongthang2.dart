import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
class ChamCongThang2Screen extends StatefulWidget {
  final String username;
  final String userRole;
  final String approverUsername;

  const ChamCongThang2Screen({
    Key? key,
    required this.username,
    this.userRole = '',
    this.approverUsername = '',
  }) : super(key: key);

  @override
  _ChamCongThang2ScreenState createState() => _ChamCongThang2ScreenState();
}

class _ChamCongThang2ScreenState extends State<ChamCongThang2Screen> {
  String? _selectedMonth;
  List<String> _monthOptions = [];
  String? _selectedBranch;
  List<String> _branchOptions = [];
  List<Map<String, dynamic>> _attendanceData = [];
  List<Map<String, dynamic>> _otherCaseData = [];
  List<Map<String, dynamic>> _userData = [];
  List<Map<String, dynamic>> _predefinedWorkHoursData = [];
  bool _hasData = false;

  // Branch mapping for special users
  final Map<String, List<String>> _userBranchMap = {
    'hm.nguyenthu': ['MIENBAC'],
    'hm.nguyengiang': ['MIENBAC'],
    'hm.lethihoa': ['LYCHEE'],
    'hm.vovy': ['LYCHEE'],
    'hm.nguyenlua': ['MIENTRUNG'],
    'hm.nguyentoan2': ['SANXUAT', 'LYCHEE'],
    'hm.anhmanh': ['SANXUAT'],
    'hm.doannga': ['DANANG'],
    'hm.damlinh': ['MIENNAM', 'LYCHEE'],
    'hm.ngochuyen': ['MIENNAM'],
  };

  // Admin users who can see all branches
  final List<String> _adminUsers = [
    'hm.tason',
    'hm.quanganh',
  ];

  @override
  void initState() {
    super.initState();
    _generateMonthOptions();
    _generateBranchOptions();
  }

  void _generateMonthOptions() {
    final now = DateTime.now();
    _monthOptions = [];
    
    // Generate options for current year and past 1 year
    for (int year = now.year; year >= now.year - 1; year--) {
      for (int month = (year == now.year ? now.month : 12); month >= 1; month--) {
        final date = DateTime(year, month);
        final monthString = DateFormat('yyyy-MM').format(date);
        _monthOptions.add(monthString);
      }
    }
    
    // Set current month as default
    _selectedMonth = DateFormat('yyyy-MM').format(now);
  }

  void _generateBranchOptions() {
  setState(() {
    _branchOptions = [];
    
    // Add "Của tôi" as the first option for all users
    _branchOptions.add('Của tôi');
    
    // Check if user is admin
    if (_adminUsers.contains(widget.username)) {
      _branchOptions.add('Tất cả');
      
      // Add all unique branches from the map
      final allBranches = <String>{};
      _userBranchMap.values.forEach((branches) {
        allBranches.addAll(branches);
      });
      _branchOptions.addAll(allBranches.toList()..sort());
      
      // Default to "Của tôi" for everyone
      _selectedBranch = 'Của tôi';
    } else if (_userBranchMap.containsKey(widget.username)) {
      // Non-admin user - add only their assigned branches
      _branchOptions.addAll(_userBranchMap[widget.username]!);
      
      // Always set default to "Của tôi"
      _selectedBranch = 'Của tôi';
    } else {
      // For users not in the branch map, still set default
      _selectedBranch = 'Của tôi';
    }
  });
}

  Future<void> _showSyncConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đồng bộ ⚠️'),
        content: const Text(
          'Quá trình đồng bộ mất nhiều thời gian do cần tải toàn bộ lịch sử của chi nhánh đã chọn.⚠️ Lưu ý các máy yếu/cũ rất dễ đơ, vui lòng kiên nhẫn ⚠️ Bạn có muốn tiếp tục?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đồng bộ'),
          ),
        ],
      ),
    );

    if (confirm == true && _selectedMonth != null && _selectedBranch != null) {
      _startSyncProcess();
    }
  }

  Future<void> _startSyncProcess() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Đang đồng bộ dữ liệu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Bước 1: Đang tải dữ liệu chấm công...'),
              ],
            ),
          );
        },
      ),
    );

    try {
      // Step 1: Load attendance data
      await _loadAttendanceData();
      
      // Update dialog to step 2
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Đang đồng bộ dữ liệu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Bước 2: Đang tải dữ liệu trường hợp khác...'),
            ],
          ),
        ),
      );

      // Step 2: Load other case data
      await _loadOtherCaseData();
      
      // Update dialog to step 3
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Đang đồng bộ dữ liệu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Bước 3: Đang tải thông tin nhân viên...'),
            ],
          ),
        ),
      );

      // Step 3: Load user data
      await _loadUserData();
      
      // Update dialog to step 4
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Đang đồng bộ dữ liệu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Bước 4: Đang tải định mức công...'),
            ],
          ),
        ),
      );

      // Step 4: Load predefined work hours data
      await _loadPredefinedWorkHoursData();
      
      Navigator.of(context).pop();
      
      setState(() {
        _hasData = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đồng bộ dữ liệu thành công'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi đồng bộ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAttendanceData() async {
    final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongthangb1/');
    final requestBody = json.encode({
      'username': widget.username,
      'month': _selectedMonth,
      'branch': _selectedBranch,
    });

    print('Request Body: $requestBody');
    final response = await http.post(
      url,
      body: requestBody,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      setState(() {
        _attendanceData = data.cast<Map<String, dynamic>>();
      });
    } else {
      throw Exception('Failed to load attendance data');
    }
  }

  Future<void> _loadOtherCaseData() async {
    final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongthangb2/');
    final response = await http.post(
      url,
      body: json.encode({
        'username': widget.username,
        'month': _selectedMonth,
        'branch': _selectedBranch,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      setState(() {
        _otherCaseData = data.cast<Map<String, dynamic>>();
      });
    } else {
      throw Exception('Failed to load other case data');
    }
  }

  Future<void> _loadUserData() async {
    final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongthangb3/');
    final response = await http.post(
      url,
      body: json.encode({
        'username': widget.username,
        'month': _selectedMonth,
        'branch': _selectedBranch,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      setState(() {
        _userData = data.cast<Map<String, dynamic>>();
      });
    } else {
      throw Exception('Failed to load user data');
    }
  }

  Future<void> _loadPredefinedWorkHoursData() async {
    final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongthangb5/');
    final response = await http.post(
      url,
      body: json.encode({
        'username': widget.username,
        'month': _selectedMonth,
        'branch': _selectedBranch,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      setState(() {
        _predefinedWorkHoursData = data.cast<Map<String, dynamic>>();
      });
    } else {
      throw Exception('Failed to load predefined work hours data');
    }
  }

  Map<String, Map<String, String>> _buildUserLookup() {
  final lookup = <String, Map<String, String>>{};
  for (final user in _userData) {
    final username = user['username'];
    if (username != null) {
      lookup[username.toString()] = {
        'MaNhanVien': user['employee_id']?.toString() ?? '',
        'TenNhanVien': user['name']?.toString() ?? '',
        'BoPhan': '', // Initialize empty department field
      };
    }
  }
  
  // Add department information from _predefinedWorkHoursData
  for (final record in _predefinedWorkHoursData) {
    final nguoiDung = record['NguoiDung']?.toString() ?? '';
    final boPhan = record['bophan']?.toString() ?? '';
    
    if (nguoiDung.isNotEmpty && lookup.containsKey(nguoiDung) && boPhan.isNotEmpty) {
      lookup[nguoiDung]!['BoPhan'] = boPhan;
    }
  }
  
  return lookup;
}

  Future<void> _exportToExcel() async {
  final shouldContinue = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cảnh báo'),
      content: const Text(
        'Quá trình tính toán và xuất Excel có thể mất nhiều thời gian. '
        'Vui lòng đợi cho đến khi hoàn thành.'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Tiếp tục'),
        ),
      ],
    ),
  );

  if (shouldContinue != true) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Đang xử lý dữ liệu. Vui lòng đợi...'),
        ],
      ),
    ),
  );

  try {
    final excel = Excel.createExcel();
    
    final userLookup = _buildUserLookup();
    
    final selectedDateTime = DateFormat('yyyy-MM').parse(_selectedMonth!);
    final daysInMonth = DateTime(selectedDateTime.year, selectedDateTime.month + 1, 0).day;
    
    Sheet sheetSummary = excel['KetQuaCongThang'];
    
    // Update headers to include BoPhan
    final summaryHeaders = [
      'MaNhanVien',
      'TenNhanVien',
      'BoPhan',  // Add department column
      'NguoiDung',
      'TruongHop',
      'TongCong',
    ];
    
    for (int day = 1; day <= daysInMonth; day++) {
      summaryHeaders.add('D$day');
    }
    
    for (int i = 0; i < summaryHeaders.length; i++) {
      final cell = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = summaryHeaders[i];
    }
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(selectedDateTime.year, selectedDateTime.month, day);
      final weekday = _getVietnameseWeekday(date.weekday);
      final dayColumn = 6 + day - 1; // Update column index (increased by 1 due to BoPhan)
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: dayColumn, rowIndex: 1)).value = weekday;
    }
    
    final employees = <String, Map<String, String>>{};
    
    for (final record in _attendanceData) {
      final nguoiDung = record['NguoiDung']?.toString() ?? '';
      if (nguoiDung.isNotEmpty && userLookup.containsKey(nguoiDung)) {
        employees[nguoiDung] = userLookup[nguoiDung]!;
      }
    }
    
    for (final record in _otherCaseData) {
      final nguoiDung = record['NguoiDung']?.toString() ?? '';
      if (nguoiDung.isNotEmpty && userLookup.containsKey(nguoiDung)) {
        employees[nguoiDung] = userLookup[nguoiDung]!;
      }
    }
    
    String userToLog = employees.containsKey('hm.tason') ? 'hm.tason' : employees.keys.last;
    print('***** LOG: Will log calculations for user: $userToLog *****');
    
    if (_attendanceData.isNotEmpty) {
      print('\n***** SAMPLE _attendanceData structure *****');
      print(_attendanceData.first.keys.toList());
      print(_attendanceData.first);
    }
    
    if (_otherCaseData.isNotEmpty) {
      print('\n***** SAMPLE _otherCaseData structure *****');
      print(_otherCaseData.first.keys.toList());
      print(_otherCaseData.first);
    }
    
    if (_predefinedWorkHoursData.isNotEmpty) {
      print('\n***** SAMPLE _predefinedWorkHoursData structure *****');
      print(_predefinedWorkHoursData.first.keys.toList());
      print(_predefinedWorkHoursData.first);
    }
    
    int currentRow = 2;
    final truongHopTypes = ['ChamCong', 'VangNghi', 'TangCa', 'DiMuon'];
    
    for (final entry in employees.entries) {
      final nguoiDung = entry.key;
      final userInfo = entry.value;
      
      bool shouldLog = nguoiDung == userToLog;
      
      final chamCongValues = <double>[];
      final vangNghiValues = <double>[];
      final diMuonValues = <double>[];  // Add array to store DiMuon values
      
      for (final truongHop in truongHopTypes) {
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = userInfo['MaNhanVien'];
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = userInfo['TenNhanVien'];
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = userInfo['BoPhan']; // Add department
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = nguoiDung;
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = truongHop;
        
        if (shouldLog) {
          print('\n***** LOG: Processing $truongHop for user $nguoiDung *****');
        }
        
        double tongCong = 0;
        
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(selectedDateTime.year, selectedDateTime.month, day);
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          
          double value = 0;
          
          switch (truongHop) {
            case 'ChamCong':
              value = _calculateChamCong(nguoiDung, dateStr, date.weekday);
              chamCongValues.add(value);
              break;
            case 'VangNghi':
              value = _calculateVangNghi(nguoiDung, dateStr);
              vangNghiValues.add(value);
              break;
            case 'TangCa':
              value = _calculateTangCa(nguoiDung, dateStr);
              break;
            case 'DiMuon':
              value = _calculateDiMuon(nguoiDung, dateStr);
              diMuonValues.add(value);  // Store DiMuon values
              break;
          }
          
          if (shouldLog) {
            print('Day $day ($dateStr) - $truongHop: $value');
            if (truongHop == 'ChamCong') {
              double maxValue = _getMaxWorkHours(nguoiDung, date.weekday);
              print('  Max value for ${_getVietnameseWeekday(date.weekday)}: $maxValue');
            }
          }
          
          final dayColumn = 6 + day - 1; // Update column index (increased by 1 due to BoPhan)
          sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: dayColumn, rowIndex: currentRow)).value = value;
          tongCong += value;
        }
        
        if (shouldLog) {
          print('$truongHop total: $tongCong');
        }
        
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = tongCong; // Update column index
        
        currentRow++;
      }
      
      // Update TruTienDiMuon row with department
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = userInfo['MaNhanVien'];
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = userInfo['TenNhanVien'];
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = userInfo['BoPhan']; // Add department
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = nguoiDung;
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = 'TruTienDiMuon';
      
      if (shouldLog) {
        print('\n***** LOG: Processing TruTienDiMuon for user $nguoiDung *****');
      }
      
      double totalPenalty = 0;
      
      for (int day = 1; day <= daysInMonth; day++) {
        final diMuonValue = diMuonValues[day - 1];
        double penalty = 0;
        
        // Apply penalty rules
        if (diMuonValue >= 3 && diMuonValue < 5) {
          penalty = 30000;
        } else if (diMuonValue >= 5 && diMuonValue < 10) {
          penalty = 50000;
        } else if (diMuonValue >= 10 && diMuonValue < 30) {
          penalty = 70000;
        } else if (diMuonValue >= 30) {
          penalty = 100000;
        }
        
        if (shouldLog) {
          print('Day $day - DiMuon: $diMuonValue, Penalty: $penalty');
        }
        
        final dayColumn = 6 + day - 1; // Update column index (increased by 1 due to BoPhan)
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: dayColumn, rowIndex: currentRow)).value = penalty;
        totalPenalty += penalty;
      }
      
      if (shouldLog) {
        print('TruTienDiMuon total: $totalPenalty');
      }
      
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = totalPenalty; // Update column index
      
      currentRow++;
      
      // Update SoPhepSuDung row with department
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = userInfo['MaNhanVien'];
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = userInfo['TenNhanVien'];
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = userInfo['BoPhan']; // Add department
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = nguoiDung;
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = 'SoPhepSuDung';
      
      if (shouldLog) {
        print('\n***** LOG: Processing SoPhepSuDung for user $nguoiDung *****');
      }
      
      double soPhepTotal = 0;
      
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(selectedDateTime.year, selectedDateTime.month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        double value = _calculateSoPhepSuDung(nguoiDung, dateStr);
        
        if (shouldLog) {
          print('Day $day ($dateStr) - SoPhepSuDung: $value');
        }
        
        final dayColumn = 6 + day - 1; // Update column index (increased by 1 due to BoPhan)
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: dayColumn, rowIndex: currentRow)).value = value;
        soPhepTotal += value;
      }
      
      if (shouldLog) {
        print('SoPhepSuDung total: $soPhepTotal');
      }
      
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = soPhepTotal; // Update column index
      
      currentRow++;
      
      // Update TongCong row with department
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = userInfo['MaNhanVien'];
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = userInfo['TenNhanVien'];
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = userInfo['BoPhan']; // Add department
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = nguoiDung;
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = 'TongCong';
      
      if (shouldLog) {
        print('\n***** LOG: Processing final TongCong for user $nguoiDung *****');
      }
      
      double tongCongTotal = 0;
      
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(selectedDateTime.year, selectedDateTime.month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        double maxValue = _getMaxWorkHours(nguoiDung, date.weekday);
        
        double combined = chamCongValues[day - 1] + vangNghiValues[day - 1];
        double finalValue = combined > maxValue ? maxValue : combined;
        
        if (shouldLog) {
          print('Day $day ($dateStr) - TongCong: ChamCong=${chamCongValues[day - 1]}, VangNghi=${vangNghiValues[day - 1]}, Combined=$combined, Max=$maxValue, Final=$finalValue');
        }
        
        final dayColumn = 6 + day - 1; // Update column index (increased by 1 due to BoPhan)
        sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: dayColumn, rowIndex: currentRow)).value = finalValue;
        tongCongTotal += finalValue;
      }
      
      if (shouldLog) {
        print('TongCong total: $tongCongTotal');
      }
      
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = tongCongTotal; // Update column index
      
      currentRow++;
    }
    
    // Update DinhMucCongNhat sheet to include department column
    Sheet sheetDinhMuc = excel['DinhMucCongNhat'];
    
    if (_predefinedWorkHoursData.isNotEmpty) {
      final headers = <String>['MaNhanVien', 'TenNhanVien', 'BoPhan', ..._predefinedWorkHoursData.first.keys];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheetDinhMuc.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
      }
      
      for (int row = 0; row < _predefinedWorkHoursData.length; row++) {
        final record = _predefinedWorkHoursData[row];
        final nguoiDung = record['NguoiDung']?.toString() ?? '';
        final userInfo = userLookup[nguoiDung] ?? {'MaNhanVien': '', 'TenNhanVien': '', 'BoPhan': ''};
        
        final cellMaNV = sheetDinhMuc.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1));
        cellMaNV.value = userInfo['MaNhanVien'];
        
        final cellTenNV = sheetDinhMuc.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row + 1));
        cellTenNV.value = userInfo['TenNhanVien'];
        
        final cellBoPhan = sheetDinhMuc.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row + 1));
        cellBoPhan.value = userInfo['BoPhan'];
        
        int col = 3; // Start from column 3 (after BoPhan)
        for (final key in _predefinedWorkHoursData.first.keys) {
          final cell = sheetDinhMuc.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
          cell.value = record[key];
          col++;
        }
      }
    }
    
    // Update the rest of the sheets (keep existing code but modify to include department)
    Sheet sheetAttendance = excel['LichSuCham'];
    
    if (_attendanceData.isNotEmpty) {
      final headers = <String>['MaNhanVien', 'TenNhanVien', 'BoPhan', ..._attendanceData.first.keys];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheetAttendance.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
      }
      
      for (int row = 0; row < _attendanceData.length; row++) {
        final record = _attendanceData[row];
        final nguoiDung = record['NguoiDung']?.toString() ?? '';
        final userInfo = userLookup[nguoiDung] ?? {'MaNhanVien': '', 'TenNhanVien': '', 'BoPhan': ''};
        
        final cellMaNV = sheetAttendance.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1));
        cellMaNV.value = userInfo['MaNhanVien'];
        
        final cellTenNV = sheetAttendance.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row + 1));
        cellTenNV.value = userInfo['TenNhanVien'];
        
        final cellBoPhan = sheetAttendance.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row + 1));
        cellBoPhan.value = userInfo['BoPhan'];
        
        int col = 3; // Start from column 3 (after BoPhan)
        for (final key in _attendanceData.first.keys) {
          final cell = sheetAttendance.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
          cell.value = record[key];
          col++;
        }
      }
    }
    
    Sheet sheetOtherCase = excel['VangNghiTca'];
    
    if (_otherCaseData.isNotEmpty) {
      final headers = <String>['MaNhanVien', 'TenNhanVien', 'BoPhan', ..._otherCaseData.first.keys];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheetOtherCase.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
      }
      
      for (int row = 0; row < _otherCaseData.length; row++) {
        final record = _otherCaseData[row];
        final nguoiDung = record['NguoiDung']?.toString() ?? '';
        final userInfo = userLookup[nguoiDung] ?? {'MaNhanVien': '', 'TenNhanVien': '', 'BoPhan': ''};
        
        final cellMaNV = sheetOtherCase.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1));
        cellMaNV.value = userInfo['MaNhanVien'];
        
        final cellTenNV = sheetOtherCase.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row + 1));
        cellTenNV.value = userInfo['TenNhanVien'];
        
        final cellBoPhan = sheetOtherCase.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row + 1));
        cellBoPhan.value = userInfo['BoPhan'];
        
        int col = 3; // Start from column 3 (after BoPhan)
        for (final key in _otherCaseData.first.keys) {
          final cell = sheetOtherCase.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
          cell.value = record[key];
          col++;
        }
      }
    }
    
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/attendance_data_${_selectedMonth}_${_selectedBranch}.xlsx';
    final fileBytes = excel.save();
    
    if (fileBytes != null) {
      Navigator.of(context).pop(); // Close loading dialog
      
      if (Platform.isWindows) {
        // Windows: Use file_picker with multiple fallback strategies
        try {
          // First attempt: Use file_picker save dialog
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Attendance Data',
            fileName: 'attendance_data_${_selectedMonth}_${_selectedBranch}.xlsx',
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );
          
          if (outputFile != null) {
            final file = File(outputFile);
            await file.writeAsBytes(fileBytes);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File saved successfully to: $outputFile'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // If user cancels, save to Downloads as fallback
            await _saveToDownloadsWindows(fileBytes);
          }
        } catch (e) {
          // If file_picker fails, save to Documents as second fallback
          await _saveToDocumentsWindows(fileBytes);
        }
      } else if (Platform.isMacOS) {
        // macOS: Use share_plus as requested
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/attendance_data_${_selectedMonth}_${_selectedBranch}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Dữ liệu chấm công tháng - ${_selectedMonth} - ${_selectedBranch} - Vui lòng kiểm tra sheet KetQuaCongThang',
        );
      } else {
        // Fallback for other platforms
        await Share.shareXFiles(
          [XFile('${(await getTemporaryDirectory()).path}/attendance_data_${_selectedMonth}_${_selectedBranch}.xlsx')],
          text: 'Dữ liệu chấm công tháng - ${_selectedMonth} - ${_selectedBranch}',
        );
      }
    }
  } catch (e) {
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi tạo file Excel: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Fallback method for Windows Downloads folder
Future<void> _saveToDownloadsWindows(List<int> fileBytes) async {
  try {
    final userHome = Platform.environment['USERPROFILE'];
    if (userHome != null) {
      final downloadsPath = '$userHome\\Downloads';
      final directory = Directory(downloadsPath);
      
      if (await directory.exists()) {
        final filePath = '$downloadsPath\\attendance_data_${_selectedMonth}_${_selectedBranch}.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to Downloads: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
    }
    // If Downloads folder not accessible, fall back to Documents
    await _saveToDocumentsWindows(fileBytes);
  } catch (e) {
    await _saveToDocumentsWindows(fileBytes);
  }
}

// Second fallback method for Windows Documents folder
Future<void> _saveToDocumentsWindows(List<int> fileBytes) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}\\attendance_data_${_selectedMonth}_${_selectedBranch}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File saved to Documents: $filePath'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error saving file: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

double _calculateChamCong(String nguoiDung, String date, int weekday) {
  if (nguoiDung == 'hm.tason') {
    print('\n***** Calculating ChamCong for $nguoiDung on $date *****');
  }
  
  double total = 0;
  
  for (final record in _attendanceData) {
    if (nguoiDung == 'hm.tason') {
      print('Checking record: NguoiDung=${record['NguoiDung']}, NgayGhi=${record['NgayGhi']}, TongCongNgay=${record['TongCongNgay']}');
    }
    
    final recordNguoiDung = record['NguoiDung']?.toString() ?? '';
    final recordDate = record['NgayGhi']?.toString() ?? '';
    final recordDate2 = record['Ngay']?.toString() ?? '';
    
    if (recordNguoiDung == nguoiDung) {
      final normalizedRecordDate = _normalizeDate(recordDate.isNotEmpty ? recordDate : recordDate2);
      final normalizedDate = _normalizeDate(date);
      
      if (normalizedRecordDate == normalizedDate) {
        final value = double.tryParse(record['TongCongNgay']?.toString() ?? '0') ?? 0;
        total += value;
        
        if (nguoiDung == 'hm.tason') {
          print('MATCH FOUND! TongCongNgay: $value');
        }
      }
    }
  }
  
  double maxValue = _getMaxWorkHours(nguoiDung, weekday);
  
  if (nguoiDung == 'hm.tason') {
    print('Total: $total, MaxValue: $maxValue');
  }
  
  return total > maxValue ? maxValue : total;
}

String _normalizeDate(String date) {
  if (date.isEmpty) return '';
  
  try {
    DateTime parsedDate = DateTime.parse(date);
    return DateFormat('yyyy-MM-dd').format(parsedDate);
  } catch (e) {
    try {
      DateTime parsedDate = DateFormat('MM/dd/yyyy').parse(date);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e2) {
      return date;
    }
  }
}

double _calculateVangNghi(String nguoiDung, String date) {
  if (nguoiDung == 'hm.tason') {
    print('\n***** Calculating VangNghi for $nguoiDung on $date *****');
  }
  
  for (final record in _otherCaseData) {
    if (record['NguoiDung'] == nguoiDung && 
        record['PhanLoai'] != null && 
        (record['PhanLoai'] == 'Nghỉ' || record['PhanLoai'] == 'Vắng') &&
        record['TrangThai'] == 'Đồng ý') {
      
      final ngayBatDauStr = record['NgayBatDau']?.toString() ?? '';
      final ngayKetThucStr = record['NgayKetThuc']?.toString() ?? '';
      
      final ngayBatDau = DateTime.tryParse(_normalizeDate(ngayBatDauStr));
      final ngayKetThuc = DateTime.tryParse(_normalizeDate(ngayKetThucStr));
      final currentDate = DateTime.parse(_normalizeDate(date));
      
      if (ngayBatDau != null && ngayKetThuc != null &&
          !currentDate.isBefore(ngayBatDau) && !currentDate.isAfter(ngayKetThuc)) {
        final value = double.tryParse(record['GiaTriNgay']?.toString() ?? '0') ?? 0;
        
        if (nguoiDung == 'hm.tason') {
          print('VangNghi found: PhanLoai=${record['PhanLoai']}, TrangThai=${record['TrangThai']}, GiaTriNgay=$value');
        }
        
        return value;
      }
    }
  }
  return 0;
}

double _calculateSoPhepSuDung(String nguoiDung, String date) {
  for (final record in _otherCaseData) {
    if (record['NguoiDung'] == nguoiDung && 
        record['PhanLoai'] == 'Nghỉ' &&
        (record['TruongHop'] == 'Nghỉ phép' || record['TruongHop'] == 'Nghỉ phép 1/2 ngày') &&
        record['TrangThai'] == 'Đồng ý') {
      
      final ngayBatDauStr = record['NgayBatDau']?.toString() ?? '';
      final ngayKetThucStr = record['NgayKetThuc']?.toString() ?? '';
      
      final ngayBatDau = DateTime.tryParse(_normalizeDate(ngayBatDauStr));
      final ngayKetThuc = DateTime.tryParse(_normalizeDate(ngayKetThucStr));
      final currentDate = DateTime.parse(_normalizeDate(date));
      
      if (ngayBatDau != null && ngayKetThuc != null &&
          !currentDate.isBefore(ngayBatDau) && !currentDate.isAfter(ngayKetThuc)) {
        return double.tryParse(record['GiaTriNgay']?.toString() ?? '0') ?? 0;
      }
    }
  }
  return 0;
}

double _calculateTangCa(String nguoiDung, String date) {
  for (final record in _otherCaseData) {
    if (record['NguoiDung'] == nguoiDung && 
        record['PhanLoai'] == 'Tăng ca' &&
        record['TrangThai'] == 'Đồng ý') {
      final ngayBatDauStr = record['NgayBatDau']?.toString() ?? '';
      final ngayKetThucStr = record['NgayKetThuc']?.toString() ?? '';
      
      final ngayBatDau = DateTime.tryParse(_normalizeDate(ngayBatDauStr));
      final ngayKetThuc = DateTime.tryParse(_normalizeDate(ngayKetThucStr));
      final currentDate = DateTime.parse(_normalizeDate(date));
      
      if (ngayBatDau != null && ngayKetThuc != null &&
          !currentDate.isBefore(ngayBatDau) && !currentDate.isAfter(ngayKetThuc)) {
        return double.tryParse(record['GiaTriNgay']?.toString() ?? '0') ?? 0;
      }
    }
  }
  return 0;
}

double _calculateDiMuon(String nguoiDung, String date) {
  double total = 0;
  
  for (final record in _attendanceData) {
    final recordNguoiDung = record['NguoiDung']?.toString() ?? '';
    final recordDate = record['NgayGhi']?.toString() ?? '';
    final recordDate2 = record['Ngay']?.toString() ?? '';
    
    if (recordNguoiDung == nguoiDung) {
      final normalizedRecordDate = _normalizeDate(recordDate.isNotEmpty ? recordDate : recordDate2);
      final normalizedDate = _normalizeDate(date);
      
      if (normalizedRecordDate == normalizedDate) {
        total += double.tryParse(record['TongDiMuonNgay']?.toString() ?? '0') ?? 0;
      }
    }
  }
  
  return total;
}

double _getMaxWorkHours(String nguoiDung, int weekday) {
  String phanLoai = weekday == DateTime.sunday ? 'CN' : 
                    weekday == DateTime.saturday ? 'T7' : 'T2T6';
  
  for (final record in _predefinedWorkHoursData) {
    if (record['NguoiDung'] == nguoiDung && record['PhanLoai'] == phanLoai) {
      return double.tryParse(record['SoCong']?.toString() ?? '0') ?? 0;
    }
  }
  
  if ((phanLoai == 'CN' || phanLoai == 'T7')) {
    for (final record in _predefinedWorkHoursData) {
      if (record['NguoiDung'] == nguoiDung && record['PhanLoai'] == 'T2T6') {
        return double.tryParse(record['SoCong']?.toString() ?? '0') ?? 0;
      }
    }
  }
  
  return 0;
}

String _getVietnameseWeekday(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'T2';
    case DateTime.tuesday:
      return 'T3';
    case DateTime.wednesday:
      return 'T4';
    case DateTime.thursday:
      return 'T5';
    case DateTime.friday:
      return 'T6';
    case DateTime.saturday:
      return 'T7';
    case DateTime.sunday:
      return 'CN';
    default:
      return '';
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng hợp công tháng'),
        backgroundColor: const Color.fromARGB(255, 190, 226, 255),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: (_selectedMonth != null && _selectedBranch != null)
                ? _showSyncConfirmation
                : null,
            tooltip: 'Đồng bộ',
          ),
          if (_hasData)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportToExcel,
              tooltip: 'Tải lượt chấm',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month dropdown
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: _selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Tháng',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        hint: const Text('Chọn tháng'),
                        items: _monthOptions.map((String value) {
                          final parts = value.split('-');
                          final year = parts[0];
                          final month = parts[1];
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text('Tháng $month/$year'),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedMonth = newValue;
                            _hasData = false;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Branch dropdown
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: _selectedBranch,
                        decoration: const InputDecoration(
                          labelText: 'Chi nhánh',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        hint: const Text('Chọn chi nhánh'),
                        items: _branchOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedBranch = newValue;
                            _hasData = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '⚠️ HƯỚNG DẪN: Chọn tháng cần xem (từ T3/2025) rồi bấm nút Đồng bộ (2 mũi tên xoay tròn) trên cùng bên phải rồi đợi tải dữ liệu.\nSau khi tải xong sẽ thấy nút Tải về (mũi tên trỏ xuống) để lưu bảng excel về máy (chọn Zalo/Mail khi chia sẻ)',
               style: TextStyle(
             color: Colors.blue,
              fontSize: 12,
                              ),
                            ),
                            const Text(
              '❌ Nếu bạn là NV xử lý công văn phòng, bạn phải vào từ mục Tổng hợp tháng',
               style: TextStyle(
             color: Colors.red,
              fontSize: 12,
                              ),
                            ),
            // Data display area
            Expanded(
  child: _hasData
      ? DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Lịch sử chấm'),
                  Tab(text: 'Vắng Nghỉ Tca'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Attendance data tab
                    _attendanceData.isNotEmpty 
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: _attendanceData.first.keys
                                  .map((key) => DataColumn(label: Text(key)))
                                  .toList(),
                              rows: _attendanceData.map((data) {
                                return DataRow(
                                  cells: data.values
                                      .map((value) => DataCell(Text(value?.toString() ?? '')))
                                      .toList(),
                                );
                              }).toList(),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text('Không có dữ liệu chấm công'),
                        ),
                    // Other case data tab
                    _otherCaseData.isNotEmpty
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: _otherCaseData.first.keys
                                  .map((key) => DataColumn(label: Text(key)))
                                  .toList(),
                              rows: _otherCaseData.map((data) {
                                return DataRow(
                                  cells: data.values
                                      .map((value) => DataCell(Text(value?.toString() ?? '')))
                                      .toList(),
                                );
                              }).toList(),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text('Không có dữ liệu vắng nghỉ tăng ca'),
                        ),
                  ],
                ),
              ),
            ],
          ),
        )
      : Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chọn tháng và chi nhánh để bắt đầu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nhấn nút đồng bộ trên appbar để tải dữ liệu',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
),
          ],
        ),
      ),
    );
  }
}