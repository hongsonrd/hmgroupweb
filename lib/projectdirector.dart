import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:core';
import 'package:media_kit/media_kit.dart';                    
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'user_state.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'http_client.dart';
import 'dart:math' as math;
import 'floating_draggable_icon.dart';

class ProjectDirectorScreen extends StatefulWidget {
  const ProjectDirectorScreen({Key? key}) : super(key: key);

  @override
  _ProjectDirectorScreenState createState() => _ProjectDirectorScreenState();
}

class _ProjectDirectorScreenState extends State<ProjectDirectorScreen> {
  late final appBarPlayer = Player();
  late final appBarVideoController = VideoController(appBarPlayer);
  bool _appBarVideoInitialized = false;

  final UserState _userState = UserState();
  bool _isLoadingProjects = false;
  bool _isLoadingHistory = false;
  String _syncStatus = '';
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  List<Map<String, dynamic>> _filteredTaskHistory = [];
  String? _selectedStartDate;
  String? _selectedEndDate;
  String? _selectedBoPhan = 'Tất cả';
  List<String> _boPhanList = ['Tất cả'];
  Timer? _autoSyncTimer;
  Timer? _secondSyncDelayTimer;
  
  final Map<String, GlobalKey> _chartKeys = {
    'phanLoaiChart': GlobalKey(),
    'issueResolutionChart': GlobalKey(),
    'issueTypeChart': GlobalKey(),
    'projectPerformanceChart': GlobalKey(),
    'dailyReportChart': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _initScreen();
    _initAppBarVideo();
    // Set up auto sync timer (every 30 minutes)
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _triggerSyncSequence();
    });
  }

  @override
  void dispose() {
    appBarPlayer.dispose();
    _autoSyncTimer?.cancel();
    _secondSyncDelayTimer?.cancel();
    super.dispose();
  }
Future<void> _initAppBarVideo() async {
  try {
    // Load video from assets
    await appBarPlayer.open(Media('asset:///assets/appbarvideo.mp4'));
    
    // Set the video to mute
    appBarPlayer.setVolume(0);
    
    // Set up looping directly with the player configuration
    appBarPlayer.setPlaylistMode(PlaylistMode.loop);
    
    // Update state when video is initialized
    appBarPlayer.stream.playing.listen((playing) {
      if (playing && mounted) {
        setState(() {
          _appBarVideoInitialized = true;
        });
      }
    });
  } catch (e) {
    print('Error initializing app bar video: $e');
  }
}
  Future<void> _initScreen() async {
  await _loadBoPhanList();
  await _loadDateRange();
  _triggerSyncSequence();
  _loadRecentImages();
}

  void _triggerSyncSequence() {
    // First sync
    _loadProjects();
    
    // Schedule second sync after 3 seconds
    _secondSyncDelayTimer?.cancel();
    _secondSyncDelayTimer = Timer(const Duration(seconds: 3), () {
      _loadHistory();
    });
  }

  Future<void> _loadBoPhanList() async {
    try {
      final List<String> boPhanList = await dbHelper.getUserBoPhanList();
      if (mounted) {
        setState(() {
          // Make sure we have unique values
          final uniqueBoPhanList = {'Tất cả', ...boPhanList.toSet()}.toList();
          _boPhanList = uniqueBoPhanList;
        });
      }
    } catch (e) {
      print('Error loading BoPhan list: $e');
      _showError('Error loading department list: $e');
    }
  }

  Future<void> _loadDateRange() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT 
          MIN(date(Ngay)) as min_date, 
          MAX(date(Ngay)) as max_date
        FROM ${DatabaseTables.taskHistoryTable}
      ''');
      
      if (result.isNotEmpty && result[0]['min_date'] != null && result[0]['max_date'] != null) {
        setState(() {
          _selectedStartDate = result[0]['max_date'] as String;
          _selectedEndDate = result[0]['max_date'] as String;
        });
        await _loadTaskHistoryData();
      }
    } catch (e) {
      print('Error loading date range: $e');
      _showError('Error loading date range: $e');
    }
  }

  Future<void> _loadTaskHistoryData() async {
    if (_selectedStartDate == null || _selectedEndDate == null) return;

    try {
      final db = await dbHelper.database;
      String query = '''
        SELECT * FROM ${DatabaseTables.taskHistoryTable}
        WHERE date(Ngay) BETWEEN ? AND ?
      ''';
      List<dynamic> args = [_selectedStartDate, _selectedEndDate];

      if (_selectedBoPhan != 'Tất cả') {
        query += ' AND BoPhan = ?';
        args.add(_selectedBoPhan);
      }

      final List<Map<String, dynamic>> results = await db.rawQuery(query, args);
      setState(() {
        _filteredTaskHistory = results;
      });
    } catch (e) {
      print('Error loading task history: $e');
      _showError('Error loading task history data');
    }
  }

  Future<void> _loadProjects() async {
    if (_isLoadingProjects) return;
    
    setState(() {
      _isLoadingProjects = true;
      _syncStatus = 'Đang đồng bộ dự án...';
    });
    
    try {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      final username = userCredentials.username.toLowerCase();
      
      // Get user role
      setState(() => _syncStatus = 'Đang lấy thông tin người dùng...');
      final roleResponse = await AuthenticatedHttpClient.get(
        Uri.parse('$baseUrl/myrole/$username')
      );

      if (roleResponse.statusCode != 200) {
        throw Exception('Failed to load user role: ${roleResponse.statusCode}');
      }

      // Fetch project list
      try {
        setState(() => _syncStatus = 'Đang lấy danh sách dự án...');
        final projectResponse = await AuthenticatedHttpClient.get(
          Uri.parse('$baseUrl/projectlist/$username')
        );
        
        if (projectResponse.statusCode != 200) {
          throw Exception('Failed to load projects: ${projectResponse.statusCode}');
        }

        final String responseText = projectResponse.body;
        final List<dynamic> projectData = json.decode(responseText);
        
        await dbHelper.clearTable(DatabaseTables.projectListTable);
        
        final List<ProjectListModel> projects = [];
        for (var project in projectData) {
          try {
            final model = ProjectListModel(
              boPhan: project['BoPhan'] ?? '',
              maBP: project['MaBP'] ?? '',
            );
            projects.add(model);
          } catch (e) {
            print('Error creating project model: $e');
            print('Problematic data: $project');
            throw e;
          }
        }

        await dbHelper.batchInsertProjectList(projects);
      } catch (e) {
        print('ERROR in Project list fetching: $e');
        throw e;
      }

      // Fetch staff list
      setState(() => _syncStatus = 'Đang lấy danh sách nhân viên...');
      final staffListResponse = await AuthenticatedHttpClient.get(
        Uri.parse('$baseUrl/dscn/$username')
      );

      if (staffListResponse.statusCode == 200) {
        final List<dynamic> staffListData = json.decode(staffListResponse.body);
        await dbHelper.clearTable(DatabaseTables.staffListTable);

        final staffList = staffListData.map((data) => StaffListModel(
          uid: data['UID'],
          manv: data['MaNV'],
          nguoiDung: data['NguoiDung'],
          vt: data['VT'],
          boPhan: data['BoPhan'],
        )).toList();

        await dbHelper.batchInsertStaffList(staffList);
      }

      // Reload BoPhan list
      await _loadBoPhanList();
      _showSuccess('Đồng bộ dự án thành công');
    } catch (e) {
      print('Error syncing projects: $e');
      _showError('Không thể đồng bộ dự án: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
          _syncStatus = '';
        });
      }
    }
  }

  Future<void> _loadHistory() async {
  if (_isLoadingHistory) return;
  
  setState(() {
    _isLoadingHistory = true;
    _syncStatus = 'Đang đồng bộ lịch sử...';
  });
  
  try {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username.toLowerCase();
    
    // Try to fetch task history
    setState(() => _syncStatus = 'Đang lấy lịch sử báo cáo...');
    final taskHistoryResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/historybaocao/$username')
    );

    if (taskHistoryResponse.statusCode != 200) {
      throw Exception('Failed to load task history: ${taskHistoryResponse.statusCode}');
    }

    final List<dynamic> taskHistoryData = json.decode(taskHistoryResponse.body);
    await dbHelper.clearTable(DatabaseTables.taskHistoryTable);

    final taskHistories = taskHistoryData.map((data) => TaskHistoryModel(
      uid: data['UID'],
      taskId: data['TaskID'],
      ngay: DateTime.parse(data['Ngay']),
      gio: data['Gio'],
      nguoiDung: data['NguoiDung'],
      ketQua: data['KetQua'],
      chiTiet: data['ChiTiet'],
      chiTiet2: data['ChiTiet2'],
      viTri: data['ViTri'],
      boPhan: data['BoPhan'],
      phanLoai: data['PhanLoai'],
      hinhAnh: data['HinhAnh'],
      giaiPhap: data['GiaiPhap'],
    )).toList();

    await dbHelper.batchInsertTaskHistory(taskHistories);

    // Try to fetch interaction history
    try {
      setState(() => _syncStatus = 'Đang lấy lịch sử tương tác...');
      final interactionResponse = await AuthenticatedHttpClient.get(
        Uri.parse('$baseUrl/historytuongtac/$username')
      );

      if (interactionResponse.statusCode == 200) {
        final List<dynamic> interactionData = json.decode(interactionResponse.body);
        await dbHelper.clearTable(DatabaseTables.interactionTable);

        final interactions = interactionData.map((data) => InteractionModel(
          uid: data['UID'],
          ngay: DateTime.parse(data['Ngay']),
          gio: data['Gio'],
          nguoiDung: data['NguoiDung'],
          boPhan: data['BoPhan'],
          giamSat: data['GiamSat'],
          noiDung: data['NoiDung'],
          chuDe: data['ChuDe'],
          phanLoai: data['PhanLoai'],
        )).toList();

        await dbHelper.batchInsertInteraction(interactions);
      }
    } catch (e) {
      print('Error fetching interaction history, skipping: $e');
    }

    // Load date range and data after sync
    await _loadDateRange();
    
    // Refresh the images after history is loaded
    _loadRecentImages();
    
    _showSuccess('Đồng bộ lịch sử thành công');
  } catch (e) {
    print('Error syncing history: $e');
    _showError('Không thể đồng bộ lịch sử: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        _syncStatus = '';
      });
    }
  }
}

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
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
        ),
      );
    }
  }

  // Stats calculations
  int get totalReports => _filteredTaskHistory.length;
  
  int get uniqueProjects {
    return _filteredTaskHistory
        .map((item) => item['BoPhan'] as String)
        .toSet()
        .length;
  }
  
  int get issuesCount {
    return _filteredTaskHistory
        .where((item) => item['KetQua'] != '✔️')
        .length;
  }

  double get issueResolutionRate {
    if (issuesCount == 0) return 0;
    int resolved = _filteredTaskHistory
        .where((item) => 
            item['KetQua'] != '✔️' && 
            item['GiaiPhap'] != null && 
            item['GiaiPhap'].toString().trim().isNotEmpty)
        .length;
    return resolved / issuesCount;
  }

  List<Map<String, dynamic>> get phanLoaiStats {
    final map = <String, int>{};
    for (var item in _filteredTaskHistory) {
      final phanLoai = item['PhanLoai'] as String? ?? 'Khác';
      map[phanLoai] = (map[phanLoai] ?? 0) + 1;
    }
    return map.entries
        .map((e) => {'name': e.key, 'value': e.value})
        .toList();
  }

  List<Map<String, dynamic>> get issueResolutionStats {
    int resolved = _filteredTaskHistory
        .where((item) => 
            item['KetQua'] != '✔️' && 
            item['GiaiPhap'] != null && 
            item['GiaiPhap'].toString().trim().isNotEmpty)
        .length;
    
    int unresolved = _filteredTaskHistory
        .where((item) => 
            item['KetQua'] != '✔️' && 
            (item['GiaiPhap'] == null || 
            item['GiaiPhap'].toString().trim().isEmpty))
        .length;

    return [
      {'name': 'Đã giải quyết', 'value': resolved},
      {'name': 'Chưa giải quyết', 'value': unresolved},
    ];
  }

  List<Map<String, dynamic>> get issuePhanLoaiStats {
    final map = <String, int>{};
    for (var item in _filteredTaskHistory) {
      if (item['KetQua'] != '✔️') {
        final phanLoai = item['PhanLoai'] as String? ?? 'Khác';
        map[phanLoai] = (map[phanLoai] ?? 0) + 1;
      }
    }
    return map.entries
        .map((e) => {'name': e.key, 'value': e.value})
        .toList();
  }

  List<Map<String, dynamic>> get projectPerformanceStats {
    final map = <String, Map<String, int>>{};
    for (var item in _filteredTaskHistory) {
      final boPhan = item['BoPhan'] as String;
      if (!map.containsKey(boPhan)) {
        map[boPhan] = {'total': 0, 'issues': 0};
      }
      map[boPhan]!['total'] = (map[boPhan]!['total'] ?? 0) + 1;
      if (item['KetQua'] != '✔️') {
        map[boPhan]!['issues'] = (map[boPhan]!['issues'] ?? 0) + 1;
      }
    }
    
    final result = map.entries.map((e) => {
      'name': e.key,
      'total': e.value['total'],
      'issues': e.value['issues'],
      'successRate': 1 - (e.value['issues'] ?? 0) / (e.value['total'] ?? 1),
    }).toList();
    
    // Fix for comparison error
    result.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    return result;
  }

  List<Map<String, dynamic>> get dailyReportStats {
    final map = <String, Map<String, int>>{};
    for (var item in _filteredTaskHistory) {
      final date = item['Ngay'] as String;
      if (!map.containsKey(date)) {
        map[date] = {'reports': 0, 'issues': 0};
      }
      map[date]!['reports'] = (map[date]!['reports'] ?? 0) + 1;
      if (item['KetQua'] != '✔️') {
        map[date]!['issues'] = (map[date]!['issues'] ?? 0) + 1;
      }
    }
    
    final result = map.entries
      .map((e) => {
        'date': e.key,
        'reports': e.value['reports'],
        'issues': e.value['issues'],
      })
      .toList();
    
    // Fix for comparison error
    result.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return result;
  }

  @override
Widget build(BuildContext context) {
 final userCredentials = Provider.of<UserCredentials>(context);
 final username = userCredentials.username.toUpperCase();

 return Stack(
   children: [
     DefaultTabController(
       length: 2,
       child: Scaffold(
         appBar: AppBar(
           toolbarHeight: 45,
           backgroundColor: Colors.transparent,
           iconTheme: IconThemeData(color: Colors.white),
           flexibleSpace: Stack(
             children: [
               if (!_appBarVideoInitialized)
                 Container(
                   decoration: BoxDecoration(
                     gradient: LinearGradient(
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight,
                       colors: [
                         Colors.red[800]!,
                         Colors.red[600]!,
                         Colors.red[400]!,
                         Colors.red[500]!,
                       ],
                     ),
                   ),
                   child: Center(
                     child: SizedBox(
                       width: 24,
                       height: 24,
                       child: CircularProgressIndicator(
                         color: Colors.white.withOpacity(0.7),
                         strokeWidth: 2,
                       ),
                     ),
                   ),
                 ),
               if (_appBarVideoInitialized)
                 SizedBox.expand(
                   child: Video(
                     controller: appBarVideoController,
                     fit: BoxFit.cover,
                   ),
                 ),
               Container(
                 color: const Color.fromARGB(255, 0, 72, 197).withOpacity(0.45),
               ),
             ],
           ),
           title: Text(
             'QUẢN TRỊ HỆ THỐNG - $username',
             style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
           ),
           actions: [
             IconButton(
               icon: Icon(_isLoadingProjects ? Icons.sync : Icons.cloud_download, color: Colors.white),
               tooltip: 'Đồng bộ dự án',
               onPressed: _isLoadingProjects ? null : _loadProjects,
             ),
             IconButton(
               icon: Icon(_isLoadingHistory ? Icons.sync : Icons.history, color: Colors.white),
               tooltip: 'Đồng bộ lịch sử',
               onPressed: _isLoadingHistory ? null : _loadHistory,
             ),
             SizedBox(width: 8),
           ],
           bottom: TabBar(
             tabs: [
               Tab(
                 icon: Icon(Icons.image, color: Colors.white),
                 text: 'Hình ảnh gần đây',
               ),
               Tab(
                 icon: Icon(Icons.analytics, color: Colors.white),
                 text: 'Phân tích chi tiết',
               ),
             ],
             indicatorColor: Colors.white,
             labelColor: Colors.white,
             unselectedLabelColor: Colors.white.withOpacity(0.7),
           ),
         ),
         body: TabBarView(
           children: [
             _buildRecentImagesTab(),
             _buildAnalyticsTab(),
           ],
         ),
       ),
     ),
     FloatingDraggableIcon(
       key: FloatingDraggableIcon.globalKey,
     ),
   ],
 );
}
Widget _buildRecentImagesTab() {
  return SingleChildScrollView(
    child: Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sync Status
          if (_syncStatus.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                _syncStatus,
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          SizedBox(height: 4),
          Container(
            margin: EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                // From Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Từ ngày:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      _buildDatePicker(
                        selectedDate: _selectedStartDate,
                        onChanged: (date) {
                          setState(() {
                            _selectedStartDate = date;
                          });
                          _loadTaskHistoryData();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // To Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đến ngày:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      _buildDatePicker(
                        selectedDate: _selectedEndDate,
                        onChanged: (date) {
                          setState(() {
                            _selectedEndDate = date;
                          });
                          _loadTaskHistoryData();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Department selection
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bộ phận:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedBoPhan,
                          isExpanded: true,
                          underline: SizedBox(),
                          hint: Text('Chọn bộ phận'),
                          items: _boPhanList.map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _selectedBoPhan = value;
                            });
                            _loadTaskHistoryData();
                            _loadRecentImages();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Summary Statistics
          SizedBox(height: 4),
          Text(
            'Tổng quan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          // Stats Cards
          Row(
            children: [
              _buildStatCard(
                'Số báo cáo',
                totalReports.toString(),
                Icons.assignment,
                Colors.blue,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Số dự án',
                uniqueProjects.toString(),
                Icons.business,
                Colors.green,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Số vấn đề',
                issuesCount.toString(),
                Icons.warning,
                Colors.orange,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Tỉ lệ giải quyết',
                '${(issueResolutionRate * 100).toStringAsFixed(0)}%',
                Icons.check_circle,
                Colors.teal,
              ),
            ],
          ),
          
          // Recent Images Display
          SizedBox(height: 24),
          Text(
            'Hình ảnh gần đây',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _buildRecentImagesGrid(),
        ],
      ),
    ),
  );
}
Widget _buildAnalyticsTab() {
  return SingleChildScrollView(
    child: Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same top section as the first tab - Sync status, date filters, dept selection, stats cards
          if (_syncStatus.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                _syncStatus,
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          SizedBox(height: 4),
          Container(
            margin: EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                // From Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Từ ngày:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      _buildDatePicker(
                        selectedDate: _selectedStartDate,
                        onChanged: (date) {
                          setState(() {
                            _selectedStartDate = date;
                          });
                          _loadTaskHistoryData();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // To Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đến ngày:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      _buildDatePicker(
                        selectedDate: _selectedEndDate,
                        onChanged: (date) {
                          setState(() {
                            _selectedEndDate = date;
                          });
                          _loadTaskHistoryData();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Department selection
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bộ phận:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedBoPhan,
                          isExpanded: true,
                          underline: SizedBox(),
                          hint: Text('Chọn bộ phận'),
                          items: _boPhanList.map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _selectedBoPhan = value;
                            });
                            _loadTaskHistoryData();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Summary Statistics
          SizedBox(height: 4),
          Text(
            'Tổng quan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          // Stats Cards
          Row(
            children: [
              _buildStatCard(
                'Số báo cáo',
                totalReports.toString(),
                Icons.assignment,
                Colors.blue,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Số dự án',
                uniqueProjects.toString(),
                Icons.business,
                Colors.green,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Số vấn đề',
                issuesCount.toString(),
                Icons.warning,
                Colors.orange,
              ),
              SizedBox(width: 12),
              _buildStatCard(
                'Tỉ lệ giải quyết',
                '${(issueResolutionRate * 100).toStringAsFixed(0)}%',
                Icons.check_circle,
                Colors.teal,
              ),
            ],
          ),
          
          // Here's where the "Phân tích chi tiết" section starts
          SizedBox(height: 24),
          Text(
            'Phân tích chi tiết',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          // Project Performance Chart
          SizedBox(height: 24),
          _buildBarChart(
            'Hiệu suất theo bộ phận',
            projectPerformanceStats,
            'projectPerformanceChart',
          ),
          
          // Daily Report Chart
          SizedBox(height: 24),
          _buildLineChart(
            'Báo cáo theo ngày',
            dailyReportStats,
            'dailyReportChart',
          ),
          
          // Category Charts
          SizedBox(height: 24),
          _buildPieChart(
            'Chủ đề báo cáo',
            phanLoaiStats,
            'phanLoaiChart',
          ),
          
          SizedBox(height: 24),
          _buildPieChart(
            'Tỉ lệ vấn đề được giải quyết',
            issueResolutionStats,
            'issueResolutionChart',
          ),
          
          SizedBox(height: 24),
          _buildPieChart(
            'Phân loại vấn đề',
            issuePhanLoaiStats,
            'issueTypeChart',
          ),
          
          // Summary
          SizedBox(height: 24),
          Text(
            'Tổng hợp báo cáo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _buildSummaryTable(),
          
          SizedBox(height: 32),
        ],
      ),
    ),
  );
}
List<Map<String, dynamic>> _recentImages = [];
bool _isLoadingImages = false;

Future<void> _loadRecentImages() async {
  if (_isLoadingImages) return;
  
  setState(() {
    _isLoadingImages = true;
  });
  
  try {
    final db = await dbHelper.database;
    String query = '''
      SELECT * FROM ${DatabaseTables.taskHistoryTable}
      WHERE HinhAnh IS NOT NULL AND HinhAnh != ''
    ''';
    List<dynamic> args = [];

    if (_selectedBoPhan != 'Tất cả') {
      query += ' AND BoPhan = ?';
      args.add(_selectedBoPhan);
    }

    query += ' ORDER BY date(Ngay) DESC, Gio DESC LIMIT 50';

    final List<Map<String, dynamic>> results = await db.rawQuery(query, args);
    
    setState(() {
      _recentImages = results;
      _isLoadingImages = false;
    });
  } catch (e) {
    print('Error loading recent images: $e');
    _showError('Error loading images: $e');
    setState(() {
      _isLoadingImages = false;
    });
  }
}
String _formatDateTime(String dateTimeStr) {
  try {
    final parts = dateTimeStr.split(' ');
    final date = DateTime.parse(parts[0]);
    
    // Format: DD/MM/YYYY HH:MM
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${parts[1]}";
  } catch (e) {
    return dateTimeStr; // Fallback to original if parsing fails
  }
}
Widget _buildRecentImagesGrid() {
 if (_isLoadingImages) {
   return Center(
     child: Padding(
       padding: EdgeInsets.symmetric(vertical: 50),
       child: CircularProgressIndicator(),
     ),
   );
 }
 
 if (_recentImages.isEmpty) {
   return Center(
     child: Padding(
       padding: EdgeInsets.symmetric(vertical: 50),
       child: Text('Không có hình ảnh nào'),
     ),
   );
 }
 
 Map<String, List<Map<String, dynamic>>> personDateGroups = {};
 
 for (var image in _recentImages) {
   final nguoiDung = image['NguoiDung'] as String;
   final ngay = image['Ngay'] as String;
   final key = '$nguoiDung-$ngay';
   
   if (!personDateGroups.containsKey(key)) {
     personDateGroups[key] = [];
   }
   
   personDateGroups[key]!.add(image);
 }
 
 personDateGroups.forEach((key, images) {
   images.sort((a, b) {
     final String gioA = a['Gio'] as String? ?? '';
     final String gioB = b['Gio'] as String? ?? '';
     return gioA.compareTo(gioB);
   });
 });
 
 final now = DateTime.now();
 final Map<String, List<Map<String, dynamic>>> groupedImages = {};

 for (var image in _recentImages) {
   final boPhan = image['BoPhan'] as String;
   final ngayStr = image['Ngay'] as String;
   final gioStr = image['Gio'] as String? ?? "00:00";
   
   try {
     final DateTime date = DateTime.parse(ngayStr);
     final List<String> timeParts = gioStr.split(':');
     final int hour = int.parse(timeParts[0]);
     final int minute = int.parse(timeParts[1]);
     
     final DateTime timestamp = DateTime(date.year, date.month, date.day, hour, minute);
     final int intervalMinutes = (minute ~/ 15) * 15;
     final DateTime interval = DateTime(date.year, date.month, date.day, hour, intervalMinutes);
     
     final String formattedDate = "${interval.year}-${interval.month.toString().padLeft(2, '0')}-${interval.day.toString().padLeft(2, '0')}";
     final String formattedTime = "${interval.hour.toString().padLeft(2, '0')}:${interval.minute.toString().padLeft(2, '0')}";
     final String formattedInterval = "$formattedDate $formattedTime";
     final String intervalKey = "$boPhan - $formattedInterval";
     
     if (!groupedImages.containsKey(intervalKey)) {
       groupedImages[intervalKey] = [];
     }
     
     groupedImages[intervalKey]!.add(image);
     image['timestamp'] = timestamp;
   } catch (e) {
     print('Error parsing date/time: $e for date: $ngayStr and time: $gioStr');
   }
 }
 
 final sortedKeys = groupedImages.keys.toList()
 ..sort((a, b) {
   final String aDateTimeStr = a.split(' - ')[1];
   final String bDateTimeStr = b.split(' - ')[1];
   
   final DateTime aDateTime = DateTime.parse(aDateTimeStr.replaceAll(' ', 'T'));
   final DateTime bDateTime = DateTime.parse(bDateTimeStr.replaceAll(' ', 'T'));
   
   return bDateTime.compareTo(aDateTime);
 });
 
 return Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: sortedKeys.map((key) {
     final images = groupedImages[key]!;
     final parts = key.split(' - ');
     final projectName = parts[0];
     final dateTimeParts = parts[1].split(' ');
     final datePart = dateTimeParts[0];
     final timePart = dateTimeParts[1];

     final intervalDateTime = DateTime.parse("$datePart $timePart:00");
     final isRecent = now.difference(intervalDateTime).inMinutes <= 30;
     
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           margin: EdgeInsets.only(top: 16, bottom: 8),
           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
           decoration: BoxDecoration(
             color: Colors.blue[700],
             borderRadius: BorderRadius.circular(4),
             boxShadow: [
               BoxShadow(
                 color: Colors.grey.withOpacity(0.3),
                 blurRadius: 3,
                 offset: Offset(0, 2),
               ),
             ],
           ),
           child: Row(
             children: [
               Icon(Icons.business, color: Colors.white),
               SizedBox(width: 8),
               Expanded(
                 child: Text(
                   projectName,
                   style: TextStyle(
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
               ),
               Text(
                 _formatDateTime(parts[1]),
                 style: TextStyle(color: Colors.white),
               ),
               if (isRecent) ...[
                 SizedBox(width: 8),
                 _buildPulsingDot(),
               ],
             ],
           ),
         ),
         
         ListView.builder(
           shrinkWrap: true,
           physics: NeverScrollableScrollPhysics(),
           itemCount: _getUniquePersonsInGroup(images).length,
           itemBuilder: (context, personIndex) {
             final person = _getUniquePersonsInGroup(images)[personIndex];
             final personImages = images.where((img) => img['NguoiDung'] == person).toList();
             final date = personImages.first['Ngay'] as String;
             
             final personDateKey = '$person-$date';
             final allPersonImagesForDay = personDateGroups[personDateKey] ?? [];
             
             return Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Padding(
                   padding: EdgeInsets.only(left: 8, top: 16, bottom: 8),
                   child: Row(
                     children: [
                       Icon(Icons.person, size: 16),
                       SizedBox(width: 8),
                       Text(
                         person,
                         style: TextStyle(fontWeight: FontWeight.bold),
                       ),
                       Spacer(),
                       Text(
                         '${_formatDate(date)} - ${allPersonImagesForDay.length} ảnh',
                         style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                       ),
                     ],
                   ),
                 ),
                 
                 Container(
                   height: 180,
                   child: ListView.builder(
                     scrollDirection: Axis.horizontal,
                     itemCount: allPersonImagesForDay.length,
                     itemBuilder: (context, imgIndex) {
                       final item = allPersonImagesForDay[imgIndex];
                       final viTri = item['ViTri'] as String? ?? '';
                       final gio = item['Gio'] as String? ?? '';
                       
                       final totalImagesAtLocation = allPersonImagesForDay
                           .where((img) => img['ViTri'] == viTri)
                           .length;
                       
                       return Container(
                         width: 150,
                         margin: EdgeInsets.symmetric(horizontal: 4),
                         child: Card(
                           elevation: 3,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Expanded(
                                 child: GestureDetector(
                                   onTap: () {
                                     showDialog(
                                       context: context,
                                       builder: (context) => Dialog(
                                         child: Column(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             AppBar(
                                               title: Text('$person - $viTri'),
                                               automaticallyImplyLeading: false,
                                               actions: [
                                                 IconButton(
                                                   icon: Icon(Icons.close),
                                                   onPressed: () => Navigator.of(context).pop(),
                                                 ),
                                               ],
                                             ),
                                             InteractiveViewer(
                                               panEnabled: true,
                                               boundaryMargin: EdgeInsets.all(20),
                                               minScale: 0.5,
                                               maxScale: 4,
                                               child: _buildNetworkImage(item['HinhAnh'] as String, BoxFit.contain),
                                             ),
                                             Padding(
                                               padding: EdgeInsets.all(16),
                                               child: Text(item['ChiTiet'] as String? ?? ''),
                                             ),
                                           ],
                                         ),
                                       ),
                                     );
                                   },
                                   child: ClipRRect(
                                     borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                     child: _buildNetworkImage(item['HinhAnh'] as String, BoxFit.cover),
                                   ),
                                 ),
                               ),
                               
                               Padding(
                                 padding: EdgeInsets.all(8),
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       viTri,
                                       style: TextStyle(
                                         fontWeight: FontWeight.bold,
                                         fontSize: 12,
                                       ),
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                     SizedBox(height: 4),
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Text(
                                           gio,
                                           style: TextStyle(fontSize: 10),
                                         ),
                                         Text(
                                           '$totalImagesAtLocation ảnh',
                                           style: TextStyle(fontSize: 10),
                                         ),
                                       ],
                                     ),
                                   ],
                                 ),
                               ),
                             ],
                           ),
                         ),
                       );
                     },
                   ),
                 ),
               ],
             );
           },
         ),
         
         Divider(height: 32, thickness: 1),
       ],
     );
   }).toList(),
 );
}

List<String> _getUniquePersonsInGroup(List<Map<String, dynamic>> images) {
 final Set<String> persons = {};
 for (var img in images) {
   persons.add(img['NguoiDung'] as String);
 }
 return persons.toList();
}

String _formatDate(String dateStr) {
 try {
   final date = DateTime.parse(dateStr);
   return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
 } catch (e) {
   return dateStr;
 }
}

// Add this method to create a pulsing dot animation
Widget _buildPulsingDot() {
  return TweenAnimationBuilder(
    tween: Tween<double>(begin: 0.5, end: 1.0),
    duration: Duration(seconds: 1),
    builder: (context, double value, child) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.greenAccent.withOpacity(value),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(value * 0.5),
              blurRadius: 6,
              spreadRadius: value * 2,
            ),
          ],
        ),
      );
    },
    onEnd: () {
      // Reverse the animation when it completes
      setState(() {});
    },
  );
}

// You'll also need to update your image card to be smaller for the 6-per-row layout
Widget _buildImageCard(Map<String, dynamic> item, int imagesAtLocation, int uniqueLocations) {
  final String imageUrl = item['HinhAnh'] as String;
  final String ngay = item['Ngay'] as String? ?? 'Unknown';
  final String gio = item['Gio'] as String? ?? 'Unknown';
  final String nguoiDung = item['NguoiDung'] as String? ?? 'Unknown';
  final String chiTiet = item['ChiTiet'] as String? ?? 'No details';
  final String viTri = item['ViTri'] as String? ?? '';
  
  // Format time for display
  final String formattedTime = gio.split(':').take(2).join(':');
  
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        Expanded(
          child: GestureDetector(
            onTap: () {
              // Show full image dialog with horizontal scroll for other images
              _showImageDetailsDialog(item);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              child: _buildNetworkImage(imageUrl, BoxFit.cover),
            ),
          ),
        ),
        
        // Info section
        Padding(
          padding: EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nguoiDung,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      viTri,
                      style: TextStyle(fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formattedTime,
                    style: TextStyle(fontSize: 8, color: Colors.grey[700]),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.photo, size: 8, color: Colors.blue),
                  SizedBox(width: 2),
                  Text(
                    '$imagesAtLocation ảnh',
                    style: TextStyle(fontSize: 8),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward, size: 8, color: Colors.blue),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
void _showImageDetailsDialog(Map<String, dynamic> selectedItem) {
  final String nguoiDung = selectedItem['NguoiDung'] as String? ?? 'Unknown';
  final String ngay = selectedItem['Ngay'] as String? ?? '';
  
  // Filter images by the same person on the same day
  final samePersonSameDayImages = _recentImages.where((item) => 
    item['NguoiDung'] == nguoiDung && item['Ngay'] == ngay
  ).toList();
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nguoiDung),
                Text(
                  '${_formatDateTime(ngay)} - ${samePersonSameDayImages.length} ảnh',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                // Main image with details
                Expanded(
                  flex: 3,
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4,
                    child: _buildNetworkImage(selectedItem['HinhAnh'] as String, BoxFit.contain),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    selectedItem['ChiTiet'] as String? ?? 'No details',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Horizontal scroll of other images by same person on same day
                Container(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: samePersonSameDayImages.length,
                    itemBuilder: (context, index) {
                      final item = samePersonSameDayImages[index];
                      final isSelected = item['TaskID'] == selectedItem['TaskID'];
                      
                      return GestureDetector(
                        onTap: () {
                          // Close this dialog and open a new one with the selected image
                          Navigator.of(context).pop();
                          _showImageDetailsDialog(item);
                        },
                        child: Container(
                          width: 100,
                          margin: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: _buildNetworkImage(item['HinhAnh'] as String, BoxFit.cover),
                              ),
                              Padding(
                                padding: EdgeInsets.all(2),
                                child: Text(
                                  item['Gio'] as String? ?? '',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ),
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
        ],
      ),
    ),
  );
}
Widget _buildNetworkImage(String url, BoxFit fit) {
  // Clean the URL if needed
  String cleanUrl = url.trim();
  
  return Image.network(
    cleanUrl,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      print('Error loading image: $error');
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.red[400]),
        ),
      );
    },
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Container(
        color: Colors.grey[200],
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
  );
}
  Widget _buildDatePicker({
    String? selectedDate,
    required Function(String) onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        if (selectedDate == null) return;
        
        final initialDate = DateTime.parse(selectedDate);
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        
        if (pickedDate != null) {
          final formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
          onChanged(formattedDate);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(selectedDate ?? 'Chọn ngày'),
            Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(String title, List<Map<String, dynamic>> data, String chartId) {
    if (data.isEmpty) return SizedBox();
    
    final List<Color> colorScheme = title == 'Chủ đề báo cáo' ? [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.teal[400]!,
      Colors.indigo[400]!,
    ] : title == 'Tỉ lệ vấn đề được giải quyết' ? [
      Colors.green[400]!,
      Colors.red[400]!,
    ] : [
      Colors.deepOrange[400]!,
      Colors.yellow[700]!,
      Colors.cyan[400]!,
      Colors.pink[400]!,
      Colors.lime[700]!,
    ];

    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: RepaintBoundary(
                    key: _chartKeys[chartId],
                    child: PieChart(
                      PieChartData(
                        sections: data.map((item) {
                          final index = data.indexOf(item) % colorScheme.length;
                          final total = data.fold(0, (sum, item) => sum + (item['value'] as int));
                         return PieChartSectionData(
                           value: item['value'].toDouble(),
                           title: '${((item['value'] as int) / total * 100).toStringAsFixed(1)}%',
                           color: colorScheme[index],
                           radius: 100,
                           titleStyle: TextStyle(
                             fontSize: 12,
                             fontWeight: FontWeight.bold,
                             color: Colors.white,
                           ),
                         );
                       }).toList(),
                       sectionsSpace: 2,
                     ),
                   ),
                 ),
               ),
               Expanded(
                 flex: 1,
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: data.map((item) {
                     final index = data.indexOf(item) % colorScheme.length;
                     return Padding(
                       padding: EdgeInsets.symmetric(vertical: 4),
                       child: Row(
                         children: [
                           Container(
                             width: 12,
                             height: 12,
                             color: colorScheme[index],
                           ),
                           SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               '${item['name']}: ${item['value']}',
                               style: TextStyle(fontSize: 12),
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                         ],
                       ),
                     );
                   }).toList(),
                 ),
               ),
             ],
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildBarChart(String title, List<Map<String, dynamic>> data, String chartId) {
   if (data.isEmpty) return SizedBox();
   
   // Limit to top 10 departments for better visualization
   final displayData = data.take(10).toList();
   
   return Container(
     height: 350,
     padding: EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(8),
       boxShadow: [
         BoxShadow(
           color: Colors.grey.withOpacity(0.2),
           blurRadius: 4,
           offset: Offset(0, 2),
         ),
       ],
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           title,
           style: TextStyle(
             fontSize: 18,
             fontWeight: FontWeight.bold,
           ),
         ),
         SizedBox(height: 16),
         Expanded(
           child: RepaintBoundary(
             key: _chartKeys[chartId],
             child: BarChart(
               BarChartData(
                 alignment: BarChartAlignment.spaceBetween,
                 maxY: displayData.fold(0.0, (max, item) => 
                   math.max(max, (item['total'] as int).toDouble())) * 1.2,
                 titlesData: FlTitlesData(
                   leftTitles: AxisTitles(
                     sideTitles: SideTitles(
                       showTitles: true,
                       reservedSize: 30,
                       getTitlesWidget: (value, meta) {
                         return Text(
                           value.toInt().toString(),
                           style: TextStyle(
                             color: Colors.grey[600],
                             fontSize: 10,
                           ),
                         );
                       },
                     ),
                   ),
                   bottomTitles: AxisTitles(
                     sideTitles: SideTitles(
                       showTitles: true,
                       reservedSize: 100,
                       getTitlesWidget: (value, meta) {
                         int index = value.toInt();
                         if (index < 0 || index >= displayData.length) {
                           return Container();
                         }
                         return Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             displayData[index]['name'].toString(),
                             style: TextStyle(
                               color: Colors.grey[700],
                               fontSize: 10,
                             ),
                             textAlign: TextAlign.center,
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                         );
                       },
                     ),
                   ),
                   rightTitles: AxisTitles(
                     sideTitles: SideTitles(showTitles: false),
                   ),
                   topTitles: AxisTitles(
                     sideTitles: SideTitles(showTitles: false),
                   ),
                 ),
                 borderData: FlBorderData(show: false),
                 gridData: FlGridData(
                   drawHorizontalLine: true,
                   horizontalInterval: 20,
                   getDrawingHorizontalLine: (value) => FlLine(
                     color: Colors.grey[200],
                     strokeWidth: 1,
                   ),
                   drawVerticalLine: false,
                 ),
                 barGroups: List.generate(
                   displayData.length,
                   (index) => BarChartGroupData(
                     x: index,
                     barRods: [
                       BarChartRodData(
                         toY: (displayData[index]['total'] as int).toDouble(),
                         color: Colors.blue[400],
                         width: 16,
                         borderRadius: BorderRadius.only(
                           topLeft: Radius.circular(4),
                           topRight: Radius.circular(4),
                         ),
                         backDrawRodData: BackgroundBarChartRodData(
                           show: true,
                           toY: (displayData[index]['total'] as int).toDouble(),
                           color: Colors.grey[200],
                         ),
                       ),
                       BarChartRodData(
                         toY: (displayData[index]['issues'] as int).toDouble(),
                         color: Colors.red[400],
                         width: 16,
                         borderRadius: BorderRadius.only(
                           topLeft: Radius.circular(4),
                           topRight: Radius.circular(4),
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
           ),
         ),
         SizedBox(height: 16),
         Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             _buildLegendItem(Colors.blue[400]!, 'Tổng báo cáo'),
             SizedBox(width: 20),
             _buildLegendItem(Colors.red[400]!, 'Vấn đề'),
           ],
         ),
       ],
     ),
   );
 }

 Widget _buildLineChart(String title, List<Map<String, dynamic>> data, String chartId) {
   if (data.isEmpty) return SizedBox();
   
   // Get the last 30 days of data for better visualization
   final displayData = data.length > 30 ? data.sublist(data.length - 30) : data;
   
   // Find max value for scaling
   double maxY = 0;
   for (var item in displayData) {
     maxY = math.max(maxY, (item['reports'] as int).toDouble());
     maxY = math.max(maxY, (item['issues'] as int).toDouble());
   }
   maxY = maxY * 1.2; // Add 20% padding
   
   return Container(
     height: 350,
     padding: EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(8),
       boxShadow: [
         BoxShadow(
           color: Colors.grey.withOpacity(0.2),
           blurRadius: 4,
           offset: Offset(0, 2),
         ),
       ],
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           title,
           style: TextStyle(
             fontSize: 18,
             fontWeight: FontWeight.bold,
           ),
         ),
         SizedBox(height: 16),
         Expanded(
           child: RepaintBoundary(
             key: _chartKeys[chartId],
             child: LineChart(
               LineChartData(
                 gridData: FlGridData(
                   show: true,
                   drawVerticalLine: false,
                   getDrawingHorizontalLine: (value) {
                     return FlLine(
                       color: Colors.grey[200],
                       strokeWidth: 1,
                     );
                   },
                 ),
                 titlesData: FlTitlesData(
                   leftTitles: AxisTitles(
                     sideTitles: SideTitles(
                       showTitles: true,
                       reservedSize: 30,
                       getTitlesWidget: (value, meta) {
                         return Text(
                           value.toInt().toString(),
                           style: TextStyle(
                             color: Colors.grey[600],
                             fontSize: 10,
                           ),
                         );
                       },
                     ),
                   ),
                   bottomTitles: AxisTitles(
                     sideTitles: SideTitles(
                       showTitles: true,
                       reservedSize: 30,
                       getTitlesWidget: (value, meta) {
                         int index = value.toInt();
                         if (index < 0 || index >= displayData.length || index % 5 != 0) {
                           return Container();
                         }
                         String date = displayData[index]['date'] as String;
                         return Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             date.split('-').sublist(1).join('/'),
                             style: TextStyle(
                               color: Colors.grey[700],
                               fontSize: 10,
                             ),
                           ),
                         );
                       },
                     ),
                   ),
                   rightTitles: AxisTitles(
                     sideTitles: SideTitles(showTitles: false),
                   ),
                   topTitles: AxisTitles(
                     sideTitles: SideTitles(showTitles: false),
                   ),
                 ),
                 borderData: FlBorderData(
                   show: true,
                   border: Border(
                     bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                     left: BorderSide(color: Colors.grey[300]!, width: 1),
                   ),
                 ),
                 minX: 0,
                 maxX: (displayData.length - 1).toDouble(),
                 minY: 0,
                 maxY: maxY,
                 lineBarsData: [
                   // Reports line
                   LineChartBarData(
                     spots: List.generate(
                       displayData.length,
                       (index) => FlSpot(
                         index.toDouble(),
                         (displayData[index]['reports'] as int).toDouble(),
                       ),
                     ),
                     isCurved: true,
                     color: Colors.blue,
                     barWidth: 3,
                     isStrokeCapRound: true,
                     dotData: FlDotData(show: false),
                     belowBarData: BarAreaData(
                       show: true,
                       color: Colors.blue.withOpacity(0.1),
                     ),
                   ),
                   // Issues line
                   LineChartBarData(
                     spots: List.generate(
                       displayData.length,
                       (index) => FlSpot(
                         index.toDouble(),
                         (displayData[index]['issues'] as int).toDouble(),
                       ),
                     ),
                     isCurved: true,
                     color: Colors.red,
                     barWidth: 3,
                     isStrokeCapRound: true,
                     dotData: FlDotData(show: false),
                     belowBarData: BarAreaData(
                       show: true,
                       color: Colors.red.withOpacity(0.1),
                     ),
                   ),
                 ],
               ),
             ),
           ),
         ),
         SizedBox(height: 16),
         Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             _buildLegendItem(Colors.blue, 'Số báo cáo'),
             SizedBox(width: 20),
             _buildLegendItem(Colors.red, 'Số vấn đề'),
           ],
         ),
       ],
     ),
   );
 }

 Widget _buildLegendItem(Color color, String label) {
   return Row(
     children: [
       Container(
         width: 12,
         height: 12,
         color: color,
       ),
       SizedBox(width: 4),
       Text(
         label,
         style: TextStyle(
           fontSize: 12,
           color: Colors.grey[800],
         ),
       ),
     ],
   );
 }

 Widget _buildSummaryTable() {
   return Container(
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(8),
       boxShadow: [
         BoxShadow(
           color: Colors.grey.withOpacity(0.2),
           blurRadius: 4,
           offset: Offset(0, 2),
         ),
       ],
     ),
     child: Column(
       children: [
         Container(
           padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
           decoration: BoxDecoration(
             color: Colors.blue[800],
             borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
           ),
           child: Row(
             children: [
               Expanded(
                 flex: 3,
                 child: Text(
                   'Bộ phận',
                   style: TextStyle(
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                 ),
               ),
               Expanded(
                 flex: 2,
                 child: Text(
                   'Báo cáo',
                   style: TextStyle(
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                   textAlign: TextAlign.center,
                 ),
               ),
               Expanded(
                 flex: 2,
                 child: Text(
                   'Vấn đề',
                   style: TextStyle(
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                   textAlign: TextAlign.center,
                 ),
               ),
               Expanded(
                 flex: 2,
                 child: Text(
                   'Đã giải quyết',
                   style: TextStyle(
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                   textAlign: TextAlign.center,
                 ),
               ),
             ],
           ),
         ),
         ListView.builder(
           shrinkWrap: true,
           physics: NeverScrollableScrollPhysics(),
           itemCount: math.min(projectPerformanceStats.length, 15),
           itemBuilder: (context, index) {
             final item = projectPerformanceStats[index];
             
             // Calculate resolved issues
             final resolvedIssues = _filteredTaskHistory
               .where((task) => 
                 task['BoPhan'] == item['name'] && 
                 task['KetQua'] != '✔️' && 
                 task['GiaiPhap'] != null && 
                 task['GiaiPhap'].toString().trim().isNotEmpty)
               .length;
             
             return Container(
               decoration: BoxDecoration(
                 border: Border(
                   bottom: BorderSide(
                     color: Colors.grey[200]!,
                     width: 1,
                   ),
                 ),
                 color: index.isEven ? Colors.grey[50] : Colors.white,
               ),
               padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
               child: Row(
                 children: [
                   Expanded(
                     flex: 3,
                     child: Text(
                       item['name'].toString(),
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   Expanded(
                     flex: 2,
                     child: Text(
                       item['total'].toString(),
                       textAlign: TextAlign.center,
                     ),
                   ),
                   Expanded(
                     flex: 2,
                     child: Text(
                       item['issues'].toString(),
                       textAlign: TextAlign.center,
                       style: TextStyle(
                         color: (item['issues'] as int) > 0 ? Colors.red : Colors.black,
                       ),
                     ),
                   ),
                   Expanded(
                     flex: 2,
                     child: Text(
                       resolvedIssues.toString(),
                       textAlign: TextAlign.center,
                       style: TextStyle(
                         color: Colors.green,
                       ),
                     ),
                   ),
                 ],
               ),
             );
           },
         ),
       ],
     ),
   );
 }
}