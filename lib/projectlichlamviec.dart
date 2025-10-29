import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
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
  bool _isSyncingCategories = false;
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
  
  String? _selectedToa;
  String? _selectedTang;
  bool _isUsingTangRange = false;
  String? _tangRangeStart;
  String? _tangRangeEnd;
  String? _selectedKhuVuc;
  List<String> _selectedDoiTuong = [];
  List<String> _selectedCongViec = [];
  String? _selectedTinhChat;

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
      await _syncTaskSchedules();
      await _syncSupportingData();
    } else {
      print('Auto sync skipped');
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
    _updateToaAndTangSelections();
  }

  void _updateToaAndTangSelections() async {
    if (_selectedProject == null) {
      _selectedToa = null;
      _selectedTang = null;
      _selectedKhuVuc = null;
      _selectedDoiTuong = [];
      _selectedCongViec = [];
      _selectedTinhChat = null;
      return;
    }

    final projectTangToas = _tangToas.where((e) => e.boPhan == _selectedProject).toList();
    final toaList = projectTangToas.where((e) => e.phanLoai?.toLowerCase() == 'tòa' || e.phanLoai?.toLowerCase() == 'toa').toList();
    final tangList = projectTangToas.where((e) => e.phanLoai?.toLowerCase() == 'tầng' || e.phanLoai?.toLowerCase() == 'tang').toList();

    bool needsSync = false;

    if (toaList.isEmpty) {
      _selectedToa = 'Toà chính';
      await _autoCreateTangToa('Toà chính', 'Tòa');
      needsSync = true;
    } else {
      _selectedToa = toaList.first.tenGoi ?? 'Toà chính';
    }

    if (tangList.isEmpty) {
      _selectedTang = 'Tầng 1';
      await _autoCreateTangToa('Tầng 1', 'Tầng');
      needsSync = true;
    } else {
      _selectedTang = tangList.first.tenGoi ?? 'Tầng 1';
    }

    if (needsSync) {
      await _syncSpecificCategory('Tầng tòa');
    }

    _selectedKhuVuc = _khuVucs.isNotEmpty ? _khuVucs.first.uid : null;
    _selectedDoiTuong = [];
    _selectedCongViec = [];
    _selectedTinhChat = _tinhChats.isNotEmpty ? _tinhChats.first.uid : null;
  }

  Future<void> _autoCreateTangToa(String tenGoi, String phanLoai) async {
    try {
      final uuid = Uuid();
      final data = {
        'uid': uuid.v4(),
        'boPhan': _selectedProject,
        'tenGoi': tenGoi,
        'phanLoai': phanLoai
      };

      await http.post(
        Uri.parse('$baseUrl/LichCNtangToathemmoi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
    } catch (e) {
      print('Error auto-creating $phanLoai: $e');
    }
  }

  List<String> _getToaListForProject() {
    if (_selectedProject == null) return ['Toà chính'];
    final toaList = _tangToas
        .where((e) => e.boPhan == _selectedProject && (e.phanLoai?.toLowerCase() == 'tòa' || e.phanLoai?.toLowerCase() == 'toa'))
        .map((e) => e.tenGoi ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return toaList.isEmpty ? ['Toà chính'] : toaList;
  }

  List<String> _getTangListForProject() {
    if (_selectedProject == null) return ['Tầng 1'];
    final tangList = _tangToas
        .where((e) => e.boPhan == _selectedProject && (e.phanLoai?.toLowerCase() == 'tầng' || e.phanLoai?.toLowerCase() == 'tang'))
        .map((e) => e.tenGoi ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return tangList.isEmpty ? ['Tầng 1'] : tangList;
  }

  int _getPositionsWithChiTiet() {
    if (_selectedProject == null) return 0;
    final positionTasks = _cachedPositionTasks[_selectedProject!] ?? {};
    int count = 0;
    for (final position in positionTasks.keys) {
      final tasks = positionTasks[position]!;
      final hasAnyDetail = tasks.any((task) => _chiTiets.any((c) => c.lichId == task.taskId));
      if (hasAnyDetail) count++;
    }
    return count;
  }
int _getPositionsCount() {
  if (_selectedProject == null) return 0;
  final positionTasks = _cachedPositionTasks[_selectedProject!] ?? {};
  return positionTasks.keys.length;
}

  double _getChiTietCompletionPercentage() {
    if (_selectedProject == null) return 0.0;
    final positionTasks = _cachedPositionTasks[_selectedProject!] ?? {};
    int totalTasks = 0;
    int completedTasks = 0;
    
    for (final tasks in positionTasks.values) {
      totalTasks += tasks.length;
      completedTasks += tasks.where((task) => _chiTiets.any((c) => c.lichId == task.taskId)).length;
    }
    
    return totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;
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
      
      _taskSchedules = await TaskScheduleManager.getTaskSchedules();
      _qrLookups = await TaskScheduleManager.getQRLookups();
      _hasTaskSchedulesSynced = true;
      _cachedProjectNames = TaskScheduleManager.getAllProjectNames(_qrLookups);
      _filteredProjectNames = _cachedProjectNames;
      _cachedPositionTasks.clear();
      
      _showSuccess('Đồng bộ LLV thành công - ${_taskSchedules.length} nhiệm vụ');
    } catch (e) {
      print('Error syncing schedules: $e');
      _showError('Không thể đồng bộ LLV: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _syncSupportingData() async {
    if (_isSyncingCategories) return;

    setState(() {
      _isSyncingCategories = true;
      _syncStatus = 'Đang đồng bộ danh mục...';
    });

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

      await _loadSupportingData();
      _showSuccess('Đồng bộ danh mục thành công - ${_khuVucs.length} khu vực, ${_tangToas.length} tầng tòa');
    } catch (e) {
      print('Error syncing categories: $e');
      _showError('Không thể đồng bộ danh mục: ${e.toString()}');
    } finally {
      setState(() {
        _isSyncingCategories = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _syncSpecificCategory(String category) async {
    try {
      switch (category) {
        case 'Khu vực':
          final response = await http.get(Uri.parse('$baseUrl/LichCNkhuVuc'));
          if (response.statusCode == 200) {
            await _dbHelper.clearLichCNkhuVucTable();
            final data = json.decode(response.body) as List;
            await _dbHelper.batchInsertLichCNkhuVucs(data.map((e) => LichCNkhuVucModel.fromMap(e)).toList());
            _khuVucs = await _dbHelper.getAllLichCNkhuVuc();
          }
          break;
        case 'Hạng mục':
          final response = await http.get(Uri.parse('$baseUrl/LichCNhangMuc'));
          if (response.statusCode == 200) {
            await _dbHelper.clearLichCNhangMucTable();
            final data = json.decode(response.body) as List;
            await _dbHelper.batchInsertLichCNhangMucs(data.map((e) => LichCNhangMucModel.fromMap(e)).toList());
            _hangMucs = await _dbHelper.getAllLichCNhangMuc();
          }
          break;
        case 'Kỹ thuật':
          final response = await http.get(Uri.parse('$baseUrl/LichCNkyThuat'));
          if (response.statusCode == 200) {
            await _dbHelper.clearLichCNkyThuatTable();
            final data = json.decode(response.body) as List;
            await _dbHelper.batchInsertLichCNkyThuats(data.map((e) => LichCNkyThuatModel.fromMap(e)).toList());
            _kyThuats = await _dbHelper.getAllLichCNkyThuat();
          }
          break;
        case 'Tính chất':
          final response = await http.get(Uri.parse('$baseUrl/LichCNtinhChat'));
          if (response.statusCode == 200) {
            await _dbHelper.clearLichCNtinhChatTable();
            final data = json.decode(response.body) as List;
            await _dbHelper.batchInsertLichCNtinhChats(data.map((e) => LichCNtinhChatModel.fromMap(e)).toList());
            _tinhChats = await _dbHelper.getAllLichCNtinhChat();
          }
          break;
        case 'Tầng tòa':
          final response = await http.get(Uri.parse('$baseUrl/LichCNtangToa'));
          if (response.statusCode == 200) {
            await _dbHelper.clearLichCNtangToaTable();
            final data = json.decode(response.body) as List;
            await _dbHelper.batchInsertLichCNtangToas(data.map((e) => LichCNtangToaModel.fromMap(e)).toList());
            _tangToas = await _dbHelper.getAllLichCNtangToa();
          }
          break;
      }
      setState(() {});
    } catch (e) {
      print('Error syncing $category: $e');
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

  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        khuVucs: _khuVucs,
        hangMucs: _hangMucs,
        kyThuats: _kyThuats,
        tinhChats: _tinhChats,
        tangToas: _tangToas,
        selectedProject: _selectedProject,
        defaultToa: _selectedToa,
        defaultTang: _selectedTang,
        baseUrl: baseUrl,
        onRefresh: (category) async {
          await _syncSpecificCategory(category);
        },
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
          SizedBox(width: 16),
          Row(
            children: [
              Container( width:450,
                child: DropdownButtonFormField<String>(
                  value: _selectedProject,
                  hint: Text('Chọn dự án'),
                  items: _filteredProjectNames.map((project) => DropdownMenuItem(value: project, child: Text(project, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedProject = value;
                        _updateToaAndTangSelections();
                      });
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
          Spacer(),
          if (!_isLoading && !_isSyncingCategories) ...[
            ElevatedButton.icon(
              onPressed: () => _syncTaskSchedules(),
              icon: Icon(Icons.schedule, size: 18),
              label: Text('Đồng bộ LLV'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600], foregroundColor: Colors.white, elevation: 2),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _syncSupportingData(),
              icon: Icon(Icons.category, size: 18),
              label: Text('Đồng bộ danh mục'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600], foregroundColor: Colors.white, elevation: 2),
            ),
          ],
          if (_isLoading || _isSyncingCategories)
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
          // Row(
          //   children: [
          //     Text('Chọn dự án', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          //     SizedBox(width: 12),
          //     Expanded(
          //       child: DropdownButtonFormField<String>(
          //         value: _selectedProject,
          //         hint: Text('Chọn dự án'),
          //         isExpanded: true,
          //         items: _filteredProjectNames.map((project) => DropdownMenuItem(value: project, child: Text(project, overflow: TextOverflow.ellipsis))).toList(),
          //         onChanged: (value) {
          //           if (value != null) {
          //             setState(() {
          //               _selectedProject = value;
          //               _updateToaAndTangSelections();
          //             });
          //             _computeProjectData(value);
          //           }
          //         },
          //         decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          //       ),
          //     ),
          //     SizedBox(width: 12),
          //     SizedBox(
          //       width: 200,
          //       child: TextField(
          //         controller: _searchController,
          //         decoration: InputDecoration(
          //           hintText: 'Tìm dự án',
          //           prefixIcon: Icon(Icons.search, size: 20),
          //           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          //           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
          // SizedBox(height: 12),
          Row(
            children: [
ElevatedButton.icon(
  onPressed: () => _showCategoryDialog(),
  icon: const Icon(Icons.category),
  label: const Text('Xem danh mục'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.cyan[600],
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
  ),
),
              if (_selectedProject != null) ...[
                SizedBox(width: 12),
                //Text('Tòa:', style: TextStyle(fontWeight: FontWeight.w500)),
                //SizedBox(width: 8),
                Container(
                  width: 150,
                                      decoration: BoxDecoration(
    color: Colors.teal[50],
    borderRadius: BorderRadius.circular(16),
  ),
                  child: DropdownButtonFormField<String>(
                    value: _getToaListForProject().contains(_selectedToa) ? _selectedToa : _getToaListForProject().first,
                    isExpanded: true,
                    items: _getToaListForProject().map((toa) => DropdownMenuItem(value: toa, child: Text(toa, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) => setState(() => _selectedToa = value),
                    decoration: InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                  ),
                ),
                SizedBox(width: 12),
                //Text('Tầng:', style: TextStyle(fontWeight: FontWeight.w500)),
                //SizedBox(width: 8),
                Container(
                  width: 150,
                    decoration: BoxDecoration(
    color: Colors.teal[50],
    borderRadius: BorderRadius.circular(16),
  ),
                  child: DropdownButtonFormField<String>(
                    value: _isUsingTangRange ? null : (_getTangListForProject().contains(_selectedTang) ? _selectedTang : _getTangListForProject().first),
                    isExpanded: true,
                    items: _getTangListForProject().map((tang) => DropdownMenuItem(value: tang, child: Text(tang, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) => setState(() {
                      _selectedTang = value;
                      _isUsingTangRange = false;
                      _tangRangeStart = null;
                      _tangRangeEnd = null;
                    }),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      hintText: _isUsingTangRange ? _selectedTang : null,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showTangRangeDialog,
                  icon: Icon(Icons.layers, size: 16),
                  label: Text('Từ tầng đến tầng'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    backgroundColor: _isUsingTangRange ? Colors.orange : Colors.grey[300],
                    foregroundColor: _isUsingTangRange ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_getTangListForProject().length} Tầng, ${_getToaListForProject().length} Tòa',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue[900]),
                      ),
                      if (_selectedProject != null && _cachedPositionTasks.containsKey(_selectedProject)) ...[
                        SizedBox(width: 6),
                        Text(
                          '${_getPositionsWithChiTiet()}/${_getPositionsCount()} vị trí có chi tiết',
                          style: TextStyle(fontSize: 12, color: Colors.green[700]),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${_getChiTietCompletionPercentage().toStringAsFixed(1)}% hoàn thành',
                          style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (_selectedProject != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Khu vực', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _khuVucs.any((e) => e.uid == _selectedKhuVuc) ? _selectedKhuVuc : null,
                        isExpanded: true,
                        items: _khuVucs.map((kv) => DropdownMenuItem(value: kv.uid, child: Text(kv.khuVuc ?? '', overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (value) => setState(() => _selectedKhuVuc = value),
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hạng mục (nhiều)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      SizedBox(height: 4),
                      InkWell(
                        onTap: () => _showMultiSelectDialog('Hạng mục', _hangMucs.map((e) => {'uid': e.uid, 'name': e.doiTuong ?? ''}).toList(), _selectedDoiTuong, (selected) => setState(() => _selectedDoiTuong = selected)),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Expanded(child: Text(_selectedDoiTuong.isEmpty ? 'Chọn hạng mục' : '${_selectedDoiTuong.length} mục', overflow: TextOverflow.ellipsis)),
                              Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kỹ thuật (nhiều)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      SizedBox(height: 4),
                      InkWell(
                        onTap: () => _showMultiSelectDialog('Kỹ thuật', _kyThuats.map((e) => {'uid': e.uid, 'name': e.congViec ?? ''}).toList(), _selectedCongViec, (selected) => setState(() => _selectedCongViec = selected)),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Expanded(child: Text(_selectedCongViec.isEmpty ? 'Chọn kỹ thuật' : '${_selectedCongViec.length} mục', overflow: TextOverflow.ellipsis)),
                              Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tính chất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _tinhChats.any((e) => e.uid == _selectedTinhChat) ? _selectedTinhChat : null,
                        isExpanded: true,
                        items: _tinhChats.map((tc) => DropdownMenuItem(value: tc.uid, child: Text(tc.tinhChat ?? '', overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (value) => setState(() => _selectedTinhChat = value),
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
    final detailFromChiTiet = _chiTiets.firstWhere((c) => c.lichId == task.taskId, orElse: () => LichCNchiTietModel(uid: ''));
    final hasDetail = detailFromChiTiet.uid.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: positionColor.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: positionColor.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                        if (hasDetail) ...[
                          SizedBox(width: 8),
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(task.task, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amberAccent[100], borderRadius: BorderRadius.circular(8)),
                    child: Text(_formatWeekdays(task.weekday), style: TextStyle(fontSize: 10, color: Colors.black)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasDetail)
                OutlinedButton.icon(
                  onPressed: () => _showDetailDialog(detailFromChiTiet),
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text('Chi tiết'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: BorderSide(color: Colors.blue)),
                ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showApplyDialog(task, hasDetail ? detailFromChiTiet : null),
                icon: Icon(Icons.save, size: 16),
                label: Text(hasDetail ? 'Cập nhật' : 'Áp dụng'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatWeeksList(String weeks) {
    if (weeks.trim().isEmpty) return '1, 2, 3, 4';
    return weeks.split(',').map((w) => w.trim()).join(', ');
  }

  String _formatMonthsList(String months) {
    if (months.trim().isEmpty) return '1-12';
    final monthList = months.split(',').map((m) => m.trim()).toList();
    if (monthList.length == 12) return '1-12';
    return monthList.join(', ');
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

  void _showMultiSelectDialog(String title, List<Map<String, String>> items, List<String> selectedUids, Function(List<String>) onChanged) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(selectedUids);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Chọn $title'),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    final crossAxisCount = isWide ? 3 : (constraints.maxWidth > 400 ? 2 : 1);
                    
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 3.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = tempSelected.contains(item['uid']);
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                tempSelected.remove(item['uid']);
                              } else {
                                tempSelected.add(item['uid']!);
                              }
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue[100] : Colors.grey[50],
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                  color: isSelected ? Colors.blue : Colors.grey,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['name'] ?? '',
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.blue[900] : Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    onChanged(tempSelected);
                    Navigator.pop(context);
                  },
                  child: Text('Xác nhận (${tempSelected.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTangRangeDialog() {
    final tangList = _getTangListForProject();
    String? startTang = tangList.isNotEmpty ? tangList.first : null;
    String? endTang = tangList.isNotEmpty ? tangList.first : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Chọn khoảng tầng'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: startTang,
                    decoration: InputDecoration(labelText: 'Từ tầng', border: OutlineInputBorder()),
                    items: tangList.map((tang) => DropdownMenuItem(value: tang, child: Text(tang))).toList(),
                    onChanged: (value) => setDialogState(() => startTang = value),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: endTang,
                    decoration: InputDecoration(labelText: 'Đến tầng', border: OutlineInputBorder()),
                    items: tangList.map((tang) => DropdownMenuItem(value: tang, child: Text(tang))).toList(),
                    onChanged: (value) => setDialogState(() => endTang = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isUsingTangRange = false;
                      _tangRangeStart = null;
                      _tangRangeEnd = null;
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (startTang != null && endTang != null) {
                      setState(() {
                        _isUsingTangRange = true;
                        _tangRangeStart = startTang;
                        _tangRangeEnd = endTang;
                        _selectedTang = 'Từ $startTang đến $endTang';
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDetailDialog(LichCNchiTietModel detail) {
    final khuVucNames = detail.khuVuc?.split(',').map((uid) => _khuVucs.firstWhere((e) => e.uid == uid.trim(), orElse: () => LichCNkhuVucModel(uid: '')).khuVuc ?? uid).join(', ') ?? '';
    final doiTuongNames = detail.doiTuong?.split(',').map((uid) => _hangMucs.firstWhere((e) => e.uid == uid.trim(), orElse: () => LichCNhangMucModel(uid: '')).doiTuong ?? uid).join(', ') ?? '';
    final congViecNames = detail.congViec?.split(',').map((uid) => _kyThuats.firstWhere((e) => e.uid == uid.trim(), orElse: () => LichCNkyThuatModel(uid: '')).congViec ?? uid).join(', ') ?? '';
    final tinhChatName = _tinhChats.firstWhere((e) => e.uid == detail.tinhChat, orElse: () => LichCNtinhChatModel(uid: '')).tinhChat ?? detail.tinhChat ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết lịch'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Người dùng', detail.nguoiDung ?? ''),
              _buildDetailRow('Ngày', detail.ngay ?? ''),
              _buildDetailRow('Giờ', detail.gio ?? ''),
              _buildDetailRow('Bộ phận', detail.boPhan ?? ''),
              _buildDetailRow('Vị trí', detail.viTri ?? ''),
              _buildDetailRow('Tháp', detail.thap ?? ''),
              _buildDetailRow('Tầng', detail.tang ?? ''),
              _buildDetailRow('Số phút', detail.soPhut?.toString() ?? ''),
              _buildDetailRow('Khu vực', khuVucNames),
              _buildDetailRow('Hạng mục', doiTuongNames),
              _buildDetailRow('Kỹ thuật', congViecNames),
              _buildDetailRow('Tính chất', tinhChatName),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showApplyDialog(TaskScheduleModel task, LichCNchiTietModel? existingDetail) {
    final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, _qrLookups);
    final positionName = userMapping['positionName'] ?? '';
    
    int soPhut = 1;
    try {
      final startParts = task.start.split(':');
      final endParts = task.end.split(':');
      if (startParts.length >= 2 && endParts.length >= 2) {
        final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        soPhut = (endMinutes - startMinutes).abs();
        if (soPhut == 0) soPhut = 1;
      }
    } catch (e) {
      soPhut = 1;
    }
    
    final now = DateTime.now();
    final ngay = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final gio = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final khuVucName = _khuVucs.firstWhere((e) => e.uid == _selectedKhuVuc, orElse: () => LichCNkhuVucModel(uid: '')).khuVuc ?? '';
    final doiTuongNames = _selectedDoiTuong.map((uid) => _hangMucs.firstWhere((e) => e.uid == uid, orElse: () => LichCNhangMucModel(uid: '')).doiTuong ?? '').join(', ');
    final congViecNames = _selectedCongViec.map((uid) => _kyThuats.firstWhere((e) => e.uid == uid, orElse: () => LichCNkyThuatModel(uid: '')).congViec ?? '').join(', ');
    final tinhChatName = _tinhChats.firstWhere((e) => e.uid == _selectedTinhChat, orElse: () => LichCNtinhChatModel(uid: '')).tinhChat ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingDetail != null ? 'Cập nhật chi tiết' : 'Áp dụng chi tiết'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Xác nhận thông tin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 12),
              _buildDetailRow('Người dùng', widget.username),
              _buildDetailRow('Ngày', ngay),
              _buildDetailRow('Giờ', gio),
              _buildDetailRow('Bộ phận', _selectedProject ?? ''),
              _buildDetailRow('Vị trí', positionName),
              _buildDetailRow('Tháp', _selectedToa ?? ''),
              _buildDetailRow('Tầng', _isUsingTangRange ? 'Từ $_tangRangeStart đến $_tangRangeEnd' : (_selectedTang ?? '')),
              _buildDetailRow('Số phút', soPhut.toString()),
              _buildDetailRow('Khu vực', khuVucName),
              _buildDetailRow('Hạng mục', doiTuongNames),
              _buildDetailRow('Kỹ thuật', congViecNames),
              _buildDetailRow('Tính chất', tinhChatName),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _submitLichChiTiet(task, existingDetail, positionName, soPhut, ngay, gio);
            },
            child: Text('Gửi'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLichChiTiet(TaskScheduleModel task, LichCNchiTietModel? existingDetail, String positionName, int soPhut, String ngay, String gio) async {
    try {
      final uuid = Uuid();
      final data = {
        'uid': existingDetail?.uid ?? uuid.v4(),
        'nguoiDung': widget.username,
        'ngay': ngay,
        'gio': gio,
        'lichId': task.taskId,
        'boPhan': _selectedProject,
        'viTri': positionName,
        'thap': _selectedToa,
        'tang': _isUsingTangRange ? 'Từ $_tangRangeStart đến $_tangRangeEnd' : _selectedTang,
        'soPhut': soPhut,
        'khuVuc': _selectedKhuVuc,
        'doiTuong': _selectedDoiTuong.join(','),
        'congViec': _selectedCongViec.join(','),
        'tinhChat': _selectedTinhChat,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/LichCNchiTietthemmoi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          if (_selectedDoiTuong.isNotEmpty) {
            _selectedDoiTuong = [_selectedDoiTuong.first];
          }
          if (_selectedCongViec.isNotEmpty) {
            _selectedCongViec = [_selectedCongViec.first];
          }
          _isUsingTangRange = false;
          _tangRangeStart = null;
          _tangRangeEnd = null;
          if (_getTangListForProject().isNotEmpty) {
            _selectedTang = _getTangListForProject().first;
          }
        });
        _showSuccess('${existingDetail != null ? 'Cập nhật' : 'Gửi'} thành công! Vui lòng đồng bộ sau 5-15 phút.');
        await Future.delayed(Duration(seconds: 2));
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Lỗi: ${e.toString()}');
    }
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

class _CategoryDialog extends StatefulWidget {
  final List<LichCNkhuVucModel> khuVucs;
  final List<LichCNhangMucModel> hangMucs;
  final List<LichCNkyThuatModel> kyThuats;
  final List<LichCNtinhChatModel> tinhChats;
  final List<LichCNtangToaModel> tangToas;
  final String? selectedProject;
  final String? defaultToa;
  final String? defaultTang;
  final String baseUrl;
  final Function(String) onRefresh;

  const _CategoryDialog({
    required this.khuVucs,
    required this.hangMucs,
    required this.kyThuats,
    required this.tinhChats,
    required this.tangToas,
    this.selectedProject,
    this.defaultToa,
    this.defaultTang,
    required this.baseUrl,
    required this.onRefresh,
  });

  @override
  _CategoryDialogState createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.selectedProject != null ? 4 : 0;
    _tabController = TabController(length: widget.selectedProject != null ? 5 : 4, vsync: this, initialIndex: initialIndex);
    _selectedTabIndex = initialIndex;
    _tabController.addListener(() {
      setState(() => _selectedTabIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    final categories = widget.selectedProject != null
        ? ['Tầng tòa', 'Khu vực', 'Hạng mục', 'Kỹ thuật', 'Tính chất']
        : ['Khu vực', 'Hạng mục', 'Kỹ thuật', 'Tính chất'];
    showDialog(
      context: context,
      builder: (context) => _AddCategoryItemDialog(
        category: categories[_selectedTabIndex],
        baseUrl: widget.baseUrl,
        selectedProject: widget.selectedProject,
        defaultToa: widget.defaultToa,
        defaultTang: widget.defaultTang,
        onSuccess: () async {
          await widget.onRefresh(categories[_selectedTabIndex]);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã thêm thành công'), backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo[600],
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Text('Danh mục', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: Icon(Icons.add, size: 16),
                    label: Text('Thêm'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                  SizedBox(width: 8),
                  IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: Colors.indigo[900],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.indigo[600],
              isScrollable: true,
              tabs: widget.selectedProject != null
                  ? [
                      Tab(text: 'Tầng tòa'),
                      Tab(text: 'Khu vực'),
                      Tab(text: 'Hạng mục'),
                      Tab(text: 'Kỹ thuật'),
                      Tab(text: 'Tính chất'),
                    ]
                  : [
                      Tab(text: 'Khu vực'),
                      Tab(text: 'Hạng mục'),
                      Tab(text: 'Kỹ thuật'),
                      Tab(text: 'Tính chất'),
                    ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: widget.selectedProject != null
                    ? [
                        _buildTangToaView(),
                        _buildGridView(widget.khuVucs.map((e) => e.khuVuc ?? '').where((s) => s.isNotEmpty).toList(), Colors.blue),
                        _buildGridView(widget.hangMucs.map((e) => e.doiTuong ?? '').where((s) => s.isNotEmpty).toList(), Colors.green),
                        _buildGridView(widget.kyThuats.map((e) => e.congViec ?? '').where((s) => s.isNotEmpty).toList(), Colors.orange),
                        _buildGridView(widget.tinhChats.map((e) => e.tinhChat ?? '').where((s) => s.isNotEmpty).toList(), Colors.purple),
                      ]
                    : [
                        _buildGridView(widget.khuVucs.map((e) => e.khuVuc ?? '').where((s) => s.isNotEmpty).toList(), Colors.blue),
                        _buildGridView(widget.hangMucs.map((e) => e.doiTuong ?? '').where((s) => s.isNotEmpty).toList(), Colors.green),
                        _buildGridView(widget.kyThuats.map((e) => e.congViec ?? '').where((s) => s.isNotEmpty).toList(), Colors.orange),
                        _buildGridView(widget.tinhChats.map((e) => e.tinhChat ?? '').where((s) => s.isNotEmpty).toList(), Colors.purple),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<String> items, Color color) {
    if (items.isEmpty) return Center(child: Text('Không có dữ liệu'));

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth / 200).floor().clamp(1, 5);
        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => Card(
            color: color.withOpacity(0.1),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(items[index], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTangToaView() {
    final filtered = widget.tangToas.where((e) => e.boPhan == widget.selectedProject).toList();
    if (filtered.isEmpty) return Center(child: Text('Không có dữ liệu'));

    final tangItems = filtered.where((e) => e.phanLoai?.toLowerCase() == 'tầng' || e.phanLoai?.toLowerCase() == 'tang').toList();
    final toaItems = filtered.where((e) => e.phanLoai?.toLowerCase() == 'tòa' || e.phanLoai?.toLowerCase() == 'toa').toList();

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                color: Colors.red[100],
                child: Text('Tầng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[900])),
              ),
              Expanded(
                child: tangItems.isEmpty
                    ? Center(child: Text('Không có dữ liệu'))
                    : ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: tangItems.length,
                        itemBuilder: (context, index) => Card(
                          color: Colors.red[50],
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(tangItems[index].tenGoi ?? '', style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                color: Colors.pink[100],
                child: Text('Tòa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.pink[900])),
              ),
              Expanded(
                child: toaItems.isEmpty
                    ? Center(child: Text('Không có dữ liệu'))
                    : ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: toaItems.length,
                        itemBuilder: (context, index) => Card(
                          color: Colors.pink[50],
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(toaItems[index].tenGoi ?? '', style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddCategoryItemDialog extends StatefulWidget {
  final String category;
  final String baseUrl;
  final String? selectedProject;
  final String? defaultToa;
  final String? defaultTang;
  final VoidCallback onSuccess;

  const _AddCategoryItemDialog({
    required this.category,
    required this.baseUrl,
    this.selectedProject,
    this.defaultToa,
    this.defaultTang,
    required this.onSuccess,
  });

  @override
  _AddCategoryItemDialogState createState() => _AddCategoryItemDialogState();
}

class _AddCategoryItemDialogState extends State<_AddCategoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _tenGoiController = TextEditingController();
  String _phanLoai = 'Tầng';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.category == 'Tầng tòa') {
      _tenGoiController.text = widget.defaultTang ?? 'Tầng 1';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _tenGoiController.dispose();
    super.dispose();
  }

  void _onPhanLoaiChanged(String? value) {
    if (value == null) return;
    setState(() {
      _phanLoai = value;
      if (_phanLoai == 'Tầng') {
        _tenGoiController.text = widget.defaultTang ?? 'Tầng 1';
      } else {
        _tenGoiController.text = widget.defaultToa ?? 'Toà chính';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận'),
        content: Text('⚠️ CẢNH BÁO: Danh mục này sẽ được chia sẻ với mọi người. Vui lòng đảm bảo rằng bạn chắc chắn về nội dung trước khi thêm.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Xác nhận'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final uuid = Uuid();
      Map<String, dynamic> data;
      String endpoint;

      switch (widget.category) {
        case 'Khu vực':
          endpoint = '${widget.baseUrl}/LichCNkhuVucthemmoi';
          data = {'uid': uuid.v4(), 'khuVuc': _textController.text.trim()};
          break;
        case 'Hạng mục':
          endpoint = '${widget.baseUrl}/LichCNhangMucthemmoi';
          data = {'uid': uuid.v4(), 'doiTuong': _textController.text.trim()};
          break;
        case 'Kỹ thuật':
          endpoint = '${widget.baseUrl}/LichCNkyThuatthemmoi';
          data = {'uid': uuid.v4(), 'congViec': _textController.text.trim()};
          break;
        case 'Tính chất':
          endpoint = '${widget.baseUrl}/LichCNtinhChatthemmoi';
          data = {'uid': uuid.v4(), 'tinhChat': _textController.text.trim()};
          break;
        case 'Tầng tòa':
          endpoint = '${widget.baseUrl}/LichCNtangToathemmoi';
          data = {'uid': uuid.v4(), 'boPhan': widget.selectedProject, 'tenGoi': _tenGoiController.text.trim(), 'phanLoai': _phanLoai};
          break;
        default:
          throw Exception('Invalid category');
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSuccess();
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Thêm ${widget.category}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.category == 'Tầng tòa') ...[
                DropdownButtonFormField<String>(
                  value: _phanLoai,
                  decoration: InputDecoration(labelText: 'Phân loại', border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'Tầng', child: Text('Tầng')),
                    DropdownMenuItem(value: 'Tòa', child: Text('Tòa')),
                  ],
                  onChanged: _onPhanLoaiChanged,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _tenGoiController,
                  decoration: InputDecoration(labelText: 'Tên gọi', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên gọi' : null,
                ),
              ] else ...[
                TextFormField(
                  controller: _textController,
                  decoration: InputDecoration(labelText: widget.category, border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập ${widget.category.toLowerCase()}' : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.pop(context), child: Text('Hủy')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Thêm'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}