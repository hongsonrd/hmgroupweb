// projectmanagementllv.dart
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; 
import 'package:path/path.dart' as path;
class LichLamViecModel {
  final String taskid;
  final String duan;
  final String vitri;
  final String weekday;
  final String? start;    // Time values
  final String? end;      // Time values
  final String? tuan;     // Text
  final String? thang;    // Text
  final String? ngaybc;   // Text
  final String? task;     // Text
  final String? username; // Text

  LichLamViecModel({
    required this.taskid,
    required this.duan,
    required this.vitri,
    required this.weekday,
    this.start,
    this.end,
    this.tuan,
    this.thang,
    this.ngaybc,
    this.task,
    this.username,
  });

  factory LichLamViecModel.fromMap(Map<String, dynamic> map) {
    return LichLamViecModel(
      taskid: map['TASKID']?.toString() ?? '',
      duan: map['DUAN']?.toString() ?? '',
      vitri: map['VITRI']?.toString() ?? '',
      weekday: map['WEEKDAY']?.toString() ?? '',
      start: map['START']?.toString(),
      end: map['END']?.toString(),
      tuan: map['TUAN']?.toString(),
      thang: map['THANG']?.toString(),
      ngaybc: map['NGAYBC']?.toString(),
      task: map['TASK']?.toString(),
      username: map['username']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'TASKID': taskid,
      'DUAN': duan,
      'VITRI': vitri,
      'WEEKDAY': weekday,
      'START': start,
      'END': end,
      'TUAN': tuan,
      'THANG': thang,
      'NGAYBC': ngaybc,
      'TASK': task,
      'username': username,
    };
  }
}

class LichLamViecManager {
  static const String _tableName = 'lich_lam_viec';
  static const String _dbName = 'lich_lam_viec.db';
  static const int _dbVersion = 1;
  static Database? _database;

  // Get database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

// Initialize database
static Future<Database> _initDatabase() async {
  String dbPath = path.join(await getDatabasesPath(), _dbName); 
  return await openDatabase(
    dbPath,
    version: _dbVersion,
    onCreate: _onCreate,
  );
}

  // Create table
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        TASKID TEXT PRIMARY KEY,
        DUAN TEXT,
        VITRI TEXT,
        WEEKDAY TEXT,
        START TEXT,
        END TEXT,
        TUAN TEXT,
        THANG TEXT,
        NGAYBC TEXT,
        TASK TEXT,
        username TEXT
      )
    ''');
  }

  // Check if should sync (cooldown mechanism)
  static Future<bool> shouldSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('lastLichLamViecSync');
      
      if (lastSyncStr == null) {
        return true; // First sync
      }
      
      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();
      final daysSinceLastSync = now.difference(lastSync).inDays;
      
      return daysSinceLastSync >= 2; // Sync every 2-3 days
    } catch (e) {
      print('Error checking LichLamViec sync cooldown: $e');
      return true; // Default to sync if error
    }
  }

  // Mark sync as complete
  static Future<void> _markSyncComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastLichLamViecSync', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error marking LichLamViec sync complete: $e');
    }
  }

  // Clear all data
  static Future<void> clearData() async {
    final db = await database;
    await db.delete(_tableName);
  }

  // Insert batch data
  static Future<void> insertBatch(List<LichLamViecModel> items) async {
    final db = await database;
    final batch = db.batch();
    
    for (final item in items) {
      batch.insert(
        _tableName,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  // Query data
  static Future<List<Map<String, dynamic>>> query({
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.query(
      _tableName,
      where: where,
      whereArgs: whereArgs,
    );
  }

  // Main sync function
  static Future<bool> syncData(String username) async {
    try {
      print('Starting LichLamViec sync for user: $username');
      
      final response = await http.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/lichcnmay/hm.tason'),
      );

      print('LichLamViec API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('LichLamViec data received: ${data.length} records');
        
        // Clear existing data
        await clearData();
        
        // Convert and insert new data
        final lichLamViecModels = data.map((item) => 
          LichLamViecModel.fromMap(item as Map<String, dynamic>)
        ).toList();

        await insertBatch(lichLamViecModels);
        
        // Mark sync as complete
        await _markSyncComplete();
        
        print('LichLamViec sync completed successfully');
        return true;
      } else {
        print('LichLamViec API failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error syncing LichLamViec: $e');
      return false;
    }
  }

  // Get records for a specific project and position
  static Future<List<LichLamViecModel>> getScheduleForPosition(String duan, String vitri) async {
    try {
      final data = await query(
        where: 'DUAN = ? AND VITRI = ?',
        whereArgs: [duan, vitri],
      );
      
      return data.map((map) => LichLamViecModel.fromMap(map)).toList();
    } catch (e) {
      print('Error getting schedule for position: $e');
      return [];
    }
  }

  // Get all records for a project
  static Future<List<LichLamViecModel>> getScheduleForProject(String duan) async {
    try {
      final data = await query(
        where: 'DUAN = ?',
        whereArgs: [duan],
      );
      
      return data.map((map) => LichLamViecModel.fromMap(map)).toList();
    } catch (e) {
      print('Error getting schedule for project: $e');
      return [];
    }
  }
}

// LLV Máy viewing screen
class LLVMayScreen extends StatefulWidget {
  final String boPhan;
  final String username;

  const LLVMayScreen({
    required this.boPhan,
    required this.username,
  });

  @override
  _LLVMayScreenState createState() => _LLVMayScreenState();
}

class _LLVMayScreenState extends State<LLVMayScreen> {
  List<LichLamViecModel> _allTasks = [];
  List<LichLamViecModel> _filteredTasks = [];
  bool _isLoading = true;
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _loadLLVData();
  }

  Future<void> _loadLLVData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to get data for current project
      final projectTasks = await LichLamViecManager.getScheduleForProject(widget.boPhan);
      
      // If no data for current project, get all data to see what's available
      if (projectTasks.isEmpty) {
        final allData = await LichLamViecManager.query();
        _allTasks = allData.map((map) => LichLamViecModel.fromMap(map)).toList();
      } else {
        _allTasks = projectTasks;
      }
      
      _filteredTasks = List.from(_allTasks);
      
    } catch (e) {
      print('Error loading LLV data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải dữ liệu LLV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forceSyncLLV() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await LichLamViecManager.syncData(widget.username);
      if (success) {
        await _loadLLVData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đồng bộ LLV thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Sync failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ LLV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterTasks(String query) {
    setState(() {
      _filterText = query;
      if (query.isEmpty) {
        _filteredTasks = List.from(_allTasks);
      } else {
        _filteredTasks = _allTasks.where((task) {
          return task.duan.toLowerCase().contains(query.toLowerCase()) ||
                 task.vitri.toLowerCase().contains(query.toLowerCase()) ||
                 (task.task?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LLV Máy - ${widget.boPhan}'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 114, 255, 175),
                Color.fromARGB(255, 201, 255, 225),
                Color.fromARGB(255, 79, 255, 249),
                Color.fromARGB(255, 188, 255, 248),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: _isLoading ? null : _forceSyncLLV,
            tooltip: 'Đồng bộ ngay',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats and filter
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng số: ${_allTasks.length} | Hiển thị: ${_filteredTasks.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm (dự án, vị trí, công việc)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _filterTasks,
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color.fromARGB(255, 0, 204, 34),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Đang tải dữ liệu LLV...'),
                    ],
                  ),
                )
              : _filteredTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _allTasks.isEmpty 
                            ? 'Không có dữ liệu LLV\nThử nhấn nút đồng bộ ở trên'
                            : 'Không tìm thấy kết quả',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_allTasks.isEmpty) ...[
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: Icon(Icons.sync),
                            label: Text('Đồng bộ ngay'),
                            onPressed: _forceSyncLLV,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = _filteredTasks[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            task.task ?? 'Không có tên công việc',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dự án: ${task.duan}'),
                              Text('Vị trí: ${task.vitri}'),
                              Text('Thời gian: ${task.start ?? ''} - ${task.end ?? ''}'),
                              Text('Ngày: ${task.weekday}'),
                              if (task.tuan != null) Text('Tuần: ${task.tuan}'),
                              if (task.thang != null) Text('Tháng: ${task.thang}'),
                              if (task.ngaybc != null) Text('Ngày BC: ${task.ngaybc}'),
                            ],
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: task.duan == widget.boPhan 
                                ? Color.fromARGB(255, 0, 204, 34)
                                : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.schedule,
                              color: Colors.white,
                              size: 20,
            ),
                          ),
                          trailing: task.duan == widget.boPhan
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}