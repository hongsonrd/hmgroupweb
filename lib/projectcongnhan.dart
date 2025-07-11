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
import 'package:shared_preferences/shared_preferences.dart';

class ProjectCongNhan extends StatefulWidget {
  final String username;

  const ProjectCongNhan({Key? key, required this.username}) : super(key: key);

  @override
  _ProjectCongNhanState createState() => _ProjectCongNhanState();
}

class _ProjectCongNhanState extends State<ProjectCongNhan> {
  bool _isLoading = false;
  List<TaskHistoryModel> _allData = [];
  List<TaskHistoryModel> _processedData = []; // Data with corrected BoPhan
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  String _syncStatus = '';
  
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
    _processBoPhanCorrection(); // Process BoPhan correction
    _updateFilterOptions();
    _autoSelectFilters(); // Auto-select after loading data
    _startSyncTimer();
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
        // Store both lowercase and uppercase versions for lookup
        final maNV = staff['MaNV'].toString();
        final hoTen = staff['Ho_ten'].toString();
        nameMap[maNV.toLowerCase()] = hoTen;
        nameMap[maNV.toUpperCase()] = hoTen;
        nameMap[maNV] = hoTen; // Original case
      }
    }
    return nameMap;
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
      
      // Save sync status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasStaffbioSynced', true);

      // Refresh the workers list to show updated names
      _updateFilteredWorkers();
      
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
          'Dự án - Công nhân',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Spacer(),
        // Staff bio sync button
        if (!_isLoading)
          ElevatedButton.icon(
            onPressed: () => _syncStaffBio(),
            icon: Icon(Icons.people, size: 18),
            label: Text('Cập nhật nhân sự'),
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
              // Project dropdown
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
          // Legend
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
                // Bar chart for unique workers
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
               // Line chart for record count
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
                         interval: 1, // This ensures each x-axis point gets exactly one label
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
           child: Row(
             children: [
               Icon(Icons.people, color: Colors.blue[600]),
               SizedBox(width: 8),
               Text(
                 'Danh sách công nhân (${_filteredWorkers.length} có mặt, ${_unavailableWorkers.length} vắng)',
                 style: TextStyle(
                   fontSize: isDesktop ? 18 : 16,
                   fontWeight: FontWeight.bold,
                   color: Colors.blue[800],
                 ),
               ),
             SizedBox(height: 12),
      Row(
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
        ],
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
      child: Text('Tên công nhân'),
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
       ],
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

// Worker Details Dialog
class WorkerDetailsDialog extends StatelessWidget {
 final WorkerSummary worker;
 final List<TaskHistoryModel> records;
 final String selectedDate;

 const WorkerDetailsDialog({
   Key? key,
   required this.worker,
   required this.records,
   required this.selectedDate,
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
                         '${worker.displayName} (${worker.name})',
                         style: TextStyle(
                           color: Colors.white,
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       Text(
                         DateFormat('dd/MM/yyyy').format(DateTime.parse(selectedDate)),
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
           // Records list
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
                         // Time and status row
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
                         // Report description
                         if (record.chiTiet?.isNotEmpty == true)
                           Text(
                             record.chiTiet!,
                             style: TextStyle(fontSize: 14),
                           ),
                         // Schedule detail
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
                         // Position
                         if (record.viTri?.isNotEmpty == true) ...[
                           SizedBox(height: 4),
                           Row(
                             children: [
                               Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                               SizedBox(width: 4),
                               Text(
                                 record.viTri!,
                                 style: TextStyle(
                                   fontSize: 12,
                                   color: Colors.grey[600],
                                 ),
                               ),
                             ],
                           ),
                         ],
                         // Area type
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
                         // Category
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
                         // Image
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