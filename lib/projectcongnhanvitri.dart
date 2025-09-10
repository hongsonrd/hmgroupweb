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
import 'projectcongnhanexcel.dart';
import 'projectcongnhanllv.dart';
import 'projectcongnhanns.dart';
import 'dart:core';
import 'dart:math';
import 'projectcongnhanbio.dart';

class ProjectCongNhanVT extends StatefulWidget {
 final String username;
 const ProjectCongNhanVT({Key? key, required this.username}) : super(key: key);
 @override
 _ProjectCongNhanVTState createState() => _ProjectCongNhanVTState();
}

class _ProjectCongNhanVTState extends State<ProjectCongNhanVT> {
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
 List<PositionSummary> _filteredPositions = [];
 List<PositionSummary> _unavailablePositions = [];
 List<FlSpot> _recordCountSpots = [];
 List<BarChartGroupData> _uniqueWorkerBars = [];
 double _maxRecordCount = 0;
 double _maxUniqueWorkers = 0;
 List<String> _chartDates = [];
 int _displayDateCount = 7;
 int _maxDisplayDates = 30;

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
   double syncProbability = 0.18;
   final prefs = await SharedPreferences.getInstance();
   final lastSync = prefs.getInt('lastTaskScheduleSync') ?? 0;
   final hoursSinceLastSync = (DateTime.now().millisecondsSinceEpoch - lastSync) / (1000 * 60 * 60);
   if (hoursSinceLastSync > 24) {
     syncProbability = 0.36;
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
       Uri.parse('$baseUrl/projectcongnhan/${widget.username}')
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
       _processBoPhanCorrection();
       _updateFilterOptions();
       _autoSelectFilters();
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
       correctProject = validProjects.entries
           .reduce((a, b) => a.value > b.value ? a : b)
           .key;
     }
     if (correctProject != null) {
       for (final record in group) {
         if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) {
           record.boPhan = correctProject;
           print('Corrected BoPhan for ${record.nguoiDung} on ${DateFormat('yyyy-MM-dd').format(record.ngay)}: $correctProject');
         }
       }
     }
   }
 }

 void _updateFilterOptions() {
   final projectSet = <String>{};
   for (final record in _processedData) {
     if (record.boPhan != null && 
         record.boPhan!.trim().isNotEmpty && 
         !_shouldFilterProject(record.boPhan!)) {
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
     _maxDisplayDates = _dateOptions.length;
     if (_displayDateCount > _maxDisplayDates) {
       _displayDateCount = _maxDisplayDates;
     }
   });
 }

 void _autoSelectFilters() {
   if (_selectedDate == null && _dateOptions.isNotEmpty) {
     _selectedDate = _dateOptions.first;
   }
   if (_selectedProject == null && _projectOptions.isNotEmpty) {
     _selectedProject = _projectOptions.first;
   }
   if (_selectedProject != null && _selectedDate != null) {
     _updateFilteredPositions();
     _updateChartData();
   }
 }

 bool _shouldFilterProject(String? projectName) {
   if (projectName == null || projectName.trim().isEmpty) return true;
   final name = projectName.toLowerCase();
   final originalName = projectName.trim();
   if (name == 'unknown') return true;
   if (name.length >= 3 && name.startsWith('hm')) {
     if (RegExp(r'^hm\d').hasMatch(name)) return true;
   }
   if (name.length >= 3 && name.startsWith('tv')) {
     if (RegExp(r'^tv\d').hasMatch(name)) return true;
   }
   if (name.length >= 4 && name.startsWith('tvn')) {
     if (RegExp(r'^tvn\d').hasMatch(name)) return true;
   }
   if (name.length >= 5 && name.startsWith('nvhm')) {
     if (RegExp(r'^nvhm\d').hasMatch(name)) return true;
   }
   if (name.startsWith('http:') || name.startsWith('https:')) return true;
   if (RegExp(r'^[a-z]{2,5}-\d+$').hasMatch(name)) return true;
   if (originalName == originalName.toUpperCase() && 
       !originalName.contains(' ') && 
       originalName.length > 1) return true;
   return false;
 }

 void _updateFilteredPositions() async {
  if (_selectedProject == null || _selectedDate == null) {
    setState(() {
      _filteredPositions = [];
      _unavailablePositions = [];
    });
    return;
  }

  // Get ONLY positions from schedule data using QR lookup
  final schedulePositions = TaskScheduleManager.getPositionsForProject(_selectedProject!, _qrLookups);
  
  if (schedulePositions.isEmpty) {
    setState(() {
      _filteredPositions = [];
      _unavailablePositions = [];
    });
    return;
  }

  final positionDataMap = <String, PositionSummary>{};
  
  // Initialize ALL schedule positions first
  for (final position in schedulePositions) {
    positionDataMap[position] = PositionSummary(
      position: position,
      reportCount: 0,
      imageCount: 0,
      topicCount: 0,
      hourCount: 0,
      workerCount: 0,
      topics: <String>{},
      hours: <String>{},
      workers: <String>{},
      hasReports: false,
    );
  }
  
  // Get reports for the selected date and project
  final relevantRecords = _processedData.where((record) => 
    record.boPhan == _selectedProject &&
    DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate &&
    record.viTri != null &&
    record.viTri!.trim().isNotEmpty
  ).toList();

  // Process reports ONLY for schedule positions
  for (final record in relevantRecords) {
    final reportPosition = record.viTri!;
    
    // Find exact or fuzzy match with schedule positions
    String? matchedSchedulePosition;
    for (final schedulePos in schedulePositions) {
      if (schedulePos.toLowerCase() == reportPosition.toLowerCase() ||
          schedulePos.toLowerCase().contains(reportPosition.toLowerCase()) ||
          reportPosition.toLowerCase().contains(schedulePos.toLowerCase())) {
        matchedSchedulePosition = schedulePos;
        break;
      }
    }
    
    // ONLY process if it matches a schedule position
    if (matchedSchedulePosition != null) {
      final summary = positionDataMap[matchedSchedulePosition]!;
      summary.hasReports = true;
      summary.reportCount++;
      
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

      if (record.nguoiDung != null && record.nguoiDung!.trim().isNotEmpty) {
        summary.workers.add(record.nguoiDung!);
      }
    }
    // If no match found, the record is ignored (not added to any position)
  }
  
  // Finalize counts for all schedule positions
  for (final summary in positionDataMap.values) {
    summary.topicCount = summary.topics.length;
    summary.hourCount = summary.hours.length;
    summary.workerCount = summary.workers.length;
  }

  // Separate available and unavailable positions (all from schedule)
  final available = positionDataMap.values.where((p) => p.hasReports).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  final unavailable = positionDataMap.values.where((p) => !p.hasReports).toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  setState(() {
    _filteredPositions = available;
    _unavailablePositions = unavailable;
  });
}

 Future<void> _syncStaffBio() async {
   if (_isLoading) return;
   setState(() {
     _isLoading = true;
     _syncStatus = 'Đang cập nhật hồ sơ nhân sự...';
   });
   try {
     final response = await http.get(
       Uri.parse('$baseUrl/staffbio'),
     );
     if (response.statusCode == 200) {
       final dynamic decoded = json.decode(response.body);
       final List<dynamic> staffbioData = decoded is Map ? decoded['data'] : decoded;
       await dbHelper.clearTable(DatabaseTables.staffbioTable);
       final staffbioModels = staffbioData
         .map((data) {
           try {
             print('Mapping staffbio data: $data');
             return StaffbioModel.fromMap(data as Map<String, dynamic>);
           } catch (e) {
             print('Error mapping staffbio data: $e');
             print('Problematic data: $data');
             rethrow;
           }
         })
         .toList();
       await dbHelper.batchInsertStaffbio(staffbioModels);
       final prefs = await SharedPreferences.getInstance();
       await prefs.setBool('hasStaffbioSynced', true);
       _updateFilteredPositions();
       _showSuccess('Cập nhật hồ sơ nhân sự thành công');
     } else {
       throw Exception('Server returned ${response.statusCode}');
     }
   } catch (e) {
     print('Error syncing staff bio: $e');
     _showError('Không thể cập nhật hồ sơ nhân sự: ${e.toString()}');
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
   final projectData = _processedData.where((record) => record.boPhan == _selectedProject).toList();
   final dateMap = <String, List<TaskHistoryModel>>{};
   for (final record in projectData) {
     final dateStr = DateFormat('yyyy-MM-dd').format(record.ngay);
     dateMap.putIfAbsent(dateStr, () => []).add(record);
   }
   final allSortedDates = dateMap.keys.toList()..sort((a, b) => b.compareTo(a));
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
     _chartDates = displayDates;
   });
 }

 void _showPositionDetails(PositionSummary position) {
  if (!position.hasReports) return;
  
  // Find all records that match this schedule position
  final positionRecords = _processedData.where((record) => 
    record.boPhan == _selectedProject &&
    DateFormat('yyyy-MM-dd').format(record.ngay) == _selectedDate &&
    record.viTri != null &&
    record.viTri!.trim().isNotEmpty &&
    _isMatchingPosition(record.viTri!, position.position)
  ).toList();
  
  positionRecords.sort((a, b) {
    final timeA = a.gio ?? '';
    final timeB = b.gio ?? '';
    return timeA.compareTo(timeB);
  });
  
  showDialog(
    context: context,
    builder: (context) => PositionDetailsDialog(
      position: position,
      records: positionRecords,
      selectedDate: _selectedDate!,
      taskSchedules: _taskSchedules,
      selectedProject: _selectedProject!,
      qrLookups: _qrLookups,
    ),
  );
}

bool _isMatchingPosition(String reportPosition, String schedulePosition) {
  return schedulePosition.toLowerCase() == reportPosition.toLowerCase() ||
         schedulePosition.toLowerCase().contains(reportPosition.toLowerCase()) ||
         reportPosition.toLowerCase().contains(schedulePosition.toLowerCase());
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
     _qrLookups,
   );
   if (dayTasks.isEmpty) return SizedBox.shrink();
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
   if (screenWidth > 1200) return 30;
   if (screenWidth > 800) return 20;
   if (screenWidth > 600) return 14;
   return 7;
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
         IconButton(
           icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24),
           onPressed: () => Navigator.of(context).pop(),
           padding: EdgeInsets.zero,
           constraints: BoxConstraints(),
         ),
         SizedBox(width: 16),
         Text(
           'Dự án - Vị trí',
           style: TextStyle(
             fontSize: 24,
             fontWeight: FontWeight.bold,
             color: Colors.black87,
           ),
         ),
         Spacer(),
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
         if (!_isLoading)
           ElevatedButton.icon(
             onPressed: () => _syncStaffBio(),
             icon: Icon(Icons.people, size: 18),
             label: Text('Đồng bộ tên CN'),
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.orange[600],
               foregroundColor: Colors.white,
               elevation: 2,
             ),
           ),
         SizedBox(width: 12),
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
                       setState(() {_selectedProject = value;
                         _updateFilteredPositions();
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
                         _updateFilteredPositions();
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
             _updateFilteredPositions();
             _updateChartData();
           });
         },
       );
     },
   );
 }

 Widget _buildDateRangeSlider() {
   if (_maxDisplayDates <= 1) return SizedBox.shrink();
   return Container(
     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
             Icon(Icons.tune, color: Colors.blue[600], size: 20),
             SizedBox(width: 8),
             Text(
               'Hiển thị biểu đồ: ${_displayDateCount} ngày',
               style: TextStyle(
                 fontSize: 14,
                 fontWeight: FontWeight.w500,
                 color: Colors.grey[700],
               ),
             ),
             Spacer(),
             Text(
               'Đề xuất: ${_getRecommendedDateCount()}',
               style: TextStyle(
                 fontSize: 12,
                 color: Colors.grey[500],
               ),
             ),
           ],
         ),
         SizedBox(height: 8),
         Slider(
           value: _displayDateCount.toDouble(),
           min: 1,
           max: _maxDisplayDates.toDouble(),
           divisions: _maxDisplayDates - 1,
           label: _displayDateCount.toString(),
           onChanged: (value) {
             setState(() {
               _displayDateCount = value.round();
               _updateChartData();
             });
           },
         ),
       ],
     ),
   );
 }

 Widget _buildChart() {
   if (_selectedProject == null || _recordCountSpots.isEmpty) {
     return SizedBox.shrink();
   }
   final isDesktop = MediaQuery.of(context).size.width > 1200;
   final isTablet = MediaQuery.of(context).size.width > 600;
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
                 'Thống kê theo ngày (Mới nhất → Cũ nhất)',
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
         Wrap(
           spacing: 20,
           children: [
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Container(
                   width: 16,
                   height: 3,
                   color: Colors.blue,
                 ),
                 SizedBox(width: 4),
                 Text('Số báo cáo', style: TextStyle(fontSize: 12)),
               ],
             ),
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Container(
                   width: 16,
                   height: 16,
                   color: Colors.orange.withOpacity(0.7),
                 ),
                 SizedBox(width: 4),
                 Text('Số công nhân', style: TextStyle(fontSize: 12)),
               ],
             ),
           ],
         ),
         SizedBox(height: 16),
         Container(
           height: isDesktop ? 350 : (isTablet ? 300 : 250),
           child: Stack(
             children: [
               BarChart(
                 BarChartData(
                   maxY: _maxUniqueWorkers * 1.1,
                   barGroups: _uniqueWorkerBars,
                   titlesData: FlTitlesData(
                     leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                      axisNameWidget: Text(
                        'Công nhân',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  backgroundColor: Colors.transparent,
                ),
              ),
              LineChart(
                LineChartData(
                  maxY: _maxRecordCount * 1.1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _recordCountSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                      axisNameWidget: Text(
                        'Báo cáo',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            ],
          ),
        ),
      ],
    ),
  );
}

 Future<void> _exportExcel() async {
   if (_isLoading) return;
   setState(() {
     _isLoading = true;
     _syncStatus = 'Đang xuất file Excel...';
   });
   try {
     await ProjectCongNhanExcel.exportToExcel(
       allData: _processedData,
       projectOptions: _projectOptions,
       context: context,
     );
     _showSuccess('Xuất Excel thành công');
   } catch (e) {
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
     _syncStatus = 'Đang xuất file Excel tháng...';
   });
   try {
     final selectedDateTime = DateTime.parse(_selectedDate!);
     await ProjectCongNhanExcel.exportToExcelMonth(
       allData: _processedData,
       projectOptions: _projectOptions,
       selectedMonth: selectedDateTime,
       context: context,
     );
     _showSuccess('Xuất Excel tháng thành công');
   } catch (e) {
     print('Error exporting month to Excel: $e');
     _showError('Lỗi xuất Excel tháng: ${e.toString()}');
   } finally {
     setState(() {
       _isLoading = false;
       _syncStatus = '';
     });
   }
 }

 void _navigateToDepartmentEvaluation() {
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => ProjectCongNhanNS(
         username: widget.username,
         taskSchedules: _taskSchedules,
         qrLookups: _qrLookups,
       ),
     ),
   );
 }

 Widget _buildPositionsTable() {
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
               'Vui lòng chọn dự án và ngày để xem danh sách vị trí',
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
   final allPositions = [..._filteredPositions, ..._unavailablePositions];
   if (allPositions.isEmpty) {
     return Container(
       padding: EdgeInsets.all(32),
       child: Center(
         child: Column(
           children: [
             Icon(
               Icons.location_off,
               size: 64,
               color: Colors.grey[400],
             ),
             SizedBox(height: 16),
             Text(
               'Không có vị trí nào trong dự án đã chọn',
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
                   Icon(Icons.location_on, color: Colors.blue[600]),
                   SizedBox(width: 8),
                   Text(
                     'Danh sách vị trí (${_filteredPositions.length} có báo cáo, ${_unavailablePositions.length} không báo cáo)',
                     style: TextStyle(
                       fontSize: isDesktop ? 18 : 16,
                       fontWeight: FontWeight.bold,
                       color: Colors.blue[800],
                     ),
                   ),
                 ],
               ),
               SizedBox(height: 8),
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
                         label: Text('Xuất tháng'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.orange[600],
                           foregroundColor: Colors.white,
                         ),
                       ),
                       SizedBox(width: 12),
                       ElevatedButton.icon(
                         onPressed: _isLoading ? null : () => _exportStaffBio(),
                         icon: Icon(Icons.person_outline, size: 18),
                         label: Text('Xuất hồ sơ NS'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.teal[600],
                           foregroundColor: Colors.white,
                         ),
                       ),
                       SizedBox(width: 12),
                       ElevatedButton.icon(
                         onPressed: (_isLoading || _selectedProject == null || _taskSchedules.isEmpty) 
                             ? null 
                             : () => _showProjectScheduleDialog(),
                         icon: Icon(Icons.schedule, size: 18),
                         label: Text('Xem lịch làm việc'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.purple[600],
                           foregroundColor: Colors.white,
                         ),
                       ),
                       SizedBox(width: 12),
                       ElevatedButton.icon(
                         onPressed: (_isLoading || _taskSchedules.isEmpty) 
                             ? null 
                             : () => _navigateToDepartmentEvaluation(),
                         icon: Icon(Icons.assessment_outlined, size: 18),
                         label: Text('Đánh giá bộ phận'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.indigo[600],
                           foregroundColor: Colors.white,
                         ),
                       ),
                       SizedBox(width: 16),
                     ],
                   ),
                 ),
               ),
             ],
           ),
         ),
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
                       width: isDesktop ? 200 : 150,
                       child: Text('Vị trí'),
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
                       width: isDesktop ? 120 : 100,
                       child: Text('Công nhân', textAlign: TextAlign.center),
                     ),
                   ),
                   DataColumn(
                     label: Container(
                       width: 80,
                       child: Text('Thao tác', textAlign: TextAlign.center),
                     ),
                   ),
                 ],
                 rows: List.generate(allPositions.length, (index) {
                   final position = allPositions[index];
                   final hasReports = position.hasReports;
                   return DataRow(
                     color: MaterialStateColor.resolveWith((states) {
                       if (!hasReports) return Colors.grey[100]!;
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
                               color: hasReports ? Colors.black : Colors.grey[500],
                             ),
                           ),
                         ),
                       ),
                       DataCell(
                         Container(
                           width: isDesktop ? 200 : 150,
                           child: Text(
                             position.position,
                             overflow: TextOverflow.ellipsis,
                             style: TextStyle(
                               color: hasReports ? Colors.black : Colors.grey[500],
                               fontWeight: hasReports ? FontWeight.bold : FontWeight.w300,
                             ),
                           ),
                         ),
                       ),
                       DataCell(
                         Container(
                           width: isDesktop ? 80 : 60,
                           child: hasReports ? Container(
                             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                             decoration: BoxDecoration(
                               color: Colors.blue[100],
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: Text(
                               position.reportCount.toString(),
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
                           child: hasReports ? Container(
                             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                             decoration: BoxDecoration(
                               color: Colors.green[100],
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: Text(
                               position.imageCount.toString(),
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
                           child: hasReports ? Column(
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
                                   position.topicCount.toString(),
                                   textAlign: TextAlign.center,
                                   style: TextStyle(
                                     fontWeight: FontWeight.bold,
                                     color: Colors.orange[800],
                                   ),
                                 ),
                               ),
                               if (position.topics.isNotEmpty) 
                                 Padding(
                                   padding: EdgeInsets.only(top: 2),
                                   child: Text(
                                     position.topics.take(3).join(', '),
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
                           child: hasReports ? Column(
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
                                   position.hourCount.toString(),
                                   textAlign: TextAlign.center,
                                   style: TextStyle(
                                     fontWeight: FontWeight.bold,
                                     color: Colors.purple[800],
                                   ),
                                 ),
                               ),
                               if (position.hours.isNotEmpty) 
                                 Padding(
                                   padding: EdgeInsets.only(top: 2),
                                   child: Text(
                                     position.hours.map((h) => h + 'h').take(5).join(', '),
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
                           child: hasReports ? Column(
                             crossAxisAlignment: CrossAxisAlignment.center,
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Container(
                                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: Colors.indigo[100],
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 child: Text(
                                   position.workerCount.toString(),
                                   textAlign: TextAlign.center,
                                   style: TextStyle(
                                     fontWeight: FontWeight.bold,
                                     color: Colors.indigo[800],
                                   ),
                                 ),
                               ),
                             ],
                           ) : Text('-', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
                         ),
                       ),
                       DataCell(
                         Container(
                           width: 80,
                           child: hasReports ? IconButton(
                             icon: Icon(Icons.open_in_new, 
                               color: Colors.blue[600], 
                               size: isDesktop ? 20 : 16
                             ),
                             onPressed: () => _showPositionDetails(position),
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
               _buildLegendItem('Công nhân', 'Số người trong vị trí', Colors.indigo[100]!, Colors.indigo[800]!),
             ],
           ),
         ),
         _buildDailyReportMatrix(),
       ],
     ),);
 }

 Future<void> _exportStaffBio() async {
   if (_isLoading) return;
   setState(() {
     _isLoading = true;
     _syncStatus = 'Đang xuất hồ sơ nhân sự...';
   });
   try {
     await ProjectCongNhanBio.exportStaffBioToExcel(context: context);
     _showSuccess('Xuất hồ sơ nhân sự thành công');
   } catch (e) {
     print('Error exporting staff bio: $e');
     _showError('Lỗi xuất hồ sơ nhân sự: ${e.toString()}');
   } finally {
     setState(() {
       _isLoading = false;
       _syncStatus = '';
     });
   }
 }

 Widget _buildDailyReportMatrix() {
  if (_selectedProject == null || _chartDates.isEmpty) {
    return SizedBox.shrink();
  }

  final schedulePositions = TaskScheduleManager.getPositionsForProject(_selectedProject!, _qrLookups);
  if (schedulePositions.isEmpty) return SizedBox.shrink();

  final isDesktop = MediaQuery.of(context).size.width > 1200;
  Map<String, Map<String, int>> positionDayReports = {};
  
  for (final position in schedulePositions) {
    positionDayReports[position] = {};
    for (final dateStr in _chartDates) {
      positionDayReports[position]![dateStr] = 0;
    }
  }
  
  for (final dateStr in _chartDates) {
    final dayRecords = _processedData.where((record) => 
      record.boPhan == _selectedProject &&
      DateFormat('yyyy-MM-dd').format(record.ngay) == dateStr &&
      record.viTri != null &&
      record.viTri!.trim().isNotEmpty
    );
    
    for (final record in dayRecords) {
      final reportPosition = record.viTri!;
      String? matchedSchedulePosition;
      for (final schedulePos in schedulePositions) {
        if (schedulePos.toLowerCase().contains(reportPosition.toLowerCase()) ||
            reportPosition.toLowerCase().contains(schedulePos.toLowerCase()) ||
            schedulePos == reportPosition) {
          matchedSchedulePosition = schedulePos;
          break;
        }
      }
      
      if (matchedSchedulePosition != null) {
        positionDayReports[matchedSchedulePosition]![dateStr] = 
            (positionDayReports[matchedSchedulePosition]![dateStr] ?? 0) + 1;
      }
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
                'Vị trí báo cáo theo ngày (Từ lịch làm việc)',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
        ),
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
                        // Position header
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
                            'Vị trí (Lịch LV)',
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
                        children: List.generate(schedulePositions.length, (positionIndex) {
                          final position = schedulePositions[positionIndex];
                          final totalReports = positionDayReports[position]?.values.fold<int>(
                            0,
                            (sum, count) => sum + count,
                          ) ?? 0;
                          
                          return Container(
                            height: 40,
                            child: Row(
                              children: [
                                // Position name cell
                                Container(
                                  width: isDesktop ? 200 : 150,
                                  height: 40,
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: positionIndex % 2 == 0 ? Colors.white : Colors.grey[50],
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
                                        position,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 12 : 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Tổng: $totalReports',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 10 : 8,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Report count cells
                                ..._chartDates.map((dateStr) {
                                  final reportCount = positionDayReports[position]?[dateStr] ?? 0;
                                  return Container(
                                    width: isDesktop ? 80 : 60,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: positionIndex % 2 == 0 ? Colors.white : Colors.grey[50],
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
         style: TextStyle(
           fontSize: 12,
           color: Colors.grey[600],
         ),
       ),
     ],
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
         _buildDateRangeSlider(),
         Expanded(
           child: SingleChildScrollView(
             child: Column(
               children: [
                 _buildChart(),
                 _buildTaskScheduleInfo(),
                 _buildPositionsTable(),
               ],
             ),
           ),
         ),
       ],
     ),
   );
 }
}

class PositionSummary {
 final String position;
 int reportCount;
 int imageCount;
 int topicCount;
 int hourCount;
 int workerCount;
 final Set<String> topics;
 final Set<String> hours;
 final Set<String> workers;
 bool hasReports;

 PositionSummary({
   required this.position,
   this.reportCount = 0,
   this.imageCount = 0,
   this.topicCount = 0,
   this.hourCount = 0,
   this.workerCount = 0,
   required this.topics,
   required this.hours,
   required this.workers,
   this.hasReports = false,
 });
}

class PositionDetailsDialog extends StatelessWidget {
 final PositionSummary position;
 final List<TaskHistoryModel> records;
 final String selectedDate;
 final List<TaskScheduleModel> taskSchedules;
 final String selectedProject;
 final List<QRLookupModel> qrLookups;

 const PositionDetailsDialog({
   Key? key,
   required this.position,
   required this.records,
   required this.selectedDate,
   this.taskSchedules = const [],
   this.selectedProject = '',
   this.qrLookups = const [],
 }) : super(key: key);

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
               borderRadius: BorderRadius.only(
                 topLeft: Radius.circular(4),
                 topRight: Radius.circular(4),
               ),
             ),
             child: Row(
               children: [
                 Icon(Icons.location_on, color: Colors.white),
                 SizedBox(width: 8),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         position.position,
                         style: TextStyle(
                           color: Colors.white,
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       Text(
                         '${DateFormat('dd/MM/yyyy').format(DateTime.parse(selectedDate))} | ${position.workerCount} công nhân',
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
                             Text(
                               record.gio ?? '',
                               style: TextStyle(
                                 fontSize: 14,
                                 fontWeight: FontWeight.w500,
                               ),
                             ),
                           ],
                         ),
                         SizedBox(height: 8),
                         if (record.nguoiDung?.isNotEmpty == true)
                           Text(
                             'Người báo cáo: ${record.nguoiDung}',
                             style: TextStyle(
                               fontSize: 12,
                               fontWeight: FontWeight.bold,
                               color: Colors.blue[800],
                             ),
                           ),
                         if (record.chiTiet?.isNotEmpty == true)
                           Text(
                             record.chiTiet!,
                             style: TextStyle(fontSize: 14),
                           ),
                         if (record.chiTiet2?.isNotEmpty == true) ...[
                           SizedBox(height: 4),
                           Text(
                             'Lịch trình: ${record.chiTiet2}',
                             style: TextStyle(
                               fontSize: 12,
                               color: Colors.grey[600],
                               fontStyle: FontStyle.italic,
                             ),
                           ),
                         ],
                         if (record.giaiPhap?.isNotEmpty == true) ...[
                           SizedBox(height: 4),
                           Text(
                             'Khu vực: ${record.giaiPhap}',
                             style: TextStyle(
                               fontSize: 12,
                               color: Colors.grey[600],
                             ),
                           ),
                         ],
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
                               style: TextStyle(
                                 fontSize: 11,
                                 color: Colors.orange[800],
                                 fontWeight: FontWeight.w500,
                               ),
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

 String _formatWeekdays(String weekdays) {
   if (weekdays.trim().isEmpty) return 'Tất cả các ngày';
   final days = weekdays.split(',').map((d) => d.trim()).toList();
   final dayNames = <String>[];
   for (final day in days) {
     switch (day) {
       case '0':
         dayNames.add('CN');
         break;
       case '1':
         dayNames.add('T2');
         break;
       case '2':
         dayNames.add('T3');
         break;
       case '3':
         dayNames.add('T4');
         break;
       case '4':
         dayNames.add('T5');
         break;
       case '5':
         dayNames.add('T6');
         break;
       case '6':
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
                                 Text(
                                   task.task,
                                   style: TextStyle(
                                     fontSize: 14,
                                     fontWeight: FontWeight.w500,
                                   ),
                                 ),
                                 SizedBox(height: 4),
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