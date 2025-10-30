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
import 'dart:typed_data';
import 'db_helper.dart';
import 'table_models.dart';
import 'projectcongnhanexcelgs.dart';
import 'projectcongnhanllvgs.dart';
//import 'projectcongnhanbio.dart';
import 'dart:math';
class ProjectGiamSat extends StatefulWidget {
  final String username;

  const ProjectGiamSat({Key? key, required this.username}) : super(key: key);

  @override
  _ProjectGiamSatState createState() => _ProjectGiamSatState();
}

class _ProjectGiamSatState extends State<ProjectGiamSat> {
  bool _isLoading = false;
  List<TaskHistoryModel> _allData = [];
  List<TaskHistoryModel> _processedData = []; // Data with corrected BoPhan
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  String _syncStatus = '';
  List<TaskScheduleModel> _taskSchedules = [];
bool _hasTaskSchedulesSynced = false;
List<QRLookupModel> _qrLookups = [];

  // Sync configuration
  Timer? _syncTimer;
  final Duration _syncInterval = Duration(minutes: 30); 
  
  // Filter variables
  List<String> _projectOptions = [];
  List<String> _dateOptions = [];
  String? _selectedProject;
  String? _selectedDate;
  List<WorkerSummary> _filteredWorkers = [];
  List<WorkerSummary> _unavailableWorkers = [];
  
  // Chart data
  List<FlSpot> _recordCountSpots = [];
  List<BarChartGroupData> _uniqueWorkerBars = [];
  double _maxRecordCount = 0;
  double _maxUniqueWorkers = 0;
  List<String> _chartDates = [];
  
  // Chart display settings
  int _displayDateCount = 7; // Default to show 7 dates
  int _maxDisplayDates = 30; // Maximum dates available

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
  
  // 33% base chance, but can be modified by other factors
  double syncProbability = 0.18;
  
  // Optional: Increase chance if it's been a while since last sync
  final prefs = await SharedPreferences.getInstance();
  final lastSync = prefs.getInt('lastTaskScheduleSync') ?? 0;
  final hoursSinceLastSync = (DateTime.now().millisecondsSinceEpoch - lastSync) / (1000 * 60 * 60);
  
  if (hoursSinceLastSync > 24) {
    syncProbability = 0.36; // Increase to 36% if more than 24 hours
  }
  
  final random = Random();
  if (random.nextDouble() < syncProbability) {
    print('TaskSchedule sync triggered (${(syncProbability * 100).toInt()}% chance)');
    _syncTaskSchedules();
  } else {
    print('TaskSchedule sync skipped');
  }
  
  _processBoPhanCorrection();
  _updateFilterOptions();
  _autoSelectFilters();
  _startSyncTimer();
  
  // Check task schedules sync status
  _hasTaskSchedulesSynced = await TaskScheduleManager.hasEverSynced();
  if (_hasTaskSchedulesSynced) {
    _taskSchedules = await TaskScheduleManager.getTaskSchedules();
    _qrLookups = await TaskScheduleManager.getQRLookups();
  }
  setState(() {});
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
    print('Error syncing task schedules: $e');
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
    final prefs = await SharedPreferences.getInstance();
    
    // Get from locally saved stafflistvp data
    final String? staffListVPJson = prefs.getString('stafflistvp_data');
    
    if (staffListVPJson != null && staffListVPJson.isNotEmpty) {
      // Use stafflistvp data
      final List<dynamic> staffListVPData = json.decode(staffListVPJson);
      final Map<String, String> nameMap = {};
      
      for (final staff in staffListVPData) {
        if (staff['Username'] != null && staff['Name'] != null) {
          final username = staff['Username'].toString();
          final name = staff['Name'].toString();
          nameMap[username.toLowerCase()] = name;
          nameMap[username.toUpperCase()] = name;
          nameMap[username] = name; // Original case
        }
      }
      return nameMap;
    } else {
      // Return empty map if no stafflistvp data available
      return {};
    }
  } catch (e) {
    print('Error loading staff names: $e');
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
      final response = await http.get(
        Uri.parse('$baseUrl/projectcongnhangs/${widget.username}')
      );

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
        _processBoPhanCorrection(); // Process BoPhan correction after sync
        _updateFilterOptions();
        _autoSelectFilters(); // Auto-select after sync
        
        _showSuccess('Đồng bộ thành công - ${_allData.length} bản ghi');
      } else {
        throw Exception('Failed to sync data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing data: $e');
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
      print('Error loading data: $e');
      _showError('Lỗi tải dữ liệu');
    }
  }

  void _processBoPhanCorrection() {
    // Create a copy of all data for processing
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

    // Group records by worker and date
    final workerDateGroups = <String, List<TaskHistoryModel>>{};
    
    for (final record in _processedData) {
      if (record.nguoiDung?.isNotEmpty == true) {
        final key = '${record.nguoiDung}_${DateFormat('yyyy-MM-dd').format(record.ngay)}';
        workerDateGroups.putIfAbsent(key, () => []).add(record);
      }
    }

    // Process each worker-date group
    for (final group in workerDateGroups.values) {
      if (group.length <= 1) continue; // Skip if only one record
      
      // Find valid BoPhan projects in this group
      final validProjects = <String, int>{};
      for (final record in group) {
        if (record.boPhan != null && !_shouldFilterProject(record.boPhan!)) {
          validProjects[record.boPhan!] = (validProjects[record.boPhan!] ?? 0) + 1;
        }
      }
      
      // Determine the most common valid project for this worker-date
      String? correctProject;
      if (validProjects.isNotEmpty) {
        correctProject = validProjects.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }
      
      // Apply correction to records with invalid BoPhan
      if (correctProject != null) {
        for (final record in group) {
          if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) {
            record.boPhan = correctProject; // Correct the BoPhan
            print('Corrected BoPhan for ${record.nguoiDung} on ${DateFormat('yyyy-MM-dd').format(record.ngay)}: $correctProject');
          }
        }
      }
    }
  }

  void _updateFilterOptions() {
    // Get unique BoPhan values (projects) from processed data
    final projectSet = <String>{};
    for (final record in _processedData) {
      if (record.boPhan != null && 
          record.boPhan!.trim().isNotEmpty && 
          !_shouldFilterProject(record.boPhan!)) {
        projectSet.add(record.boPhan!);
      }
    }
    
    // Get unique dates from processed data
    final dateSet = <String>{};
    for (final record in _processedData) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.ngay);
      dateSet.add(dateStr);
    }

    setState(() {
      _projectOptions = projectSet.toList()..sort();
      _dateOptions = dateSet.toList()..sort((a, b) => b.compareTo(a)); // Latest first
      _maxDisplayDates = _dateOptions.length;
      if (_displayDateCount > _maxDisplayDates) {
        _displayDateCount = _maxDisplayDates;
      }
    });
  }

  void _autoSelectFilters() {
    // Auto-select latest date if none selected
    if (_selectedDate == null && _dateOptions.isNotEmpty) {
      _selectedDate = _dateOptions.first; // First item is latest due to sorting
    }
    
    // Auto-select first project if none selected
    if (_selectedProject == null && _projectOptions.isNotEmpty) {
      _selectedProject = _projectOptions.first;
    }
    
    // Update workers and chart data
    if (_selectedProject != null && _selectedDate != null) {
      _updateFilteredWorkers();
      _updateChartData();
    }
  }

  bool _shouldFilterProject(String? projectName) {
  if (projectName == null || projectName.trim().isEmpty) return true;
  final name = projectName.toLowerCase();
  final originalName = projectName.trim();
  
  // 1. Filter out "unknown"
  if (name == 'unknown') return true;
  
  // 2. Filter out "hm" + numbers (e.g., "hm123", "hm45")
  if (name.length >= 3 && name.startsWith('hm')) {
    if (RegExp(r'^hm\d').hasMatch(name)) return true;
  }
  
  // 3. Filter out "tv" + numbers (e.g., "tv123", "tv45")
  if (name.length >= 3 && name.startsWith('tv')) {
    if (RegExp(r'^tv\d').hasMatch(name)) return true;
  }
  
  // 4. Filter out "tvn" + numbers (e.g., "tvn123", "tvn45")
  if (name.length >= 4 && name.startsWith('tvn')) {
    if (RegExp(r'^tvn\d').hasMatch(name)) return true;
  }
  
  // 5. Filter out "nvhm" + numbers (e.g., "nvhm123", "nvhm45")
  if (name.length >= 5 && name.startsWith('nvhm')) {
    if (RegExp(r'^nvhm\d').hasMatch(name)) return true;
  }
  
  // 6. Filter out URLs starting with "http:" or "https:"
  if (name.startsWith('http:') || name.startsWith('https:')) return true;
  
  // 7. Filter out pattern: 2-5 characters + "-" + numbers (e.g., "ab-123", "xyz-45")
  if (RegExp(r'^[a-z]{2,5}-\d+$').hasMatch(name)) return true;
  
  // 8. Filter out full capitalized text with no spaces (e.g., "ABCDEF", "XYZ123")
  if (originalName == originalName.toUpperCase() && 
      !originalName.contains(' ') && 
      originalName.length > 1) return true;
  
  return false;
}

  void _updateFilteredWorkers() async {
  if (_selectedProject == null || _selectedDate == null) {
    setState(() {
      _filteredWorkers = [];
      _unavailableWorkers = [];
    });
    return;
  }

  // Get staff name mapping
  final staffNameMap = await _getStaffNameMap();

  // Get all workers for the selected project across all dates (using processed data)
  final allProjectWorkers = <String>{};
  final availableWorkers = <String>{};
  final workerDataMap = <String, WorkerSummary>{};
  
  // First pass: get all workers for this project
  for (final record in _processedData) {
    if (record.boPhan == _selectedProject &&
        record.nguoiDung != null &&
        record.nguoiDung!.trim().isNotEmpty) {
      allProjectWorkers.add(record.nguoiDung!);
    }
  }
  
  // Second pass: get workers available on selected date and their stats
  final relevantRecords = _processedData.where((record) => 
    record.boPhan == _selectedProject &&
    DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate &&
    record.nguoiDung != null &&
    record.nguoiDung!.trim().isNotEmpty
  ).toList();

  for (final record in relevantRecords) {
    final workerName = record.nguoiDung!;
    final capitalizedWorkerName = workerName.toUpperCase(); // Capitalize for lookup
    availableWorkers.add(workerName);
    
    if (!workerDataMap.containsKey(workerName)) {
      workerDataMap[workerName] = WorkerSummary(
        name: workerName,
        displayName: staffNameMap[capitalizedWorkerName] ?? '❓❓❓', // Use capitalized version for lookup
        reportCount: 0,
        imageCount: 0,
        topicCount: 0,
        hourCount: 0,
        topics: <String>{},
        hours: <String>{},
        isAvailable: true,
      );
    }
    
    final summary = workerDataMap[workerName]!;
    summary.reportCount++;
    
    // Count images
    if (record.hinhAnh != null && record.hinhAnh!.trim().isNotEmpty) {
      summary.imageCount++;
    }
    
    // Count unique topics
    if (record.phanLoai != null && record.phanLoai!.trim().isNotEmpty) {
      summary.topics.add(record.phanLoai!);
    }
    
    // Count unique hours
    if (record.gio != null && record.gio!.trim().isNotEmpty) {
      try {
        final timeParts = record.gio!.split(':');
        if (timeParts.isNotEmpty) {
          summary.hours.add(timeParts[0]); // Hour portion
        }
      } catch (e) {
        // Handle any time parsing errors
      }
    }
  }
  
  // Create summaries for unavailable workers
  final unavailableWorkerNames = allProjectWorkers.difference(availableWorkers);
  for (final workerName in unavailableWorkerNames) {
    final capitalizedWorkerName = workerName.toUpperCase(); // Capitalize for lookup
    workerDataMap[workerName] = WorkerSummary(
      name: workerName,
      displayName: staffNameMap[capitalizedWorkerName] ?? '❓❓❓', // Use capitalized version for lookup
      reportCount: 0,
      imageCount: 0,
      topicCount: 0,
      hourCount: 0,
      topics: <String>{},
      hours: <String>{},
      isAvailable: false,
    );
  }
  
  // Finalize topic and hour counts
  for (final summary in workerDataMap.values) {
    summary.topicCount = summary.topics.length;
    summary.hourCount = summary.hours.length;
  }

  // Separate available and unavailable workers
  final available = workerDataMap.values.where((w) => w.isAvailable).toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName)); // Sort by display name
  final unavailable = workerDataMap.values.where((w) => !w.isAvailable).toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName)); // Sort by display name

  setState(() {
    _filteredWorkers = available;
    _unavailableWorkers = unavailable;
  });
}
Future<void> _syncStaffListVP() async {
  if (_isLoading) return;

  setState(() {
    _isLoading = true;
    _syncStatus = 'Đang cập nhật danh sách nhân viên...';
  });

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/stafflistvp'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> staffListData = json.decode(response.body);
      
      // Save to SharedPreferences as JSON string
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stafflistvp_data', json.encode(staffListData));
      await prefs.setBool('hasStaffListVPSynced', true);

      // Refresh the workers list to show updated names
      _updateFilteredWorkers();
      
      _showSuccess('Cập nhật danh sách nhân viên thành công - ${staffListData.length} bản ghi');
    } else {
      throw Exception('Server returned ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing staff list VP: $e');
    _showError('Không thể cập nhật danh sách nhân viên: ${e.toString()}');
  } finally {
    setState(() {
      _isLoading = false;
      _syncStatus = '';
    });
  }
}
  void _updateChartData() {
    if (_selectedProject == null) {
      setState(() {
        _recordCountSpots = [];
        _uniqueWorkerBars = [];
        _maxRecordCount = 0;
        _maxUniqueWorkers = 0;
        _chartDates = [];
      });
      return;
    }

    // Get all dates for selected project and sort them (using processed data)
    final projectData = _processedData.where((record) => record.boPhan == _selectedProject).toList();
    final dateMap = <String, List<TaskHistoryModel>>{};
    
    for (final record in projectData) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.ngay);
      dateMap.putIfAbsent(dateStr, () => []).add(record);
    }
    
    // Sort dates: latest to oldest (reverse chronological) and ensure uniqueness
    final allSortedDates = dateMap.keys.toList()..sort((a, b) => b.compareTo(a));
    
    // Take only the number of dates to display
    final displayDates = allSortedDates.take(_displayDateCount).toList();
    
    final recordSpots = <FlSpot>[];
    final workerBars = <BarChartGroupData>[];
    double maxRecords = 0;
    double maxWorkers = 0;
    
    for (int i = 0; i < displayDates.length; i++) {
      final dateStr = displayDates[i];
      final dayRecords = dateMap[dateStr]!;
      final recordCount = dayRecords.length.toDouble();
      final uniqueWorkers = dayRecords.map((r) => r.nguoiDung).toSet().length.toDouble();
      
      recordSpots.add(FlSpot(i.toDouble(), recordCount));
      workerBars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: uniqueWorkers,
              color: Colors.orange.withOpacity(0.7),
              width: MediaQuery.of(context).size.width > 600 ? 12 : 8,
            ),
          ],
        ),
      );
      
      if (recordCount > maxRecords) maxRecords = recordCount;
      if (uniqueWorkers > maxWorkers) maxWorkers = uniqueWorkers;
    }
    
    setState(() {
      _recordCountSpots = recordSpots;
      _uniqueWorkerBars = workerBars;
      _maxRecordCount = maxRecords;
      _maxUniqueWorkers = maxWorkers;
      _chartDates = displayDates; // This ensures unique dates for x-axis labels
    });
  }
void _showWorkerDetails(WorkerSummary worker) {
  if (!worker.isAvailable) return;

  // Get all records for this worker on selected date (using processed data)
  final workerRecords = _processedData.where((record) => 
    record.boPhan == _selectedProject &&
    DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate &&
    record.nguoiDung == worker.name
  ).toList();

  // Sort by time (chronological order)
  workerRecords.sort((a, b) {
    final timeA = a.gio ?? '';
    final timeB = b.gio ?? '';
    return timeA.compareTo(timeB);
  });

  showDialog(
    context: context,
    builder: (context) => WorkerDetailsDialog(
      worker: worker,
      records: workerRecords,
      selectedDate: _selectedDate!,
      taskSchedules: _taskSchedules,
      selectedProject: _selectedProject!,
      qrLookups: _qrLookups, 
    ),
  );
}
Widget _buildTaskScheduleInfo() {
  if (_selectedProject == null || _taskSchedules.isEmpty || _selectedDate == null) {
    return SizedBox.shrink();
  }

  final selectedDateTime = DateTime.parse(_selectedDate!);
  final dayTasks = TaskScheduleManager.getTasksForProjectAndDate(
    _taskSchedules,
    _selectedProject!,
    selectedDateTime,
    _qrLookups, // Add missing QR lookups parameter
  );

  if (dayTasks.isEmpty) return SizedBox.shrink();

  // Group tasks by position using QR lookup
  final tasksByPosition = <String, List<TaskScheduleModel>>{};
  for (final task in dayTasks) {
    final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, _qrLookups);
    final positionName = userMapping['positionName'];
    if (positionName?.isNotEmpty == true) {
      tasksByPosition.putIfAbsent(positionName!, () => []).add(task);
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
  );
}
  Future<void> _showFullImage(String imageUrl) async {
    showDialog(
      context: context,
      builder: (context) => FullImageDialog(imageUrl: imageUrl),
    );
  }

  int _getRecommendedDateCount() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 30; // Desktop
    if (screenWidth > 800) return 20;  // Tablet
    if (screenWidth > 600) return 14;  // Large phone
    return 7; // Small phone
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
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
        // Back button
        IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
        SizedBox(width: 16),
        Text(
          'Dự án - Giám sát',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Spacer(),
        // Task schedule sync button (only show if never synced)
        //if (!_hasTaskSchedulesSynced && !_isLoading)
        if (!_isLoading)
          ElevatedButton.icon(
            onPressed: () => _syncTaskSchedules(),
            icon: Icon(Icons.schedule, size: 18),
            label: Text('Đồng bộ LLV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
              elevation: 2,
            ),
          ),
        if (!_hasTaskSchedulesSynced && !_isLoading)
          SizedBox(width: 12),
        // Staff bio sync button
        if (!_isLoading)
          ElevatedButton.icon(
            onPressed: () => _syncStaffListVP(),
            icon: Icon(Icons.people, size: 18),
            label: Text('Đồng bộ tên VP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              elevation: 2,
            ),
          ),
        SizedBox(width: 12),
        // Manual sync button
        if (!_isLoading)
          ElevatedButton.icon(
            onPressed: () => _syncData(),
            icon: Icon(Icons.refresh, size: 18),
            label: Text('Đồng bộ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 2,
            ),
          ),
        SizedBox(width: 12),
        if (_isLoading)
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
              ),
              SizedBox(width: 8),
              Text(
                _syncStatus.isNotEmpty ? _syncStatus : 'Đang đồng bộ...',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        if (!_isLoading)
          Text(
            'Tự động đồng bộ mỗi 30 phút',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
      ],
    ),
  );
}

  Widget _buildFilters() {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
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
        Text(
          'Bộ lọc',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            // Project dropdown with search
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dự án',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProject,
                    hint: Text('Chọn dự án'),
                    isExpanded: true,
                    items: _projectOptions.map((project) {
                      return DropdownMenuItem(
                        value: project,
                        child: Text(
                          project,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedProject = value;
                        _updateFilteredWorkers();
                        _updateChartData();
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search),
                        onPressed: () => _showProjectSearchDialog(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            // Date dropdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ngày',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedDate,
                    hint: Text('Chọn ngày'),
                    items: _dateOptions.map((date) {
                      return DropdownMenuItem(
                        value: date,
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.parse(date)),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDate = value;
                        _updateFilteredWorkers();
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
void _showProjectSearchDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return ProjectSearchDialog(
        projects: _projectOptions,
        selectedProject: _selectedProject,
        onProjectSelected: (String project) {
          setState(() {
            _selectedProject = project;
            _updateFilteredWorkers();
            _updateChartData();
          });
        },
      );
    },
  );
}
Widget _buildHourlyChart() {
  if (_selectedProject == null || _selectedDate == null) {
    return SizedBox.shrink();
  }

  final isDesktop = MediaQuery.of(context).size.width > 1200;
  final isTablet = MediaQuery.of(context).size.width > 600;

  // Parse hours and aggregate data
  final hourlyReportCounts = <int, int>{};
  final hourlyTopics = <int, Set<String>>{};
  final hourlyHasNhanSu = <int, bool>{};
  final hourlyHasIssues = <int, bool>{}; // Track hours with issues
  
  // Get relevant records for selected project and date
  final relevantRecords = _processedData.where((record) => 
    record.boPhan == _selectedProject &&
    DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate
  ).toList();

  for (final record in relevantRecords) {
    if (record.gio == null || record.gio!.isEmpty) continue;
    
    // Extract hour from time string (format: "HH:mm" or "HH:mm:ss")
    final timeParts = record.gio!.split(':');
    if (timeParts.isEmpty) continue;
    
    final hour = int.tryParse(timeParts[0]);
    if (hour == null || hour < 0 || hour > 23) continue;
    
    // Count reports per hour
    hourlyReportCounts[hour] = (hourlyReportCounts[hour] ?? 0) + 1;
    
    // Check for issues (KetQua != '✔️')
    if (record.ketQua != '✔️') {
      hourlyHasIssues[hour] = true;
    }
    
    // Collect unique topics (PhanLoai) per hour
    if (record.phanLoai != null && record.phanLoai!.trim().isNotEmpty) {
      hourlyTopics.putIfAbsent(hour, () => <String>{});
      hourlyTopics[hour]!.add(record.phanLoai!);
      
      // Check if this is a "Nhân sự" report
      if (record.phanLoai!.trim() == 'Nhân sự') {
        hourlyHasNhanSu[hour] = true;
      }
    }
  }
  
  // Create data for all 24 hours (0-23)
  final hourEntries = List.generate(24, (hour) {
    return MapEntry(
      hour,
      {
        'count': hourlyReportCounts[hour] ?? 0,
        'topics': (hourlyTopics[hour] ?? <String>{}).length,
        'hasNhanSu': hourlyHasNhanSu[hour] ?? false,
        'hasIssues': hourlyHasIssues[hour] ?? false,
      },
    );
  });
  
  final maxCount = hourlyReportCounts.values.isEmpty 
      ? 10.0
      : hourlyReportCounts.values.reduce((a, b) => a > b ? a : b).toDouble();
  final maxTopics = hourlyTopics.values.isEmpty 
      ? 5.0
      : hourlyTopics.values.map((s) => s.length).reduce((a, b) => a > b ? a : b).toDouble();

  if (hourlyReportCounts.isEmpty) {
    return SizedBox.shrink();
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
            Icon(Icons.access_time, color: Colors.purple[600]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tần suất báo cáo theo giờ',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            // Legend for report count
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 4),
            Text('Số báo cáo', style: TextStyle(fontSize: 12)),
            SizedBox(width: 16),
            // Legend for topics
            Container(
              width: 16,
              height: 3,
              color: Colors.orange,
            ),
            SizedBox(width: 4),
            Text('Số chủ đề', style: TextStyle(fontSize: 12)),
            SizedBox(width: 16),
            // Legend for Nhân sự
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 4),
            Text('Có báo cáo Nhân sự', style: TextStyle(fontSize: 12)),
            SizedBox(width: 16),
            // Legend for issues - MORE PROMINENT
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.red, width: 2),
              ),
            ),
            SizedBox(width: 4),
            Text('Có vấn đề', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[700])),
          ],
        ),
        SizedBox(height: 16),
        Container(
          height: isDesktop ? 350 : (isTablet ? 300 : 250),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // FIRST: Draw red backgrounds for hours with issues
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 40,
                        right: 40,
                        bottom: 30,
                        top: 0,
                      ),
                      child: CustomPaint(
                        painter: _IssueBackgroundPainter(
                          hourEntries: hourEntries,
                          maxCount: maxCount,
                        ),
                      ),
                    ),
                  ),
                  // THEN: Bar chart for report counts
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxCount + (maxCount * 0.2),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final hour = group.x.toInt();
                            if (hour < 0 || hour >= hourEntries.length) return null;
                            final data = hourEntries[hour].value;
                            final hasNhanSu = data['hasNhanSu'] as bool;
                            final hasIssues = data['hasIssues'] as bool;
                            return BarTooltipItem(
                              '${hour.toString().padLeft(2, '0')}:00\n'
                              'Báo cáo: ${data['count']}\n'
                              'Chủ đề: ${data['topics']}'
                              '${hasNhanSu ? '\n✓ Có Nhân sự' : ''}'
                              '${hasIssues ? '\n⚠️ CÓ VẤN ĐỀ' : ''}',
                              TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final hour = value.toInt();
                              // Show every 2 hours for better readability
                              if (hour >= 0 && hour <= 23 && hour % 2 == 0) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}h',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          axisNameWidget: Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Số báo cáo',
                              style: TextStyle(fontSize: 11, color: Colors.blue),
                            ),
                          ),
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(fontSize: 10, color: Colors.blue),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          axisNameWidget: Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Số chủ đề',
                              style: TextStyle(fontSize: 11, color: Colors.orange),
                            ),
                          ),
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              // Scale the right axis to match topic values
                              final topicValue = maxTopics > 0 
                                  ? (value / (maxCount + maxCount * 0.2)) * maxTopics 
                                  : 0;
                              return Text(
                                topicValue.toInt().toString(),
                                style: TextStyle(fontSize: 10, color: Colors.orange),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: (maxCount + maxCount * 0.2) / 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300],
                            strokeWidth: 0.5,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300],
                            strokeWidth: 0.5,
                            dashArray: [5, 5],
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(color: Colors.blue, width: 2),
                          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
                          right: BorderSide(color: Colors.orange, width: 2),
                        ),
                      ),
                      barGroups: hourEntries.map((entry) {
                        final hour = entry.key;
                        final data = entry.value;
                        final count = data['count'] as int;
                        final hasData = count > 0;
                        final hasNhanSu = data['hasNhanSu'] as bool;
                        
                        return BarChartGroupData(
                          x: hour,
                          barRods: [
                            BarChartRodData(
                              toY: count.toDouble(),
                              color: hasNhanSu 
                                  ? Colors.green.withOpacity(0.7) 
                                  : (hasData ? Colors.blue : Colors.grey[300]),
                              width: 12,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  // Custom painter for topic count line overlay
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 40,
                        right: 40,
                        bottom: 30,
                        top: 0,
                      ),
                      child: CustomPaint(
                        painter: _HourlyTopicLinePainter(
                          hourEntries: hourEntries,
                          maxCount: maxCount,
                          maxTopics: maxTopics,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(height: 12),
        // Summary statistics
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thống kê:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              SizedBox(height: 4),
              if (hourlyReportCounts.isNotEmpty)
                Text(
                  '• Giờ có nhiều báo cáo nhất: ${hourlyReportCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key.toString().padLeft(2, '0')}:00 (${hourlyReportCounts.values.reduce((a, b) => a > b ? a : b)} báo cáo)',
                  style: TextStyle(fontSize: 11),
                ),
              if (hourlyTopics.isNotEmpty)
                Text(
                  '• Giờ có nhiều chủ đề nhất: ${hourlyTopics.entries.reduce((a, b) => a.value.length > b.value.length ? a : b).key.toString().padLeft(2, '0')}:00 (${hourlyTopics.values.map((s) => s.length).reduce((a, b) => a > b ? a : b)} chủ đề)',
                  style: TextStyle(fontSize: 11),
                ),
              Text(
                '• Tổng số báo cáo: ${hourlyReportCounts.values.fold<int>(0, (a, b) => a + b)}',
                style: TextStyle(fontSize: 11),
              ),
              Text(
                '• Tổng số chủ đề khác nhau: ${hourlyTopics.values.fold<Set<String>>(<String>{}, (acc, topics) => acc..addAll(topics)).length}',
                style: TextStyle(fontSize: 11),
              ),
              if (hourlyHasNhanSu.isNotEmpty)
                Text(
                  '• Giờ có báo cáo Nhân sự: ${hourlyHasNhanSu.keys.map((h) => '${h.toString().padLeft(2, '0')}h').join(', ')}',
                  style: TextStyle(fontSize: 11, color: Colors.green[800], fontWeight: FontWeight.bold),
                ),
              // Show hours with issues
              if (hourlyHasIssues.isNotEmpty)
                Text(
                  '• Giờ có vấn đề: ${hourlyHasIssues.keys.map((h) => '${h.toString().padLeft(2, '0')}h').join(', ')}',
                  style: TextStyle(fontSize: 11, color: Colors.red[800], fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _buildIssuesList() {
  if (_selectedProject == null || _selectedDate == null) {
    return SizedBox.shrink();
  }

  final isDesktop = MediaQuery.of(context).size.width > 1200;
  final isTablet = MediaQuery.of(context).size.width > 600;

  // Get issues for selected project and date
  var issueRecords = _processedData.where((record) => 
    record.boPhan == _selectedProject &&
    DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate &&
    record.ketQua != '✔️' &&
    record.ketQua != null
  ).toList();

  // If no issues for selected project/date, get all issues from selected date
  final showAllProjects = issueRecords.isEmpty;
  if (showAllProjects) {
    issueRecords = _processedData.where((record) => 
      DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate && // Use selected date, not today
      record.ketQua != '✔️' &&
      record.ketQua != null
    ).toList();
  }

  // Sort by time (newest first)
  issueRecords.sort((a, b) {
    final dateCompare = b.ngay.compareTo(a.ngay);
    if (dateCompare != 0) return dateCompare;
    final timeA = a.gio ?? '';
    final timeB = b.gio ?? '';
    return timeB.compareTo(timeA);
  });

  // Limit to latest 10 issues
  if (issueRecords.length > 10) {
    issueRecords = issueRecords.take(10).toList();
  }

  if (issueRecords.isEmpty) {
    return SizedBox.shrink();
  }

  return Container(
    margin: EdgeInsets.all(16),
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
        // Header
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Danh sách vấn đề',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                  ),
                  if (showAllProjects)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Text(
                        'Tất cả dự án - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(_selectedDate!))}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (!showAllProjects)
                Text(
                  'Các báo cáo có vấn đề trong ${_selectedProject} ngày ${DateFormat('dd/MM/yyyy').format(DateTime.parse(_selectedDate!))}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[600],
                  ),
                ),
            ],
          ),
        ),
        // Issues list
        Container(
          constraints: BoxConstraints(maxHeight: isDesktop ? 400 : 300),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.all(16),
            itemCount: issueRecords.length,
            itemBuilder: (context, index) {
              final issue = issueRecords[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: InkWell(
                  onTap: () => _showIssueDetails(issue),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Status icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getStatusColor(issue.ketQua).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getStatusColor(issue.ketQua)),
                          ),
                          child: Center(
                            child: Text(
                              issue.ketQua ?? '?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Issue details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    issue.nguoiDung ?? 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${issue.gio ?? ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (showAllProjects) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        issue.boPhan ?? '',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                issue.chiTiet ?? 'Không có mô tả',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (issue.viTri?.isNotEmpty == true) ...[
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                    SizedBox(width: 4),
                                    Text(
                                      issue.viTri!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (issue.phanLoai?.isNotEmpty == true) ...[
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    issue.phanLoai!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Arrow icon
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
void _showIssueDetails(TaskHistoryModel issue) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width > 600 ? 500 : MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: _getStatusColor(issue.ketQua)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chi tiết vấn đề',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(),
            _buildDetailRow('Người báo cáo', issue.nguoiDung ?? '-'),
            _buildDetailRow('Thời gian', '${DateFormat('dd/MM/yyyy').format(issue.ngay)} ${issue.gio ?? ''}'),
            _buildDetailRow('Dự án', issue.boPhan ?? '-'),
            _buildDetailRow('Vị trí', issue.viTri ?? '-'),
            _buildDetailRow('Kết quả', _formatKetQua(issue.ketQua)),
            _buildDetailRow('Phân loại', issue.phanLoai ?? '-'),
            if (issue.chiTiet?.isNotEmpty == true)
              _buildDetailRow('Chi tiết', issue.chiTiet!),
            if (issue.chiTiet2?.isNotEmpty == true)
              _buildDetailRow('Lịch trình', issue.chiTiet2!),
            if (issue.giaiPhap?.isNotEmpty == true)
              _buildDetailRow('Khu vực', issue.giaiPhap!),
            if (issue.hinhAnh?.isNotEmpty == true) ...[
              SizedBox(height: 12),
              Text('Hình ảnh:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showFullImage(issue.hinhAnh!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: issue.hinhAnh!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
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
    ),
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatKetQua(String? ketQua) {
  if (ketQua == null) return '';
  switch (ketQua) {
    case '✔️':
      return '✔️ Đạt';
    case '❌':
      return '❌ Không làm';
    case '⚠️':
      return '⚠️ Chưa tốt';
    default:
      return ketQua;
  }
}

Color _getStatusColor(String? ketQua) {
  if (ketQua == null) return Colors.grey;
  switch (ketQua) {
    case '✔️':
      return Colors.green;
    case '❌':
      return Colors.red;
    case '⚠️':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}
Future<void> _exportExcel() async {
  if (_isLoading) return;
  
  setState(() {
    _isLoading = true;
    _syncStatus = 'Đang chuẩn bị xuất file Excel...';
  });

  ProgressDialog.show(context, 'Đang chuẩn bị dữ liệu...');

  try {
    await ProjectCongNhanExcel.exportToExcel(
      allData: _processedData,
      projectOptions: _projectOptions,
      context: context,
      taskSchedules: _taskSchedules,
      qrLookups: _qrLookups,
    );
    
    ProgressDialog.hide(); // Remove context parameter
    _showSuccess('Xuất Excel thành công');
  } catch (e) {
    ProgressDialog.hide(); // Remove context parameter
    print('Error exporting to Excel: $e');
    _showError('Lỗi xuất Excel: ${e.toString()}');
  } finally {
    setState(() {
      _isLoading = false;
      _syncStatus = '';
    });
  }
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
    
    ProgressDialog.hide(); // Remove context parameter
    _showSuccess('Xuất Excel tháng thành công');
  } catch (e) {
    ProgressDialog.hide(); // Remove context parameter
    print('Error exporting month to Excel: $e');
    _showError('Lỗi xuất Excel tháng: ${e.toString()}');
  } finally {
    setState(() {
      _isLoading = false;
      _syncStatus = '';
    });
  }
}

Future<void> _exportEvaluationOnly() async {
  if (_isLoading) return;
  
  setState(() {
    _isLoading = true;
    _syncStatus = 'Đang xuất đánh giá công nhân...';
  });

  ProgressDialog.show(context, 'Đang chuẩn bị đánh giá công nhân...');

  try {
    await ProjectCongNhanExcel.exportEvaluationOnly(
      allData: _processedData,
      projectOptions: _projectOptions,
      context: context,
      taskSchedules: _taskSchedules,
      qrLookups: _qrLookups,
    );
    
    ProgressDialog.hide(); // Remove context parameter
    _showSuccess('Xuất đánh giá công nhân thành công');
  } catch (e) {
    ProgressDialog.hide(); // Remove context parameter
    print('Error exporting evaluation: $e');
    _showError('Lỗi xuất đánh giá: ${e.toString()}');
  } finally {
    setState(() {
      _isLoading = false;
      _syncStatus = '';
    });
  }
}

Widget _buildWorkersTable() {
  if (_selectedProject == null || _selectedDate == null) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.filter_list,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Vui lòng chọn dự án và ngày để xem danh sách công nhân',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  final isDesktop = MediaQuery.of(context).size.width > 1200;
  final isTablet = MediaQuery.of(context).size.width > 600;
  final allWorkers = [..._filteredWorkers, ..._unavailableWorkers];

  if (allWorkers.isEmpty) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Không có công nhân nào trong dự án đã chọn',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
        // Header
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: Colors.blue[600]),
                  SizedBox(width: 8),
                  Text(
                    'Danh sách giám sát (${_filteredWorkers.length} có mặt, ${_unavailableWorkers.length} vắng)',
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Add descriptive text
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.amber[700]),
                    SizedBox(width: 4),
                    Text(
                      'Cuộn xuống để xem ma trận báo cáo theo ngày',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[800],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Container(
                height: 50,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _exportExcel(),
                        icon: Icon(Icons.table_chart, size: 18),
                        label: Text('Xuất excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _exportMonth(),
                        icon: Icon(Icons.calendar_month, size: 18),
                        label: Text('Xuất nhanh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: (_isLoading || _selectedProject == null || _taskSchedules.isEmpty) 
                            ? null 
                            : () => _showProjectScheduleDialog(),
                        icon: Icon(Icons.schedule, size: 18),
                        label: Text('Xem lịch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                        ),
                      ),                       SizedBox(width: 12),
                                            ElevatedButton.icon(
                        onPressed: (_isLoading || _selectedProject == null || _taskSchedules.isEmpty) 
                            ? null 
                            : () => _showProjectScheduleDialog(),
                        icon: Icon(Icons.schedule, size: 18),
                        label: Text('KPI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Table
        Container(
          constraints: BoxConstraints(maxHeight: isDesktop ? 500 : 400),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                border: TableBorder.all(color: Colors.grey[300]!),
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => Colors.grey[100]!,
                ),
                columnSpacing: isDesktop ? 24 : 16,
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: isDesktop ? 14 : 12,
                ),
                dataTextStyle: TextStyle(
                  fontSize: isDesktop ? 13 : 11,
                  color: Colors.grey[800],
                ),
                columns: [
                  DataColumn(
                    label: Container(
                      width: 40,
                      child: Text('STT', textAlign: TextAlign.center),
                    ),
                  ),
                  DataColumn(
                    label: Container(
                      width: isDesktop ? 120 : 100,
                      child: Text('Mã NV'),
                    ),
                  ),
                  DataColumn(
                    label: Container(
                      width: isDesktop ? 200 : 150,
                      child: Text('Tên GS'),
                    ),
                  ),
                  DataColumn(
                    label: Container(
                      width: isDesktop ? 80 : 60,
                      child: Text('Báo cáo', textAlign: TextAlign.center),
                    ),
                  ),
                  DataColumn(
                    label: Container(
                      width: isDesktop ? 80 : 60,
                      child: Text('Hình ảnh', textAlign: TextAlign.center),
                    ),
                  ),
                  DataColumn(
                    label: Container(
                      width: isDesktop ? 120 : 100,
                      child: Text('Chủ đề', textAlign: TextAlign.center),
                    ),
                  ),
                  DataColumn(
                    label: Container(
                      width: isDesktop ? 120 : 100,
                      child: Text('Giờ làm', textAlign: TextAlign.center),
                    ),
                  ),
                  DataColumn(
                    label: Container(
                      width: 80,
                      child: Text('Thao tác', textAlign: TextAlign.center),
                    ),
                  ),
                ],
                rows: List.generate(allWorkers.length, (index) {
                  final worker = allWorkers[index];
                  final isAvailable = worker.isAvailable;
                  
                  return DataRow(
                    color: MaterialStateColor.resolveWith((states) {
                      if (!isAvailable) return Colors.grey[100]!;
                      return index % 2 == 0 ? Colors.white : Colors.grey[50]!;
                    }),
                    cells: [
                      DataCell(
                        Container(
                          width: 40,
                          child: Text(
                            (index + 1).toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isAvailable ? Colors.black : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          width: isDesktop ? 120 : 100,
                          child: Text(
                            worker.name, // This is the MaNV
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isAvailable ? Colors.black : Colors.grey[500],
                              fontWeight: isAvailable ? FontWeight.normal : FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          width: isDesktop ? 200 : 150,
                          child: Text(
                            worker.displayName, 
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isAvailable ? Colors.black : Colors.grey[500],
                              fontWeight: isAvailable ? FontWeight.bold : FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          width: isDesktop ? 80 : 60,
                          child: isAvailable ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              worker.reportCount.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ) : Text('-', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
                        ),
                      ),
                      DataCell(
                        Container(
                          width: isDesktop ? 80 : 60,
                          child: isAvailable ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              worker.imageCount.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ) : Text('-', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
                        ),
                      ),
                      DataCell(
                        Container(
                          width: isDesktop ? 120 : 100,
                          child: isAvailable ? Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  worker.topicCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                              if (worker.topics.isNotEmpty) 
                                Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    worker.topics.take(3).join(', '),
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ) : Text('-', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
                        ),
                      ),
                      DataCell(
                        Container(
                          width: isDesktop ? 120 : 100,
                          child: isAvailable ? Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  worker.hourCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[800],
                                  ),
                                ),
                              ),
                              if (worker.hours.isNotEmpty) 
                                Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    worker.hours.map((h) => h + 'h').take(5).join(', '),
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ) : Text('-', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
                        ),
                      ),
                      DataCell(
                        Container(
                          width: 80,
                          child: isAvailable ? IconButton(
                            icon: Icon(Icons.open_in_new, 
                              color: Colors.blue[600], 
                              size: isDesktop ? 20 : 16
                            ),
                            onPressed: () => _showWorkerDetails(worker),
                            tooltip: 'Xem chi tiết',
                          ) : Icon(Icons.remove, color: Colors.grey[400], size: 16),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
        // Table legend
        Container(
          padding: EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Báo cáo', 'Tổng số báo cáo', Colors.blue[100]!, Colors.blue[800]!),
              _buildLegendItem('Hình ảnh', 'Báo cáo có hình', Colors.green[100]!, Colors.green[800]!),
              _buildLegendItem('Chủ đề', 'Loại công việc', Colors.orange[100]!, Colors.orange[800]!),
              _buildLegendItem('Giờ làm', 'Khung giờ khác nhau', Colors.purple[100]!, Colors.purple[800]!),
            ],
          ),
        ),
        
        // NEW: Daily Report Matrix Section
        _buildDailyReportMatrix(),
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
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    ],
  );
}

Widget _buildDailyReportMatrix() {
  if (_selectedProject == null || _chartDates.isEmpty || _filteredWorkers.isEmpty) {
    return SizedBox.shrink();
  }

  final isDesktop = MediaQuery.of(context).size.width > 1200;
  final isTablet = MediaQuery.of(context).size.width > 600;

  // Get report counts for each worker per day
  Map<String, Map<String, int>> workerDayReports = {};
  
  for (final worker in _filteredWorkers) {
    workerDayReports[worker.name] = {};
    for (final dateStr in _chartDates) {
      final dailyReports = _processedData.where((record) => 
        record.boPhan == _selectedProject &&
        DateFormat('yyyy-MM-dd').format(record.ngay) == dateStr &&
        record.nguoiDung == worker.name
      ).length;
      workerDayReports[worker.name]![dateStr] = dailyReports;
    }
  }

  return Container(
    margin: EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Matrix Header
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
                'Giám sát báo cáo theo ngày',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
        ),
        // Matrix Table
        Container(
          constraints: BoxConstraints(maxHeight: isDesktop ? 400 : 300),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: (isDesktop ? 200 : 150) + (_chartDates.length * (isDesktop ? 80.0 : 60.0)),
              child: Column(
                children: [
                  // Header row
                  Container(
                    height: 50,
                    child: Row(
                      children: [
                        // Worker header
                        Container(
                          width: isDesktop ? 200 : 150,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!),
                              right: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Tên GS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isDesktop ? 14 : 12,
                            ),
                          ),
                        ),
                        // Date headers
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
                      ],
                    ),
                  ),
                  // Data rows
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: List.generate(_filteredWorkers.length, (workerIndex) {
                          final worker = _filteredWorkers[workerIndex];
                          
                          return Container(
                            height: 40,
                            child: Row(
                              children: [
                                // Worker name cell
                                Container(
                                  width: isDesktop ? 200 : 150,
                                  height: 40,
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: workerIndex % 2 == 0 ? Colors.white : Colors.grey[50],
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
                                        worker.displayName,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 12 : 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        worker.name,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 10 : 8,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Report count cells
                                ..._chartDates.map((dateStr) {
                                  final reportCount = workerDayReports[worker.name]?[dateStr] ?? 0;
                                  return Container(
                                    width: isDesktop ? 80 : 60,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: workerIndex % 2 == 0 ? Colors.white : Colors.grey[50],
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
        // Matrix Legend
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
 Widget _buildLegendItem(String title, String description, Color bgColor, Color textColor) {
   return Row(
     mainAxisSize: MainAxisSize.min,
     children: [
       Container(
         width: 16,
         height: 16,
         decoration: BoxDecoration(
           color: bgColor,
           borderRadius: BorderRadius.circular(8),
         ),
       ),
       SizedBox(width: 8),
       Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             title,
             style: TextStyle(
               fontWeight: FontWeight.bold,
               fontSize: 12,
               color: textColor,
             ),
           ),
           Text(
             description,
             style: TextStyle(
               fontSize: 10,
               color: Colors.grey[600],
             ),
           ),
         ],
       ),
     ],
   );
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
               style: TextStyle(
                 color: Colors.white,
                 fontWeight: FontWeight.bold,
                 fontSize: 16,
               ),
               textAlign: TextAlign.center,
             ),
           ),
         _buildFilters(),
         Expanded(
           child: SingleChildScrollView(
             child: Column(
               children: [
                 _buildHourlyChart(),
                 _buildIssuesList(),
                 _buildTaskScheduleInfo(), 
                 _buildWorkersTable(),
               ],
             ),
           ),
         ),
       ],
     ),
   );
 }
}

// Worker Summary Model
class WorkerSummary {
 final String name;
   final String displayName;
 int reportCount;
 int imageCount;
 int topicCount;
 int hourCount;
 final Set<String> topics;
 final Set<String> hours;
 bool isAvailable;

 WorkerSummary({
   required this.name,
       required this.displayName,
   this.reportCount = 0,
   this.imageCount = 0,
   this.topicCount = 0,
   this.hourCount = 0,
   required this.topics,
   required this.hours,
   this.isAvailable = true,
 });
}
class WorkerDetailsDialog extends StatefulWidget {
  final WorkerSummary worker;
  final List<TaskHistoryModel> records;
  final String selectedDate;
  final List<TaskScheduleModel> taskSchedules;
  final String selectedProject;
  final List<QRLookupModel> qrLookups;

  const WorkerDetailsDialog({
    Key? key,
    required this.worker,
    required this.records,
    required this.selectedDate,
    this.taskSchedules = const [],
    this.selectedProject = '',
    this.qrLookups = const [],
  }) : super(key: key);

  @override
  _WorkerDetailsDialogState createState() => _WorkerDetailsDialogState();
}

class _WorkerDetailsDialogState extends State<WorkerDetailsDialog> {
  String _getWorkerPosition() {
    final positions = <String, int>{};
    
    for (final record in widget.records) {
      if (record.viTri != null && record.viTri!.trim().isNotEmpty) {
        positions[record.viTri!] = (positions[record.viTri!] ?? 0) + 1;
      }
    }
    
    if (positions.isEmpty) return widget.worker.name;
    
    return positions.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String _formatKetQua(String? ketQua) {
    if (ketQua == null) return '';
    switch (ketQua) {
      case '✔️':
        return '✔️ Đạt';
      case '❌':
        return '❌ Không làm';
      case '⚠️':
        return '⚠️ Chưa tốt';
      default:
        return ketQua;
    }
  }

  Color _getStatusColor(String? ketQua) {
    if (ketQua == null) return Colors.grey;
    switch (ketQua) {
      case '✔️':
        return Colors.green;
      case '❌':
        return Colors.red;
      case '⚠️':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getTimeDifferenceText(String reportTime, String scheduleInfo) {
    try {
      final parts = scheduleInfo.split('-');
      if (parts.length >= 2) {
        final scheduleEndTime = parts[1];
        final timeDiff = TaskScheduleManager.calculateTimeDifference(reportTime, scheduleEndTime);
        
        if (timeDiff == 0) {
          return '⏰ Đúng giờ';
        } else if (timeDiff > 0) {
          return '⏰ Muộn ${timeDiff} phút';
        } else {
          return '⏰ Sớm ${(-timeDiff)} phút';
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  Color _getTimeDifferenceColor(String reportTime, String scheduleInfo) {
    try {
      final parts = scheduleInfo.split('-');
      if (parts.length >= 2) {
        final scheduleEndTime = parts[1];
        final timeDiff = TaskScheduleManager.calculateTimeDifference(reportTime, scheduleEndTime);
        
        if (timeDiff == 0) return Colors.green;
        if (timeDiff > 0) return Colors.red;
        return Colors.blue;
      }
      return Colors.grey;
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildTaskCompletionPanel() {
    if (widget.taskSchedules.isEmpty || widget.selectedProject.isEmpty || widget.qrLookups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              'Không có dữ liệu lịch làm việc',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    final selectedDateTime = DateTime.parse(widget.selectedDate);
    final dayTasks = TaskScheduleManager.getTasksForProjectAndDate(
      widget.taskSchedules,
      widget.selectedProject,
      selectedDateTime,
      widget.qrLookups,
    );

    final workerPosition = _getWorkerPosition();
    final analysis = TaskScheduleManager.analyzeTaskCompletion(
      dayTasks,
      widget.records,
      workerPosition,
      widget.qrLookups,
    );

    final positionTasks = analysis['positionTasks'] as List<TaskScheduleModel>;
    final completedTaskIds = analysis['completedTaskIds'] as List<String>;
    final completedTasks = analysis['completedTasks'] as int;
    final totalTasks = analysis['totalTasks'] as int;
    final completionRate = analysis['completionRate'] as double;

    if (positionTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              'Không có nhiệm vụ cho vị trí "$workerPosition"',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Completion summary
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildMiniSummaryCard(
                  'Tổng NV',
                  totalTasks.toString(),
                  Colors.blue,
                  Icons.assignment,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummaryCard(
                  'Hoàn thành',
                  completedTasks.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummaryCard(
                  'Tỷ lệ',
                  '${completionRate.toStringAsFixed(0)}%',
                  completionRate >= 80 ? Colors.green : completionRate >= 60 ? Colors.orange : Colors.red,
                  Icons.pie_chart,
                ),
              ),
            ],
          ),
        ),
        // Tasks list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: positionTasks.length,
            itemBuilder: (context, index) {
              final task = positionTasks[index];
              final isCompleted = completedTaskIds.contains(task.taskId);
              
              TaskHistoryModel? correspondingReport;
              for (final report in widget.records) {
                if (report.chiTiet2 != null && report.chiTiet2!.contains(task.task)) {
                  correspondingReport = report;
                  break;
                }
              }
              
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCompleted ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCompleted ? Colors.green : Colors.red,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCompleted ? Icons.check_circle : Icons.cancel,
                                  size: 12,
                                  color: isCompleted ? Colors.green[800] : Colors.red[800],
                                ),
                                SizedBox(width: 3),
                                Text(
                                  isCompleted ? 'Xong' : 'Chưa',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted ? Colors.green[800] : Colors.red[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Spacer(),
                          Text(
                            '${TaskScheduleManager.formatScheduleTime(task.start)} - ${TaskScheduleManager.formatScheduleTime(task.end)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        task.task,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isCompleted && correspondingReport != null) ...[
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.report, size: 11, color: Colors.blue[600]),
                                  SizedBox(width: 3),
                                  Text(
                                    'BC: ${correspondingReport.gio ?? ''}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                  Spacer(),
                                  if (correspondingReport.gio != null)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getTimeDifferenceColor(correspondingReport.gio!, task.start).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _getTimeDifferenceColor(correspondingReport.gio!, task.start),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        _getTimeDifferenceText(correspondingReport.gio!, task.start),
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: _getTimeDifferenceColor(correspondingReport.gio!, task.start),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (correspondingReport.chiTiet?.isNotEmpty == true) ...[
                                SizedBox(height: 3),
                                Text(
                                  correspondingReport.chiTiet!,
                                  style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
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
    );
  }

  Widget _buildMiniSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Increased dimensions
    final dialogWidth = isDesktop ? 1400.0 : screenWidth * 0.95;
    final dialogHeight = isDesktop ? 800.0 : screenHeight * 0.9;
    
    return Dialog(
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
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
                          '${widget.worker.displayName} (${widget.worker.name})',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.selectedDate))} | Vị trí: ${_getWorkerPosition()}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
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
            // Split view content
            Expanded(
              child: Row(
                children: [
                  // Left panel - Reports
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.grey[300]!)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.article, size: 18, color: Colors.blue[700]),
                                SizedBox(width: 6),
                                Text(
                                  'Báo cáo chi tiết (${widget.records.length})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.all(12),
                              itemCount: widget.records.length,
                              itemBuilder: (context, index) {
                                final record = widget.records[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(record.ketQua).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: _getStatusColor(record.ketQua)),
                                              ),
                                              child: Text(
                                                _formatKetQua(record.ketQua),
                                                style: TextStyle(
                                                  color: _getStatusColor(record.ketQua),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            Spacer(),
                                            Text(
                                              record.gio ?? '',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6),
                                        if (record.chiTiet?.isNotEmpty == true)
                                          Text(
                                            record.chiTiet!,
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        if (record.chiTiet2?.isNotEmpty == true) ...[
                                          SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Lịch: ${record.chiTiet2}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                              if (record.gio != null)
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getTimeDifferenceColor(record.gio!, record.chiTiet2!).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: _getTimeDifferenceColor(record.gio!, record.chiTiet2!),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _getTimeDifferenceText(record.gio!, record.chiTiet2!),
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      color: _getTimeDifferenceColor(record.gio!, record.chiTiet2!),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                        if (record.viTri?.isNotEmpty == true) ...[
                                          SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on, size: 11, color: Colors.grey[600]),
                                              SizedBox(width: 3),
                                              Text(
                                                record.viTri!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (record.phanLoai?.isNotEmpty == true) ...[
                                          SizedBox(height: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[100],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              record.phanLoai!,
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.orange[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (record.hinhAnh?.isNotEmpty == true) ...[
                                          SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: () => _showFullImage(context, record.hinhAnh!),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: CachedNetworkImage(
                                                imageUrl: record.hinhAnh!,
                                                height: 80,
                                                width: 80,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  height: 80,
                                                  width: 80,
                                                  color: Colors.grey[200],
                                                  child: Icon(Icons.image, color: Colors.grey[400]),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  height: 80,
                                                  width: 80,
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
                  ),
                  // Right panel - Task Completion
                  Expanded(
                    flex: 1,
                    child: Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.assessment, size: 18, color: Colors.purple[700]),
                                SizedBox(width: 6),
                                Text(
                                  'Đánh giá hoàn thành',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _buildTaskCompletionPanel(),
                          ),
                        ],
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

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => FullImageDialog(imageUrl: imageUrl),
    );
  }
}

// Full Image Dialog
class FullImageDialog extends StatelessWidget {
 final String imageUrl;

 const FullImageDialog({Key? key, required this.imageUrl}) : super(key: key);

 Future<void> _saveImage() async {
   try {
     // Download image
     final response = await http.get(Uri.parse(imageUrl));
     if (response.statusCode == 200) {
       // Get temporary directory
       final directory = await getTemporaryDirectory();
       final imagePath = '${directory.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';
       
       // Save to file
       final file = File(imagePath);
       await file.writeAsBytes(response.bodyBytes);
       
       // Share the file
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
// Project Search Dialog
class ProjectSearchDialog extends StatefulWidget {
  final List<String> projects;
  final String? selectedProject;
  final Function(String) onProjectSelected;

  const ProjectSearchDialog({
    Key? key,
    required this.projects,
    required this.selectedProject,
    required this.onProjectSelected,
  }) : super(key: key);

  @override
  _ProjectSearchDialogState createState() => _ProjectSearchDialogState();
}

class _ProjectSearchDialogState extends State<ProjectSearchDialog> {
  late TextEditingController _searchController;
  List<String> _filteredProjects = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredProjects = widget.projects;
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
      if (query.isEmpty) {
        _filteredProjects = widget.projects;
      } else {
        _filteredProjects = widget.projects
            .where((project) => project.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    
    return Dialog(
      child: Container(
        width: isDesktop ? 500 : MediaQuery.of(context).size.width * 0.9,
        height: isDesktop ? 600 : MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tìm kiếm dự án',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Search field
            Container(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nhập tên dự án...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            // Results count
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Tìm thấy ${_filteredProjects.length} dự án',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (widget.selectedProject != null) ...[
                    Spacer(),
                    TextButton(
                      onPressed: () {
                        widget.onProjectSelected('');
                        Navigator.of(context).pop();
                      },
                      child: Text('Bỏ chọn'),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1),
            // Projects list
            Expanded(
              child: _filteredProjects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Không tìm thấy dự án nào',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredProjects.length,
                      itemBuilder: (context, index) {
                        final project = _filteredProjects[index];
                        final isSelected = project == widget.selectedProject;
                        
                        return ListTile(
                          title: Text(
                            project,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.blue[800] : Colors.black,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: Colors.blue[600])
                              : null,
                          selected: isSelected,
                          selectedTileColor: Colors.blue[50],
                          onTap: () {
                            widget.onProjectSelected(project);
                            Navigator.of(context).pop();
                          },
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
class TaskCompletionDialog extends StatelessWidget {
  final WorkerSummary worker;
  final String selectedDate;
  final Map<String, dynamic> analysis;
  final List<TaskScheduleModel> dayTasks;
  final List<TaskHistoryModel> records;
  final String workerPosition;
  final List<QRLookupModel> qrLookups; 

  const TaskCompletionDialog({
    Key? key,
    required this.worker,
    required this.selectedDate,
    required this.analysis,
    required this.dayTasks,
    required this.records,
    required this.workerPosition,
    required this.qrLookups, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final positionTasks = analysis['positionTasks'] as List<TaskScheduleModel>;
    final completedTaskIds = analysis['completedTaskIds'] as List<String>;
    final missedTaskIds = analysis['missedTaskIds'] as List<String>;
    final completionRate = analysis['completionRate'] as double;
    
    return Dialog(
      child: Container(
        width: isDesktop ? 700 : MediaQuery.of(context).size.width * 0.9,
        height: isDesktop ? 600 : MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[600],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.assessment, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đánh giá hoàn thành - ${worker.displayName}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Vị trí: $workerPosition | ${DateFormat('dd/MM/yyyy').format(DateTime.parse(selectedDate))}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
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
            // Completion summary
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Tổng nhiệm vụ',
                      analysis['totalTasks'].toString(),
                      Colors.blue,
                      Icons.assignment,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Đã hoàn thành',
                      analysis['completedTasks'].toString(),
                      Colors.green,
                      Icons.check_circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Tỷ lệ hoàn thành',
                      '${completionRate.toStringAsFixed(1)}%',
                      completionRate >= 80 ? Colors.green : completionRate >= 60 ? Colors.orange : Colors.red,
                      Icons.pie_chart,
                    ),
                  ),
                ],
              ),
            ),
            // Tasks list
            Expanded(
              child: positionTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Không có nhiệm vụ nào cho vị trí "$workerPosition"',
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
                        final isCompleted = completedTaskIds.contains(task.taskId);
                        final isMissed = missedTaskIds.contains(task.taskId);
                        
                        // Find corresponding report for this task
                        TaskHistoryModel? correspondingReport;
                        for (final report in records) {
                          if (report.chiTiet2 != null && report.chiTiet2!.contains(task.task)) {
                            correspondingReport = report;
                            break;
                          }
                        }
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Task header
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isCompleted ? Colors.green[100] : Colors.red[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCompleted ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isCompleted ? Icons.check_circle : Icons.cancel,
                                            size: 14,
                                            color: isCompleted ? Colors.green[800] : Colors.red[800],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            isCompleted ? 'Hoàn thành' : 'Chưa làm',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isCompleted ? Colors.green[800] : Colors.red[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Spacer(),
                                    Text(
                                      '${TaskScheduleManager.formatScheduleTime(task.start)} - ${TaskScheduleManager.formatScheduleTime(task.end)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // Task description
                                Text(
                                  task.task,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                // Position info
                                Text(
                                  'Vị trí: ${task.vitri}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                // Report details if completed
                                if (isCompleted && correspondingReport != null) ...[
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.report, size: 14, color: Colors.blue[600]),
                                            SizedBox(width: 4),
                                            Text(
                                              'Báo cáo: ${correspondingReport.gio ?? ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[800],
                                              ),
                                            ),
                                            Spacer(),
                                            if (correspondingReport.gio != null)
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _getTimeDifferenceColor(correspondingReport.gio!, task.start).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: _getTimeDifferenceColor(correspondingReport.gio!, task.start),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  _getTimeDifferenceText(correspondingReport.gio!, task.start),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: _getTimeDifferenceColor(correspondingReport.gio!, task.start),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (correspondingReport.chiTiet?.isNotEmpty == true) ...[
                                          SizedBox(height: 4),
                                          Text(
                                            correspondingReport.chiTiet!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                        if (correspondingReport.ketQua?.isNotEmpty == true) ...[
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                'Kết quả: ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                _formatKetQua(correspondingReport.ketQua),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _getStatusColor(correspondingReport.ketQua),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
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

  // Add the missing helper methods:
  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatKetQua(String? ketQua) {
    if (ketQua == null) return '';
    switch (ketQua) {
      case '✔️':
        return '✔️ Đạt';
      case '❌':
        return '❌ Không làm';
      case '⚠️':
        return '⚠️ Chưa tốt';
      default:
        return ketQua;
    }
  }

  Color _getStatusColor(String? ketQua) {
    if (ketQua == null) return Colors.grey;
    switch (ketQua) {
      case '✔️':
        return Colors.green;
      case '❌':
        return Colors.red;
      case '⚠️':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getTimeDifferenceText(String reportTime, String scheduleTime) {
    try {
      final timeDiff = TaskScheduleManager.calculateTimeDifference(reportTime, scheduleTime);
      
      if (timeDiff == 0) {
        return '⏰ Đúng giờ';
      } else if (timeDiff > 0) {
        return '⏰ Muộn ${timeDiff} phút';
      } else {
        return '⏰ Sớm ${(-timeDiff)} phút';
      }
    } catch (e) {
      return '';
    }
  }

  Color _getTimeDifferenceColor(String reportTime, String scheduleTime) {
    try {
      final timeDiff = TaskScheduleManager.calculateTimeDifference(reportTime, scheduleTime);
      
      if (timeDiff == 0) return Colors.green;
      if (timeDiff > 0) return Colors.red;
      return Colors.blue;
    } catch (e) {
      return Colors.grey;
    }
  }
}
class ProjectScheduleDialog extends StatefulWidget {
  final String projectName;
  final String selectedDate;
  final List<TaskScheduleModel> dayTasks;
  final List<TaskScheduleModel> allTasks;

  const ProjectScheduleDialog({
    Key? key,
    required this.projectName,
    required this.selectedDate,
    required this.dayTasks,
    required this.allTasks,
    required this.qrLookups,
  }) : super(key: key);
final List<QRLookupModel> qrLookups;
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
        ? widget.allTasks.where((task) { // Use widget.allTasks
            final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, widget.qrLookups); // Use widget.qrLookups
            return userMapping['projectName'] == widget.projectName; // Use widget.projectName
          }).toList()
        : widget.dayTasks; // Use widget.dayTasks

    _tasksByPosition.clear();
    for (final task in tasksToShow) {
      final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, widget.qrLookups); // Use widget.qrLookups
      final positionName = userMapping['positionName'];
      if (positionName?.isNotEmpty == true) { // Add null check
        _tasksByPosition.putIfAbsent(positionName!, () => []).add(task); // Add null assertion
      }
    }
    
    // Sort tasks within each position by start time
    for (final tasks in _tasksByPosition.values) {
      tasks.sort((a, b) => a.start.compareTo(b.start));
    }
  }

  String _formatWeekdays(String weekdays) {
  if (weekdays.trim().isEmpty) return 'Tất cả các ngày';
  
  final days = weekdays.split(',').map((d) => d.trim()).toList();
  final dayNames = <String>[];
  
  for (final day in days) {
    switch (day) {
      case '1':
        dayNames.add('CN');
        break;
      case '2':
        dayNames.add('T2');
        break;
      case '3':
        dayNames.add('T3');
        break;
      case '4':
        dayNames.add('T4');
        break;
      case '5':
        dayNames.add('T5');
        break;
      case '6':
        dayNames.add('T6');
        break;
      case '7':
        dayNames.add('T7');
        break;
    }
  }
  return dayNames.join(', ');
}

  Color _getPositionColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[index % colors.length];
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
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[600],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _showAllDays 
                              ? 'Tất cả các ngày (${_tasksByPosition.values.fold<int>(0, (sum, tasks) => sum + tasks.length)} nhiệm vụ)'
                              : 'Ngày ${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.selectedDate))} (${widget.dayTasks.length} nhiệm vụ)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle button
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
            // Summary stats
            if (positions.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Vị trí',
                        positions.length.toString(),
                        Colors.blue,
                        Icons.location_on,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Tổng nhiệm vụ',
                        _tasksByPosition.values.fold<int>(0, (sum, tasks) => sum + tasks.length).toString(),
                        Colors.green,
                        Icons.assignment,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Giờ làm việc',
                        _getWorkingHoursRange(),
                        Colors.orange,
                        Icons.access_time,
                      ),
                    ),
                  ],
                ),
              ),
            // Positions and tasks list
            Expanded(
              child: positions.isEmpty
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
                            _showAllDays 
                                ? 'Không có lịch làm việc nào cho dự án này'
                                : 'Không có lịch làm việc nào cho ngày đã chọn',
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
                      itemCount: positions.length,
                      itemBuilder: (context, index) {
                        final position = positions[index];
                        final tasks = _tasksByPosition[position]!;
                        final positionColor = _getPositionColor(index);
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            initiallyExpanded: positions.length <= 3,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: positionColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: positionColor),
                              ),
                              child: Icon(Icons.person, color: positionColor),
                            ),
                            title: Text(
                              position,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: positionColor,
                              ),
                            ),
                            subtitle: Text(
                              '${tasks.length} nhiệm vụ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            children: tasks.map((task) => Container(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: positionColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: positionColor.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Time and task header
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: positionColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: positionColor),
                                        ),
                                        child: Text(
                                          '${TaskScheduleManager.formatScheduleTime(task.start)} - ${TaskScheduleManager.formatScheduleTime(task.end)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: positionColor,
                                          ),
                                        ),
                                      ),
                                      Spacer(),
                                      if (_showAllDays)
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _formatWeekdays(task.weekday),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  // Task description
                                  Text(
                                    task.task,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  // Task ID
                                  Text(
                                    'ID: ${task.taskId}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                      fontFamily: 'monospace',
                                    ),
                                  ),
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

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getWorkingHoursRange() {
    if (_tasksByPosition.isEmpty) return '-';
    
    String? earliestStart;
    String? latestEnd;
    
    for (final tasks in _tasksByPosition.values) {
      for (final task in tasks) {
        if (earliestStart == null || task.start.compareTo(earliestStart) < 0) {
          earliestStart = task.start;
        }
        if (latestEnd == null || task.end.compareTo(latestEnd) > 0) {
          latestEnd = task.end;
        }
      }
    }
    
    if (earliestStart != null && latestEnd != null) {
      return '${TaskScheduleManager.formatScheduleTime(earliestStart)} - ${TaskScheduleManager.formatScheduleTime(latestEnd)}';
    }
    
    return '-';
  }
}
class _HourlyTopicLinePainter extends CustomPainter {
  final List<MapEntry<int, Map<String, dynamic>>> hourEntries;
  final double maxCount;
  final double maxTopics;

  _HourlyTopicLinePainter({
    required this.hourEntries,
    required this.maxCount,
    required this.maxTopics,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hourEntries.isEmpty || maxTopics == 0) return;

    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final maxY = maxCount + (maxCount * 0.2);
    
    // Calculate spacing between bars
    final barSpacing = size.width / 24;
    
    bool firstPoint = true;
    final points = <Offset>[];

    for (int i = 0; i < hourEntries.length; i++) {
      final entry = hourEntries[i];
      final topics = entry.value['topics'] as int;
      
      // Scale topics to chart height
      final scaledTopics = maxTopics > 0 ? (topics / maxTopics) * maxY : 0.0;
      
      // Calculate position
      final x = (i + 0.5) * barSpacing; // Center of each bar
      final y = size.height - (scaledTopics / maxY * size.height);
      
      final point = Offset(x, y);
      points.add(point);

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw the line
    canvas.drawPath(path, paint);

    // Draw dots
    for (final point in points) {
      canvas.drawCircle(point, 4, dotBorderPaint);
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyTopicLinePainter oldDelegate) {
    return oldDelegate.hourEntries != hourEntries ||
        oldDelegate.maxCount != maxCount ||
        oldDelegate.maxTopics != maxTopics;
  }
}
class _AreaLinePainter extends CustomPainter {
  final List<MapEntry<int, Map<String, dynamic>>> hourEntries;
  final double maxCount;
  final double maxArea;

  _AreaLinePainter({
    required this.hourEntries,
    required this.maxCount,
    required this.maxArea,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hourEntries.isEmpty || maxArea == 0) return;

    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final maxY = maxCount + (maxCount * 0.2);
    
    // Calculate spacing between bars
    final barSpacing = size.width / 24;
    
    bool firstPoint = true;
    final points = <Offset>[];

    for (int i = 0; i < hourEntries.length; i++) {
      final entry = hourEntries[i];
      final area = entry.value['area'] as double;
      
      // Scale area to chart height
      final scaledArea = maxArea > 0 ? (area / maxArea) * maxY : 0.0;
      
      // Calculate position
      final x = (i + 0.5) * barSpacing; // Center of each bar
      final y = size.height - (scaledArea / maxY * size.height);
      
      final point = Offset(x, y);
      points.add(point);

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw the line
    canvas.drawPath(path, paint);

    // Draw dots
    for (final point in points) {
      canvas.drawCircle(point, 4, dotBorderPaint);
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaLinePainter oldDelegate) {
    return oldDelegate.hourEntries != hourEntries ||
        oldDelegate.maxCount != maxCount ||
        oldDelegate.maxArea != maxArea;
  }
}
class _IssueBackgroundPainter extends CustomPainter {
  final List<MapEntry<int, Map<String, dynamic>>> hourEntries;
  final double maxCount;

  _IssueBackgroundPainter({
    required this.hourEntries,
    required this.maxCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = maxCount + (maxCount * 0.2);
    final barWidth = size.width / 24;
    
    for (int i = 0; i < hourEntries.length; i++) {
      final entry = hourEntries[i];
      final hasIssues = entry.value['hasIssues'] as bool;
      
      if (hasIssues) {
        final paint = Paint()
          ..color = Colors.red.withOpacity(0.15)
          ..style = PaintingStyle.fill;
        
        // Calculate the center position for each bar
        final centerX = (i + 0.5) * barWidth;
        
        // Draw vertical red stripe centered on the bar
        final rect = Rect.fromLTWH(
          centerX - (barWidth * 0.4), // 40% to the left of center
          0,
          barWidth * 0.8, // 80% of bar width
          size.height,
        );
        
        // Draw the red background
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(4)),
          paint,
        );
        
        // Add a stronger red border
        final borderPaint = Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
          
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(4)),
          borderPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IssueBackgroundPainter oldDelegate) {
    return oldDelegate.hourEntries != hourEntries ||
        oldDelegate.maxCount != maxCount;
  }
}