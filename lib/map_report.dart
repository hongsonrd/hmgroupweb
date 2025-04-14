import 'dart:convert';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'http_client.dart'; 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:sqflite/sqflite.dart';

class MapReportScreen extends StatefulWidget {
  final String mapUID;
  final String mapName;
  
  const MapReportScreen({
    Key? key, 
    required this.mapUID,
    required this.mapName
  }) : super(key: key);

  @override
  _MapReportScreenState createState() => _MapReportScreenState();
}

class _MapReportScreenState extends State<MapReportScreen> {
  final DBHelper dbHelper = DBHelper();
  final Map<String, Widget> zoneWidgetCache = {};
  bool _isSyncing = false;

  MapListModel? mapData;
  List<MapFloorModel> floors = [];
  String? selectedFloorUID;
  
  bool isLoading = false;
  String statusMessage = '';
  Set<String> visibleFloors = {};

  @override
  void initState() {
    super.initState();
    _loadMapData();
    _loadFloors();
    _loadFloors().then((_) => _preloadZones());
    dbHelper.debugTaskHistoryViTri();
    dbHelper.debugTableRecordCounts().then((_) {
    dbHelper.addTestMapReports();
  });
  }
  Future<void> _syncMapReports() async {
  if (_isSyncing) return;
  
  setState(() {
    _isSyncing = true;
    statusMessage = 'Đang đồng bộ báo cáo bản đồ...';
  });
  
  try {
    final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
    
    // Step 1: Clear existing map reports - do this in a separate transaction
    setState(() => statusMessage = 'Đang xóa dữ liệu cũ...');
    final db = await dbHelper.database;
    
    await db.transaction((txn) async {
      final deleteCount = await txn.delete(
        DatabaseTables.taskHistoryTable,
        where: "PhanLoai = ?",
        whereArgs: ['map_report']
      );
      print('Deleted $deleteCount existing map reports');
    });
    
    // Step 2: Fetch new data
    setState(() => statusMessage = 'Đang lấy báo cáo bản đồ từ server...');
    final mapReportResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/mapreport')
    );
    
    if (mapReportResponse.statusCode != 200) {
      throw Exception('Failed to load map reports: ${mapReportResponse.statusCode}');
    }

    final String responseText = mapReportResponse.body;
    final List<dynamic> mapReportData = json.decode(responseText);
    
    print('Retrieved ${mapReportData.length} map reports from server');
    
    // Step 3: Process and insert data
    setState(() => statusMessage = 'Đang lưu ${mapReportData.length} báo cáo vào cơ sở dữ liệu...');
    
    // Create TaskHistory models from map report data
    final List<Map<String, dynamic>> taskHistories = [];
    final Set<String> processedUIDs = {}; // Track UIDs to avoid duplicates
    
    for (var report in mapReportData) {
      try {
        final uid = report['UID']?.toString() ?? '';
        
        // Skip if UID is empty or we've already processed this UID
        if (uid.isEmpty || processedUIDs.contains(uid)) {
          continue;
        }
        
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
          'PhanLoai': 'map_report', // Force the correct value
          'HinhAnh': report['HinhAnh'] ?? '',
          'GiaiPhap': report['GiaiPhap'] ?? '',
        };
        taskHistories.add(taskMap);
      } catch (e) {
        print('Error processing map report: $e');
        print('Problematic data: $report');
        // Continue with other records instead of throwing
      }
    }

    // Step 4: Insert in batches to handle large datasets
    if (taskHistories.isNotEmpty) {
      int successCount = 0;
      
      // Insert in smaller batches of 50 records
      for (int i = 0; i < taskHistories.length; i += 50) {
        final int end = min(i + 50, taskHistories.length);
        final batch = db.batch();
        
        for (int j = i; j < end; j++) {
          batch.insert(
            DatabaseTables.taskHistoryTable, 
            taskHistories[j],
            conflictAlgorithm: ConflictAlgorithm.replace // Replace if duplicate
          );
        }
        
        await batch.commit(noResult: true);
        successCount += end - i;
        
        // Update progress
        setState(() {
          statusMessage = 'Đã lưu $successCount/${taskHistories.length} báo cáo...';
        });
      }
      
      print('Successfully inserted $successCount map reports');
    }
    
    // Save last sync date
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('last_map_report_sync_date', today);
    
    setState(() {
      statusMessage = 'Đồng bộ hoàn tất: ${taskHistories.length} báo cáo';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đồng bộ dữ liệu báo cáo bản đồ thành công: ${taskHistories.length} báo cáo'))
    );
    
  } catch (e) {
    print('Error syncing map reports: $e');
    setState(() {
      statusMessage = 'Lỗi đồng bộ báo cáo: $e';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi đồng bộ dữ liệu báo cáo: $e'))
    );
  } finally {
    setState(() {
      _isSyncing = false;
    });
  }
}
  Future<void> _preloadZones() async {
  if (floors.isEmpty) return;
  
  for (final floor in floors) {
    if (floor.floorUID != null) {
      try {
        final zones = await dbHelper.getMapZonesByFloorUID(floor.floorUID!);
        zoneCache[floor.floorUID!] = zones;
      } catch (e) {
        print('Error preloading zones for floor ${floor.floorUID}: $e');
      }
    }
  }
}
  Future<void> _loadMapData() async {
    try {
      final map = await dbHelper.getMapListByUID(widget.mapUID);
      setState(() {
        mapData = map;
      });
    } catch (e) {
      print('Error loading map data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải dữ liệu bản đồ'))
        );
      }
    }
  }
  
  Future<void> _loadFloors() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Đang tải danh sách tầng...';
    });
    
    try {
      final loadedFloors = await dbHelper.getMapFloorsByMapUID(widget.mapUID);
      
      // Sort floors in reverse order (e.g., Floor 3 > Floor 2 > Floor 1)
      loadedFloors.sort((a, b) {
        // Try to extract floor numbers for natural sorting
        final aName = a.tenTang ?? '';
        final bName = b.tenTang ?? '';
        
        // Extract digits if they exist
        final aMatch = RegExp(r'\d+').firstMatch(aName);
        final bMatch = RegExp(r'\d+').firstMatch(bName);
        
        if (aMatch != null && bMatch != null) {
          final aNum = int.parse(aMatch.group(0)!);
          final bNum = int.parse(bMatch.group(0)!);
          return bNum.compareTo(aNum); // Reverse order
        }
        
        return bName.compareTo(aName); // Fallback to reverse alphabetical
      });
      
      setState(() {
        floors = loadedFloors;
        // Select first floor by default if available
        if (floors.isNotEmpty && selectedFloorUID == null) {
          selectedFloorUID = floors.first.floorUID;
        }
        // Initialize visible floors with the selected floor
        visibleFloors = selectedFloorUID != null ? {selectedFloorUID!} : {};
        isLoading = false;
        statusMessage = '';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = 'Lỗi tải dữ liệu: $e';
      });
      print('Error loading floors: $e');
    }
  }
  
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Báo cáo: ${widget.mapName}'),
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
          tooltip: 'Đồng bộ dữ liệu báo cáo bản đồ',
          onPressed: _isSyncing ? null : _syncMapReports,
        ),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.greenAccent.shade400, Colors.green.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    ),
      body: isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(statusMessage),
              ],
            ),
          )
        : Column(
            children: [
              if (statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    statusMessage,
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              Expanded(
                child: _buildMapView(),
              ),
            ],
          ),
    );
  }
  final Map<String, List<MapZoneModel>> zoneCache = {};

  Widget _buildMapView() {
    if (mapData == null) {
      return Center(child: Text('Không có dữ liệu bản đồ'));
    }
    
    if (floors.isEmpty) {
      return Center(child: Text('Không có tầng nào để hiển thị'));
    }
    
    // Calculate aspect ratio based on map dimensions
    final mapWidth = mapData!.chieuDaiMet ?? 1200.0;
    final mapHeight = mapData!.chieuCaoMet ?? 600.0;
    final aspectRatio = mapWidth / mapHeight;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xem bản đồ ${widget.mapName}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              
              // Floor visibility toggles - show only one floor at a time
              Text('Chọn tầng để hiển thị:'),
              SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: floors.map((floor) {
                  final isVisible = visibleFloors.contains(floor.floorUID);
                  return ChoiceChip(
                    label: Text(floor.tenTang ?? 'Không tên'),
                    selected: isVisible,
                    onSelected: (selected) {
                      setState(() {
                        // Only one floor visible at a time
                        visibleFloors.clear();
                        if (selected) {
                          visibleFloors.add(floor.floorUID!);
                          selectedFloorUID = floor.floorUID;
                        }
                      });
                    },
                    selectedColor: Colors.blue.withOpacity(0.3),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the size based on the available width and the aspect ratio
              double width = constraints.maxWidth;
              double height = width / aspectRatio;
              
              // If height exceeds available height, recalculate based on height
              if (height > constraints.maxHeight) {
                height = constraints.maxHeight;
                width = height * aspectRatio;
              }
              
              return InteractiveViewer(
                constrained: true,
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Container(
                    width: width,
                    height: height,
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Stack(
                        children: [
                          // Base map image
                          if (mapData?.hinhAnhBanDo != null && mapData!.hinhAnhBanDo!.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.2,
                                child: Image.network(
                                  mapData!.hinhAnhBanDo!,
                                  fit: BoxFit.fill,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(color: Colors.grey[200]);
                                  },
                                ),
                              ),
                            ),
                          
                          // Display floors at their actual positions and sizes
                          ...floors.where((floor) => 
                            visibleFloors.contains(floor.floorUID)
                          ).map((floor) {
                            // Get floor dimensions
                            final floorWidth = floor.chieuDaiMet ?? mapWidth;
                            final floorHeight = floor.chieuCaoMet ?? mapHeight;
                            
                            // Calculate position based on offsets
                            final offsetX = floor.offsetX ?? 0;
                            final offsetY = floor.offsetY ?? 0;
                            
                            // Convert to percentages of map size
                            final leftPercent = (offsetX / mapWidth) * 100;
                            final topPercent = (offsetY / mapHeight) * 100;
                            final widthPercent = (floorWidth / mapWidth) * 100;
                            final heightPercent = (floorHeight / mapHeight) * 100;
                            
                            return Positioned(
                              left: leftPercent * width / 100,
                              top: topPercent * height / 100,
                              width: widthPercent * width / 100,
                              height: heightPercent * height / 100,
                              child: Stack(
                                children: [
                                  // Floor background
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: selectedFloorUID == floor.floorUID ? Colors.blue : Colors.grey,
                                        width: selectedFloorUID == floor.floorUID ? 2 : 1,
                                      ),
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    child: Stack(
                                      children: [
                                        if (floor.hinhAnhTang != null && floor.hinhAnhTang!.isNotEmpty)
                                          Positioned.fill(
                                            child: Image.network(
                                              floor.hinhAnhTang!,
                                              fit: BoxFit.fill,
                                              errorBuilder: (context, error, stackTrace) {
                                                return SizedBox();
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  FutureBuilder<List<MapZoneModel>>(
  future: zoneCache.containsKey(floor.floorUID) 
      ? Future.value(zoneCache[floor.floorUID])
      : dbHelper.getMapZonesByFloorUID(floor.floorUID!).then((zones) {
          zoneCache[floor.floorUID!] = zones;
          return zones;
        }),
  builder: (context, snapshot) {
    // Check cache first
    if (zoneWidgetCache.containsKey(floor.floorUID)) {
      return zoneWidgetCache[floor.floorUID]!;
    }
    
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      return SizedBox();
    }
    
    final zones = snapshot.data ?? [];
    
    // Create a map of scaled points for each zone for faster access
    final Map<String, List<Offset>> zonePointsMap = {};
    
    for (var zone in zones) {
      try {
        final pointsData = json.decode(zone.cacDiemMoc ?? '[]') as List;
        if (pointsData.isEmpty) {
          continue; 
        }
        final points = pointsData.map((point) {
          if (point is! Map || !point.containsKey('x') || !point.containsKey('y')) {
            return null;
          }
          return Offset(
            (point['x'] as num).toDouble(),
            (point['y'] as num).toDouble(),
          );
        }).whereType<Offset>().toList(); 
        if (points.length < 3) {
          continue;
        }
              
        // Convert to scaled points
        final scaledPoints = points.map((point) {
          final xPercent = (point.dx - (floor.offsetX ?? 0)) / floorWidth;
          final yPercent = (point.dy - (floor.offsetY ?? 0)) / floorHeight;
          
          return Offset(
            xPercent * widthPercent * width / 100,
            yPercent * heightPercent * height / 100,
          );
        }).toList();
        
        zonePointsMap[zone.zoneUID!] = scaledPoints;
      } catch (e) {
        print('Error processing zone points for ${zone.zoneUID}: $e');
        continue;
      }
    }
    
    final zoneWidgets = zones.map((zone) {
      // Parse color
      Color zoneColor = _parseColor(zone.mauSac ?? '#3388FF80');
      final scaledPoints = zonePointsMap[zone.zoneUID] ?? [];
      
      return GestureDetector(
        onTap: () {
          // Create a fresh copy to avoid closure issues
          final clickedZone = MapZoneModel(
            zoneUID: zone.zoneUID,
            floorUID: zone.floorUID,
            tenKhuVuc: zone.tenKhuVuc,
            mauSac: zone.mauSac,
            cacDiemMoc: zone.cacDiemMoc
          );
          _showZoneInfo(clickedZone);
        },
        child: CustomPaint(
          painter: ZoneAreaPainter(
            points: scaledPoints,
            color: zoneColor,
            isSelectable: true,
          ),
          size: Size(
            widthPercent * width / 100,
            heightPercent * height / 100,
          ),
        ),
      );
    }).toList();
    
    final stackWidget = Stack(children: zoneWidgets);
    zoneWidgetCache[floor.floorUID!] = stackWidget;
    return stackWidget;
  },
),
                                  
                                  // Floor label
                                  Positioned(
                                    left: 4,
                                    top: 4,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      color: Colors.black.withOpacity(0.7),
                                      child: Text(
                                        floor.tenTang ?? '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  Widget buildZoneGestureDetector(MapZoneModel zone, List<Offset> points, Color color, Size size) {
  return GestureDetector(
    onTap: () {
      // Directly create a NEW MapZoneModel to avoid closure issues
      final clickedZone = MapZoneModel(
        zoneUID: zone.zoneUID,
        floorUID: zone.floorUID, 
        tenKhuVuc: zone.tenKhuVuc,
        mauSac: zone.mauSac,
        cacDiemMoc: zone.cacDiemMoc
      );
      _showZoneInfo(clickedZone);
    },
    child: CustomPaint(
      painter: ZoneAreaPainter(
        points: points,
        color: color,
      ),
      size: size,
    ),
  );
}
  void _showZoneInfo(MapZoneModel zone) {
  // Calculate zone area (keeping your existing code)
  final mapWidth = mapData?.chieuDaiMet ?? 1200.0;
  final mapHeight = mapData?.chieuCaoMet ?? 600.0;
  
  List<Offset> zonePoints = [];
  try {
    final pointsData = json.decode(zone.cacDiemMoc ?? '[]') as List;
    zonePoints = pointsData.map((point) {
      return Offset(
        (point['x'] as num).toDouble(),
        (point['y'] as num).toDouble(),
      );
    }).toList();
  } catch (e) {
    print('Error parsing zone points: $e');
  }
  
  final zoneArea = 0.25 * _calculateZoneArea(zonePoints, mapWidth, mapHeight, zone.cacDiemMoc ?? '[]');
  
  // Load data about positions in this zone
  showDialog(
    context: context,
    builder: (context) => FutureBuilder<List<MapPositionModel>>(
      future: dbHelper.getMapPositionsByZone(
        mapUID: widget.mapUID,
        floorUID: selectedFloorUID ?? '',
        zoneUID: zone.zoneUID ?? ''
      ),
      builder: (context, positionSnapshot) {
        if (positionSnapshot.connectionState == ConnectionState.waiting) {
          return AlertDialog(
            title: Text(zone.tenKhuVuc ?? 'Khu vực không tên'),
            content: Center(child: CircularProgressIndicator()),
          );
        }
        
        final positions = positionSnapshot.data ?? [];
        final positionCount = positions.length;
        
        // Get today's date for report comparison
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        return AlertDialog(
          title: Row(
            children: [
      Expanded(child: Text(zone.tenKhuVuc ?? 'Khu vực không tên')),
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          '$positionCount vị trí',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone information section
                Text('Thông tin khu vực:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                
                Row(
                  children: [
                    Text('Màu sắc: '),
                    Container(
                      width: 20,
                      height: 20,
                      margin: EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: _parseColor(zone.mauSac ?? '#3388FF80'),
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Text(' ${zone.mauSac ?? '#3388FF80'}'),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Zone statistics
                Text('Thống kê:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                
                FutureBuilder<int>(
                  future: dbHelper.getReportCountForZone(zoneUID: zone.zoneUID ?? ''),
                  builder: (context, reportCountSnapshot) {
                    final reportCount = reportCountSnapshot.data ?? 0;
                    return _buildStatItem(Icons.report, 'Số lượt báo cáo', '$reportCount');
                  }
                ),
                
                FutureBuilder<double>(
                  future: dbHelper.getAverageDailyReportCountForZone(zoneUID: zone.zoneUID ?? ''),
                  builder: (context, avgReportSnapshot) {
                    final avgReportCount = avgReportSnapshot.data ?? 0.0;
                    return _buildStatItem(Icons.access_time, 'Trung bình báo cáo/ngày', '${avgReportCount.toStringAsFixed(1)}');
                  }
                ),
                
                _buildStatItem(Icons.square_foot, 'Diện tích khu vực', '${zoneArea.toStringAsFixed(2)} m²'),
                
                SizedBox(height: 16),
                
                // Staff positions section
                Text('Vị trí nhân viên (${positions.length}):', 
                     style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                
                Expanded(
                  child: positions.isEmpty 
                    ? Center(child: Text('Không có vị trí nào trong khu vực này'))
                    : FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                        future: _getPositionReportsMap(positions),
                        builder: (context, reportsMapSnapshot) {
                          if (reportsMapSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          
                          final positionReportsMap = reportsMapSnapshot.data ?? {};
                          
                          // Create a sorted list of positions based on report status (green first, then red)
                          final sortedPositions = List.of(positions);
                          sortedPositions.sort((a, b) {
                            final aHasReportToday = _hasReportToday(positionReportsMap[a.viTri] ?? [], today);
                            final bHasReportToday = _hasReportToday(positionReportsMap[b.viTri] ?? [], today);
                            
                            if (aHasReportToday && !bHasReportToday) return -1;
                            if (!aHasReportToday && bHasReportToday) return 1;
                            return (a.viTri ?? '').compareTo(b.viTri ?? '');
                          });
                          
                          return ListView.builder(
  shrinkWrap: true,
  itemCount: sortedPositions.length,
  itemBuilder: (context, index) {
    final position = sortedPositions[index];
    final reports = positionReportsMap[position.viTri] ?? [];
    final hasReportToday = _hasReportToday(reports, today);
    
    return ExpansionTile(
      title: Text(
        position.viTri ?? 'Vị trí không tên',
        style: TextStyle(
          color: hasReportToday ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text('${reports.length} báo cáo'),
      children: [
        if (reports.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Không có báo cáo nào'),
          )
        else
          ...reports.map((report) {
            final reportDate = report['Ngay'] ?? '';
            final reportTime = report['Gio'] ?? '';
            final reportResult = report['KetQua'] ?? '';
            final reporterUsername = report['NguoiDung'] ?? '';
            
            return FutureBuilder<Map<String, String>?>(
              future: _getStaffInfo(reporterUsername),
              builder: (context, staffSnapshot) {
                final String staffName = staffSnapshot.data?['hoTen'] ?? reporterUsername;
                final String staffRole = staffSnapshot.data?['vaiTro'] ?? '';
                final String staffInfo = staffName + (staffRole.isNotEmpty ? ' ($staffRole)' : '');
                
                final bool hasImage = report['HinhAnh'] != null && report['HinhAnh'].toString().isNotEmpty;
                
                return ListTile(
                  dense: true,
                  title: Text(reportResult),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDateTime(reportDate, reportTime)),
                      Text(staffInfo, style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                  leading: hasImage ? Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.network(
                        report['HinhAnh'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.broken_image, size: 20);
                        },
                      ),
                    ),
                  ) : null,
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showReportDetails(report),
                );
              },
            );
          }).toList(),
      ],
    );
  },
);
                        },
                      ),
                ),
                
                SizedBox(height: 16),
                
                Text('Zone UID: ${zone.zoneUID ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Floor UID: ${zone.floorUID ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
            ),
          ],
        );
      },
    ),
  );
}
Future<Map<String, String>?> _getStaffInfo(String username) async {
  if (username.isEmpty) return null;
  
  try {
    final db = await dbHelper.database;
    final results = await db.query(
      DatabaseTables.mapStaffTable,
      columns: ['hoTen', 'vaiTro'],
      where: 'nguoiDung = ?',
      whereArgs: [username],
      limit: 1
    );
    
    if (results.isNotEmpty) {
      return {
        'hoTen': results.first['hoTen']?.toString() ?? username,
        'vaiTro': results.first['vaiTro']?.toString() ?? '',
      };
    }
    
    return null;
  } catch (e) {
    print('Error getting staff info: $e');
    return null;
  }
}
// Helper function to get reports for each position
Future<Map<String, List<Map<String, dynamic>>>> _getPositionReportsMap(List<MapPositionModel> positions) async {
  final Map<String, List<Map<String, dynamic>>> result = {};
  
  for (var position in positions) {
  if (position.viTri != null && position.viTri!.isNotEmpty) {
    print('Looking for reports for position: "${position.viTri}"');
    final reports = await dbHelper.getReportsByPosition(position.viTri!);
    result[position.viTri!] = reports;
  }
}
  
  return result;
}

// Helper function to check if a position has a report today
bool _hasReportToday(List<Map<String, dynamic>> reports, String today) {
  return reports.any((report) {
    final reportDate = report['Ngay']?.toString() ?? '';
    return reportDate == today || reportDate.split('T')[0] == today;
  });
}
String _formatDateTime(String? dateStr, String? timeStr) {
  if (dateStr == null || dateStr.isEmpty) return 'N/A';
  
  try {
    // Parse the date - handle both ISO format and regular format
    DateTime date;
    if (dateStr.contains('T')) {
      date = DateTime.parse(dateStr.split('.')[0]);
    } else {
      date = DateTime.parse(dateStr);
    }
    
    // Format date as DD/MM
    final formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}";
    
    // Format time if available
    String formattedTime = '';
    if (timeStr != null && timeStr.isNotEmpty) {
      // Take only hours and minutes
      final timeParts = timeStr.split(':');
      if (timeParts.length >= 2) {
        formattedTime = " - ${timeParts[0]}:${timeParts[1]}";
      }
    }
    
    return "$formattedDate$formattedTime";
  } catch (e) {
    print('Error formatting date/time: $e');
    return dateStr;
  }
}
// Function to show detailed report information
void _showReportDetails(Map<String, dynamic> report) {
  final String reporterUsername = report['NguoiDung'] ?? '';
  final bool hasImage = report['HinhAnh'] != null && report['HinhAnh'].toString().isNotEmpty;
  
  showDialog(
    context: context,
    builder: (context) => FutureBuilder<Map<String, String>?>(
      future: _getStaffInfo(reporterUsername),
      builder: (context, staffSnapshot) {
        final String staffName = staffSnapshot.data?['hoTen'] ?? reporterUsername;
        final String staffRole = staffSnapshot.data?['vaiTro'] ?? '';
        
        return AlertDialog(
          title: Text('Chi tiết báo cáo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kết quả: ${report['KetQua'] ?? 'N/A'}', 
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                
                Text('Người báo cáo: $staffName',
                     style: TextStyle(fontWeight: FontWeight.bold)),
                if (staffRole.isNotEmpty)
                  Text('Vai trò: $staffRole'),
                SizedBox(height: 8),
                
                Text('Thời gian: ${_formatDateTime(report['Ngay'], report['Gio'])}'),
                Text('Vị trí: ${report['ViTri'] ?? 'N/A'}'),
                Text('Bộ phận: ${report['BoPhan'] ?? 'N/A'}'),
                SizedBox(height: 12),
                
                if (report['ChiTiet'] != null && report['ChiTiet'].toString().isNotEmpty) 
                  Text('Chi tiết:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (report['ChiTiet'] != null && report['ChiTiet'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 8.0),
                    child: Text(report['ChiTiet'].toString()),
                  ),
                  
                if (report['ChiTiet2'] != null && report['ChiTiet2'].toString().isNotEmpty) 
                  Text('Chi tiết bổ sung:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (report['ChiTiet2'] != null && report['ChiTiet2'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 8.0),
                    child: Text(report['ChiTiet2'].toString()),
                  ),
                  
                if (report['GiaiPhap'] != null && report['GiaiPhap'].toString().isNotEmpty) 
                  Text('Giải pháp:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (report['GiaiPhap'] != null && report['GiaiPhap'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 8.0),
                    child: Text(report['GiaiPhap'].toString()),
                  ),
                
                if (hasImage)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hình ảnh:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  appBar: AppBar(
                                    title: Text('Hình ảnh báo cáo'),
                                    backgroundColor: Colors.black,
                                  ),
                                  body: Center(
                                    child: InteractiveViewer(
                                      panEnabled: true,
                                      boundaryMargin: EdgeInsets.all(20),
                                      minScale: 0.5,
                                      maxScale: 4,
                                      child: Image.network(
                                        report['HinhAnh'],
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Text('Không thể tải hình ảnh: $error');
                                        },
                                      ),
                                    ),
                                  ),
                                  backgroundColor: Colors.black,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: 200,
                              maxWidth: double.infinity,
                            ),
                            child: Image.network(
                              report['HinhAnh'],
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Text('Không thể tải hình ảnh: $error');
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
            ),
          ],
        );
      },
    ),
  );
}


// Move the calculateZoneArea function out of _showZoneInfo to make it a class method
double _calculateZoneArea(List<Offset> points, double mapWidth, double mapHeight, String cacDiemMoc) {
  if (points.length < 3) return 0.0;
  
  // Shoelace formula for polygon area calculation
  double area = 0.0;
  for (int i = 0; i < points.length; i++) {
    int j = (i + 1) % points.length;
    area += (points[i].dx * points[j].dy) - (points[j].dx * points[i].dy);
  }
  area = area.abs() / 2.0;
  
  try {
    // Calculate the actual area based on map dimensions
    final pointsData = json.decode(cacDiemMoc) as List;
    if (pointsData.isEmpty) return 0.0;
    
    // Find the min and max coordinates of the original points
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    
    for (var point in pointsData) {
      final x = (point['x'] as num).toDouble();
      final y = (point['y'] as num).toDouble();
      
      minX = minX > x ? x : minX;
      maxX = maxX < x ? x : maxX;
      minY = minY > y ? y : minY;
      maxY = maxY < y ? y : maxY;
    }
    
    // Calculate the actual area in square meters
    final zoneWidth = maxX - minX;
    final zoneHeight = maxY - minY;
    
    // Proportional scaling to map dimensions
    final widthRatio = zoneWidth / mapWidth;
    final heightRatio = zoneHeight / mapHeight;
    
    return (widthRatio * heightRatio * mapWidth * mapHeight);
  } catch (e) {
    print('Error calculating area: $e');
    return 0.0;
  }
}
  
  Widget _buildStatItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        String hexColor = colorStr.substring(1);
        if (hexColor.length == 6) {
          return Color(int.parse('0xFF$hexColor')).withOpacity(0.3);
        } else if (hexColor.length == 8) {
          final alpha = int.parse(hexColor.substring(6, 8), radix: 16);
          final baseColor = Color(int.parse('0xFF${hexColor.substring(0, 6)}'));
          return baseColor.withOpacity(alpha / 255.0 * 0.6);
        }
      }
    } catch (e) {
      print('Error parsing color: $e');
    }
    return Colors.blue.withOpacity(0.3);
  }
}

class ZoneAreaPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final bool isHighlighted;
  final bool isSelectable;
  
  ZoneAreaPainter({
    required this.points, 
    required this.color, 
    this.isHighlighted = false,
    this.isSelectable = false,
  });
  
  @override
void paint(Canvas canvas, Size size) {
  if (points.isEmpty) return;
  
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  
  final path = Path();

  path.moveTo(points.first.dx, points.first.dy);

  for (int i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }

  path.close();

  canvas.drawPath(path, paint);

  if (isHighlighted) {
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawPath(path, borderPaint);
  }
}
  
  @override
  bool hitTest(Offset position) {
    // Only do hit testing if this zone is selectable
    if (!isSelectable || points.length < 3) {
      return false;
    }
    
    // Ray casting algorithm for point-in-polygon test
    bool isInside = false;
    int i = 0, j = points.length - 1;
    
    for (i = 0; i < points.length; i++) {
      if (((points[i].dy > position.dy) != (points[j].dy > position.dy)) &&
          (position.dx < (points[j].dx - points[i].dx) * (position.dy - points[i].dy) / 
          (points[j].dy - points[i].dy) + points[i].dx)) {
        isInside = !isInside;
      }
      j = i;
    }
    
    return isInside;
  }
  
  @override
  bool shouldRepaint(covariant ZoneAreaPainter oldDelegate) {
    return oldDelegate.points != points || 
           oldDelegate.color != color || 
           oldDelegate.isHighlighted != isHighlighted;
  }
}
class ZoneClipper extends CustomClipper<Path> {
  final List<Offset> points;
  
  ZoneClipper({required this.points});
  
  @override
  Path getClip(Size size) {
    final path = Path();
    if (points.isEmpty) return path;
    
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(ZoneClipper oldClipper) => oldClipper.points != points;
}