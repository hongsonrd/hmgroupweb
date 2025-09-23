import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'db_helper.dart';
import 'table_models.dart';
import 'projectcongnhanexcel.dart';
import 'projectcongnhanllv.dart';
import 'dart:math';

class ProjectStaffReports extends StatefulWidget {
  final String username;

  const ProjectStaffReports({Key? key, required this.username}) : super(key: key);

  @override
  _ProjectStaffReportsState createState() => _ProjectStaffReportsState();
}

class _ProjectStaffReportsState extends State<ProjectStaffReports> {
  bool _isLoading = false;
  List<TaskHistoryModel> _allData = [];
  List<TaskHistoryModel> _processedData = [];
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  String _syncStatus = '';
  List<TaskScheduleModel> _taskSchedules = [];
  bool _hasTaskSchedulesSynced = false;
  List<QRLookupModel> _qrLookups = [];

  Timer? _syncTimer;
  final Duration _syncInterval = Duration(minutes: 30);
  
  List<String> _projectOptions = [];
  List<String> _dateOptions = [];
  String? _selectedProject;
  String? _selectedDate;
  String _selectedReportType = 'Tất cả';
  String _selectedEntityType = 'Tất cả';
  
  List<String> _reportTypeOptions = ['Tất cả', 'Robot', 'Máy móc', 'Chất lượng khác'];
  List<String> _entityTypeOptions = ['Tất cả', 'Nhân viên', 'Giám sát', 'Robot'];
  
  List<StaffSummary> _filteredStaff = [];
  List<StaffSummary> _allProjectStaff = [];
  
  // Chart data
  List<String> _chartDates = [];
  int _displayDateCount = 7;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

Future<void> _initializeData() async {
  await _checkAndSync();
  await _loadAllData();
  
  // Remove the random schedule sync logic completely
  
  _processBoPhanCorrection();
  _updateFilterOptions();
  _autoSelectFilters();
  _startSyncTimer();
  
  _hasTaskSchedulesSynced = await TaskScheduleManager.hasEverSynced();
  if (_hasTaskSchedulesSynced) {
    _taskSchedules = await TaskScheduleManager.getTaskSchedules();
    _qrLookups = await TaskScheduleManager.getQRLookups();
  }
  setState(() {});
}
Widget _buildResultPercentageChart() {
  if (_selectedProject == null || _chartDates.isEmpty) {
    return SizedBox.shrink();
  }

  final isDesktop = MediaQuery.of(context).size.width > 1200;

  // Calculate good result percentage for each date
  final resultPercentages = <FlSpot>[];

  for (int i = 0; i < _chartDates.length; i++) {
    final dateStr = _chartDates[i];
    final dayRecords = _processedData.where((record) => 
      record.boPhan == _selectedProject &&
      DateFormat('yyyy-MM-dd').format(record.ngay) == dateStr &&
      (_selectedReportType == 'Tất cả' || _getReportType(record.phanLoai) == _selectedReportType) &&
      (_selectedEntityType == 'Tất cả' || _getEntityType(record.nguoiDung) == _selectedEntityType)
    ).toList();

    if (dayRecords.isNotEmpty) {
      final goodResults = dayRecords.where((r) => r.ketQua == '✔️').length;
      final percentage = (goodResults / dayRecords.length) * 100;
      resultPercentages.add(FlSpot(i.toDouble(), percentage));
    } else {
      resultPercentages.add(FlSpot(i.toDouble(), 0));
    }
  }

  return Container(
    margin: EdgeInsets.all(16),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pie_chart, color: Colors.green[600]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tỷ lệ kết quả tốt theo ngày (%)',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Container(width: 16, height: 3, color: Colors.green),
            SizedBox(width: 4),
            Text('Tỷ lệ kết quả ✔️', style: TextStyle(fontSize: 12)),
          ],
        ),
        SizedBox(height: 16),
        Container(
          height: isDesktop ? 250 : 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: resultPercentages,
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withOpacity(0.2),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 20,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: TextStyle(fontSize: 10, color: Colors.green),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < _chartDates.length) {
                        final dateStr = _chartDates[index];
                        final date = DateTime.parse(dateStr);
                        return Transform.rotate(
                          angle: isDesktop ? 0 : -0.5,
                          child: Text(
                            DateFormat('dd/MM').format(date),
                            style: TextStyle(fontSize: isDesktop ? 10 : 8),
                          ),
                        );
                      }
                      return Text('');
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ],
    ),
  );
}
  Future<void> _syncTaskSchedules() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ lịch làm việc...';
    });

    try {
      await TaskScheduleManager.syncTaskSchedules(baseUrl);
      _taskSchedules = await TaskScheduleManager.getTaskSchedules();
      _qrLookups = await TaskScheduleManager.getQRLookups();
      _hasTaskSchedulesSynced = true;
      _showSuccess('Đồng bộ lịch làm việc thành công - ${_taskSchedules.length} nhiệm vụ, ${_qrLookups.length} ánh xạ');
    } catch (e) {
      _showError('Không thể đồng bộ lịch làm việc: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      _checkAndSync();
    });
  }

  Future<void> _checkAndSync() async {
    if (await _shouldSync()) {
      await _syncData();
    }
  }

  Future<Map<String, String>> _getStaffNameMap() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> staffbioResults = await db.query(DatabaseTables.staffbioTable);
      
      final Map<String, String> nameMap = {};
      for (final staff in staffbioResults) {
        if (staff['MaNV'] != null && staff['Ho_ten'] != null) {
          final maNV = staff['MaNV'].toString();
          final hoTen = staff['Ho_ten'].toString();
          nameMap[maNV.toLowerCase()] = hoTen;
          nameMap[maNV.toUpperCase()] = hoTen;
          nameMap[maNV] = hoTen;
        }
      }
      return nameMap;
    } catch (e) {
      return {};
    }
  }

  Future<bool> _shouldSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('lastProjectSync') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSync) > _syncInterval.inMilliseconds;
  }

  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastProjectSync', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _syncData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ dữ liệu...';
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/projectcongnhansanbay/${widget.username}'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        await dbHelper.clearTable(DatabaseTables.taskHistoryTable);

        final taskHistories = data.map((item) => TaskHistoryModel(
          uid: item['UID'],
          taskId: item['TaskID'],
          ngay: DateTime.parse(item['Ngay']),
          gio: item['Gio'],
          nguoiDung: item['NguoiDung'],
          ketQua: item['KetQua'],
          chiTiet: item['ChiTiet'],
          chiTiet2: item['ChiTiet2'],
          viTri: item['ViTri'],
          boPhan: item['BoPhan'],
          phanLoai: item['PhanLoai'],
          hinhAnh: item['HinhAnh'],
          giaiPhap: item['GiaiPhap'],
        )).toList();

        await dbHelper.batchInsertTaskHistory(taskHistories);
        await _updateLastSyncTime();
        
        await _loadAllData();
        _processBoPhanCorrection();
        _updateFilterOptions();
        _autoSelectFilters();
        
        _showSuccess('Đồng bộ thành công - ${_allData.length} bản ghi');
      } else {
        throw Exception('Failed to sync data: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Không thể đồng bộ: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _loadAllData() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT * FROM ${DatabaseTables.taskHistoryTable}
        ORDER BY Ngay DESC, Gio DESC
      ''');

      setState(() {
        _allData = results.map((item) => TaskHistoryModel(
          uid: item['UID'],
          taskId: item['TaskID'],
          ngay: DateTime.parse(item['Ngay']),
          gio: item['Gio'],
          nguoiDung: item['NguoiDung'],
          ketQua: item['KetQua'],
          chiTiet: item['ChiTiet'],
          chiTiet2: item['ChiTiet2'],
          viTri: item['ViTri'],
          boPhan: item['BoPhan'],
          phanLoai: item['PhanLoai'],
          hinhAnh: item['HinhAnh'],
          giaiPhap: item['GiaiPhap'],
        )).toList();
      });
    } catch (e) {
      _showError('Lỗi tải dữ liệu');
    }
  }

  void _processBoPhanCorrection() {
    _processedData = _allData.map((record) => TaskHistoryModel(
      uid: record.uid,
      taskId: record.taskId,
      ngay: record.ngay,
      gio: record.gio,
      nguoiDung: record.nguoiDung,
      ketQua: record.ketQua,
      chiTiet: record.chiTiet,
      chiTiet2: record.chiTiet2,
      viTri: record.viTri,
      boPhan: record.boPhan,
      phanLoai: record.phanLoai,
      hinhAnh: record.hinhAnh,
      giaiPhap: record.giaiPhap,
    )).toList();

    final workerDateGroups = <String, List<TaskHistoryModel>>{};
    
    for (final record in _processedData) {
      if (record.nguoiDung?.isNotEmpty == true) {
        final key = '${record.nguoiDung}_${DateFormat('yyyy-MM-dd').format(record.ngay)}';
        workerDateGroups.putIfAbsent(key, () => []).add(record);
      }
    }

    for (final group in workerDateGroups.values) {
      if (group.length <= 1) continue;
      
      final validProjects = <String, int>{};
      for (final record in group) {
        if (record.boPhan != null && !_shouldFilterProject(record.boPhan!)) {
          validProjects[record.boPhan!] = (validProjects[record.boPhan!] ?? 0) + 1;
        }
      }
      
      String? correctProject;
      if (validProjects.isNotEmpty) {
        correctProject = validProjects.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }
      
      if (correctProject != null) {
        for (final record in group) {
          if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) {
            record.boPhan = correctProject;
          }
        }
      }
    }
  }

  void _updateFilterOptions() {
    final projectSet = <String>{};
    for (final record in _processedData) {
      if (record.boPhan != null && record.boPhan!.trim().isNotEmpty && !_shouldFilterProject(record.boPhan!)) {
        projectSet.add(record.boPhan!);
      }
    }
    
    final dateSet = <String>{};
    for (final record in _processedData) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.ngay);
      dateSet.add(dateStr);
    }

    setState(() {
      _projectOptions = projectSet.toList()..sort();
      _dateOptions = dateSet.toList()..sort((a, b) => b.compareTo(a));
    });
  }

  void _autoSelectFilters() {
    if (_selectedDate == null && _dateOptions.isNotEmpty) {
      _selectedDate = _dateOptions.first;
    }
    
    if (_selectedProject == null && _projectOptions.isNotEmpty) {
      _selectedProject = _projectOptions.first;
    }
    
    if (_selectedProject != null) {
      _updateChartData();
      if (_selectedDate != null) {
        _updateFilteredStaff();
      }
    }
  }

  bool _shouldFilterProject(String? projectName) {
    if (projectName == null || projectName.trim().isEmpty) return true;
    final name = projectName.toLowerCase();
    final originalName = projectName.trim();
    
    if (name == 'unknown') return true;
    if (name.length >= 3 && name.startsWith('hm') && RegExp(r'^hm\d').hasMatch(name)) return true;
    if (name.length >= 3 && name.startsWith('tv') && RegExp(r'^tv\d').hasMatch(name)) return true;
    if (name.length >= 4 && name.startsWith('tvn') && RegExp(r'^tvn\d').hasMatch(name)) return true;
    if (name.length >= 5 && name.startsWith('nvhm') && RegExp(r'^nvhm\d').hasMatch(name)) return true;
    if (name.startsWith('http:') || name.startsWith('https:')) return true;
    if (RegExp(r'^[a-z]{2,5}-\d+$').hasMatch(name)) return true;
    if (originalName == originalName.toUpperCase() && !originalName.contains(' ') && originalName.length > 1) return true;
    
    return false;
  }

  String _getEntityType(String? username) {
    if (username == null || username.trim().isEmpty) return 'Unknown';
    
    if (username == 'hm.gausium') return 'Robot';
    if (username.toLowerCase().startsWith('hm.')) return 'Giám sát';
    return 'Nhân viên';
  }

  String _getReportType(String? phanLoai) {
    if (phanLoai == null || phanLoai.trim().isEmpty) return 'Chất lượng khác';
    
    final type = phanLoai.toLowerCase();
    if (type.contains('robot')) return 'Robot';
    if (type.contains('máy móc') || type.contains('may moc')) return 'Máy móc';
    return 'Chất lượng khác';
  }
void _updateChartData() {
  if (_selectedProject == null) {
    setState(() {
      _chartDates = [];
    });
    return;
  }

  final projectData = _processedData.where((record) => record.boPhan == _selectedProject).toList();
  final dateMap = <String, List<TaskHistoryModel>>{};
  
  for (final record in projectData) {
    final dateStr = DateFormat('yyyy-MM-dd').format(record.ngay);
    dateMap.putIfAbsent(dateStr, () => []).add(record);
  }
  
  final allSortedDates = dateMap.keys.toList()..sort((a, b) => b.compareTo(a));
  // Limit to 4 latest days for performance
  final displayDates = allSortedDates.take(4).toList();
  
  setState(() {
    _chartDates = displayDates;
  });
}

 void _updateFilteredStaff() async {
  if (_selectedProject == null || _selectedDate == null) {
    setState(() {
      _filteredStaff = [];
      _allProjectStaff = [];
    });
    return;
  }

  // Show loading for matrix calculation
  setState(() {
    _isCalculatingMatrix = true;
  });

  final staffNameMap = await _getStaffNameMap();

  // Your existing staff calculation logic...
  final allProjectUsers = <String>{};
  final staffDataMap = <String, StaffSummary>{};
  
  for (final record in _processedData) {
    if (record.boPhan == _selectedProject && record.nguoiDung != null && record.nguoiDung!.trim().isNotEmpty) {
      allProjectUsers.add(record.nguoiDung!);
    }
  }
  
  final relevantRecords = _processedData.where((record) => 
    record.boPhan == _selectedProject &&
    DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate &&
    record.nguoiDung != null &&
    record.nguoiDung!.trim().isNotEmpty &&
    (_selectedReportType == 'Tất cả' || _getReportType(record.phanLoai) == _selectedReportType) &&
    (_selectedEntityType == 'Tất cả' || _getEntityType(record.nguoiDung) == _selectedEntityType)
  ).toList();

  for (final record in relevantRecords) {
    final username = record.nguoiDung!;
    final capitalizedUsername = username.toUpperCase();
    
    if (!staffDataMap.containsKey(username)) {
      staffDataMap[username] = StaffSummary(
        username: username,
        displayName: staffNameMap[capitalizedUsername] ?? username,
        entityType: _getEntityType(username),
        reportCount: 0,
        imageCount: 0,
        topicCount: 0,
        hourCount: 0,
        topics: <String>{},
        hours: <String>{},
        hasReported: false,
      );
    }
    
    final summary = staffDataMap[username]!;
    summary.reportCount++;
    summary.hasReported = true;
    
    if (record.hinhAnh != null && record.hinhAnh!.trim().isNotEmpty) {
      summary.imageCount++;
    }
    
    if (record.phanLoai != null && record.phanLoai!.trim().isNotEmpty) {
      summary.topics.add(record.phanLoai!);
    }
    
    if (record.gio != null && record.gio!.trim().isNotEmpty) {
      try {
        final timeParts = record.gio!.split(':');
        if (timeParts.isNotEmpty) {
          summary.hours.add(timeParts[0]);
        }
      } catch (e) {}
    }
  }
  
  for (final username in allProjectUsers) {
    final entityType = _getEntityType(username);
    if (_selectedEntityType != 'Tất cả' && entityType != _selectedEntityType) continue;
    
    if (!staffDataMap.containsKey(username)) {
      final capitalizedUsername = username.toUpperCase();
      staffDataMap[username] = StaffSummary(
        username: username,
        displayName: staffNameMap[capitalizedUsername] ?? username,
        entityType: entityType,
        reportCount: 0,
        imageCount: 0,
        topicCount: 0,
        hourCount: 0,
        topics: <String>{},
        hours: <String>{},
        hasReported: false,
      );
    }
  }
  
  for (final summary in staffDataMap.values) {
    summary.topicCount = summary.topics.length;
    summary.hourCount = summary.hours.length;
  }

  final allStaff = staffDataMap.values.toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));

  // Add a small delay to ensure UI updates properly, then calculate matrix
  await Future.delayed(Duration(milliseconds: 100));
  
  setState(() {
    _filteredStaff = allStaff.where((s) => s.hasReported).toList();
    _allProjectStaff = allStaff;
    _isCalculatingMatrix = false; 
  });
}

  Future<void> _syncStaffBio() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang cập nhật hồ sơ nhân sự...';
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/staffbio'));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> staffbioData = decoded is Map ? decoded['data'] : decoded;
        
        await dbHelper.clearTable(DatabaseTables.staffbioTable);
        
        final staffbioModels = staffbioData.map((data) {
          return StaffbioModel.fromMap(data as Map<String, dynamic>);
        }).toList();

        await dbHelper.batchInsertStaffbio(staffbioModels);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasStaffbioSynced', true);

        _updateFilteredStaff();
        _showSuccess('Cập nhật hồ sơ nhân sự thành công');
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      _showError('Không thể cập nhật hồ sơ nhân sự: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  void _showStaffDetails(StaffSummary staff) {
    if (!staff.hasReported) return;

    final staffRecords = _processedData.where((record) => 
      record.boPhan == _selectedProject &&
      DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate &&
      record.nguoiDung == staff.username
    ).toList();

    staffRecords.sort((a, b) {
      final timeA = a.gio ?? '';
      final timeB = b.gio ?? '';
      return timeA.compareTo(timeB);
    });

    showDialog(
      context: context,
      builder: (context) => StaffDetailsDialog(
        staff: staff,
        records: staffRecords,
        selectedDate: _selectedDate!,
        taskSchedules: _taskSchedules,
        selectedProject: _selectedProject!,
        qrLookups: _qrLookups,
      ),
    );
  }

  Future<void> _exportMonth() async {
    if (_isLoading || _selectedDate == null) return;
    
    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang chuẩn bị xuất file Excel tháng...';
    });

    ProgressDialog.show(context, 'Đang chuẩn bị dữ liệu tháng...');

    try {
      final selectedDateTime = DateTime.parse(_selectedDate!);
      await ProjectCongNhanExcel.exportToExcelMonth(
        allData: _processedData,
        projectOptions: _projectOptions,
        selectedMonth: selectedDateTime,
        context: context,
        taskSchedules: _taskSchedules,
        qrLookups: _qrLookups,
      );
      
      ProgressDialog.hide();
      _showSuccess('Xuất Excel tháng thành công');
    } catch (e) {
      ProgressDialog.hide();
      _showError('Lỗi xuất Excel tháng: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  void _showProjectScheduleDialog() {
    if (_selectedProject == null || _selectedDate == null) {
      _showError('Vui lòng chọn dự án và ngày');
      return;
    }

    final selectedDateTime = DateTime.parse(_selectedDate!);
    final dayTasks = TaskScheduleManager.getTasksForProjectAndDate(
      _taskSchedules,
      _selectedProject!,
      selectedDateTime,
      _qrLookups,
    );

    showDialog(
      context: context,
      builder: (context) => ProjectScheduleDialog(
        projectName: _selectedProject!,
        selectedDate: _selectedDate!,
        dayTasks: dayTasks,
        allTasks: _taskSchedules,
        qrLookups: _qrLookups,
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red, duration: Duration(seconds: 3)),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
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
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 16),
              Text(
                'Báo cáo nhân sự',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Spacer(),
              if (_isLoading)
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black87)),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _syncStatus.isNotEmpty ? _syncStatus : 'Đang đồng bộ...',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              if (!_isLoading)
                Text(
                  'Tự động đồng bộ mỗi 30 phút',
                  style: TextStyle(color: Colors.black54, fontSize: 8),
                ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (!_isLoading) _buildHeaderButton(
                    onPressed: () => _syncTaskSchedules(),
                    icon: Icons.schedule,
                    label: 'Đồng bộ LLV',
                    color: Colors.purple[600]!,
                  ),
                  SizedBox(width: 8),
                  if (!_isLoading) _buildHeaderButton(
                    onPressed: () => _syncStaffBio(),
                    icon: Icons.people,
                    label: 'Đồng bộ tên NV',
                    color: Colors.orange[600]!,
                  ),
                  SizedBox(width: 8),
                  if (!_isLoading) _buildHeaderButton(
                    onPressed: () => _syncData(),
                    icon: Icons.refresh,
                    label: 'Đồng bộ',
                    color: Colors.white,
                    textColor: Colors.black87,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    Color? textColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor ?? Colors.white,
        elevation: 2,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(0, 32),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dự án', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedProject,
                      hint: Text('Chọn dự án'),
                      isExpanded: true,
                      items: _projectOptions.map((project) {
                        return DropdownMenuItem(value: project, child: Text(project, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProject = value;
                          _updateChartData();
                          _updateFilteredStaff();
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ngày', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDate,
                      hint: Text('Chọn ngày'),
                      items: _dateOptions.map((date) {
                        return DropdownMenuItem(
                          value: date,
                          child: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(date))),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDate = value;
                          _updateFilteredStaff();
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loại báo cáo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedReportType,
                      items: _reportTypeOptions.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedReportType = value!;
                          _updateFilteredStaff();
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Người báo cáo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedEntityType,
                      items: _entityTypeOptions.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedEntityType = value!;
                          _updateFilteredStaff();
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeChart() {
    if (_selectedProject == null || _chartDates.isEmpty) {
      return SizedBox.shrink();
    }

    final isDesktop = MediaQuery.of(context).size.width > 1200;

    // Prepare data for line chart
    final reportTypeData = <String, List<FlSpot>>{
      'Robot': [],
      'Máy móc': [],
      'Chất lượng khác': [],
    };

    for (int i = 0; i < _chartDates.length; i++) {
      final dateStr = _chartDates[i];
      final dayRecords = _processedData.where((record) => 
        record.boPhan == _selectedProject &&
        DateFormat('yyyy-MM-dd').format(record.ngay) == dateStr
      ).toList();

      final robotCount = dayRecords.where((r) => _getReportType(r.phanLoai) == 'Robot').length.toDouble();
      final machineCount = dayRecords.where((r) => _getReportType(r.phanLoai) == 'Máy móc').length.toDouble();
      final qualityCount = dayRecords.where((r) => _getReportType(r.phanLoai) == 'Chất lượng khác').length.toDouble();

      reportTypeData['Robot']!.add(FlSpot(i.toDouble(), robotCount));
      reportTypeData['Máy móc']!.add(FlSpot(i.toDouble(), machineCount));
      reportTypeData['Chất lượng khác']!.add(FlSpot(i.toDouble(), qualityCount));
    }

    final maxY = reportTypeData.values
        .expand((spots) => spots.map((spot) => spot.y))
        .fold(0.0, (max, value) => value > max ? value : max) * 1.1;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue[600]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Thống kê theo loại báo cáo (4 ngày gần nhất)',
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 20,
            children: [
              _buildLegendItem('Robot', Colors.red),
              _buildLegendItem('Máy móc', Colors.green),
              _buildLegendItem('Chất lượng khác', Colors.orange),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: isDesktop ? 300 : 250,
            child: LineChart(
              LineChartData(
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: reportTypeData['Robot']!,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: reportTypeData['Máy móc']!,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: reportTypeData['Chất lượng khác']!,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _chartDates.length) {
                          final dateStr = _chartDates[index];
                          final date = DateTime.parse(dateStr);
                          return Transform.rotate(
                            angle: isDesktop ? 0 : -0.5,
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: TextStyle(fontSize: isDesktop ? 10 : 8),
                            ),
                          );
                        }
                        return Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStaffTable() {
    if (_selectedProject == null || _selectedDate == null) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.filter_list, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'Vui lòng chọn dự án và ngày để xem danh sách nhân sự',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_allProjectStaff.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'Không có nhân sự nào trong dự án đã chọn',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue[600]),
                    SizedBox(width: 8),
                    Text(
                      'Danh sách nhân sự (${_filteredStaff.length} có báo cáo, ${_allProjectStaff.length - _filteredStaff.length} chưa báo cáo)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  height: 50,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildActionButton(
                          onPressed: _isLoading ? null : () => _exportMonth(),
                          icon: Icons.calendar_month,
                          label: 'Xuất excel',
                          color: Colors.orange[600]!,
                        ),
                        SizedBox(width: 8),
                        _buildActionButton(
                          onPressed: (_isLoading || _selectedProject == null || _taskSchedules.isEmpty) ? null : () => _showProjectScheduleDialog(),
                          icon: Icons.schedule,
                          label: 'Xem lịch',
                          color: Colors.purple[600]!,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildDailyReportMatrix(),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size(0, 32),
      ),
    );
  }
bool _isCalculatingMatrix = false;

  Widget _buildDailyReportMatrix() {
  if (_selectedProject == null || _allProjectStaff.isEmpty || _chartDates.isEmpty) {
    return SizedBox.shrink();
  }

  if (_isCalculatingMatrix) {
    return Container(
      margin: EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.grid_on, color: Colors.green[600]),
                SizedBox(width: 8),
                Text(
                  'Đang tính toán ma trận báo cáo...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800]),
                ),
                Spacer(),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang xử lý dữ liệu...'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

    final isDesktop = MediaQuery.of(context).size.width > 1200;

    // Get report counts for each staff per day
    Map<String, Map<String, int>> staffDayReports = {};
    
    for (final staff in _allProjectStaff) {
      staffDayReports[staff.username] = {};
      for (final dateStr in _chartDates) {
        final dailyReports = _processedData.where((record) => 
          record.boPhan == _selectedProject &&
          DateFormat('yyyy-MM-dd').format(record.ngay) == dateStr &&
          record.nguoiDung == staff.username
        ).length;
        staffDayReports[staff.username]![dateStr] = dailyReports;
      }
    }

    return Container(
      margin: EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.grid_on, color: Colors.green[600]),
                SizedBox(width: 8),
                Text(
                  'Nhân sự báo cáo theo ngày',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800]),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: (isDesktop ? 250 : 200) + (_chartDates.length * (isDesktop ? 80.0 : 60.0)) + 80,
                child: Column(
                  children: [
                    Container(
                      height: 50,
                      child: Row(
                        children: [
                          Container(
                            width: isDesktop ? 250 : 200,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[300]!),
                                right: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text('Tên nhân sự', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          ..._chartDates.map((dateStr) {
                            final date = DateTime.parse(dateStr);
                            return Container(
                              width: isDesktop ? 80 : 60,
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[300]!),
                                  right: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: TextStyle(
                                  fontSize: isDesktop ? 12 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                          Container(
                            width: 80,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                            ),
                            alignment: Alignment.center,
                            child: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: List.generate(_allProjectStaff.length, (staffIndex) {
                            final staff = _allProjectStaff[staffIndex];
                            
                            return Container(
                              height: 60,
                              child: Row(
                                children: [
                                  Container(
                                    width: isDesktop ? 250 : 200,
                                    height: 60,
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: staffIndex % 2 == 0 ? Colors.white : Colors.grey[50],
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[200]!),
                                        right: BorderSide(color: Colors.grey[300]!),
                                      ),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          staff.displayName,
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${staff.username} (${staff.entityType})',
                                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._chartDates.map((dateStr) {
                                    final reportCount = staffDayReports[staff.username]?[dateStr] ?? 0;
                                    return Container(
                                      width: isDesktop ? 80 : 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: staffIndex % 2 == 0 ? Colors.white : Colors.grey[50],
                                        border: Border(
                                          bottom: BorderSide(color: Colors.grey[200]!),
                                          right: BorderSide(color: Colors.grey[300]!),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: reportCount > 0
                                          ? Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getReportCountColor(reportCount).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _getReportCountColor(reportCount),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                reportCount.toString(),
                                                style: TextStyle(
                                                  fontSize: isDesktop ? 12 : 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getReportCountColor(reportCount),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              '-',
                                              style: TextStyle(
                                                fontSize: isDesktop ? 12 : 10,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                    );
                                  }).toList(),
                                  Container(
                                    width: 80,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: staffIndex % 2 == 0 ? Colors.white : Colors.grey[50],
                                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                    ),
                                    alignment: Alignment.center,
                                    child: staff.hasReported
                                        ? IconButton(
                                            icon: Icon(Icons.open_in_new, color: Colors.blue[600], size: 16),
                                            onPressed: () => _showStaffDetails(staff),
                                            tooltip: 'Xem chi tiết',
                                          )
                                        : Icon(Icons.remove, color: Colors.grey[400], size: 16),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildMatrixLegendItem('1-2 báo cáo', Colors.blue),
                _buildMatrixLegendItem('3-5 báo cáo', Colors.green),
                _buildMatrixLegendItem('6-10 báo cáo', Colors.orange),
                _buildMatrixLegendItem('>10 báo cáo', Colors.red),
                _buildMatrixLegendItem('Không báo cáo', Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getReportCountColor(int count) {
    if (count == 0) return Colors.grey;
    if (count <= 2) return Colors.blue;
    if (count <= 5) return Colors.green;
    if (count <= 10) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMatrixLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
String _formatKetQua(String? ketQua) {
  if (ketQua == null) return '';
  if (ketQua == '✔️') return '✔️ Tốt';
  return '$ketQua Chưa tốt';
}

Color _getStatusColor(String? ketQua) {
  if (ketQua == null) return Colors.grey;
  if (ketQua == '✔️') return Colors.green;
  return Colors.red; 
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          if (_syncStatus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Colors.blue[900],
              child: Text(
                _syncStatus,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          _buildFilters(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildReportTypeChart(),
                  _buildResultPercentageChart(),
                  _buildStaffTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StaffSummary {
  final String username;
  final String displayName;
  final String entityType;
  int reportCount;
  int imageCount;
  int topicCount;
  int hourCount;
  final Set<String> topics;
  final Set<String> hours;
  bool hasReported;

  StaffSummary({
    required this.username,
    required this.displayName,
    required this.entityType,
    this.reportCount = 0,
    this.imageCount = 0,
    this.topicCount = 0,
    this.hourCount = 0,
    required this.topics,
    required this.hours,
    this.hasReported = false,
  });
}

class StaffDetailsDialog extends StatelessWidget {
  final StaffSummary staff;
  final List<TaskHistoryModel> records;
  final String selectedDate;
  final List<TaskScheduleModel> taskSchedules;
  final String selectedProject;
  final List<QRLookupModel> qrLookups;

  const StaffDetailsDialog({
    Key? key,
    required this.staff,
    required this.records,
    required this.selectedDate,
    this.taskSchedules = const [],
    this.selectedProject = '',
    this.qrLookups = const [],
  }) : super(key: key);

  String _formatKetQua(String? ketQua) {
    if (ketQua == null) return '';
    switch (ketQua) {
      case '✔️': return '✔️ Đạt';
      case '❌': return '❌ Không làm';
      case '⚠️': return '⚠️ Chưa tốt';
      default: return ketQua;
    }
  }

  Color _getStatusColor(String? ketQua) {
    if (ketQua == null) return Colors.grey;
    switch (ketQua) {
      case '✔️': return Colors.green;
      case '❌': return Colors.red;
      case '⚠️': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    
    return Dialog(
      child: Container(
        width: isDesktop ? 800 : MediaQuery.of(context).size.width * 0.9,
        height: isDesktop ? 600 : MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${staff.displayName} (${staff.username})',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(DateTime.parse(selectedDate))} | ${staff.entityType}',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(record.ketQua).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _getStatusColor(record.ketQua)),
                                ),
                                child: Text(
                                  _formatKetQua(record.ketQua),
                                  style: TextStyle(
                                    color: _getStatusColor(record.ketQua),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Spacer(),
                              Text(record.gio ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          SizedBox(height: 8),
                          if (record.chiTiet?.isNotEmpty == true)
                            Text(record.chiTiet!, style: TextStyle(fontSize: 14)),
                          if (record.phanLoai?.isNotEmpty == true) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                record.phanLoai!,
                                style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                          if (record.hinhAnh?.isNotEmpty == true) ...[
                            SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _showFullImage(context, record.hinhAnh!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: record.hinhAnh!,
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 100,
                                    width: 100,
                                    color: Colors.grey[200],
                                    child: Icon(Icons.image, color: Colors.grey[400]),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 100,
                                    width: 100,
                                    color: Colors.grey[200],
                                    child: Icon(Icons.broken_image, color: Colors.grey[400]),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => FullImageDialog(imageUrl: imageUrl),
    );
  }
}

class FullImageDialog extends StatelessWidget {
  final String imageUrl;

  const FullImageDialog({Key? key, required this.imageUrl}) : super(key: key);

  Future<void> _saveImage() async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(imagePath);
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(imagePath)], text: 'Hình ảnh từ báo cáo');
      }
    } catch (e) {
      print('Error saving image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: Row(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: _saveImage,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.share, color: Colors.black),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: Colors.white,
                  child: Icon(Icons.close, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectScheduleDialog extends StatefulWidget {
  final String projectName;
  final String selectedDate;
  final List<TaskScheduleModel> dayTasks;
  final List<TaskScheduleModel> allTasks;
  final List<QRLookupModel> qrLookups;

  const ProjectScheduleDialog({
    Key? key,
    required this.projectName,
    required this.selectedDate,
    required this.dayTasks,
    required this.allTasks,
    required this.qrLookups,
  }) : super(key: key);

  @override
  _ProjectScheduleDialogState createState() => _ProjectScheduleDialogState();
}

class _ProjectScheduleDialogState extends State<ProjectScheduleDialog> {
  bool _showAllDays = false;
  Map<String, List<TaskScheduleModel>> _tasksByPosition = {};

  @override
  void initState() {
    super.initState();
    _updateTasksByPosition();
  }

  void _updateTasksByPosition() {
    final tasksToShow = _showAllDays 
        ? widget.allTasks.where((task) {
            final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, widget.qrLookups);
            return userMapping['projectName'] == widget.projectName;
          }).toList()
        : widget.dayTasks;

    _tasksByPosition.clear();
    for (final task in tasksToShow) {
      final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, widget.qrLookups);
      final positionName = userMapping['positionName'];
      if (positionName?.isNotEmpty == true) {
        _tasksByPosition.putIfAbsent(positionName!, () => []).add(task);
      }
    }
    
    for (final tasks in _tasksByPosition.values) {
      tasks.sort((a, b) => a.start.compareTo(b.start));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final positions = _tasksByPosition.keys.toList()..sort();
    
    return Dialog(
      child: Container(
        width: isDesktop ? 1000 : MediaQuery.of(context).size.width * 0.95,
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
                  Icon(Icons.schedule, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lịch làm việc - ${widget.projectName}',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _showAllDays 
                              ? 'Tất cả các ngày (${_tasksByPosition.values.fold<int>(0, (sum, tasks) => sum + tasks.length)} nhiệm vụ)'
                              : 'Ngày ${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.selectedDate))} (${widget.dayTasks.length} nhiệm vụ)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAllDays = !_showAllDays;
                        _updateTasksByPosition();
                      });
                    },
                    icon: Icon(_showAllDays ? Icons.today : Icons.calendar_month, size: 16),
                    label: Text(_showAllDays ? 'Chỉ hôm nay' : 'Tất cả ngày'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple[600],
                      elevation: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: positions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule_outlined, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            _showAllDays ? 'Không có lịch làm việc nào cho dự án này' : 'Không có lịch làm việc nào cho ngày đã chọn',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: positions.length,
                      itemBuilder: (context, index) {
                        final position = positions[index];
                        final tasks = _tasksByPosition[position]!;
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            initiallyExpanded: positions.length <= 3,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue),
                              ),
                              child: Icon(Icons.person, color: Colors.blue),
                            ),
                            title: Text(position, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            subtitle: Text('${tasks.length} nhiệm vụ', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            children: tasks.map((task) => Container(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.blue),
                                        ),
                                        child: Text(
                                          '${TaskScheduleManager.formatScheduleTime(task.start)} - ${TaskScheduleManager.formatScheduleTime(task.end)}',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(task.task, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  SizedBox(height: 4),
                                  Text('ID: ${task.taskId}', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
                                ],
                              ),
                            )).toList(),
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