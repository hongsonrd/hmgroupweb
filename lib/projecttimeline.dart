import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'db_helper.dart';
import 'table_models.dart';

class ProjectTimeline extends StatefulWidget {
  final String username;

  const ProjectTimeline({Key? key, required this.username}) : super(key: key);

  @override
  _ProjectTimelineState createState() => _ProjectTimelineState();
}

class _ProjectTimelineState extends State<ProjectTimeline> {
  bool _isLoading = false;
  List<TaskHistoryModel> _timelineData = [];
  List<String> _availableDates = [];
  List<String> _availableProjects = [];
  String? _selectedDate;
  String? _selectedProject = 'Tất cả';
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  String _syncStatus = '';
  
  // Timeline configuration
  final double timelineHeight = 60.0;
  final double projectRowHeight = 40.0; // Reduced since we have 2 lines per project
  final double projectColumnWidth = 200.0;
  double _zoomFactor = 1.5; // Default 150%
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  
  // Current time line
  double get _currentTimePosition {
    final now = DateTime.now();
    final hour = now.hour + (now.minute / 60.0);
    return hour;
  }

  @override
  void initState() {
    super.initState();
    _checkAndSync();
    _loadAvailableDates();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    if (_horizontalScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final screenWidth = MediaQuery.of(context).size.width;
        final timelineWidth = math.max(screenWidth, 800.0) * _zoomFactor;
        final currentTimeX = (_currentTimePosition / 24.0) * (timelineWidth - projectColumnWidth);
        final targetScroll = (currentTimeX - (screenWidth - projectColumnWidth) / 2).clamp(0.0, _horizontalScrollController.position.maxScrollExtent);
        
        _horizontalScrollController.animateTo(
          targetScroll,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  Future<void> _checkAndSync() async {
    if (await _shouldSync()) {
      await _syncData();
    }
  }

  Future<bool> _shouldSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('lastTimelineSync') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSync) > 1 * 60 * 60 * 1000; // 1 hour
  }

  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastTimelineSync', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _syncData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ dữ liệu...';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/historybaocao/${widget.username}')
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
        
        _showSuccess('Đồng bộ thành công');
        await _loadAvailableDates();
      } else {
        throw Exception('Failed to sync data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing timeline data: $e');
      _showError('Không thể đồng bộ: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _loadAvailableDates() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT DISTINCT date(Ngay) as date
        FROM ${DatabaseTables.taskHistoryTable}
        ORDER BY date DESC
      ''');

      setState(() {
        _availableDates = results.map((row) => row['date'] as String).toList();
        if (_availableDates.isNotEmpty && _selectedDate == null) {
          _selectedDate = _availableDates.first;
          _loadTimelineData();
        }
      });
    } catch (e) {
      print('Error loading available dates: $e');
      _showError('Lỗi tải danh sách ngày');
    }
  }

  Future<void> _loadTimelineData() async {
    if (_selectedDate == null) return;

    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT * FROM ${DatabaseTables.taskHistoryTable}
        WHERE date(Ngay) = ?
        ORDER BY Gio ASC
      ''', [_selectedDate]);

      final timelineData = results.map((item) => TaskHistoryModel(
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

      setState(() {
        _timelineData = timelineData;
        _loadAvailableProjects();
      });
      
      _scrollToCurrentTime();
    } catch (e) {
      print('Error loading timeline data: $e');
      _showError('Lỗi tải dữ liệu timeline');
    }
  }

  void _loadAvailableProjects() {
    final projects = _getFilteredProjects();
    setState(() {
      _availableProjects = ['Tất cả', ...projects];
      if (_selectedProject != null && !_availableProjects.contains(_selectedProject)) {
        _selectedProject = 'Tất cả';
      }
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  double _timeToPosition(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0.0;
    
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return hour + (minute / 60.0);
      }
    } catch (e) {
      print('Error parsing time: $timeStr');
    }
    return 0.0;
  }

  List<String> _getFilteredProjects() {
    return _timelineData
        .where((item) => _isValidProject(item.boPhan))
        .map((item) => item.boPhan!)
        .toSet()
        .toList()
        ..sort();
  }

  bool _isValidProject(String? boPhan) {
  if (boPhan == null || boPhan.trim().isEmpty) return false;
  if (boPhan.length <= 6) return false;
  
  final lowerBoPhan = boPhan.toLowerCase();
  if (lowerBoPhan.startsWith('hm') || lowerBoPhan.startsWith('http')) return false;
  
  // Check if project name is all caps without any spaces
  if (boPhan == boPhan.toUpperCase() && !boPhan.contains(' ')) {
    return false;
  }
  
  return true;
}

  List<String> _getProjectsForDisplay() {
    if (_selectedProject == null || _selectedProject == 'Tất cả') {
      return _getFilteredProjects();
    } else {
      return [_selectedProject!];
    }
  }

  List<TaskHistoryModel> _getProjectRecords(String project) {
    return _timelineData
        .where((item) => item.boPhan == project)
        .toList();
  }

  List<TaskHistoryModel> _getProjectRecordsWithImages(String project) {
    return _getProjectRecords(project)
        .where((item) => _hasImage(item))
        .toList();
  }

  List<TaskHistoryModel> _getProjectRecordsWithoutImages(String project) {
    return _getProjectRecords(project)
        .where((item) => !_hasImage(item))
        .toList();
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

  bool _hasImage(TaskHistoryModel record) {
    return record.hinhAnh != null && record.hinhAnh!.trim().isNotEmpty;
  }

  void _showRecordDetail(BuildContext context, TaskHistoryModel record) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chi tiết báo cáo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Thời gian', '${record.gio ?? ''}'),
                        _buildDetailRow('Bộ phận', record.boPhan ?? ''),
                        _buildDetailRow('Vị trí', record.viTri ?? ''),
                        _buildDetailRow('Phân loại', record.phanLoai ?? ''),
                        _buildDetailRow('Kết quả', _formatKetQua(record.ketQua)),
                        _buildDetailRow('Chi tiết', record.chiTiet ?? ''),
                        if (record.chiTiet2?.isNotEmpty == true)
                          _buildDetailRow('Chi tiết 2', record.chiTiet2!),
                        if (record.giaiPhap?.isNotEmpty == true)
                          _buildDetailRow('Giải pháp', record.giaiPhap!),
                        if (record.hinhAnh?.isNotEmpty == true) ...[
                          SizedBox(height: 16),
                          Text(
                            'Hình ảnh:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: 300,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                record.hinhAnh!,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('Image load error: $error');
                                  return Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Không thể tải hình ảnh',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Đóng'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + ':',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatKetQua(String? ketQua) {
    if (ketQua == null) return '';
    switch (ketQua) {
      case '✔️':
        return 'Đạt';
      case '❌':
        return 'Không làm';
      case '⚠️':
        return 'Chưa tốt';
      default:
        return ketQua;
    }
  }

  Widget _buildTimelineHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final timelineWidth = math.max(screenWidth, 800.0) * _zoomFactor;
    
    return Container(
      height: timelineHeight,
      child: Row(
        children: [
          // Project name column header
          Container(
            width: projectColumnWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.grey[100],
            ),
            child: Text(
              'Dự án',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Time scale
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.grey[50],
              ),
              child: CustomPaint(
                painter: TimeScalePainter(_zoomFactor),
                child: Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSection(String project) {
  final recordsWithoutImages = _getProjectRecordsWithoutImages(project);
  final recordsWithImages = _getProjectRecordsWithImages(project);
  final totalRecords = recordsWithoutImages.length + recordsWithImages.length;

  return Column(
    children: [
      // Project header with counts
      Container(
        height: 48,
        decoration: BoxDecoration(
    border: Border.all(color: Colors.grey[300]!),
    color: Colors.blue[50], // Light blue background
    gradient: LinearGradient( // Gradient background
      colors: [Colors.blue[50]!, Colors.blue[100]!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),),
        child: Row(
          children: [
            Container(
              width: projectColumnWidth,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      project,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13, 
                        color: Colors.blue[800], 
                      ),
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '($totalRecords)',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.blue[600], 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.grey[50],
                ),
              ),
            ),
          ],
        ),
      ),
      // Text records row
      _buildProjectRow(project, recordsWithoutImages, 'Văn bản', false),
      // Image records row
      _buildProjectRow(project, recordsWithImages, 'Có hình', true),
    ],
  );
}

  Widget _buildProjectRow(String project, List<TaskHistoryModel> records, String rowLabel, bool isImageRow) {
    return Container(
      height: projectRowHeight,
      child: Row(
        children: [
          // Row label
          Container(
            width: projectColumnWidth,
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.white,
            ),
            child: Row(
              children: [
                SizedBox(width: 16), // Indent for sub-row
                if (isImageRow) 
                  Icon(Icons.camera_alt, size: 12, color: Colors.grey[600])
                else 
                  Icon(Icons.text_fields, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$rowLabel (${records.length})',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Timeline with records
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.white,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Hour grid lines
                      CustomPaint(
                        painter: GridPainter(_zoomFactor),
                        child: Container(),
                      ),
                      // Current time line (only show if selected date is today)
                      if (_isSelectedDateToday())
                        _buildCurrentTimeLine(constraints.maxWidth),
                      // Records
                      ...records.map((record) => _buildTimelinePoint(record, constraints.maxWidth, isImageRow)),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelectedDateToday() {
    if (_selectedDate == null) return false;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _selectedDate == today;
  }

  Widget _buildCurrentTimeLine(double timelineWidth) {
    final currentTimeX = (_currentTimePosition / 24.0) * timelineWidth;
    
    return Positioned(
      left: currentTimeX - 1,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: Colors.red,
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                width: 2,
                color: Colors.red.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelinePoint(TaskHistoryModel record, double timelineWidth, bool isImageRow) {
    final timePosition = _timeToPosition(record.gio);
    final color = _getStatusColor(record.ketQua);
    final leftPosition = (timePosition / 24.0) * timelineWidth - 8;
    
    return Positioned(
      left: leftPosition.clamp(0.0, timelineWidth - 16),
      top: (projectRowHeight / 2) - 8,
      child: GestureDetector(
        onTap: () => _showRecordDetail(context, record),
        child: isImageRow 
          ? _buildStarShape(color)
          : _buildCircleShape(color),
      ),
    );
  }

  Widget _buildCircleShape(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildStarShape(Color color) {
    return Container(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: StarPainter(color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectsForDisplay = _getProjectsForDisplay();
    final screenWidth = MediaQuery.of(context).size.width;
    final timelineWidth = math.max(screenWidth, 800.0) * _zoomFactor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dòng thời gian - ${widget.username.toUpperCase()}'),
        flexibleSpace: Container(
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
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _scrollToCurrentTime,
            tooltip: 'Đi đến giờ hiện tại',
          ),
          IconButton(
            icon: _isLoading 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.sync),
            onPressed: _isLoading ? null : _syncData,
            tooltip: 'Đồng bộ dữ liệu',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_syncStatus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Text(
                _syncStatus,
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          // Controls
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Date and Project selectors
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn ngày:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          DropdownButton<String>(
                            value: _selectedDate,
                            isExpanded: true,
                            items: _availableDates.map((String date) {
                              return DropdownMenuItem<String>(
                                value: date,
                                child: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(date))),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDate = newValue;
                              });
                              _loadTimelineData();
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn dự án:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          DropdownButton<String>(
                            value: _selectedProject,
                            isExpanded: true,
                            items: _availableProjects.map((String project) {
                              return DropdownMenuItem<String>(
                                value: project,
                                child: Text(
                                  project,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedProject = newValue;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Zoom controls and legend
                Row(
                  children: [
                    Text('Zoom: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.zoom_out),
                      onPressed: () {
                        setState(() {
                          _zoomFactor = (_zoomFactor - 0.2).clamp(0.5, 3.0);
                        });
                        _scrollToCurrentTime();
                      },
                    ),
                    Text('${(_zoomFactor * 100).toInt()}%'),
                    IconButton(
                      icon: Icon(Icons.zoom_in),
                      onPressed: () {
                        setState(() {
                          _zoomFactor = (_zoomFactor + 0.2).clamp(0.5, 3.0);
                        });
                        _scrollToCurrentTime();
                      },
                    ),
                    Spacer(),
                    // Legend
                    _buildLegendItem('Đạt', Colors.green),
                    SizedBox(width: 8),
                    _buildLegendItem('Không làm', Colors.red),
                    SizedBox(width: 8),
                    _buildLegendItem('Chưa tốt', Colors.orange),
                    SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStarShape(Colors.grey),
                        SizedBox(width: 4),
                        Text('Có hình', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Timeline
          Expanded(
            child: _selectedDate == null || projectsForDisplay.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                       _selectedDate == null 
                         ? 'Chọn ngày để xem timeline'
                         : 'Không có dữ liệu cho ngày này',
                       style: TextStyle(
                         fontSize: 16,
                         color: Colors.grey[600],
                       ),
                     ),
                   ],
                 ),
               )
             : Column(
                 children: [
                   // Timeline content with horizontal scrolling
                   Expanded(
                     child: Scrollbar(
                       controller: _horizontalScrollController,
                       thumbVisibility: true,
                       thickness: 12,
                       radius: Radius.circular(6),
                       child: SingleChildScrollView(
                         controller: _horizontalScrollController,
                         scrollDirection: Axis.horizontal,
                         child: SizedBox(
                           width: timelineWidth,
                           child: Scrollbar(
                             controller: _verticalScrollController,
                             thumbVisibility: true,
                             thickness: 12,
                             radius: Radius.circular(6),
                             child: SingleChildScrollView(
                               controller: _verticalScrollController,
                               child: Column(
                                 children: [
                                   _buildTimelineHeader(),
                                   ...projectsForDisplay.map((project) => _buildProjectSection(project)),
                                 ],
                               ),
                             ),
                           ),
                         ),
                       ),
                     ),
                   ),
                 ],
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
         width: 12,
         height: 12,
         decoration: BoxDecoration(
           color: color,
           shape: BoxShape.circle,
         ),
       ),
       SizedBox(width: 4),
       Text(label, style: TextStyle(fontSize: 12)),
     ],
   );
 }
}

class TimeScalePainter extends CustomPainter {
 final double zoomFactor;
 
 TimeScalePainter(this.zoomFactor);

 @override
 void paint(Canvas canvas, Size size) {
   final paint = Paint()
     ..color = Colors.grey[600]!
     ..strokeWidth = 1;

   // Adjust hour interval based on zoom
   int hourInterval = zoomFactor > 2.0 ? 1 : 2;

   // Draw hour markers
   for (int hour = 0; hour <= 24; hour += hourInterval) {
     final x = (hour / 24.0) * size.width;
     
     // Draw tick mark
     canvas.drawLine(
       Offset(x, size.height - 10),
       Offset(x, size.height),
       paint,
     );

     // Draw hour label
     final textSpan = TextSpan(
       text: hour.toString().padLeft(2, '0') + ':00',
       style: TextStyle(
         color: Colors.grey[600],
         fontSize: math.min(10 * zoomFactor, 14),
       ),
     );
     
     final textPainter = TextPainter(
       text: textSpan,
       textDirection: ui.TextDirection.ltr,
     );
     
     textPainter.layout();
     textPainter.paint(
       canvas,
       Offset(x - textPainter.width / 2, size.height - 30),
     );
   }
 }

 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
 final double zoomFactor;
 
 GridPainter(this.zoomFactor);

 @override
 void paint(Canvas canvas, Size size) {
   final paint = Paint()
     ..color = Colors.grey[200]!
     ..strokeWidth = 0.5;

   // Draw vertical grid lines for each hour
   for (int hour = 0; hour <= 24; hour++) {
     final x = (hour / 24.0) * size.width;
     canvas.drawLine(
       Offset(x, 0),
       Offset(x, size.height),
       paint,
     );
   }

   // Draw additional lines for half hours when zoomed in
   if (zoomFactor > 1.5) {
     final halfHourPaint = Paint()
       ..color = Colors.grey[100]!
       ..strokeWidth = 0.3;
       
     for (int hour = 0; hour < 24; hour++) {
       final x = ((hour + 0.5) / 24.0) * size.width;
       canvas.drawLine(
         Offset(x, 0),
         Offset(x, size.height),
         halfHourPaint,
       );
     }
   }
 }

 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StarPainter extends CustomPainter {
 final Color color;
 
 StarPainter(this.color);

 @override
 void paint(Canvas canvas, Size size) {
   final paint = Paint()
     ..color = color
     ..style = PaintingStyle.fill;

   final borderPaint = Paint()
     ..color = Colors.white
     ..style = PaintingStyle.stroke
     ..strokeWidth = 1;

   final path = Path();
   final center = Offset(size.width / 2, size.height / 2);
   final outerRadius = size.width / 2 - 2;
   final innerRadius = outerRadius * 0.4;

   for (int i = 0; i < 10; i++) {
     final angle = (i * math.pi / 5) - (math.pi / 2);
     final radius = i.isEven ? outerRadius : innerRadius;
     final x = center.dx + radius * math.cos(angle);
     final y = center.dy + radius * math.sin(angle);
     
     if (i == 0) {
       path.moveTo(x, y);
     } else {
       path.lineTo(x, y);
     }
   }
   path.close();

   // Draw star
   canvas.drawPath(path, paint);
   canvas.drawPath(path, borderPaint);

   // Add shadow effect
   final shadowPaint = Paint()
     ..color = Colors.black26
     ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
   
   canvas.drawPath(path, shadowPaint);
 }

 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}