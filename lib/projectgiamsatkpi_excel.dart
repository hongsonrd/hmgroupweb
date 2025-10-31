import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceModel {
  final DateTime ngay;
  final String nguoiDung;
  final String batDau;

  AttendanceModel({
    required this.ngay,
    required this.nguoiDung,
    required this.batDau,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      ngay: DateTime.parse(json['Ngay']),
      nguoiDung: json['NguoiDung'],
      batDau: json['BatDau'],
    );
  }
}

class KPIPlanModel {
  final String uid;
  final DateTime ngay;
  final String boPhan;
  final String phanLoai;
  final double giaTri;

  KPIPlanModel({
    required this.uid,
    required this.ngay,
    required this.boPhan,
    required this.phanLoai,
    required this.giaTri,
  });

  factory KPIPlanModel.fromJson(Map<String, dynamic> json) {
    return KPIPlanModel(
      uid: json['uid'],
      ngay: DateTime.parse(json['ngay']),
      boPhan: json['boPhan'],
      phanLoai: json['phanLoai'],
      giaTri: (json['giaTri'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'ngay': DateFormat('yyyy-MM-dd').format(ngay),
      'boPhan': boPhan,
      'phanLoai': phanLoai,
      'giaTri': giaTri,
    };
  }
}

class DailyReportModel {
  final String uid;
  final String nguoiDung;
  final String taskId;
  final String ketQua;
  final DateTime ngay;
  final String gio;
  final String chiTiet;
  final String chiTiet2;
  final String viTri;
  final String boPhan;
  final String phanLoai;
  final String hinhAnh;
  final String giaiPhap;

  DailyReportModel({
    required this.uid,
    required this.nguoiDung,
    required this.taskId,
    required this.ketQua,
    required this.ngay,
    required this.gio,
    required this.chiTiet,
    required this.chiTiet2,
    required this.viTri,
    required this.boPhan,
    required this.phanLoai,
    required this.hinhAnh,
    required this.giaiPhap,
  });

  factory DailyReportModel.fromJson(Map<String, dynamic> json) {
    return DailyReportModel(
      uid: json['UID'] ?? '',
      nguoiDung: json['NguoiDung'] ?? '',
      taskId: json['TaskID'] ?? '',
      ketQua: json['KetQua'] ?? '',
      ngay: DateTime.parse(json['Ngay']),
      gio: json['Gio'] ?? '',
      chiTiet: json['ChiTiet'] ?? '',
      chiTiet2: json['ChiTiet2'] ?? '',
      viTri: json['ViTri'] ?? '',
      boPhan: json['BoPhan'] ?? '',
      phanLoai: json['PhanLoai'] ?? '',
      hinhAnh: json['HinhAnh'] ?? '',
      giaiPhap: json['GiaiPhap'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'UID': uid,
    'NguoiDung': nguoiDung,
    'TaskID': taskId,
    'KetQua': ketQua,
    'Ngay': DateFormat('yyyy-MM-dd').format(ngay),
    'Gio': gio,
    'ChiTiet': chiTiet,
    'ChiTiet2': chiTiet2,
    'ViTri': viTri,
    'BoPhan': boPhan,
    'PhanLoai': phanLoai,
    'HinhAnh': hinhAnh,
    'GiaiPhap': giaiPhap,
  };
}

class KPIStatsModel {
  final String nguoiDung;
  final String date;
  final String mainProject;
  final double bienDongNhanSu;
  final double robotControl;
  
  double get totalPoints => bienDongNhanSu + robotControl;
  double get totalPercent => (totalPoints / 35.0) * 100;

  KPIStatsModel({
    required this.nguoiDung,
    required this.date,
    required this.mainProject,
    required this.bienDongNhanSu,
    required this.robotControl,
  });

  Map<String, dynamic> toJson() => {
    'nguoiDung': nguoiDung,
    'date': date,
    'mainProject': mainProject,
    'bienDongNhanSu': bienDongNhanSu,
    'robotControl': robotControl,
  };

  factory KPIStatsModel.fromJson(Map<String, dynamic> json) => KPIStatsModel(
    nguoiDung: json['nguoiDung'],
    date: json['date'],
    mainProject: json['mainProject'],
    bienDongNhanSu: (json['bienDongNhanSu'] as num).toDouble(),
    robotControl: (json['robotControl'] as num).toDouble(),
  );
}

class AttendanceWithProject {
  final AttendanceModel attendance;
  final String mainProject;

  AttendanceWithProject({
    required this.attendance,
    required this.mainProject,
  });
}

class ProjectGiamSatKPI extends StatefulWidget {
  final String username;
  final List<dynamic> taskHistoryData;
  final List<String> projectOptions;

  const ProjectGiamSatKPI({
    Key? key,
    required this.username,
    required this.taskHistoryData,
    required this.projectOptions,
  }) : super(key: key);

  @override
  _ProjectGiamSatKPIState createState() => _ProjectGiamSatKPIState();
}

class _ProjectGiamSatKPIState extends State<ProjectGiamSatKPI> {
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  bool _isLoading = false;
  String _syncStatus = '';
  
  List<AttendanceModel> _attendanceData = [];
  List<KPIPlanModel> _kpiPlanData = [];
  Map<String, KPIStatsModel> _kpiStats = {};
  Map<String, List<DailyReportModel>> _dailyReports = {};
  
  List<String> _dateOptions = [];
  String? _selectedDate;
  
  Map<String, String> _staffNameMap = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadStaffNames();
    await _checkAndSyncAttendance();
    await _checkAndSyncKPIPlan();
    _updateDateOptions();
    _autoSelectLatestDate();
    await _loadKPIStats();
    await _loadDailyReports();
  }

  Future<void> _loadKPIStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString('kpi_stats');
      if (statsJson != null) {
        final List<dynamic> statsList = json.decode(statsJson);
        setState(() {
          _kpiStats = {
            for (var item in statsList)
              '${item['nguoiDung']}_${item['date']}': KPIStatsModel.fromJson(item)
          };
        });
      }
    } catch (e) {
      print('Error loading KPI stats: $e');
    }
  }

  Future<void> _saveKPIStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsList = _kpiStats.values.map((s) => s.toJson()).toList();
      await prefs.setString('kpi_stats', json.encode(statsList));
    } catch (e) {
      print('Error saving KPI stats: $e');
    }
  }

  Future<void> _loadDailyReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getString('daily_reports');
      if (reportsJson != null) {
        final Map<String, dynamic> reportsMap = json.decode(reportsJson);
        setState(() {
          _dailyReports = reportsMap.map((key, value) => MapEntry(
            key,
            (value as List).map((item) => DailyReportModel.fromJson(item)).toList(),
          ));
        });
      }
    } catch (e) {
      print('Error loading daily reports: $e');
    }
  }

  Future<void> _saveDailyReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsMap = _dailyReports.map((key, value) => MapEntry(
        key,
        value.map((r) => r.toJson()).toList(),
      ));
      await prefs.setString('daily_reports', json.encode(reportsMap));
    } catch (e) {
      print('Error saving daily reports: $e');
    }
  }

  Future<void> _syncDailyReports() async {
    if (_selectedDate == null) {
      _showError('Vui lòng chọn ngày');
      return;
    }

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ báo cáo ngày $_selectedDate...';
    });

    try {
      final dateFormatted = DateFormat('yyyyMMdd').format(DateTime.parse(_selectedDate!));
      final response = await http.get(Uri.parse('$baseUrl/gsbaocaotheongay/$dateFormatted'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final reports = data.map((item) => DailyReportModel.fromJson(item)).toList();
        
        setState(() {
          _dailyReports[_selectedDate!] = reports;
        });
        
        await _saveDailyReports();
        _showSuccess('Đồng bộ báo cáo thành công - ${reports.length} bản ghi');
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing daily reports: $e');
      _showError('Không thể đồng bộ báo cáo: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _loadStaffNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? staffListVPJson = prefs.getString('stafflistvp_data');
      
      if (staffListVPJson != null && staffListVPJson.isNotEmpty) {
        final List<dynamic> staffListVPData = json.decode(staffListVPJson);
        final Map<String, String> nameMap = {};
        
        for (final staff in staffListVPData) {
          if (staff['Username'] != null && staff['Name'] != null) {
            final username = staff['Username'].toString();
            final name = staff['Name'].toString();
            nameMap[username.toLowerCase()] = name;
            nameMap[username.toUpperCase()] = name;
            nameMap[username] = name;
          }
        }
        setState(() {
          _staffNameMap = nameMap;
        });
      }
    } catch (e) {
      print('Error loading staff names: $e');
    }
  }

  Future<void> _checkAndSyncAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAttendanceSynced = prefs.getBool('hasAttendanceSynced') ?? false;
    
    if (!hasAttendanceSynced) {
      await _syncAttendance();
    } else {
      final String? attendanceJson = prefs.getString('attendance_data');
      if (attendanceJson != null && attendanceJson.isNotEmpty) {
        final List<dynamic> data = json.decode(attendanceJson);
        setState(() {
          _attendanceData = data.map((item) => AttendanceModel.fromJson(item)).toList();
        });
      }
    }
  }

  Future<void> _syncAttendance() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ dữ liệu điểm danh...';
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/gsdilam'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('attendance_data', json.encode(data));
        await prefs.setBool('hasAttendanceSynced', true);
        
        setState(() {
          _attendanceData = data.map((item) => AttendanceModel.fromJson(item)).toList();
        });
        
        _updateDateOptions();
        _autoSelectLatestDate();
        
        _showSuccess('Đồng bộ điểm danh thành công - ${_attendanceData.length} bản ghi');
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing attendance: $e');
      _showError('Không thể đồng bộ điểm danh: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _checkAndSyncKPIPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final hasKPIPlanSynced = prefs.getBool('hasKPIPlanSynced') ?? false;
    
    if (!hasKPIPlanSynced) {
      await _syncKPIPlan();
    } else {
      final String? kpiPlanJson = prefs.getString('kpiplan_data');
      if (kpiPlanJson != null && kpiPlanJson.isNotEmpty) {
        final List<dynamic> data = json.decode(kpiPlanJson);
        setState(() {
          _kpiPlanData = data.map((item) => KPIPlanModel.fromJson(item)).toList();
        });
      }
    }
  }

  Future<void> _syncKPIPlan() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ kế hoạch KPI...';
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/gskpiplan'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kpiplan_data', json.encode(data));
        await prefs.setBool('hasKPIPlanSynced', true);
        
        setState(() {
          _kpiPlanData = data.map((item) => KPIPlanModel.fromJson(item)).toList();
        });
        
        _showSuccess('Đồng bộ kế hoạch KPI thành công - ${_kpiPlanData.length} bản ghi');
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing KPI plan: $e');
      _showError('Không thể đồng bộ kế hoạch KPI: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  void _updateDateOptions() {
    final dateSet = <String>{};
    for (final attendance in _attendanceData) {
      final dateStr = DateFormat('yyyy-MM-dd').format(attendance.ngay);
      dateSet.add(dateStr);
    }
    
    setState(() {
      _dateOptions = dateSet.toList()..sort((a, b) => b.compareTo(a));
    });
  }

  void _autoSelectLatestDate() {
    if (_selectedDate == null && _dateOptions.isNotEmpty) {
      setState(() {
        _selectedDate = _dateOptions.first;
      });
    }
  }

  String _getMainProject(String nguoiDung, DateTime selectedDate) {
    for (int daysBack = 0; daysBack <= 7; daysBack++) {
      final checkDate = selectedDate.subtract(Duration(days: daysBack));
      final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
      
      final projectCounts = <String, int>{};
      
      for (final record in widget.taskHistoryData) {
        if (record['NguoiDung'] == nguoiDung && 
            DateFormat('yyyy-MM-dd').format(DateTime.parse(record['Ngay'])) == dateStr &&
            record['BoPhan'] != null &&
            record['BoPhan'].toString().trim().isNotEmpty) {
          final project = record['BoPhan'].toString();
          projectCounts[project] = (projectCounts[project] ?? 0) + 1;
        }
      }
      
      if (projectCounts.isNotEmpty) {
        return projectCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }
    }
    
    return 'Không xác định';
  }

  List<AttendanceWithProject> _getFilteredAttendance() {
    if (_selectedDate == null) return [];
    
    final selectedDateTime = DateTime.parse(_selectedDate!);
    final filtered = _attendanceData.where((attendance) => 
      DateFormat('yyyy-MM-dd').format(attendance.ngay) == _selectedDate
    ).toList();
    
    return filtered.map((attendance) => AttendanceWithProject(
      attendance: attendance,
      mainProject: _getMainProject(attendance.nguoiDung, selectedDateTime),
    )).toList()..sort((a, b) => a.attendance.batDau.compareTo(b.attendance.batDau));
  }

  Future<void> _calculateKPI() async {
    if (_selectedDate == null) {
      _showError('Vui lòng chọn ngày');
      return;
    }

    if (!_dailyReports.containsKey(_selectedDate)) {
      _showError('Vui lòng đồng bộ báo cáo ngày đã chọn trước');
      return;
    }

    final filteredAttendance = _getFilteredAttendance();
    if (filteredAttendance.isEmpty) {
      _showError('Không có dữ liệu điểm danh cho ngày đã chọn');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => KPICalculationDialog(
        attendanceList: filteredAttendance,
        selectedDate: _selectedDate!,
        dailyReports: _dailyReports[_selectedDate!]!,
        kpiPlanData: _kpiPlanData,
        onStatsCalculated: (stats) {
          setState(() {
            for (final stat in stats) {
              final key = '${stat.nguoiDung}_${stat.date}';
              _kpiStats[key] = stat;
            }
          });
          _saveKPIStats();
        },
      ),
    );
  }

  void _showKPIPlanDialog() {
    if (_kpiPlanData.isEmpty && widget.projectOptions.isEmpty) {
      _showError('Chưa có dữ liệu kế hoạch KPI hoặc danh sách dự án');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => KPIPlanDialog(
        kpiPlanData: _kpiPlanData,
        projectOptions: widget.projectOptions,
        baseUrl: baseUrl,
        onDataChanged: () async {
          await _syncKPIPlan();
        },
      ),
    );
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red, duration: Duration(seconds: 3)),
      );
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 114, 255, 217),
            Color.fromARGB(255, 201, 255, 236),
            Color.fromARGB(255, 79, 255, 214),
            Color.fromARGB(255, 188, 255, 235),
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 16),
          Text('Đánh giá KPI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          Spacer(),
          if (!_isLoading)
            ElevatedButton.icon(
              onPressed: () => _syncAttendance(),
              icon: Icon(Icons.people_alt, size: 18),
              label: Text('Đồng bộ điểm danh'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, elevation: 2),
            ),
          SizedBox(width: 12),
          if (!_isLoading)
            ElevatedButton.icon(
              onPressed: () => _syncKPIPlan(),
              icon: Icon(Icons.assessment, size: 18),
              label: Text('Đồng bộ KPI plan'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600], foregroundColor: Colors.white, elevation: 2),
            ),
          if (_isLoading) ...[
            SizedBox(width: 12),
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black87))),
            SizedBox(width: 8),
            Text(_syncStatus, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final hasDailyReport = _selectedDate != null && _dailyReports.containsKey(_selectedDate);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chọn ngày', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedDate,
                  hint: Text('Chọn ngày'),
                  items: _dateOptions.map((date) => DropdownMenuItem(value: date, child: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(date))))).toList(),
                  onChanged: (value) => setState(() => _selectedDate = value),
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(top: 32),
            child: ElevatedButton.icon(
              onPressed: _selectedDate == null || _isLoading ? null : _syncDailyReports,
              icon: Icon(Icons.sync, size: 18),
              label: Text(hasDailyReport ? 'Đã đồng bộ' : 'Đồng bộ báo cáo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasDailyReport ? Colors.grey[600] : Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
          SizedBox(width: 16),
          Padding(
            padding: EdgeInsets.only(top: 32),
            child: ElevatedButton.icon(
              onPressed: hasDailyReport ? _calculateKPI : null,
              icon: Icon(Icons.calculate, size: 18),
              label: Text('Bắt đầu tính toán'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ),
          SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(top: 32),
            child: ElevatedButton.icon(
              onPressed: _kpiPlanData.isEmpty ? null : () => _showKPIPlanDialog(),
              icon: Icon(Icons.table_chart, size: 18),
              label: Text('Danh mục KPI'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[600], foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    final filteredAttendance = _getFilteredAttendance();

    if (_selectedDate == null) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.date_range, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text('Vui lòng chọn ngày để xem danh sách điểm danh', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (filteredAttendance.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text('Không có dữ liệu điểm danh cho ngày đã chọn', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 1200;

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text('Danh sách điểm danh (${filteredAttendance.length} người)', style: TextStyle(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold, color: Colors.blue[800])),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              border: TableBorder.all(color: Colors.grey[300]!),
              headingRowColor: MaterialStateColor.resolveWith((states) => Colors.grey[100]!),
              columnSpacing: isDesktop ? 20 : 14,
              headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: isDesktop ? 13 : 11),
              dataTextStyle: TextStyle(fontSize: isDesktop ? 12 : 10, color: Colors.grey[800]),
              columns: [
                DataColumn(label: Container(width: 35, child: Text('STT', textAlign: TextAlign.center))),
                DataColumn(label: Container(width: isDesktop ? 100 : 80, child: Text('Mã NV'))),
                DataColumn(label: Container(width: isDesktop ? 160 : 120, child: Text('Tên giám sát'))),
                DataColumn(label: Container(width: isDesktop ? 80 : 60, child: Text('Giờ vào', textAlign: TextAlign.center))),
                DataColumn(label: Container(width: isDesktop ? 130 : 100, child: Text('Dự án chính'))),
                DataColumn(label: Container(width: isDesktop ? 90 : 70, child: Text('Biến động NS', textAlign: TextAlign.center))),
                DataColumn(label: Container(width: isDesktop ? 80 : 60, child: Text('Robot', textAlign: TextAlign.center))),
                DataColumn(label: Container(width: isDesktop ? 80 : 60, child: Text('Tổng điểm', textAlign: TextAlign.center))),
                DataColumn(label: Container(width: isDesktop ? 80 : 60, child: Text('Tỷ lệ %', textAlign: TextAlign.center))),
              ],
              rows: List.generate(filteredAttendance.length, (index) {
                final item = filteredAttendance[index];
                final displayName = _staffNameMap[item.attendance.nguoiDung.toUpperCase()] ?? '❓❓❓';
                final statsKey = '${item.attendance.nguoiDung}_$_selectedDate';
                final stats = _kpiStats[statsKey];
                
                return DataRow(
                  color: MaterialStateColor.resolveWith((states) => index % 2 == 0 ? Colors.white : Colors.grey[50]!),
                  cells: [
                    DataCell(Container(width: 35, child: Text((index + 1).toString(), textAlign: TextAlign.center))),
                    DataCell(Container(width: isDesktop ? 100 : 80, child: Text(item.attendance.nguoiDung, overflow: TextOverflow.ellipsis))),
                    DataCell(Container(width: isDesktop ? 160 : 120, child: Text(displayName, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)))),
                    DataCell(Container(width: isDesktop ? 80 : 60, child: Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(10)), child: Text(item.attendance.batDau, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 11))))),
                    DataCell(Container(width: isDesktop ? 130 : 100, child: Text(item.mainProject, overflow: TextOverflow.ellipsis))),
                    DataCell(Container(
                      width: isDesktop ? 90 : 70,
                      child: stats != null 
                          ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: stats.bienDongNhanSu >= 5 ? Colors.green[100] : stats.bienDongNhanSu >= 3 ? Colors.orange[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                stats.bienDongNhanSu.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: stats.bienDongNhanSu >= 5 ? Colors.green[800] : stats.bienDongNhanSu >= 3 ? Colors.orange[800] : Colors.red[800],
                                ),
                              ),
                            )
                          : Text('-', textAlign: TextAlign.center),
                    )),
                    DataCell(Container(
                      width: isDesktop ? 80 : 60,
                      child: stats != null 
                          ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: stats.robotControl >= 4.5 ? Colors.green[100] : stats.robotControl >= 3 ? Colors.orange[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                stats.robotControl.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: stats.robotControl >= 4.5 ? Colors.green[800] : stats.robotControl >= 3 ? Colors.orange[800] : Colors.red[800],
                                ),
                              ),
                            )
                          : Text('-', textAlign: TextAlign.center),
                    )),
                    DataCell(Container(
                      width: isDesktop ? 80 : 60,
                      child: stats != null 
                          ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                stats.totalPoints.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue[800]),
                              ),
                            )
                          : Text('-', textAlign: TextAlign.center),
                    )),
                    DataCell(Container(
                      width: isDesktop ? 80 : 60,
                      child: stats != null 
                          ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: stats.totalPercent >= 80 ? Colors.green[100] : stats.totalPercent >= 60 ? Colors.orange[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${stats.totalPercent.toStringAsFixed(0)}%',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: stats.totalPercent >= 80 ? Colors.green[800] : stats.totalPercent >= 60 ? Colors.orange[800] : Colors.red[800],
                                ),
                              ),
                            )
                          : Text('-', textAlign: TextAlign.center),
                    )),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(child: SingleChildScrollView(child: _buildAttendanceList())),
        ],
      ),
    );
  }
}

class KPICalculationDialog extends StatefulWidget {
  final List<AttendanceWithProject> attendanceList;
  final String selectedDate;
  final List<DailyReportModel> dailyReports;
  final List<KPIPlanModel> kpiPlanData;
  final Function(List<KPIStatsModel>) onStatsCalculated;

  const KPICalculationDialog({
    Key? key,
    required this.attendanceList,
    required this.selectedDate,
    required this.dailyReports,
    required this.kpiPlanData,
    required this.onStatsCalculated,
  }) : super(key: key);

  @override
  _KPICalculationDialogState createState() => _KPICalculationDialogState();
}

class _KPICalculationDialogState extends State<KPICalculationDialog> {
  int _currentIndex = 0;
  String _currentStatus = 'Đang khởi động...';
  final List<KPIStatsModel> _calculatedStats = [];

  @override
  void initState() {
    super.initState();
    _startCalculation();
  }

  Future<void> _startCalculation() async {
    for (int i = 0; i < widget.attendanceList.length; i++) {
      final item = widget.attendanceList[i];
      
      setState(() {
        _currentIndex = i;
        _currentStatus = 'Đang tính toán cho ${item.attendance.nguoiDung}...';
      });

      await Future.delayed(Duration(milliseconds: 100));

      final bienDongNhanSu = _calculateBienDongNhanSu(item.attendance.nguoiDung, item.mainProject);
      await Future.delayed(Duration(milliseconds: 50));

      final robotControl = _calculateRobotControl(item.attendance.nguoiDung, item.mainProject);
      await Future.delayed(Duration(milliseconds: 50));

      _calculatedStats.add(KPIStatsModel(
        nguoiDung: item.attendance.nguoiDung,
        date: widget.selectedDate,
        mainProject: item.mainProject,
        bienDongNhanSu: bienDongNhanSu,
        robotControl: robotControl,
      ));
    }

    widget.onStatsCalculated(_calculatedStats);
    Navigator.of(context).pop();
  }

  double _calculateBienDongNhanSu(String nguoiDung, String project) {
    String? latestTime;
    
    final supervisorReports = widget.dailyReports.where((r) => 
      r.nguoiDung.toLowerCase().startsWith('hm')
    ).toList();
    
    for (final record in supervisorReports) {
      if (record.nguoiDung == nguoiDung &&
          record.boPhan == project &&
          record.phanLoai == 'Nhân sự' &&
          record.chiTiet.length >= 2) {
        final time = record.gio;
        if (time.isNotEmpty) {
          if (latestTime == null || time.compareTo(latestTime) > 0) {
            latestTime = time;
          }
        }
      }
    }

    if (latestTime == null) return 0.0;

    final timeParts = latestTime.split(':');
    if (timeParts.isEmpty) return 0.0;

    final hour = int.tryParse(timeParts[0]) ?? 0;
    return hour < 9 ? 5.0 : 3.0;
  }

  double _calculateRobotControl(String nguoiDung, String project) {
    KPIPlanModel? plan = widget.kpiPlanData.firstWhere(
      (p) => p.boPhan == project && p.phanLoai == 'Robot',
      orElse: () => widget.kpiPlanData.firstWhere(
        (p) => p.boPhan == 'Mặc định' && p.phanLoai == 'Robot',
        orElse: () => KPIPlanModel(uid: '', ngay: DateTime.now(), boPhan: '', phanLoai: '', giaTri: 0),
      ),
    );

    if (plan.giaTri == 0) return 5.0;

    double totalArea = 0.0;
    
    final supervisorReports = widget.dailyReports.where((r) => 
      r.nguoiDung.toLowerCase().startsWith('hm')
    ).toList();
    
    for (final record in supervisorReports) {
      if (record.nguoiDung == nguoiDung &&
          record.boPhan == project &&
          record.phanLoai == 'Robot' &&
          record.chiTiet.isNotEmpty) {
        final regex = RegExp(r'Diện tích sử dụng \(m2\):\s*([\d.]+)');
        final match = regex.firstMatch(record.chiTiet);
        
        if (match != null) {
          final areaStr = match.group(1);
          final area = double.tryParse(areaStr ?? '0') ?? 0.0;
          totalArea += area.roundToDouble();
        }
      }
    }

    if (plan.giaTri == 0) return 0.0;
    
    final percentage = (totalArea / plan.giaTri) * 100;
    
    if (percentage >= 95) return 5.0;
    if (percentage < 50) return 0.0;
    
    return 2.5 + ((percentage - 50) / 45) * 2.5;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.attendanceList.isEmpty ? 0.0 : (_currentIndex + 1) / widget.attendanceList.length;
    
    return Dialog(
      child: Container(
        width: 400,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đang tính toán KPI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(value: progress, strokeWidth: 6),
            SizedBox(height: 16),
            Text('${(_currentIndex + 1)}/${widget.attendanceList.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(_currentStatus, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class KPIPlanDialog extends StatefulWidget {
  final List<KPIPlanModel> kpiPlanData;
  final List<String> projectOptions;
  final String baseUrl;
  final VoidCallback onDataChanged;

  const KPIPlanDialog({
    Key? key,
    required this.kpiPlanData,
    required this.projectOptions,
    required this.baseUrl,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  _KPIPlanDialogState createState() => _KPIPlanDialogState();
}

class _KPIPlanDialogState extends State<KPIPlanDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredProjects = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredProjects = widget.projectOptions;
    _searchController.addListener(_filterProjects);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProjects() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProjects = query.isEmpty 
          ? widget.projectOptions 
          : widget.projectOptions.where((p) => p.toLowerCase().contains(query)).toList();
    });
  }

  Map<String, List<KPIPlanModel>> _groupByProject() {
    final Map<String, List<KPIPlanModel>> grouped = {};
    for (final plan in widget.kpiPlanData) {
      grouped.putIfAbsent(plan.boPhan, () => []).add(plan);
    }
    return grouped;
  }

  Future<void> _createKPISet(String boPhan) async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      
      final types = [
        {'phanLoai': 'Checklist', 'giaTri': 1.0},
        {'phanLoai': 'QR', 'giaTri': 5.0},
        {'phanLoai': 'Máy móc', 'giaTri': 1.0},
        {'phanLoai': 'Robot', 'giaTri': 0.0},
      ];

      for (final type in types) {
        final uid = 'KPI_${now.millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 1000000}';
        final response = await http.post(
          Uri.parse('${widget.baseUrl}/gskpiplan/add'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'uid': uid,
            'ngay': dateStr,
            'boPhan': boPhan,
            'phanLoai': type['phanLoai'],
            'giaTri': type['giaTri'],
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to create ${type['phanLoai']}');
        }
      }

      widget.onDataChanged();
      Navigator.of(context).pop();
      _showSuccess('Tạo bộ KPI thành công cho $boPhan');
    } catch (e) {
      _showError('Lỗi tạo KPI: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateKPI(KPIPlanModel plan, double newValue) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/gskpiplan/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'uid': plan.uid, 'giaTri': newValue}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update');
      }

      widget.onDataChanged();
      _showSuccess('Cập nhật thành công');
    } catch (e) {
      _showError('Lỗi cập nhật: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteKPISet(String boPhan, List<KPIPlanModel> plans) async {
    if (plans.any((p) => p.phanLoai == 'Mặc định')) {
      _showError('Không thể xóa bộ KPI có loại Mặc định');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Xóa toàn bộ ${plans.length} KPI của $boPhan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      for (final plan in plans) {
        final response = await http.delete(
          Uri.parse('${widget.baseUrl}/gskpiplan/delete'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'uid': plan.uid}),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to delete ${plan.phanLoai}');
        }
      }

      widget.onDataChanged();
      Navigator.of(context).pop();
      _showSuccess('Xóa bộ KPI thành công');
    } catch (e) {
      _showError('Lỗi xóa: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn dự án'),
        content: Container(
          width: 400,
          height: 400,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm dự án...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = _filteredProjects[index];
                    return ListTile(
                      title: Text(project),
                      onTap: () {
                        Navigator.pop(context);
                        _createKPISet(project);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))],
      ),
    );
  }

  void _showEditDialog(KPIPlanModel plan) {
    if (plan.phanLoai == 'Mặc định') {
      _showError('Không thể chỉnh sửa loại Mặc định');
      return;
    }

    final controller = TextEditingController(text: plan.giaTri.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chỉnh sửa ${plan.phanLoai}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Giá trị', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy')),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                Navigator.pop(context);
                _updateKPI(plan, value);
              }
            },
            child: Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final grouped = _groupByProject();
    final projects = grouped.keys.toList()..sort();

    return Dialog(
      child: Container(
        width: isDesktop ? 900 : MediaQuery.of(context).size.width * 0.95,
        height: isDesktop ? 700 : MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[600],
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Danh mục KPI (${widget.kpiPlanData.length} kế hoạch)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  if (!_isLoading)
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: Icon(Icons.add, size: 18),
                      label: Text('Tạo mới'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  SizedBox(width: 8),
                  IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            if (_isLoading) LinearProgressIndicator(),
            Expanded(
              child: projects.isEmpty
                  ? Center(child: Text('Chưa có KPI nào', style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final plans = grouped[project]!;
                        final canDelete = !plans.any((p) => p.phanLoai == 'Mặc định');

                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              ListTile(
                                tileColor: Colors.blue[50],
                                title: Text(project, style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${plans.length} KPI'),
                                trailing: canDelete
                                    ? IconButton(
                                        icon: Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteKPISet(project, plans),
                                      )
                                    : null,
                              ),
                              ...plans.map((plan) => ListTile(
                                    title: Text(plan.phanLoai),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)),
                                          child: Text(plan.giaTri.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
                                        ),
                                        if (plan.phanLoai != 'Mặc định') ...[
                                          SizedBox(width: 8),
                                          IconButton(icon: Icon(Icons.edit, size: 20), onPressed: () => _showEditDialog(plan)),
                                        ],
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}