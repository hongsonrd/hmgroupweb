import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'http_client.dart'; 
import 'db_helper.dart'; 
import 'table_models.dart'; 
import 'map_floor.dart'; 
import 'map_report.dart'; 
import 'package:cached_network_image/cached_network_image.dart';

class MapProjectScreen extends StatefulWidget {
  final String username;
  
  const MapProjectScreen({Key? key, required this.username}) : super(key: key);

  @override
  _MapProjectScreenState createState() => _MapProjectScreenState();
}

class _MapProjectScreenState extends State<MapProjectScreen> {
  final DBHelper dbHelper = DBHelper();
  final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  String _syncStatus = '';
  bool _isSyncing = false;
  
  String? selectedMapUID;
  
  @override
  void initState() {
    super.initState();
    _checkAndSync();
  }

  Future<void> _checkAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncDate = prefs.getString('last_map_sync_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastSyncDate != today) {
      _syncData();
    }
  }
  
  Future<void> _syncData() async {
  if (_isSyncing) return;
  setState(() {
    _isSyncing = true;
    _syncStatus = 'Đang đồng bộ dữ liệu...';
  });
  try {
    // Step 1: Sync project list
    await _syncProjectList();
    // Step 2: Sync map list
    await _syncMapList();
    // Step 3: Sync map floors
    await _syncMapFloors();
    // Step 4: Sync map zones
    await _syncMapZones();
    // Step 5: Sync map staff
    await _syncMapStaff();
    // Step 6: Sync map positions
    await _syncMapPositions();
    // Step 7: Sync map reports
    //await _syncMapReports();
    // Save last sync date
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('last_map_sync_date', today);
    setState(() {
      _syncStatus = 'Đồng bộ hoàn tất';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đồng bộ dữ liệu bản đồ thành công')),
    );
  } catch (e) {
    setState(() {
      _syncStatus = 'Lỗi đồng bộ: $e';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi đồng bộ dữ liệu: $e')),
    );
  } finally {
    setState(() {
      _isSyncing = false;
    });
  }
}
  Future<void> _syncMapStaff() async {
  setState(() => _syncStatus = 'Đang lấy danh sách nhân viên bản đồ...');
  final mapStaffResponse = await AuthenticatedHttpClient.get(
    Uri.parse('$baseUrl/mapstaff')
  );
  if (mapStaffResponse.statusCode != 200) {
    throw Exception('Failed to load map staff: ${mapStaffResponse.statusCode}');
  }
  final String responseText = mapStaffResponse.body;
  final List<dynamic> mapStaffData = json.decode(responseText);
  await dbHelper.clearTable(DatabaseTables.mapStaffTable);
  final List<MapStaffModel> mapStaffs = [];
  for (var staff in mapStaffData) {
    try {
      final model = MapStaffModel(
        uid: staff['UID'] ?? '',
        mapProject: staff['MapProject'] ?? '',
        nguoiDung: staff['NguoiDung'] ?? '',
        hoTen: staff['HoTen'] ?? '',
        vaiTro: staff['VaiTro'] ?? '',
      );
      mapStaffs.add(model);
    } catch (e) {
      print('Error creating map staff model: $e');
      print('Problematic data: $staff');
      throw e;
    }
  }
  await _batchInsertMapStaff(mapStaffs);
}
Future<void> _syncMapPositions() async {
  setState(() => _syncStatus = 'Đang lấy danh sách vị trí bản đồ...');
  final mapPositionResponse = await AuthenticatedHttpClient.get(
    Uri.parse('$baseUrl/mapposition')
  );
  if (mapPositionResponse.statusCode != 200) {
    throw Exception('Failed to load map positions: ${mapPositionResponse.statusCode}');
  }
  final String responseText = mapPositionResponse.body;
  final List<dynamic> mapPositionData = json.decode(responseText);
  await dbHelper.clearTable(DatabaseTables.mapPositionTable);

  final List<MapPositionModel> mapPositions = [];
  for (var position in mapPositionData) {
    try {
      final model = MapPositionModel(
        uid: position['UID'] ?? '',
        mapList: position['MapList'] ?? '',
        mapFloor: position['MapFloor'] ?? '',
        mapZone: position['MapZone'] ?? '',
        viTri: position['ViTri'] ?? '',
      );
      mapPositions.add(model);
    } catch (e) {
      print('Error creating map position model: $e');
      print('Problematic data: $position');
      throw e;
    }
  }
  await _batchInsertMapPosition(mapPositions);
}
Future<void> _batchInsertMapPosition(List<MapPositionModel> mapPositions) async {
  final db = await dbHelper.database;
  final batch = db.batch();
  for (var position in mapPositions) {
    batch.insert(DatabaseTables.mapPositionTable, position.toMap());
  }
  await batch.commit(noResult: true);
}

Future<void> _batchInsertMapStaff(List<MapStaffModel> mapStaffs) async {
  final db = await dbHelper.database;
  final batch = db.batch();
  for (var staff in mapStaffs) {
    batch.insert(DatabaseTables.mapStaffTable, staff.toMap());
  }
  await batch.commit(noResult: true);
}
Future<void> _syncMapReports() async {
  setState(() => _syncStatus = 'Đang lấy báo cáo bản đồ...');
  final mapReportResponse = await AuthenticatedHttpClient.get(
    Uri.parse('$baseUrl/mapreport')
  );
  
  if (mapReportResponse.statusCode != 200) {
    throw Exception('Failed to load map reports: ${mapReportResponse.statusCode}');
  }

  final String responseText = mapReportResponse.body;
  final List<dynamic> mapReportData = json.decode(responseText);
  
  // Extract all UIDs from the incoming data
  final List<String> incomingUIDs = [];
  for (var report in mapReportData) {
    if (report['UID'] != null) {
      incomingUIDs.add(report['UID'].toString());
    }
  }
  
  // Delete any existing records with UIDs that match the incoming data
  if (incomingUIDs.isNotEmpty) {
    final db = await dbHelper.database;
    final placeholders = incomingUIDs.map((_) => '?').join(',');
    await db.execute(
      'DELETE FROM ${DatabaseTables.taskHistoryTable} WHERE UID IN ($placeholders)',
      incomingUIDs
    );
  }
  
  // Create TaskHistory models from map report data
  final List<Map<String, dynamic>> taskHistories = [];
  final Set<String> processedUIDs = {}; // Track UIDs we've seen to avoid duplicates
  
  for (var report in mapReportData) {
    try {
      final String uid = report['UID']?.toString() ?? '';
      
      // Skip if we've already processed this UID or if it's empty
      if (uid.isEmpty || processedUIDs.contains(uid)) continue;
      processedUIDs.add(uid);
      
      final Map<String, dynamic> taskMap = {
        'UID': uid,
        'NguoiDung': report['NguoiDung'] ?? '',
        'TaskID': report['TaskID'] ?? '',
        'KetQua': report['KetQua'] ?? '',
        'Ngay': report['Ngay'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'Gio': report['Gio'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
        'ChiTiet': report['ChiTiet'] ?? '',
        'ChiTiet2': report['ChiTiet2'] ?? '',
        'ViTri': report['ViTri'] ?? '',
        'BoPhan': report['BoPhan'] ?? '',
        'PhanLoai': report['PhanLoai'] ?? 'map_report',
        'HinhAnh': report['HinhAnh'] ?? '',
        'GiaiPhap': report['GiaiPhap'] ?? '',
      };
      taskHistories.add(taskMap);
    } catch (e) {
      print('Error creating task history from map report: $e');
      print('Problematic data: $report');
    }
  }

  // Batch insert task histories
  if (taskHistories.isNotEmpty) {
    await _batchInsertTaskHistory(taskHistories);
  }
}

Future<void> _batchInsertTaskHistory(List<Map<String, dynamic>> taskHistories) async {
  final batch = await dbHelper.database.then((db) => db.batch());
  for (var taskHistory in taskHistories) {
    batch.insert(DatabaseTables.taskHistoryTable, taskHistory);
  }
  await batch.commit(noResult: true);
}
  Future<void> _syncProjectList() async {
    setState(() => _syncStatus = 'Đang lấy danh sách dự án...');
    final projectResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/projectlist/${widget.username}')
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
  }
  
  Future<void> _syncMapList() async {
    setState(() => _syncStatus = 'Đang lấy danh sách bản đồ...');
    final mapListResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/maplist')
    );
    
    if (mapListResponse.statusCode != 200) {
      throw Exception('Failed to load map list: ${mapListResponse.statusCode}');
    }

    final String responseText = mapListResponse.body;
    final List<dynamic> mapListData = json.decode(responseText);
    
    await dbHelper.clearTable(DatabaseTables.mapListTable);
    
    final List<MapListModel> mapLists = [];
    for (var map in mapListData) {
      try {
        final model = MapListModel(
          mapUID: map['mapUID'] ?? '',
          nguoiDung: map['nguoiDung'] ?? '',
          boPhan: map['boPhan'] ?? '',
          tenBanDo: map['tenBanDo'] ?? '',
          hinhAnhBanDo: map['hinhAnhBanDo'] ?? '',
          chieuDaiMet: map['chieuDaiMet'] != null ? double.tryParse(map['chieuDaiMet'].toString()) : null,
          chieuCaoMet: map['chieuCaoMet'] != null ? double.tryParse(map['chieuCaoMet'].toString()) : null,
        );
        mapLists.add(model);
      } catch (e) {
        print('Error creating map list model: $e');
        print('Problematic data: $map');
        throw e;
      }
    }

    await _batchInsertMapList(mapLists);
  }
  
  Future<void> _syncMapFloors() async {
    setState(() => _syncStatus = 'Đang lấy danh sách tầng...');
    final mapFloorResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/mapfloor')
    );
    
    if (mapFloorResponse.statusCode != 200) {
      throw Exception('Failed to load map floors: ${mapFloorResponse.statusCode}');
    }

    final String responseText = mapFloorResponse.body;
    final List<dynamic> mapFloorData = json.decode(responseText);
    
    await dbHelper.clearTable(DatabaseTables.mapFloorTable);
    
    final List<MapFloorModel> mapFloors = [];
    for (var floor in mapFloorData) {
      try {
        final model = MapFloorModel(
          floorUID: floor['floorUID'] ?? '',
          mapUID: floor['mapUID'] ?? '',
          tenTang: floor['tenTang'] ?? '',
          hinhAnhTang: floor['hinhAnhTang'] ?? '',
          chieuDaiMet: floor['chieuDaiMet'] != null ? double.tryParse(floor['chieuDaiMet'].toString()) : null,
          chieuCaoMet: floor['chieuCaoMet'] != null ? double.tryParse(floor['chieuCaoMet'].toString()) : null,
          offsetX: floor['offsetX'] != null ? double.tryParse(floor['offsetX'].toString()) : null,
          offsetY: floor['offsetY'] != null ? double.tryParse(floor['offsetY'].toString()) : null,
        );
        mapFloors.add(model);
      } catch (e) {
        print('Error creating map floor model: $e');
        print('Problematic data: $floor');
        throw e;
      }
    }

    await _batchInsertMapFloor(mapFloors);
  }
  
  Future<void> _syncMapZones() async {
    setState(() => _syncStatus = 'Đang lấy danh sách khu vực...');
    final mapZoneResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/mapzone')
    );
    
    if (mapZoneResponse.statusCode != 200) {
      throw Exception('Failed to load map zones: ${mapZoneResponse.statusCode}');
    }

    final String responseText = mapZoneResponse.body;
    final List<dynamic> mapZoneData = json.decode(responseText);
    
    await dbHelper.clearTable(DatabaseTables.mapZoneTable);
    
    final List<MapZoneModel> mapZones = [];
    for (var zone in mapZoneData) {
      try {
        final model = MapZoneModel(
          zoneUID: zone['zoneUID'] ?? '',
          floorUID: zone['floorUID'] ?? '',
          tenKhuVuc: zone['tenKhuVuc'] ?? '',
          cacDiemMoc: zone['cacDiemMoc'] ?? '',
          mauSac: zone['mauSac'] ?? '',
        );
        mapZones.add(model);
      } catch (e) {
        print('Error creating map zone model: $e');
        print('Problematic data: $zone');
        throw e;
      }
    }

    await _batchInsertMapZone(mapZones);
  }
  
  // Batch insert methods
  Future<void> _batchInsertMapList(List<MapListModel> mapLists) async {
    final batch = await dbHelper.database.then((db) => db.batch());
    for (var mapList in mapLists) {
      batch.insert(DatabaseTables.mapListTable, mapList.toMap());
    }
    await batch.commit(noResult: true);
  }
  
  Future<void> _batchInsertMapFloor(List<MapFloorModel> mapFloors) async {
    final batch = await dbHelper.database.then((db) => db.batch());
    for (var mapFloor in mapFloors) {
      batch.insert(DatabaseTables.mapFloorTable, mapFloor.toMap());
    }
    await batch.commit(noResult: true);
  }
  
  Future<void> _batchInsertMapZone(List<MapZoneModel> mapZones) async {
    final batch = await dbHelper.database.then((db) => db.batch());
    for (var mapZone in mapZones) {
      batch.insert(DatabaseTables.mapZoneTable, mapZone.toMap());
    }
    await batch.commit(noResult: true);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text('Bản đồ dự án'),
  actions: [
    IconButton(
      icon: _isSyncing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(Icons.sync),
      tooltip: 'Đồng bộ dữ liệu bản đồ',
      onPressed: _isSyncing ? null : _syncData,
    ),
  ],
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.greenAccent.shade400,Colors.green.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
),
      body: Column(
        children: [
          if (_syncStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_syncStatus, style: TextStyle(fontStyle: FontStyle.italic)),
            ),
          Expanded(
            child: FutureBuilder<List<MapListModel>>(
              future: dbHelper.getAllMapLists(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Không có dữ liệu bản đồ'));
                }
                
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final map = snapshot.data![index];
                    final isExpanded = selectedMapUID == map.mapUID;
                    
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.green.shade100, Colors.green.shade200],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(18),
  ),
  child: ListTile(
    title: Text(
      map.tenBanDo ?? 'Không có tên',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Text(map.boPhan ?? 'Không có bộ phận'),
    trailing: Icon(
      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
    ),
    onTap: () {
      setState(() {
        if (isExpanded) {
          selectedMapUID = null;
        } else {
          selectedMapUID = map.mapUID;
        }
      });
    },
  ),
),
                          // Map details
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person, size: 18, color: Colors.grey),
                                    SizedBox(width: 8),
                                    Text('Người tạo: ${map.nguoiDung ?? 'Không có thông tin'}'),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.straighten, size: 18, color: Colors.grey),
                                    SizedBox(width: 8),
                                    Text('Kích thước: ${map.chieuDaiMet ?? 0}m × ${map.chieuCaoMet ?? 0}m'),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.tag, size: 18, color: Colors.grey),
                                    SizedBox(width: 8),
                                    Text('Mã: ${map.mapUID ?? 'Không có mã'}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Preview of map image
                          if (map.hinhAnhBanDo != null && map.hinhAnhBanDo!.isNotEmpty)
                            Container(
                              height: 180,
                              width: double.infinity,
                              child: map.hinhAnhBanDo!.startsWith('http')
                                ? CachedNetworkImage(
  imageUrl: map.hinhAnhBanDo!,
  fit: BoxFit.contain,
  placeholder: (context, url) => Center(child: CircularProgressIndicator()),
  errorWidget: (context, url, error) => Icon(Icons.broken_image),
)
                                : Center(
                                    child: Text('Không thể hiển thị hình ảnh'),
                                  ),
                            ),
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Divider(),
                                  // Action buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
  ElevatedButton.icon(
    icon: Icon(Icons.bar_chart),
    label: Text('Xem báo cáo'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue, // Blue background
      foregroundColor: Colors.white, // White text/icon
    ),
    onPressed: () {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => MapReportScreen(
            mapUID: map.mapUID!,
            mapName: map.tenBanDo ?? 'Bản đồ',
          ),
        ),
      );
    },
  ),
  ElevatedButton.icon(
    icon: Icon(Icons.edit),
    label: Text('Sửa bản đồ'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red, // Red background
      foregroundColor: Colors.white, // White text/icon
    ),
    onPressed: () {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => MapFloorScreen(
            mapUID: map.mapUID!,
            mapName: map.tenBanDo ?? 'Bản đồ',
          ),
        ),
      );
    },
  ),
],

                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Floor list
                                  Text(
                                    'Danh sách tầng:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  
                                  // Display floors
                                  _buildFloorList(map.mapUID!),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFloorList(String mapUID) {
    return FutureBuilder<List<MapFloorModel>>(
      future: dbHelper.getMapFloorsByMapUID(mapUID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Text('Lỗi tải dữ liệu tầng: ${snapshot.error}');
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('Không có tầng nào');
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final floor = snapshot.data![index];
            return ExpansionTile(
              title: Text(floor.tenTang ?? 'Tầng không tên'),
              subtitle: Text('${floor.chieuDaiMet ?? 0}m x ${floor.chieuCaoMet ?? 0}m'),
              children: [
                _buildZoneList(floor.floorUID!)
              ],
            );
          },
        );
      },
    );
  }
  
  Widget _buildZoneList(String floorUID) {
    return FutureBuilder<List<MapZoneModel>>(
      future: dbHelper.getMapZonesByFloorUID(floorUID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Lỗi tải dữ liệu khu vực: ${snapshot.error}'),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Không có khu vực nào'),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final zone = snapshot.data![index];
              return ListTile(
                leading: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _parseColor(zone.mauSac),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(zone.tenKhuVuc ?? 'Khu vực không tên'),
                dense: true,
              );
            },
          ),
        );
      },
    );
  }
  
  // Helper method to parse color from string (format "#RRGGBB" or named color)
  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey; // Default color
    }
    
    if (colorString.startsWith('#')) {
      return Color(int.parse('0xFF${colorString.substring(1)}'));
    }
    
    // Handle named colors
    switch (colorString.toLowerCase()) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'blue': return Colors.blue;
      case 'yellow': return Colors.yellow;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'pink': return Colors.pink;
      case 'brown': return Colors.brown;
      case 'grey':
      case 'gray': return Colors.grey;
      case 'black': return Colors.black;
      case 'white': return Colors.white;
      default: return Colors.grey;
    }
  }
}