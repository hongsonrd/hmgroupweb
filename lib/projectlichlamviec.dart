import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'db_helper.dart';
import 'table_models.dart';
import 'projectcongnhanllv.dart';

class ProjectLichLamViec extends StatefulWidget {
  final String username;

  const ProjectLichLamViec({Key? key, required this.username}) : super(key: key);

  @override
  _ProjectLichLamViecState createState() => _ProjectLichLamViecState();
}

class _ProjectLichLamViecState extends State<ProjectLichLamViec> {
  bool _isLoading = false;
  String _syncStatus = '';
  List<TaskScheduleModel> _taskSchedules = [];
  bool _hasTaskSchedulesSynced = false;
  List<QRLookupModel> _qrLookups = [];
  String? _selectedProject;
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  Map<String, Map<String, List<TaskScheduleModel>>> _cachedPositionTasks = {};
  List<String> _cachedProjectNames = [];
  bool _isComputingProject = false;
  
  final DBHelper _dbHelper = DBHelper();
  
  List<LichCNkhuVucModel> _khuVucs = [];
  List<LichCNhangMucModel> _hangMucs = [];
  List<LichCNkyThuatModel> _kyThuats = [];
  List<LichCNtinhChatModel> _tinhChats = [];
  List<LichCNtangToaModel> _tangToas = [];
  List<LichCNchiTietModel> _chiTiets = [];
  
  TextEditingController _searchController = TextEditingController();
  List<String> _filteredProjectNames = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_filterProjects);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProjects() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredProjectNames = _cachedProjectNames;
      } else {
        _filteredProjectNames = _cachedProjectNames.where((p) => p.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
      }
    });
  }

  Future<void> _initializeData() async {
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
    
    _hasTaskSchedulesSynced = await TaskScheduleManager.hasEverSynced();
    if (_hasTaskSchedulesSynced) {
      _taskSchedules = await TaskScheduleManager.getTaskSchedules();
      _qrLookups = await TaskScheduleManager.getQRLookups();
      _cachedProjectNames = TaskScheduleManager.getAllProjectNames(_qrLookups);
      _filteredProjectNames = _cachedProjectNames;
      await _loadSupportingData();
    }
    setState(() {});
  }

  Future<void> _loadSupportingData() async {
    _khuVucs = await _dbHelper.getAllLichCNkhuVuc();
    _hangMucs = await _dbHelper.getAllLichCNhangMuc();
    _kyThuats = await _dbHelper.getAllLichCNkyThuat();
    _tinhChats = await _dbHelper.getAllLichCNtinhChat();
    _tangToas = await _dbHelper.getAllLichCNtangToa();
    _chiTiets = await _dbHelper.getAllLichCNchiTiet();
  }

  Future<void> _computeProjectData(String projectName) async {
    if (_cachedPositionTasks.containsKey(projectName)) return;

    setState(() => _isComputingProject = true);

    await Future.delayed(Duration(milliseconds: 50));

    final positions = TaskScheduleManager.getPositionsForProject(projectName, _qrLookups);
    final positionTasksMap = <String, List<TaskScheduleModel>>{};
    
    for (final position in positions) {
      final tasks = _taskSchedules.where((task) {
        final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, _qrLookups);
        return userMapping['projectName'] == projectName && userMapping['positionName'] == position;
      }).toList();
      
      tasks.sort((a, b) => a.start.compareTo(b.start));
      positionTasksMap[position] = tasks;
    }
    
    _cachedPositionTasks[projectName] = positionTasksMap;

    setState(() => _isComputingProject = false);
  }

  Future<void> _syncTaskSchedules() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ lịch làm việc...';
    });

    try {
      await TaskScheduleManager.syncTaskSchedules(baseUrl);
      
      setState(() => _syncStatus = 'Đang đồng bộ dữ liệu hỗ trợ...');
      await _syncSupportingData();
      
      _taskSchedules = await TaskScheduleManager.getTaskSchedules();
      _qrLookups = await TaskScheduleManager.getQRLookups();
      _hasTaskSchedulesSynced = true;
      _cachedProjectNames = TaskScheduleManager.getAllProjectNames(_qrLookups);
      _filteredProjectNames = _cachedProjectNames;
      _cachedPositionTasks.clear();
      
      await _loadSupportingData();
      
      _showSuccess('Đồng bộ thành công - ${_taskSchedules.length} nhiệm vụ, ${_khuVucs.length} khu vực, ${_tangToas.length} tầng tòa');
    } catch (e) {
      print('Error syncing: $e');
      _showError('Không thể đồng bộ: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _syncSupportingData() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/LichCNkhuVuc')),
        http.get(Uri.parse('$baseUrl/LichCNhangMuc')),
        http.get(Uri.parse('$baseUrl/LichCNkyThuat')),
        http.get(Uri.parse('$baseUrl/LichCNtinhChat')),
        http.get(Uri.parse('$baseUrl/LichCNtangToa')),
        http.get(Uri.parse('$baseUrl/LichCNchiTiet')),
      ]);

      await _dbHelper.clearLichCNkhuVucTable();
      await _dbHelper.clearLichCNhangMucTable();
      await _dbHelper.clearLichCNkyThuatTable();
      await _dbHelper.clearLichCNtinhChatTable();
      await _dbHelper.clearLichCNtangToaTable();
      await _dbHelper.clearLichCNchiTietTable();

      if (responses[0].statusCode == 200) {
        final data = json.decode(responses[0].body) as List;
        await _dbHelper.batchInsertLichCNkhuVucs(data.map((e) => LichCNkhuVucModel.fromMap(e)).toList());
      }
      if (responses[1].statusCode == 200) {
        final data = json.decode(responses[1].body) as List;
        await _dbHelper.batchInsertLichCNhangMucs(data.map((e) => LichCNhangMucModel.fromMap(e)).toList());
      }
      if (responses[2].statusCode == 200) {
        final data = json.decode(responses[2].body) as List;
        await _dbHelper.batchInsertLichCNkyThuats(data.map((e) => LichCNkyThuatModel.fromMap(e)).toList());
      }
      if (responses[3].statusCode == 200) {
        final data = json.decode(responses[3].body) as List;
        await _dbHelper.batchInsertLichCNtinhChats(data.map((e) => LichCNtinhChatModel.fromMap(e)).toList());
      }
      if (responses[4].statusCode == 200) {
        final data = json.decode(responses[4].body) as List;
        await _dbHelper.batchInsertLichCNtangToas(data.map((e) => LichCNtangToaModel.fromMap(e)).toList());
      }
      if (responses[5].statusCode == 200) {
        final data = json.decode(responses[5].body) as List;
        await _dbHelper.batchInsertLichCNchiTiets(data.map((e) => LichCNchiTietModel.fromMap(e)).toList());
      }
    } catch (e) {
      print('Error syncing supporting data: $e');
    }
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

  void _showListDialog(String title, List<String> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: items.isEmpty
              ? Center(child: Text('Không có dữ liệu'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) => ListTile(
                    dense: true,
                    title: Text(items[index]),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng')),
        ],
      ),
    );
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
          Text('Lịch làm việc', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          Spacer(),
          if (!_isLoading)
            ElevatedButton.icon(
              onPressed: () => _syncTaskSchedules(),
              icon: Icon(Icons.schedule, size: 18),
              label: Text('Đồng bộ LLV'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[600], foregroundColor: Colors.white, elevation: 2),
            ),
          if (_isLoading)
            Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black87))),
                SizedBox(width: 8),
                Text(_syncStatus.isNotEmpty ? _syncStatus : 'Đang đồng bộ...', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProjectSelector() {
    if (_cachedProjectNames.isEmpty) {
      return SizedBox.shrink();
    }

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
              Text('Chọn dự án', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedProject,
                  hint: Text('Chọn dự án'),
                  isExpanded: true,
                  items: _filteredProjectNames.map((project) => DropdownMenuItem(value: project, child: Text(project, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedProject = value);
                      _computeProjectData(value);
                    }
                  },
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm dự án',
                    prefixIcon: Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: () => _showListDialog('Danh mục Khu vực', _khuVucs.map((e) => e.khuVuc ?? '').where((s) => s.isNotEmpty).toList()), child: Text('Khu vực'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[100], foregroundColor: Colors.blue[900]))),
              SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: () => _showListDialog('Danh mục Hạng mục', _hangMucs.map((e) => e.doiTuong ?? '').where((s) => s.isNotEmpty).toList()), child: Text('Hạng mục'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green[100], foregroundColor: Colors.green[900]))),
              SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: () => _showListDialog('Danh mục Kỹ thuật', _kyThuats.map((e) => e.congViec ?? '').where((s) => s.isNotEmpty).toList()), child: Text('Kỹ thuật'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[100], foregroundColor: Colors.orange[900]))),
              SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: () => _showListDialog('Danh mục Tính chất', _tinhChats.map((e) => e.tinhChat ?? '').where((s) => s.isNotEmpty).toList()), child: Text('Tính chất'), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[100], foregroundColor: Colors.purple[900]))),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedProject == null ? null : () {
                    final filtered = _tangToas.where((e) => e.boPhan == _selectedProject).map((e) => '${e.tenGoi ?? ''} (${e.phanLoai ?? ''})').where((s) => s.isNotEmpty).toList();
                    _showListDialog('Danh mục Tầng tòa', filtered);
                  },
                  child: Text('Tầng tòa'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100], foregroundColor: Colors.red[900], disabledBackgroundColor: Colors.grey[300], disabledForegroundColor: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleByPosition() {
    if (_selectedProject == null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.filter_list, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text('Vui lòng chọn dự án để xem lịch làm việc', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_isComputingProject) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)),
              SizedBox(height: 16),
              Text('Đang tải dữ liệu...', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final positionTasks = _cachedPositionTasks[_selectedProject!] ?? {};
    final positions = positionTasks.keys.toList();
    
    if (positions.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_off, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text('Không có vị trí nào cho dự án này', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: positions.length,
        itemBuilder: (context, index) {
          final position = positions[index];
          final tasks = positionTasks[position]!;
          final positionColor = _getPositionColor(index);

          return Card(
            margin: EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              initiallyExpanded: positions.length <= 3,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: positionColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: positionColor)),
                child: Icon(Icons.person, color: positionColor),
              ),
              title: Text(position, style: TextStyle(fontWeight: FontWeight.bold, color: positionColor)),
              subtitle: Text('${tasks.length} nhiệm vụ', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              children: tasks.map((task) => _buildTaskItem(task, positionColor)).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskItem(TaskScheduleModel task, Color positionColor) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: positionColor.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: positionColor.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: positionColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: positionColor)),
                child: Text('${TaskScheduleManager.formatScheduleTime(task.start)} - ${TaskScheduleManager.formatScheduleTime(task.end)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: positionColor)),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: Text(_formatWeekdays(task.weekday), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(task.task, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('ID: ${task.taskId}', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Color _getPositionColor(int index) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.indigo, Colors.pink];
    return colors[index % colors.length];
  }

  String _formatWeekdays(String weekdays) {
    if (weekdays.trim().isEmpty) return 'Tất cả';
    final days = weekdays.split(',').map((d) => d.trim()).toList();
    final dayNames = <String>[];
    for (final day in days) {
      switch (day) {
        case '1': dayNames.add('CN'); break;
        case '2': dayNames.add('T2'); break;
        case '3': dayNames.add('T3'); break;
        case '4': dayNames.add('T4'); break;
        case '5': dayNames.add('T5'); break;
        case '6': dayNames.add('T6'); break;
        case '7': dayNames.add('T7'); break;
      }
    }
    return dayNames.join(', ');
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
              child: Text(_syncStatus, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            ),
          if (!_hasTaskSchedulesSynced)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text('Nhấn nút "Đồng bộ LLV" để tải lịch làm việc', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          if (_hasTaskSchedulesSynced) ...[
            _buildProjectSelector(),
            _buildScheduleByPosition(),
          ],
        ],
      ),
    );
  }
}