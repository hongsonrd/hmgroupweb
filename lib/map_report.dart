import 'dart:convert';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'http_client.dart'; 
import 'package:cached_network_image/cached_network_image.dart';

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

class _MapReportScreenState extends State<MapReportScreen> with TickerProviderStateMixin {
  final DBHelper dbHelper = DBHelper();
  final Map<String, Widget> zoneWidgetCache = {};
  bool _isSyncing = false;
  final Map<String, List<PositionDot>> zonePositionDots = {};
  late AnimationController _dotsAnimationController;
  Random random = Random();
  Timer? _dotAnimationTimer;
  Timer? _dotTargetTimer;
  MapListModel? mapData;
  List<MapFloorModel> floors = [];
  String? selectedFloorUID;
  bool _statsVisible = true;
  bool isLoading = false;
  String statusMessage = '';
  Set<String> visibleFloors = {};
  Timer? _inactivityTimer;
  Timer? _autoCycleTimer;
  bool _isAutoCycling = false;
  int _currentFloorIndex = 0;
  static const Duration _inactivityTimeout = Duration(seconds: 30);
  static const Duration _cycleInterval = Duration(seconds: 5);
  // Add new variables to track sync times
  DateTime? _lastSyncTime;
  bool _hasPerformedMorningSync = false;
  bool _hasPerformedAfternoonSync = false;
List<Map<String, dynamic>> hoverStats = [
  {
    'title': 'Vị trí đã báo cáo/tổng',
    'icon': Icons.location_on,
    'value': '0/0',
    'color': Colors.blue,
    'futureType': 'positionRatio'
  },
  {
    'title': 'Người dùng báo cáo hôm nay',
    'icon': Icons.person,
    'value': '0',
    'color': Colors.orange,
    'futureType': 'usersToday'
  },
  {
    'title': 'Báo cáo máy móc',
    'icon': Icons.build,
    'value': '0',
    'color': Colors.purple,
    'futureType': 'machineReports'
  },
  {
    'title': 'Giờ có báo cáo',
    'icon': Icons.access_time,
    'value': '0',
    'color': Colors.green,
    'futureType': 'reportHours'
  },
];
bool _statsLoaded = false;
@override
void initState() {
  super.initState();
  print("MapReportScreen: initState called");
  _loadMapData();
  _loadFloors().then((_) => _preloadZones());
  _loadHoverStats();
  
  // Initialize animation controller
  print("Setting up animation controller");
  _dotsAnimationController = AnimationController(
    vsync: this,
    duration: Duration(seconds: 5), 
  );
  _dotsAnimationController.addListener(() {
    print("Animation value: ${_dotsAnimationController.value}");
  });
  
  // Start the animation after a short delay
  Future.delayed(Duration(milliseconds: 500), () {
    if (mounted) {
      print("Starting animation");
      _dotsAnimationController.repeat(reverse: true);
    }
  });
  
  // Load the last sync time from SharedPreferences
  _loadLastSyncTime();
  
  // Start inactivity timer for auto-cycling
  _startInactivityTimer();
}
   @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if we should perform automatic sync
    _checkAndPerformAutoSync();
  }
  @override
@override
void dispose() {
  _dotsAnimationController.dispose();
  _dotAnimationTimer?.cancel();
  _dotTargetTimer?.cancel();
  
  // Clean up auto-cycle timers
  _cancelInactivityTimer();
  _stopAutoCycle();
  
  super.dispose();
}
void _startInactivityTimer() {
  _cancelInactivityTimer();
  _inactivityTimer = Timer(_inactivityTimeout, () {
    if (mounted) {
      _startAutoCycle();
    }
  });
}

// Method to cancel the inactivity timer
void _cancelInactivityTimer() {
  _inactivityTimer?.cancel();
  _inactivityTimer = null;
}

// Method to reset the inactivity timer (called on user interaction)
void _resetInactivityTimer() {
  if (_isAutoCycling) {
    _stopAutoCycle();
  }
  _startInactivityTimer();
}

// Method to start auto-cycling through floors
void _startAutoCycle() {
  if (floors.isEmpty) return;
  
  setState(() {
    _isAutoCycling = true;
  });
  
  print('Starting auto-cycle mode for TV display');
  
  // Set the first floor as current
  _currentFloorIndex = 0;
  if (floors.isNotEmpty) {
    _handleFloorChange(floors[_currentFloorIndex].floorUID!);
  }
  
  // Start cycling timer
  _autoCycleTimer = Timer.periodic(_cycleInterval, (timer) {
    if (!mounted || floors.isEmpty) {
      timer.cancel();
      return;
    }
    
    // Move to next floor
    _currentFloorIndex = (_currentFloorIndex + 1) % floors.length;
    _handleFloorChange(floors[_currentFloorIndex].floorUID!);
    
    print('Auto-cycling to floor: ${floors[_currentFloorIndex].tenTang}');
  });
}

// Method to stop auto-cycling
void _stopAutoCycle() {
  _autoCycleTimer?.cancel();
  _autoCycleTimer = null;
  
  setState(() {
    _isAutoCycling = false;
  });
  
  print('Stopped auto-cycle mode');
}

// Method to handle user interaction and reset timers
void _handleUserInteraction([_]) {
  if (_isAutoCycling || _inactivityTimer != null) {
    print('User interaction detected - resetting timers');
    _resetInactivityTimer();
  }
}
Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimeStr = prefs.getString('last_map_report_sync_time');
      if (lastSyncTimeStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncTimeStr);
        _checkSyncPeriodStatus();
      }
    } catch (e) {
      print('Error loading last sync time: $e');
    }
  }
  
  // New method to save last sync time to SharedPreferences
  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString('last_map_report_sync_time', now.toIso8601String());
      _lastSyncTime = now;
      _checkSyncPeriodStatus();
    } catch (e) {
      print('Error saving last sync time: $e');
    }
  }
  
  // Check which sync period (morning/afternoon) we're in
  void _checkSyncPeriodStatus() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Check if last sync was today
    if (_lastSyncTime != null) {
      final lastSyncDay = DateTime(_lastSyncTime!.year, _lastSyncTime!.month, _lastSyncTime!.day);
      final lastSyncHour = _lastSyncTime!.hour;
      
      // If sync was today, mark morning or afternoon sync as done
      if (lastSyncDay.isAtSameMomentAs(today)) {
        if (lastSyncHour < 12) {
          _hasPerformedMorningSync = true;
        } else {
          _hasPerformedAfternoonSync = true;
        }
      } else {
        // Reset sync flags for a new day
        _hasPerformedMorningSync = false;
        _hasPerformedAfternoonSync = false;
      }
    }
  }
  
  // Method to check if auto-sync should be performed
  Future<void> _checkAndPerformAutoSync() async {
    if (_isSyncing) return;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // Morning sync (before noon) if not already done today
    if (currentHour < 12 && !_hasPerformedMorningSync) {
      print('Performing automatic morning sync');
      await _syncMapReports();
      _hasPerformedMorningSync = true;
      return;
    }
    
    // Afternoon sync (after noon) if not already done today
    if (currentHour >= 12 && !_hasPerformedAfternoonSync) {
      print('Performing automatic afternoon sync');
      await _syncMapReports();
      _hasPerformedAfternoonSync = true;
      return;
    }
  }
Future<void> _loadHoverStats() async {
  if (_statsLoaded) return;
  
  try {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    for (var i = 0; i < hoverStats.length; i++) {
      final futureType = hoverStats[i]['futureType'] as String;
      String result = '?';
      
      switch (futureType) {
        case 'positionRatio':
          result = await _getReportedPositionsRatio();
          break;
        case 'usersToday':
          result = await _getUsersReportingToday();
          break;
        case 'machineReports':
          result = await _getMachineReportsCount();
          break;
        case 'reportHours':
          result = await _getReportHoursCount();
          break;
      }
      
      if (mounted) {
        setState(() {
          hoverStats[i]['value'] = result;
        });
      }
    }
    
    _statsLoaded = true;
  } catch (e) {
    print('Error loading hover stats: $e');
  }
}
Future<String> _getReportedPositionsRatio() async {
  try {
    final db = await dbHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Get total unique positions
    final totalResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT viTri) as count
      FROM ${DatabaseTables.mapPositionTable}
    ''');
    
    final totalPositions = totalResult.first['count'] as int? ?? 0;
    
    // Get reported positions for TODAY only
    final reportedResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT ViTri) as count
      FROM ${DatabaseTables.taskHistoryTable}
      WHERE PhanLoai = 'map_report' AND date(Ngay, '+1 day') = date(?)
    ''', [today]);
    
    final reportedPositions = reportedResult.first['count'] as int? ?? 0;
    
    return '$reportedPositions/$totalPositions';
  } catch (e) {
    print('Error getting position ratio: $e');
    return '?/?';
  }
}

Future<String> _getUsersReportingToday() async {
  try {
    final db = await dbHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Query using date +1 day adjustment
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT NguoiDung) as count
      FROM ${DatabaseTables.taskHistoryTable}
      WHERE PhanLoai = 'map_report' AND date(Ngay, '+1 day') = date(?)
    ''', [today]);
    
    return (result.first['count'] as int? ?? 0).toString();
  } catch (e) {
    print('Error getting users count: $e');
    return '?';
  }
}

Future<String> _getMachineReportsCount() async {
  try {
    final db = await dbHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM ${DatabaseTables.taskHistoryTable}
      WHERE PhanLoai = 'map_report' AND BoPhan = 'Máy móc' 
      AND date(Ngay, '+1 day') = date(?)
    ''', [today]);
    
    return (result.first['count'] as int? ?? 0).toString();
  } catch (e) {
    print('Error getting machine reports: $e');
    return '?';
  }
}

Future<String> _getReportHoursCount() async {
  try {
    final db = await dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT substr(Gio, 1, 2)) as count
      FROM ${DatabaseTables.taskHistoryTable}
      WHERE PhanLoai = 'map_report'
    ''');
    
    return (result.first['count'] as int? ?? 0).toString();
  } catch (e) {
    print('Error getting report hours: $e');
    return '?';
  }
}
  Future<void> _syncMapReports() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
      statusMessage = 'Đang đồng bộ báo cáo bản đồ...';
    });
    
    try {
      final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
      
      // Step 1: Clear existing map reports
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
      final Set<String> processedUIDs = {};
      
      for (var report in mapReportData) {
        try {
          final uid = report['UID']?.toString() ?? '';
          
          if (uid.isEmpty || processedUIDs.contains(uid)) {
            continue;
          }
          
          processedUIDs.add(uid);
          final reportDate = report['Ngay'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

          final Map<String, dynamic> taskMap = {
            'UID': uid,
            'NguoiDung': report['NguoiDung'] ?? '',
            'TaskID': report['TaskID'] ?? '',
            'KetQua': report['KetQua'] ?? '',
            'Ngay': _normalizeDateString(reportDate),
            'Gio': report['Gio'] ?? DateFormat('HH:mm:ss').format(DateTime.now()),
            'ChiTiet': report['ChiTiet'] ?? '',
            'ChiTiet2': report['ChiTiet2'] ?? '',
            'ViTri': report['ViTri'] ?? '',
            'BoPhan': report['BoPhan'] ?? '',
            'PhanLoai': 'map_report',
            'HinhAnh': report['HinhAnh'] ?? '',
            'GiaiPhap': report['GiaiPhap'] ?? '',
          };
          taskHistories.add(taskMap);
        } catch (e) {
          print('Error processing map report: $e');
          print('Problematic data: $report');
        }
      }

      // Step 4: Insert in batches to handle large datasets
      if (taskHistories.isNotEmpty) {
        int successCount = 0;
        
        for (int i = 0; i < taskHistories.length; i += 50) {
          final int end = min(i + 50, taskHistories.length);
          final batch = db.batch();
          
          for (int j = i; j < end; j++) {
            batch.insert(
              DatabaseTables.taskHistoryTable, 
              taskHistories[j],
              conflictAlgorithm: ConflictAlgorithm.replace
            );
          }
          
          await batch.commit(noResult: true);
          successCount += end - i;
          
          setState(() {
            statusMessage = 'Đã lưu $successCount/${taskHistories.length} báo cáo...';
          });
        }
        
        print('Successfully inserted $successCount map reports');
      }
      
      // Step 5: Sync checklist data
      setState(() => statusMessage = 'Đang đồng bộ lịch công việc (checklist)...');
      await _syncChecklist();
      
      // Save last sync date and time
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setString('last_map_report_sync_date', today);
      
      // Save the sync time to track morning/afternoon syncs
      await _saveLastSyncTime();
      
      setState(() {
        statusMessage = 'Đồng bộ hoàn tất: ${taskHistories.length} báo cáo';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đồng bộ dữ liệu báo cáo bản đồ thành công: ${taskHistories.length} báo cáo'))
      );
      
      // Refresh the screen after successful sync
      await _refreshAfterSync();
      
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
  Future<void> _refreshAfterSync() async {
    try {
      // Clear all caches to ensure fresh data is loaded
      zoneWidgetCache.clear();
      
      // Reset animation
      _dotAnimationTimer?.cancel();
      _dotTargetTimer?.cancel();
      
      // Reload stats
      await _loadHoverStats();
      
      // Reload zones with fresh data
      await _preloadZones();
      
      // Refresh the screen
      setState(() {
        _statsLoaded = false; // Force stats reload
      });
      
      // Start animation again
      _startDotMovement();
      
    } catch (e) {
      print('Error refreshing screen after sync: $e');
    }
  }

// Add this new method to sync checklist data
Future<void> _syncChecklist() async {
  try {
    final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
    final String encodedMapName = Uri.encodeComponent(widget.mapName);
    
    // Fetch checklist data from server
    final checklistResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/maplich/$encodedMapName')
    );
    
    if (checklistResponse.statusCode != 200) {
      throw Exception('Failed to load checklist: ${checklistResponse.statusCode}');
    }
    
    final String responseText = checklistResponse.body;
    final List<dynamic> checklistData = json.decode(responseText);
    
    print('Retrieved ${checklistData.length} checklist items from server');
    
    // Clear existing checklist data
    final db = await dbHelper.database;
    await db.delete(DatabaseTables.checklistTable);
    print('Cleared existing checklist table');
    
    // Insert new checklist data
    if (checklistData.isNotEmpty) {
      int successCount = 0;
      
      // Insert in batches
      for (int i = 0; i < checklistData.length; i += 50) {
        final int end = min(i + 50, checklistData.length);
        final batch = db.batch();
        
        for (int j = i; j < end; j++) {
          final item = checklistData[j];
          
          final Map<String, dynamic> checklistMap = {
            'TASKID': item['TASKID'] ?? const Uuid().v4().toString(),
            'DUAN': item['DUAN'] ?? '',
            'VITRI': item['VITRI'] ?? '',
            'WEEKDAY': item['WEEKDAY'] ?? '',
            'START': item['START'] ?? '',
            'END': item['END'] ?? '',
            'TASK': item['TASK'] ?? '',
            'TUAN': item['TUAN'] ?? '',
            'THANG': item['THANG'] ?? '',
            'NGAYBC': item['NGAYBC'] ?? '',
          };
          
          batch.insert(
            DatabaseTables.checklistTable, 
            checklistMap,
            conflictAlgorithm: ConflictAlgorithm.replace
          );
        }
        
        await batch.commit(noResult: true);
        successCount += end - i;
        
        // Update progress for the whole sync operation
        setState(() {
          statusMessage = 'Đã lưu $successCount/${checklistData.length} lịch công việc...';
        });
      }
      
      print('Successfully inserted $successCount checklist items');
    }
    
    return;
  } catch (e) {
    print('Error syncing checklist: $e');
    throw e; // Re-throw to be caught by the calling method
  }
}
  Future<void> _preloadZones() async {
  if (floors.isEmpty) return;
  
  // Check if map name contains "VMáy" to determine default icon type
  final bool defaultMachineMap = widget.mapName.contains('VMáy');
  
  for (final floor in floors) {
    if (floor.floorUID != null) {
      try {
        final zones = await dbHelper.getMapZonesByFloorUID(floor.floorUID!);
        zoneCache[floor.floorUID!] = zones;
        
        // For each zone, load positions and create dots
        for (final zone in zones) {
          if (zone.zoneUID != null) {
            // Get positions for this zone
            final positions = await dbHelper.getMapPositionsByZone(
              mapUID: widget.mapUID,
              floorUID: floor.floorUID!,
              zoneUID: zone.zoneUID!
            );
            
            // Get today's date for report comparison
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            
            // Parse zone boundary points
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
              continue;
            }
            
            if (zonePoints.length < 3) continue;
            
            // For each position, create initial dots
            List<PositionDot> dots = [];
            
            for (final position in positions) {
              // Get reports for this position to determine color
              final reports = await dbHelper.getReportsByPosition(position.viTri ?? '');
              final hasReportToday = reports.any((report) {
                final reportDate = report['Ngay']?.toString() ?? '';
                if (reportDate.isEmpty) return false;
                
                try {
                  DateTime date;
                  if (reportDate.contains('T')) {
                    date = DateTime.parse(reportDate.split('.')[0]);
                  } else {
                    date = DateTime.parse(reportDate);
                  }
                  date = date.add(Duration(days: 1));
                  final adjustedDateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                  return adjustedDateStr == today;
                } catch (e) {
                  return false;
                }
              });
              
              // Check if has machine reports
              final hasMachineReports = reports.any((report) => 
                report['BoPhan']?.toString() == 'Máy móc'
              );
              
              // Determine if this is a machine position based on position name or map name
              bool isMachine = hasMachineReports || 
                            defaultMachineMap ||
                            (position.viTri?.contains('Máy') ?? false) ||
                            (position.viTri?.contains('Robot') ?? false);
              
              // Generate a truly random position within the zone using the triangle method
              final initialPos = _generateRandomPointInPolygon(zonePoints);
              
              final dot = PositionDot(
                positionName: position.viTri ?? 'Vị trí không tên',
                zoneUID: zone.zoneUID!,
                floorUID: floor.floorUID!, 
                position: initialPos,
                hasReportToday: hasReportToday,
                isMachine: isMachine,
                random: Random(),
              );
              
              // Set initial target different from current position
              dot.setNewTarget(zonePoints, random);
              dots.add(dot);
            }
            
            // Store dots for this zone
            zonePositionDots[zone.zoneUID!] = dots;
          }
        }
      } catch (e) {
        print('Error preloading zones for floor ${floor.floorUID}: $e');
      }
    }
  }
  
  // Start dot movement updates
  _startDotMovement();
}

// Add this new method to generate random points in a polygon
Offset _generateRandomPointInPolygon(List<Offset> polygon) {
  if (polygon.length < 3) {
    throw Exception('A polygon must have at least 3 vertices');
  }
  
  // Calculate bounding box
  double minX = double.infinity, maxX = double.negativeInfinity;
  double minY = double.infinity, maxY = double.negativeInfinity;
  
  for (var point in polygon) {
    minX = min(minX, point.dx);
    maxX = max(maxX, point.dx);
    minY = min(minY, point.dy);
    maxY = max(maxY, point.dy);
  }
  
  // Ray casting algorithm to check if point is in polygon
  bool isPointInPolygon(Offset point, List<Offset> polygon) {
    bool isInside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy) &&
          (point.dx < (polygon[j].dx - polygon[i].dx) * (point.dy - polygon[i].dy) / 
          (polygon[j].dy - polygon[i].dy) + polygon[i].dx)) {
        isInside = !isInside;
      }
      j = i;
    }
    
    return isInside;
  }
  
  // Adjusted random point generation with wider distribution
  // Try up to 50 times to find a point inside the polygon
  for (int attempt = 0; attempt < 50; attempt++) {
    final x = minX + random.nextDouble() * (maxX - minX);
    final y = minY + random.nextDouble() * (maxY - minY);
    final point = Offset(x, y);
    
    if (isPointInPolygon(point, polygon)) {
      return point;
    }
  }
  
  // Fallback: If we couldn't find a point inside the polygon after 50 attempts,
  // return a point near a random vertex of the polygon
  int vertexIndex = random.nextInt(polygon.length);
  return Offset(
    polygon[vertexIndex].dx + (random.nextDouble() - 0.5) * 10,
    polygon[vertexIndex].dy + (random.nextDouble() - 0.5) * 10
  );
}

void _startDotMovement() {
  // Cancel any existing timers first
  _dotAnimationTimer?.cancel();
  _dotTargetTimer?.cancel();
  
  // Move dots every 50ms (20fps) - simple direct movement
  _dotAnimationTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    
    bool anyDotsMoved = false;
    
    // Update all dots' positions
    zonePositionDots.forEach((zoneUID, dots) {
      for (var dot in dots) {
        // Only move dots for the current floor
        if (dot.floorUID == selectedFloorUID) {
          // Store old position to check if it moved
          final oldX = dot.position.dx;
          final oldY = dot.position.dy;
          
          // Update position
          dot.updatePosition(0); // t parameter no longer used
          
          // Check if it moved significantly
          if ((dot.position.dx - oldX).abs() > 0.5 || 
              (dot.position.dy - oldY).abs() > 0.5) {
            anyDotsMoved = true;
          }
        }
      }
    });
    
    // Only rebuild if dots actually moved
    if (anyDotsMoved) {
      setState(() {
        // Nothing needed here, just trigger rebuild
      });
    }
  });
  
  // Set new targets every 3 seconds
  _dotTargetTimer = Timer.periodic(Duration(seconds: 3), (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    
    // Set new targets for all dots
    zonePositionDots.forEach((zoneUID, dots) {
      // Skip dots that aren't for the current floor
      if (dots.isEmpty || dots.first.floorUID != selectedFloorUID) {
        return;
      }
      
      // Get the zone for these dots
      final zones = zoneCache[selectedFloorUID] ?? [];
      final zone = zones.firstWhere(
        (z) => z.zoneUID == zoneUID, 
        orElse: () => MapZoneModel()
      );
      
      if (zone.zoneUID == null || zone.cacDiemMoc == null) return;
      
      // Parse zone boundary points
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
        return;
      }
      
      if (zonePoints.length < 3) return;
      
      // Set new targets for all dots in this zone
      for (var dot in dots) {
        dot.setNewTarget(zonePoints, random);
        
        // Print movement info for debugging
        print('Setting new target for dot in zone ${zone.tenKhuVuc}: '
            'From (${dot.position.dx.toStringAsFixed(1)}, ${dot.position.dy.toStringAsFixed(1)}) '
            'to (${dot.targetPosition.dx.toStringAsFixed(1)}, ${dot.targetPosition.dy.toStringAsFixed(1)})');
      }
    });
  });
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
  return GestureDetector(
    onTap: _handleUserInteraction,
    onPanDown: _handleUserInteraction,
    behavior: HitTestBehavior.translucent, // Allows gestures to pass through
    child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Báo cáo: ${widget.mapName}'),
            if (_isAutoCycling) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tv, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'TV Mode',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Add manual stop auto-cycle button
          if (_isAutoCycling)
            IconButton(
              icon: Icon(Icons.stop),
              tooltip: 'Dừng chế độ tự động',
              onPressed: () {
                _resetInactivityTimer();
              },
            ),
          // Stats toggle button
          IconButton(
            icon: Icon(_statsVisible ? Icons.analytics : Icons.analytics_outlined),
            tooltip: _statsVisible ? 'Ẩn thống kê' : 'Hiện thống kê',
            onPressed: () {
              _handleUserInteraction(); // Reset timer on interaction
              setState(() {
                _statsVisible = !_statsVisible;
              });
            },
          ),
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
            onPressed: _isSyncing ? null : () {
              _handleUserInteraction(); // Reset timer on interaction
              _syncMapReports();
            },
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
        : Row(
            children: [
              // Main content area
              Expanded(
                child: Column(
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
              ),
              
              // Right side stats panel with animation
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: _statsVisible ? 200 : 0,
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: _statsVisible ? Column(
                  children: [
                    // Stats header with close button
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 3,
                            spreadRadius: 0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Thống kê hôm nay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  _handleUserInteraction(); // Reset timer on interaction
                                  setState(() {
                                    _statsVisible = false;
                                  });
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () {
                          _handleUserInteraction(); // Reset timer on interaction
                          return _loadHoverStats();
                        },
                        child: ListView.builder(
                          itemCount: hoverStats.length,
                          itemBuilder: (context, index) {
                            final stat = hoverStats[index];
                            return _buildStatCard(
                              title: stat['title'],
                              value: stat['value'],
                              icon: stat['icon'],
                              color: stat['color'],
                            );
                          },
                        ),
                      ),
                    ),
                    // Refresh button at bottom
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          _handleUserInteraction(); // Reset timer on interaction
                          _loadHoverStats();
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('Làm mới'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ) : null,
              ),
            ],
          ),
    ),
  );
}
Widget _buildStatCard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Card(
    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
  final Map<String, List<MapZoneModel>> zoneCache = {};
  void _clearZoneWidgetCache() {
  zoneWidgetCache.clear();
}
void _handleFloorChange(String floorUID) {
  if (selectedFloorUID == floorUID) return;
  
  print("Floor changing from ${selectedFloorUID} to ${floorUID}");
  
  // Clear all caches
  zoneWidgetCache.clear();
  
  setState(() {
    // Update floor selection
    selectedFloorUID = floorUID;
    visibleFloors.clear();
    visibleFloors.add(floorUID);
    
    // Force rebuild of zones for this floor only
    print("Cleared zone widget cache for floor change");
  });
  
  // Restart dot animation
  _dotAnimationTimer?.cancel();
  _dotTargetTimer?.cancel();
  _startDotMovement();
  
  // Force immediate rebuild of widget tree
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() {});
  });
}
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
              //Text(
              //  'Xem bản đồ ${widget.mapName}',
              //  style: TextStyle(
              //    fontSize: 18,
              //    fontWeight: FontWeight.bold,
              //  ),
              //),
              //SizedBox(height: 8),
              
              // Floor visibility toggles - show only one floor at a time
              Text('${widget.mapName} / Chọn tầng để hiển thị:'),
              SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: floors.map((floor) {
                  final isVisible = visibleFloors.contains(floor.floorUID);
                  return ChoiceChip(
  label: Text(floor.tenTang ?? 'Không tên'),
  selected: isVisible,
  onSelected: (selected) {
    if (selected) {
      _handleUserInteraction(); // Reset timer on interaction
      _handleFloorChange(floor.floorUID!);
    }
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
// Base map image
if (mapData?.hinhAnhBanDo != null && mapData!.hinhAnhBanDo!.isNotEmpty)
  Positioned.fill(
    child: Opacity(
      opacity: 0.2,
      child: CachedNetworkImage(
        imageUrl: mapData!.hinhAnhBanDo!,
        fit: BoxFit.fill,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 8),
                Text('Đang tải bản đồ...', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(color: Colors.grey[200]),
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
                                      color: Colors.white.withOpacity(0.4),
                                    ),
                                    child: Stack(
                                      children: [
                                       if (floor.hinhAnhTang != null && floor.hinhAnhTang!.isNotEmpty)
  Positioned.fill(
    child: CachedNetworkImage(
      imageUrl: floor.hinhAnhTang!,
      fit: BoxFit.fill,
      placeholder: (context, url) => Container(
        color: Colors.transparent,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) => SizedBox(),
    ),
  ),
                                      ],
                                    ),
                                  ),
                                  
                                  FutureBuilder<List<MapZoneModel>>(
  key: ValueKey("floor_zones_${floor.floorUID}"), // Add a key that changes with floor
  future: dbHelper.getMapZonesByFloorUID(floor.floorUID!), // Always get fresh data
  builder: (context, snapshot) {
  print("Building zones for floor ${floor.floorUID}, selected floor is ${selectedFloorUID}");

    // Only use cache if it's valid for the current floor
    if (zoneWidgetCache.containsKey(floor.floorUID) && selectedFloorUID == floor.floorUID) {
      return zoneWidgetCache[floor.floorUID]!;
    }
    
    // Clear cache for other floors to ensure correct display
    for (final key in List.from(zoneWidgetCache.keys)) {
      if (key != floor.floorUID) {
        zoneWidgetCache.remove(key);
      }
    }
    
    if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      print("Error loading zones: ${snapshot.error}");
      return Center(child: Text("Error loading zone data"));
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
    
    final List<Widget> allZoneWidgets = [];
    
    // First add the zone polygons
    for (var zone in zones) {
      // Parse color
      Color zoneColor = _parseColor(zone.mauSac ?? '#3388FF80');
      final scaledPoints = zonePointsMap[zone.zoneUID] ?? [];
      
      allZoneWidgets.add(
        GestureDetector(
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
        )
      );
      
      // Now add position dots for this zone
      final dots = zonePositionDots[zone.zoneUID] ?? [];
      if (zone.floorUID == selectedFloorUID) {

      for (var dot in dots) {
        // Update dot position based on animation controller
        dot.updatePosition(_dotsAnimationController.value);
        
        // Scale dot position to match the floor dimensions
        final xPercent = (dot.position.dx - (floor.offsetX ?? 0)) / floorWidth;
        final yPercent = (dot.position.dy - (floor.offsetY ?? 0)) / floorHeight;
        
        final scaledX = xPercent * widthPercent * width / 100;
        final scaledY = yPercent * heightPercent * height / 100;
        
        allZoneWidgets.add(
  Positioned(
    left: scaledX - 10,
    top: scaledY - 10,
    child: GestureDetector(
      onTap: () {
        _showPositionChecklist(dot.positionName);
      },
      child: Container(
        width: 29,
        height: 29, 
        decoration: BoxDecoration(
          color: dot.hasReportToday ? Colors.green.shade600 : Colors.red.shade600,
          shape: dot.isMachine ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: dot.isMachine ? BorderRadius.circular(4) : null,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 4,
              spreadRadius: 1,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            dot.iconData, 
            size: 12,
            color: Colors.white,
          ),
        ),
      ),
    ),
  )
);
      }
    }
    }
    final stackWidget = Stack(children: allZoneWidgets);
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
  void _showPositionChecklist(String positionName) async {
  try {
    // Fetch checklist items for this position
    final db = await dbHelper.database;
    final items = await db.query(
      DatabaseTables.checklistTable,
      where: 'VITRI = ?',
      whereArgs: [positionName]
    );
    
    // Fetch report images for this position
    final reports = await dbHelper.getReportsByPosition(positionName);
    final reportImages = reports
        .where((report) => report['HinhAnh'] != null && report['HinhAnh'].toString().isNotEmpty)
        .map((report) => report['HinhAnh'].toString())
        .toList();
    
    // Show dialog with checklist items and images
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vị trí: $positionName'),
        content: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images section
              if (reportImages.isNotEmpty) ...[
                Text('Hình ảnh báo cáo (${reportImages.length}):', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Container(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: reportImages.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
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
                                    child: CachedNetworkImage(
  imageUrl: reportImages[index],
  fit: BoxFit.contain,
  placeholder: (context, url) => Center(
    child: CircularProgressIndicator(),
  ),
  errorWidget: (context, url, error) => Text('Không thể tải hình ảnh: $error'),
),
                                  ),
                                ),
                                backgroundColor: Colors.black,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 100,
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
  borderRadius: BorderRadius.circular(7),
  child: CachedNetworkImage(
    imageUrl: reportImages[index],
    fit: BoxFit.cover,
    placeholder: (context, url) => Container(
      color: Colors.grey.shade200,
      child: Center(child: CircularProgressIndicator(strokeWidth: 1)),
    ),
    errorWidget: (context, url, error) => Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.broken_image, color: Colors.grey),
    ),
  ),
),
                        ),
                      );
                    },
                  ),
                ),
                Divider(height: 24),
              ],
              
              // Checklist header
              Text('Danh sách công việc' + (items.isEmpty ? ': Không có' : ' (${items.length}):'), 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              
              // Checklist items
              Expanded(
                child: items.isEmpty
                  ? Center(child: Text('Không có công việc nào cho vị trí này'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item['TASK']?.toString() ?? 'Không có tên'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item['START'] != null && item['END'] != null)
                                  Text('${item['START']} - ${item['END']}'),
                                if (item['WEEKDAY'] != null)
                                  Text('${item['WEEKDAY']}'),
                              ],
                            ),
                            leading: Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                          ),
                        );
                      },
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
      ),
    );
  } catch (e) {
    print('Error showing position checklist and images: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi: $e'))
    );
  }
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
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${reports.length} báo cáo'),
          // Add the "Xem lịch" button here
          TextButton.icon(
            icon: Icon(Icons.schedule, size: 16),
            label: Text('Xem lịch'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size(80, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Navigator.pop(context); // Close the zone info dialog
              _showPositionChecklist(position.viTri ?? '');
            },
          ),
        ],
      ),
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
String _normalizeDateString(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  
  try {
    DateTime date;
    if (dateStr.contains('T')) {
      date = DateTime.parse(dateStr.split('.')[0]);
    } else if (dateStr.contains('/')) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } else {
        date = DateTime.now();
      }
    } else {
      date = DateTime.parse(dateStr);
    }
    // Add one day to fix the -1 day issue
    date = date.add(Duration(days: 1));
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  } catch (e) {
    print('Error normalizing date: $e for date string: $dateStr');
    return dateStr; 
  }
}
bool _hasReportToday(List<Map<String, dynamic>> reports, String today) {
  return reports.any((report) {
    final reportDate = report['Ngay']?.toString() ?? '';
    if (reportDate.isEmpty) return false;
    try {
      DateTime date;
      if (reportDate.contains('T')) {
        date = DateTime.parse(reportDate.split('.')[0]);
      } else {
        date = DateTime.parse(reportDate);
      }
      date = date.add(Duration(days: 1));
      final adjustedDateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      return adjustedDateStr == today;
    } catch (e) {
      print('Error parsing date in _hasReportToday: $e');
      return false;
    }
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
                                      child: ClipRRect(
  borderRadius: BorderRadius.circular(3),
  child: CachedNetworkImage(
    imageUrl: report['HinhAnh'],
    fit: BoxFit.cover,
    placeholder: (context, url) => Center(
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1),
      ),
    ),
    errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 20),
  ),
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
                            child: CachedNetworkImage(
  imageUrl: report['HinhAnh'],
  fit: BoxFit.contain,
  placeholder: (context, url) => Center(child: CircularProgressIndicator()),
  errorWidget: (context, url, error) => Text('Không thể tải hình ảnh: $error'),
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
class PositionDot {
  final String positionName;
  final String zoneUID;
  final String floorUID;
  Offset position;
  Offset targetPosition;
  bool hasReportToday;
  bool isMachine; 
  IconData iconData; 
  Color color;
  Random random;
  
  PositionDot({
    required this.positionName,
    required this.zoneUID,
    required this.floorUID, 
    required this.position,
    required this.hasReportToday,
    required this.isMachine,
    required this.random,
  }) : 
    targetPosition = position,
    color = hasReportToday ? Colors.green.shade600 : Colors.red.shade600,
    iconData = Icons.person {
      // Determine the appropriate icon based on position name
      if (positionName.contains('Máy')) {
        iconData = Icons.ice_skating;
      } else if (positionName.contains('Robot')) {
        iconData = Icons.auto_awesome;
      } else if (isMachine) {
        iconData = Icons.ice_skating;
      }
    }
  
  void updatePosition(double t) {
  // Skip the animation controller value and just move directly toward target
  // Use a fixed amount like 5% of the distance each time
  final dx = targetPosition.dx - position.dx;
  final dy = targetPosition.dy - position.dy;
  
  // Move 5% of the way to the target each time
  position = Offset(
    position.dx + dx * 0.05,
    position.dy + dy * 0.05
  );
}
  
  void setNewTarget(List<Offset> zoneBoundary, Random random) {
    // Get random point within zone polygon
    if (zoneBoundary.length < 3) return;
    
    // Simple method: find bounding box and try random points until one is inside the polygon
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    
    for (var point in zoneBoundary) {
      minX = min(minX, point.dx);
      maxX = max(maxX, point.dx);
      minY = min(minY, point.dy);
      maxY = max(maxY, point.dy);
    }
    
    bool isPointInPolygon(Offset point, List<Offset> polygon) {
      bool isInside = false;
      int i = 0, j = polygon.length - 1;
      
      for (i = 0; i < polygon.length; i++) {
        if (((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy)) &&
            (point.dx < (polygon[j].dx - polygon[i].dx) * (point.dy - polygon[i].dy) / 
            (polygon[j].dy - polygon[i].dy) + polygon[i].dx)) {
          isInside = !isInside;
        }
        j = i;
      }
      
      return isInside;
    }
    
    // Try up to 10 times to find a point inside the polygon
    for (int i = 0; i < 10; i++) {
      final newX = minX + random.nextDouble() * (maxX - minX);
      final newY = minY + random.nextDouble() * (maxY - minY);
      final testPoint = Offset(newX, newY);
      
      if (isPointInPolygon(testPoint, zoneBoundary)) {
        targetPosition = testPoint;
        return;
      }
    }
    
    // If we couldn't find a point inside, just use the current position
    targetPosition = position;
  }
}
class DotsPainter extends CustomPainter {
  final List<PositionDot> dots;
  final Map<String, double> dotScaleFactors; // Scaling factors by floorUID
  
  DotsPainter({required this.dots, required this.dotScaleFactors});
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var dot in dots) {
      final scale = dotScaleFactors[dot.floorUID] ?? 1.0;
      
      // Draw dot
      final paint = Paint()
        ..color = dot.color
        ..style = PaintingStyle.fill;
      
      // Draw shadow first
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(
        Offset(dot.position.dx, dot.position.dy),
        12 * scale, // Shadow slightly larger
        shadowPaint
      );
      
      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      
      canvas.drawCircle(
        Offset(dot.position.dx, dot.position.dy),
        10 * scale,
        borderPaint
      );
      
      // Draw dot itself
      canvas.drawCircle(
        Offset(dot.position.dx, dot.position.dy),
        10 * scale,
        paint
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant DotsPainter oldDelegate) {
    // Always repaint when dot positions change
    return true;
  }
}