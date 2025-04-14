// db_helper.dart
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'table_models.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:path_provider/path_provider.dart';
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() => _instance;

  DBHelper._internal() {
    // Initialize FFI for Windows/Linux
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  Future<Database> _initDatabase() async {
  try {
    String path;
    if (Platform.isWindows || Platform.isLinux) {
      final appDir = await getApplicationDocumentsDirectory();
      path = join(appDir.path, 'app_database.db');
    } else {
      path = join(await getDatabasesPath(), 'app_database.db');
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasReset = prefs.getBool('db_reset_v20') ?? false;
    
    if (!hasReset) {
      print('Forcing database reset for version 20...');
      try {
        await deleteDatabase(path);
        await prefs.setBool('db_reset_v20', true);
        print('Database reset successful');
      } catch (e) {
        print('Error during database reset: $e');
      }
    }
    
    await Directory(dirname(path)).create(recursive: true);
    
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 20,
        onCreate: (Database db, int version) async {
          print('Creating database tables...');
          await db.execute(DatabaseTables.createInteractionTable);
          await db.execute(DatabaseTables.createStaffbioTable);
          await db.execute(DatabaseTables.createChecklistTable);
          await db.execute(DatabaseTables.createTaskHistoryTable);
          await db.execute(DatabaseTables.createVTHistoryTable);
          await db.execute(DatabaseTables.createStaffListTable);
          await db.execute(DatabaseTables.createPositionListTable);
          await db.execute(DatabaseTables.createProjectListTable);
          await db.execute(DatabaseTables.createBaocaoTable);
          await db.execute(DatabaseTables.createDongPhucTable);
          await db.execute(DatabaseTables.createChiTietDPTable);
          await db.execute(DatabaseTables.createOrderMatHangTable);
          await db.execute(DatabaseTables.createOrderTable);
          await db.execute(DatabaseTables.createOrderChiTietTable);
          await db.execute(DatabaseTables.createOrderDinhMucTable);
          await db.execute(DatabaseTables.createChamCongCNTable);
          await db.execute(DatabaseTables.createHinhAnhZaloTable);
          await db.execute(DatabaseTables.createHDDuTruTable); 
          await db.execute(DatabaseTables.createHDChiTietYCMMTable); 
          await db.execute(DatabaseTables.createHDYeuCauMMTable); 
          await db.execute(DatabaseTables.createChamCongTable); 
          await db.execute(DatabaseTables.createChamCongGioTable); 
          await db.execute(DatabaseTables.createChamCongLSTable);  
          await db.execute(DatabaseTables.createChamCongCNThangTable); 
          await db.execute(DatabaseTables.createChamCongVangNghiTcaTable); 
          await ChecklistInitializer.initializeChecklistTable(db);
          await db.execute(DatabaseTables.createMapListTable);
          await db.execute(DatabaseTables.createMapFloorTable);
          await db.execute(DatabaseTables.createMapZoneTable);
          await db.execute(DatabaseTables.createCoinTable);
          await db.execute(DatabaseTables.createCoinRateTable);
          await db.execute(DatabaseTables.createMapStaffTable);
          await db.execute(DatabaseTables.createMapPositionTable);
          print('Database tables created successfully');
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 20) {

          }
        },
        onOpen: (db) async {
          print('Database opened successfully');
          final tables = await db.query('sqlite_master', 
            where: 'type = ?', 
            whereArgs: ['table']
          );
          print('Available tables: ${tables.map((t) => t['name']).toList()}');
        }
      ),
    );

    return db;

  } catch (e, stackTrace) {
    print('Error initializing database: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}
// ==================== MapStaff CRUD Operations ====================
Future<List<MapStaffModel>> getAllMapStaff() async {
  final staffs = await query(DatabaseTables.mapStaffTable);
  return staffs.map((staff) => MapStaffModel.fromMap(staff)).toList();
}

Future<MapStaffModel?> getMapStaffByUID(String uid) async {
  final staffs = await query(
    DatabaseTables.mapStaffTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
  if (staffs.isNotEmpty) {
    return MapStaffModel.fromMap(staffs.first);
  }
  return null;
}

Future<List<MapStaffModel>> getMapStaffByProject(String mapProject) async {
  final staffs = await query(
    DatabaseTables.mapStaffTable,
    where: 'mapProject = ?',
    whereArgs: [mapProject],
  );
  return staffs.map((staff) => MapStaffModel.fromMap(staff)).toList();
}

Future<List<MapStaffModel>> getMapStaffByUser(String nguoiDung) async {
  final staffs = await query(
    DatabaseTables.mapStaffTable,
    where: 'nguoiDung = ?',
    whereArgs: [nguoiDung],
  );
  return staffs.map((staff) => MapStaffModel.fromMap(staff)).toList();
}

Future<void> insertMapStaff(MapStaffModel staff) async {
  await insert(DatabaseTables.mapStaffTable, staff.toMap());
}

Future<void> updateMapStaff(MapStaffModel staff) async {
  await update(
    DatabaseTables.mapStaffTable,
    staff.toMap(),
    where: 'uid = ?',
    whereArgs: [staff.uid],
  );
}

Future<void> deleteMapStaff(String uid) async {
  await delete(
    DatabaseTables.mapStaffTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
}

// ==================== MapPosition CRUD Operations ====================
// Get positions in a specific zone
Future<List<MapPositionModel>> getMapPositionsByZone({
  required String mapUID,
  required String floorUID, 
  required String zoneUID,
}) async {
  final db = await database;
  
  // First, get the actual names from the IDs
  final mapList = await db.query(
    DatabaseTables.mapListTable,
    columns: ['tenBanDo'],
    where: 'mapUID = ?',
    whereArgs: [mapUID],
    limit: 1
  );
  
  final mapFloor = await db.query(
    DatabaseTables.mapFloorTable,
    columns: ['tenTang'],
    where: 'floorUID = ?',
    whereArgs: [floorUID],
    limit: 1
  );
  
  final mapZone = await db.query(
    DatabaseTables.mapZoneTable,
    columns: ['tenKhuVuc'],
    where: 'zoneUID = ?',
    whereArgs: [zoneUID],
    limit: 1
  );
  
  if (mapList.isEmpty || mapFloor.isEmpty || mapZone.isEmpty) {
    print('Could not find map, floor, or zone names for the specified IDs');
    return [];
  }
  
  final mapName = mapList.first['tenBanDo'] as String;
  final floorName = mapFloor.first['tenTang'] as String;
  final zoneName = mapZone.first['tenKhuVuc'] as String;
  
  print('Searching for positions with MapList=$mapName, MapFloor=$floorName, MapZone=$zoneName');
  
  // Now query by names instead of IDs
  final result = await db.query(
    DatabaseTables.mapPositionTable,
    where: 'MapList = ? AND MapFloor = ? AND MapZone = ?',
    whereArgs: [mapName, floorName, zoneName],
  );
  
  print('Found ${result.length} map positions');
  return result.map((e) => MapPositionModel.fromMap(e)).toList();
}

// Get all reports for a specific position
Future<List<Map<String, dynamic>>> getReportsByPosition(String position) async {
  final db = await database;
  print('Searching for reports with ViTri = $position');
  
  // Query TaskHistory table where ViTri exactly matches the position and PhanLoai is 'map_report'
  final result = await db.query(
    DatabaseTables.taskHistoryTable,
    where: 'ViTri = ? AND PhanLoai = ?',
    whereArgs: [position, 'map_report'],
    orderBy: 'Ngay DESC, Gio DESC',
  );
  
  print('Found ${result.length} reports for position $position');
  return result;
}

// Get total report count for a zone
Future<int> getReportCountForZone({required String zoneUID}) async {
  final db = await database;
  print('Looking for report count for zone: $zoneUID');
  
  // First get the zone name
  final zoneResult = await db.query(
    DatabaseTables.mapZoneTable,
    columns: ['tenKhuVuc'],
    where: 'zoneUID = ?',
    whereArgs: [zoneUID],
    limit: 1
  );
  
  if (zoneResult.isEmpty) {
    print('Could not find zone with ID $zoneUID');
    return 0;
  }
  
  final zoneName = zoneResult.first['tenKhuVuc'] as String;
  
  // Get all positions in this zone
  final positions = await db.query(
    DatabaseTables.mapPositionTable,
    columns: ['ViTri'],
    where: 'MapZone = ?',
    whereArgs: [zoneName],
  );
  
  print('Found ${positions.length} positions in zone $zoneName');
  
  if (positions.isEmpty) return 0;
  
  final positionNames = positions.map((p) => p['ViTri'] as String).toList();
  print('Position names: $positionNames');
  
  // Count reports for each position
  int totalCount = 0;
  for (var pos in positionNames) {
    final countResult = await db.query(
      DatabaseTables.taskHistoryTable,
      columns: ['COUNT(*) as count'],
      where: 'ViTri = ? AND PhanLoai = ?',
      whereArgs: [pos, 'map_report'],
    );
    
    if (countResult.isNotEmpty) {
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      totalCount += count;
      print('Found $count reports for position $pos');
    }
  }
  
  print('Total reports for zone $zoneName: $totalCount');
  return totalCount;
}

// Calculate average daily report count for a zone
Future<double> getAverageDailyReportCountForZone({required String zoneUID}) async {
  final db = await database;
  print('Calculating average daily report count for zone: $zoneUID');
  
  // Get total report count
  final totalReports = await getReportCountForZone(zoneUID: zoneUID);
  
  if (totalReports == 0) return 0.0;
  
  // Get zone name
  final zoneResult = await db.query(
    DatabaseTables.mapZoneTable,
    columns: ['tenKhuVuc'],
    where: 'zoneUID = ?',
    whereArgs: [zoneUID],
    limit: 1
  );
  
  if (zoneResult.isEmpty) {
    print('Could not find zone with ID $zoneUID');
    return 0.0;
  }
  
  final zoneName = zoneResult.first['tenKhuVuc'] as String;
  
  // Get positions in this zone
  final positions = await db.query(
    DatabaseTables.mapPositionTable,
    columns: ['ViTri'],
    where: 'MapZone = ?',
    whereArgs: [zoneName],
  );
  
  if (positions.isEmpty) return 0.0;
  
  final positionNames = positions.map((p) => p['ViTri'] as String).toList();
  
  // Get distinct days with reports for these positions
  Set<String> uniqueDays = {};
  
  for (var pos in positionNames) {
    final daysResult = await db.query(
      DatabaseTables.taskHistoryTable,
      columns: ['DISTINCT Ngay'],
      where: 'ViTri = ? AND PhanLoai = ?',
      whereArgs: [pos, 'map_report'],
    );
    
    for (var day in daysResult) {
      uniqueDays.add(day['Ngay'] as String);
    }
  }
  
  final totalDays = uniqueDays.length;
  print('Found reports on ${totalDays} unique days for zone $zoneName');
  
  // Avoid division by zero
  if (totalDays == 0) return 0.0;
  
  return totalReports / totalDays;
}
// Debug function to check TaskHistory records
Future<void> debugTaskHistoryViTri() async {
  final db = await database;
  
  // Get all distinct ViTri values from TaskHistory table where PhanLoai is map_report
  final distinctViTriResult = await db.rawQuery(
    'SELECT DISTINCT ViTri FROM ${DatabaseTables.taskHistoryTable} WHERE PhanLoai = ?',
    ['map_report']
  );
  
  print('Found ${distinctViTriResult.length} distinct ViTri values in TaskHistory with PhanLoai = map_report:');
  for (var item in distinctViTriResult) {
    print('ViTri: "${item['ViTri']}"');
  }
  
  // Get a sample of records for each ViTri
  for (var item in distinctViTriResult) {
    final vitri = item['ViTri'];
    final sampleRecords = await db.query(
      DatabaseTables.taskHistoryTable,
      where: 'ViTri = ? AND PhanLoai = ?',
      whereArgs: [vitri, 'map_report'],
      limit: 2
    );
    
    print('\nSample records for ViTri = "$vitri":');
    for (var record in sampleRecords) {
      print('UID: ${record['UID']}, Date: ${record['Ngay']}, Result: ${record['KetQua']}');
    }
  }
  
  // Also check what positions are in MapPosition table
  final positionResult = await db.query(DatabaseTables.mapPositionTable, limit: 10);
  print('\nSample of positions in MapPosition table (max 10):');
  for (var pos in positionResult) {
    print('UID: ${pos['uid']}, MapList: ${pos['mapList']}, MapZone: ${pos['mapZone']}, ViTri: "${pos['viTri']}"');
  }
  
  // Compare ViTri values to see matches
  final mapPositionViTri = await db.rawQuery(
    'SELECT DISTINCT viTri FROM ${DatabaseTables.mapPositionTable}'
  );
  
  final taskHistoryViTri = await db.rawQuery(
    'SELECT DISTINCT ViTri FROM ${DatabaseTables.taskHistoryTable} WHERE PhanLoai = ?',
    ['map_report']
  );
  
  final mapPositionViTriValues = mapPositionViTri.map((item) => item['viTri'].toString()).toSet();
  final taskHistoryViTriValues = taskHistoryViTri.map((item) => item['ViTri'].toString()).toSet();
  
  final intersection = mapPositionViTriValues.intersection(taskHistoryViTriValues);
  
  print('\nComparison of ViTri values:');
  print('MapPosition distinct ViTri count: ${mapPositionViTriValues.length}');
  print('TaskHistory distinct ViTri count: ${taskHistoryViTriValues.length}');
  print('Matching ViTri values between tables: ${intersection.length}');
  
  if (intersection.isEmpty) {
    print('\nNo matching ViTri values found! Sample comparison:');
    print('MapPosition ViTri examples: ${mapPositionViTriValues.take(5).join(", ")}');
    print('TaskHistory ViTri examples: ${taskHistoryViTriValues.take(5).join(", ")}');
  } else {
    print('\nMatching ViTri examples: ${intersection.take(5).join(", ")}');
  }
}
Future<void> debugTableRecordCounts() async {
  final db = await database;
  
  // Check TaskHistory table
  final taskHistoryCount = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.taskHistoryTable}')
  ) ?? 0;
  
  print('TaskHistory table record count: $taskHistoryCount');
  
  // Check if there are any map_report records specifically
  final mapReportCount = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.taskHistoryTable} WHERE PhanLoai = ?', ['map_report'])
  ) ?? 0;
  
  print('TaskHistory records with PhanLoai = "map_report": $mapReportCount');
  
  // Check other relevant tables
  final mapPositionCount = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.mapPositionTable}')
  ) ?? 0;
  
  print('MapPosition table record count: $mapPositionCount');
  
  final mapZoneCount = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.mapZoneTable}')
  ) ?? 0;
  
  print('MapZone table record count: $mapZoneCount');
  
  // Check the last sync date for map data
  final prefs = await SharedPreferences.getInstance();
  final lastSyncDate = prefs.getString('last_map_sync_date') ?? 'Never';
  
  print('Last map sync date: $lastSyncDate');
}
Future<void> addTestMapReports() async {
  final db = await database;
  
  // First check if there are already map reports
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.taskHistoryTable} WHERE PhanLoai = ?', ['map_report'])
  ) ?? 0;
  
  if (count > 0) {
    print('Map reports already exist. No test data added.');
    return;
  }
  
  print('Adding test map reports...');
  
  // Get positions from MapPosition table
  final positions = await db.query(DatabaseTables.mapPositionTable);
  
  if (positions.isEmpty) {
    print('No positions found in MapPosition table. Cannot create test reports.');
    return;
  }
  
  // Create test reports for each position
  final batch = db.batch();
  final today = DateTime.now();
  final random = Random();
  
  for (var position in positions) {
    final viTri = position['viTri'];
    if (viTri == null || viTri.toString().isEmpty) continue;
    
    // Randomize the number of reports for this position (0-5)
    final reportCount = random.nextInt(6);
    
    for (int i = 0; i < reportCount; i++) {
      // Create a report date between today and 30 days ago
      final daysAgo = random.nextInt(30);
      final reportDate = today.subtract(Duration(days: daysAgo));
      final formattedDate = DateFormat('yyyy-MM-dd').format(reportDate);
      
      // Randomize report time
      final hour = random.nextInt(12) + 8; // 8am to 8pm
      final minute = random.nextInt(60);
      final formattedTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
      
      // Create varied report text
      final resultOptions = [
        'Kiểm tra vệ sinh',
        'Kiểm tra thiết bị',
        'Đánh giá chất lượng',
        'Báo cáo sự cố',
        'Báo cáo tình trạng',
      ];
      
      final detailOptions = [
        'Đã kiểm tra và xử lý',
        'Cần bổ sung vật tư',
        'Hoạt động bình thường',
        'Có vấn đề cần xử lý',
        'Cần kiểm tra lại',
      ];
      
      final solutionOptions = [
        'Tiếp tục theo dõi',
        'Cần báo cáo quản lý',
        'Đã xử lý xong',
        'Cần gọi bảo trì',
        'Không cần xử lý thêm',
      ];
      
      final result = resultOptions[random.nextInt(resultOptions.length)];
      final detail = detailOptions[random.nextInt(detailOptions.length)];
      final solution = solutionOptions[random.nextInt(solutionOptions.length)];
      
      // Create unique UID for each report
      final uid = 'test-${viTri.toString().hashCode}-$i-${DateTime.now().millisecondsSinceEpoch}';
      
      batch.insert(DatabaseTables.taskHistoryTable, {
        'UID': uid,
        'NguoiDung': 'TestUser',
        'TaskID': 'test-task-$i',
        'KetQua': result,
        'Ngay': formattedDate,
        'Gio': formattedTime,
        'ChiTiet': '$detail cho vị trí $viTri',
        'ChiTiet2': '',
        'ViTri': viTri.toString(),
        'BoPhan': position['MapZone']?.toString() ?? 'Test Zone',
        'PhanLoai': 'map_report',
        'HinhAnh': '',
        'GiaiPhap': solution,
      });
    }
  }
  
  await batch.commit();
  print('Added varied test map reports for ${positions.length} positions');
}
Future<List<MapPositionModel>> getAllMapPositions() async {
  final positions = await query(DatabaseTables.mapPositionTable);
  return positions.map((position) => MapPositionModel.fromMap(position)).toList();
}

Future<MapPositionModel?> getMapPositionByUID(String uid) async {
  final positions = await query(
    DatabaseTables.mapPositionTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
  if (positions.isNotEmpty) {
    return MapPositionModel.fromMap(positions.first);
  }
  return null;
}

Future<List<MapPositionModel>> getMapPositionsByMapList(String mapList) async {
  final positions = await query(
    DatabaseTables.mapPositionTable,
    where: 'mapList = ?',
    whereArgs: [mapList],
  );
  return positions.map((position) => MapPositionModel.fromMap(position)).toList();
}

Future<List<MapPositionModel>> getMapPositionsByFloor(String mapFloor) async {
  final positions = await query(
    DatabaseTables.mapPositionTable,
    where: 'mapFloor = ?',
    whereArgs: [mapFloor],
  );
  return positions.map((position) => MapPositionModel.fromMap(position)).toList();
}

Future<void> insertMapPosition(MapPositionModel position) async {
  await insert(DatabaseTables.mapPositionTable, position.toMap());
}

Future<void> updateMapPosition(MapPositionModel position) async {
  await update(
    DatabaseTables.mapPositionTable,
    position.toMap(),
    where: 'uid = ?',
    whereArgs: [position.uid],
  );
}

Future<void> deleteMapPosition(String uid) async {
  await delete(
    DatabaseTables.mapPositionTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
}
// ==================== Coin CRUD Operations ====================
Future<List<CoinModel>> getAllCoins() async {
  final coins = await query(DatabaseTables.coinTable);
  return coins.map((coin) => CoinModel.fromMap(coin)).toList();
}

Future<CoinModel?> getCoinByUID(String uid) async {
  final coins = await query(
    DatabaseTables.coinTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
  if (coins.isNotEmpty) {
    return CoinModel.fromMap(coins.first);
  }
  return null;
}

Future<List<CoinModel>> getCoinsByUser(String nguoiDung) async {
  final coins = await query(
    DatabaseTables.coinTable,
    where: 'nguoiDung = ?',
    whereArgs: [nguoiDung],
  );
  return coins.map((coin) => CoinModel.fromMap(coin)).toList();
}

Future<List<CoinModel>> getCoinsByDate(String date) async {
  final coins = await query(
    DatabaseTables.coinTable,
    where: 'ngay = ?',
    whereArgs: [date],
  );
  return coins.map((coin) => CoinModel.fromMap(coin)).toList();
}

Future<void> insertCoin(CoinModel coin) async {
  await insert(DatabaseTables.coinTable, coin.toMap());
}

Future<void> updateCoin(CoinModel coin) async {
  await update(
    DatabaseTables.coinTable,
    coin.toMap(),
    where: 'uid = ?',
    whereArgs: [coin.uid],
  );
}

Future<void> deleteCoin(String uid) async {
  await delete(
    DatabaseTables.coinTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
}

Future<void> batchInsertCoins(List<CoinModel> coins) async {
  final db = await database;
  final batch = db.batch();
  for (var coin in coins) {
    batch.insert(DatabaseTables.coinTable, coin.toMap());
  }
  await batch.commit(noResult: true);
}

// ==================== CoinRate CRUD Operations ====================
Future<List<CoinRateModel>> getAllCoinRates() async {
  final rates = await query(DatabaseTables.coinRateTable);
  return rates.map((rate) => CoinRateModel.fromMap(rate)).toList();
}

Future<CoinRateModel?> getCoinRateByUID(String uid) async {
  final rates = await query(
    DatabaseTables.coinRateTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
  if (rates.isNotEmpty) {
    return CoinRateModel.fromMap(rates.first);
  }
  return null;
}

Future<CoinRateModel?> getCoinRateByCase(String caseType) async {
  final rates = await query(
    DatabaseTables.coinRateTable,
    where: 'case = ?',
    whereArgs: [caseType],
  );
  if (rates.isNotEmpty) {
    return CoinRateModel.fromMap(rates.first);
  }
  return null;
}

Future<void> insertCoinRate(CoinRateModel rate) async {
  await insert(DatabaseTables.coinRateTable, rate.toMap());
}

Future<void> updateCoinRate(CoinRateModel rate) async {
  await update(
    DatabaseTables.coinRateTable,
    rate.toMap(),
    where: 'uid = ?',
    whereArgs: [rate.uid],
  );
}

Future<void> deleteCoinRate(String uid) async {
  await delete(
    DatabaseTables.coinRateTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
}

Future<void> batchInsertCoinRates(List<CoinRateModel> rates) async {
  final db = await database;
  final batch = db.batch();
  for (var rate in rates) {
    batch.insert(DatabaseTables.coinRateTable, rate.toMap());
  }
  await batch.commit(noResult: true);
}
// ==================== MapList CRUD Operations ====================
Future<List<MapListModel>> getAllMapLists() async {
  final maps = await query(DatabaseTables.mapListTable);
  return maps.map((map) => MapListModel.fromMap(map)).toList();
}

Future<MapListModel?> getMapListByUID(String mapUID) async {
  final maps = await query(
    DatabaseTables.mapListTable,
    where: 'mapUID = ?',
    whereArgs: [mapUID],
  );
  if (maps.isNotEmpty) {
    return MapListModel.fromMap(maps.first);
  }
  return null;
}

Future<List<MapListModel>> getMapListsByUser(String nguoiDung) async {
  final maps = await query(
    DatabaseTables.mapListTable,
    where: 'nguoiDung = ?',
    whereArgs: [nguoiDung],
  );
  return maps.map((map) => MapListModel.fromMap(map)).toList();
}

Future<void> insertMapList(MapListModel mapList) async {
  await insert(DatabaseTables.mapListTable, mapList.toMap());
}

Future<void> updateMapList(MapListModel mapList) async {
  await update(
    DatabaseTables.mapListTable,
    mapList.toMap(),
    where: 'mapUID = ?',
    whereArgs: [mapList.mapUID],
  );
}

Future<void> deleteMapList(String mapUID) async {
  await delete(
    DatabaseTables.mapListTable,
    where: 'mapUID = ?',
    whereArgs: [mapUID],
  );
}
Future<void> batchInsertMapList(List<MapListModel> mapLists) async {
  final db = await database;
  final batch = db.batch();
  for (var mapList in mapLists) {
    batch.insert(DatabaseTables.mapListTable, mapList.toMap());
  }
  await batch.commit(noResult: true);
}
// ==================== MapFloor CRUD Operations ====================
Future<List<MapFloorModel>> getAllMapFloors() async {
  final maps = await query(DatabaseTables.mapFloorTable);
  return maps.map((map) => MapFloorModel.fromMap(map)).toList();
}

Future<MapFloorModel?> getMapFloorByUID(String floorUID) async {
  final maps = await query(
    DatabaseTables.mapFloorTable,
    where: 'floorUID = ?',
    whereArgs: [floorUID],
  );
  if (maps.isNotEmpty) {
    return MapFloorModel.fromMap(maps.first);
  }
  return null;
}

Future<List<MapFloorModel>> getMapFloorsByMapUID(String mapUID) async {
  final maps = await query(
    DatabaseTables.mapFloorTable,
    where: 'mapUID = ?',
    whereArgs: [mapUID],
  );
  return maps.map((map) => MapFloorModel.fromMap(map)).toList();
}

Future<void> insertMapFloor(MapFloorModel mapFloor) async {
  await insert(DatabaseTables.mapFloorTable, mapFloor.toMap());
}

Future<void> updateMapFloor(MapFloorModel mapFloor) async {
  await update(
    DatabaseTables.mapFloorTable,
    mapFloor.toMap(),
    where: 'floorUID = ?',
    whereArgs: [mapFloor.floorUID],
  );
}

Future<void> deleteMapFloor(String floorUID) async {
  await delete(
    DatabaseTables.mapFloorTable,
    where: 'floorUID = ?',
    whereArgs: [floorUID],
  );
}
Future<void> batchInsertMapFloor(List<MapFloorModel> mapFloors) async {
  final db = await database;
  final batch = db.batch();
  for (var mapFloor in mapFloors) {
    batch.insert(DatabaseTables.mapFloorTable, mapFloor.toMap());
  }
  await batch.commit(noResult: true);
}
// ==================== MapZone CRUD Operations ====================
Future<List<MapZoneModel>> getAllMapZones() async {
  final maps = await query(DatabaseTables.mapZoneTable);
  return maps.map((map) => MapZoneModel.fromMap(map)).toList();
}

Future<MapZoneModel?> getMapZoneByUID(String zoneUID) async {
  final maps = await query(
    DatabaseTables.mapZoneTable,
    where: 'zoneUID = ?',
    whereArgs: [zoneUID],
  );
  if (maps.isNotEmpty) {
    return MapZoneModel.fromMap(maps.first);
  }
  return null;
}

Future<List<MapZoneModel>> getMapZonesByFloorUID(String floorUID) async {
  final maps = await query(
    DatabaseTables.mapZoneTable,
    where: 'floorUID = ?',
    whereArgs: [floorUID],
  );
  return maps.map((map) => MapZoneModel.fromMap(map)).toList();
}

Future<void> insertMapZone(MapZoneModel mapZone) async {
  await insert(DatabaseTables.mapZoneTable, mapZone.toMap());
}

Future<void> updateMapZone(MapZoneModel mapZone) async {
  await update(
    DatabaseTables.mapZoneTable,
    mapZone.toMap(),
    where: 'zoneUID = ?',
    whereArgs: [mapZone.zoneUID],
  );
}
Future<void> batchInsertMapZone(List<MapZoneModel> mapZones) async {
  final db = await database;
  final batch = db.batch();
  for (var mapZone in mapZones) {
    batch.insert(DatabaseTables.mapZoneTable, mapZone.toMap());
  }
  await batch.commit(noResult: true);
}
Future<void> deleteMapZone(String zoneUID) async {
  await delete(
    DatabaseTables.mapZoneTable,
    where: 'zoneUID = ?',
    whereArgs: [zoneUID],
  );
}
// ==================== ChamCongVangNghiTca CRUD Operations ====================
Future<List<ChamCongVangNghiTcaModel>> getChamCongVangNghiTcaByNguoiDuyet(String nguoiDuyet) async {
 final maps = await query(
   DatabaseTables.chamCongVangNghiTcaTable,
   where: 'NguoiDuyet = ?',
   whereArgs: [nguoiDuyet],
 );
 return maps.map((map) => ChamCongVangNghiTcaModel.fromMap(map)).toList();
}
Future<void> insertChamCongVangNghiTca(ChamCongVangNghiTcaModel chamCongVangNghiTca) async {
 await insert(DatabaseTables.chamCongVangNghiTcaTable, chamCongVangNghiTca.toMap());
}

Future<List<ChamCongVangNghiTcaModel>> getAllChamCongVangNghiTca() async {
 final maps = await query(DatabaseTables.chamCongVangNghiTcaTable);
 return maps.map((map) => ChamCongVangNghiTcaModel.fromMap(map)).toList();
}

Future<ChamCongVangNghiTcaModel?> getChamCongVangNghiTcaByUID(String uid) async {
 final maps = await query(
   DatabaseTables.chamCongVangNghiTcaTable,
   where: 'UID = ?',
   whereArgs: [uid],
 );
 if (maps.isEmpty) return null;
 return ChamCongVangNghiTcaModel.fromMap(maps.first);
}

Future<List<ChamCongVangNghiTcaModel>> getChamCongVangNghiTcaByNguoiDung(String nguoiDung) async {
 final maps = await query(
   DatabaseTables.chamCongVangNghiTcaTable,
   where: 'NguoiDung = ?',
   whereArgs: [nguoiDung],
 );
 return maps.map((map) => ChamCongVangNghiTcaModel.fromMap(map)).toList();
}

Future<List<ChamCongVangNghiTcaModel>> getChamCongVangNghiTcaByDateRange(DateTime startDate, DateTime endDate) async {
 final maps = await query(
   DatabaseTables.chamCongVangNghiTcaTable,
   where: 'NgayBatDau >= ? AND NgayKetThuc <= ?',
   whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
 );
 return maps.map((map) => ChamCongVangNghiTcaModel.fromMap(map)).toList();
}

Future<List<ChamCongVangNghiTcaModel>> getChamCongVangNghiTcaByTrangThai(String trangThai) async {
 final maps = await query(
   DatabaseTables.chamCongVangNghiTcaTable,
   where: 'TrangThai = ?',
   whereArgs: [trangThai],
 );
 return maps.map((map) => ChamCongVangNghiTcaModel.fromMap(map)).toList();
}

Future<int> updateChamCongVangNghiTca(String uid, Map<String, dynamic> updates) async {
 return await update(
   DatabaseTables.chamCongVangNghiTcaTable,
   updates,
   where: 'UID = ?',
   whereArgs: [uid],
 );
}

Future<int> deleteChamCongVangNghiTca(String uid) async {
 return await delete(
   DatabaseTables.chamCongVangNghiTcaTable,
   where: 'UID = ?',
   whereArgs: [uid],
 );
}

Future<void> batchInsertChamCongVangNghiTca(List<ChamCongVangNghiTcaModel> items) async {
 final db = await database;
 await db.transaction((txn) async {
   final batch = txn.batch();
   for (var item in items) {
     batch.insert(
       DatabaseTables.chamCongVangNghiTcaTable, 
       item.toMap(),
       conflictAlgorithm: ConflictAlgorithm.replace
     );
   }
   await batch.commit(noResult: true);
 });
}
// ==================== ChamCongCNThang CRUD Operations ====================
Future<void> insertChamCongCNThang(ChamCongCNThangModel chamCongCNThang) async {
  await insert(DatabaseTables.chamCongCNThangTable, chamCongCNThang.toMap());
}

Future<List<ChamCongCNThangModel>> getAllChamCongCNThang() async {
  final maps = await query(DatabaseTables.chamCongCNThangTable);
  return maps.map((map) => ChamCongCNThangModel.fromMap(map)).toList();
}

Future<ChamCongCNThangModel?> getChamCongCNThangByUID(String uid) async {
  final maps = await query(
    DatabaseTables.chamCongCNThangTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  if (maps.isEmpty) return null;
  return ChamCongCNThangModel.fromMap(maps.first);
}

Future<List<ChamCongCNThangModel>> getChamCongCNThangByGiaiDoan(DateTime giaiDoan) async {
  final maps = await query(
    DatabaseTables.chamCongCNThangTable,
    where: 'GiaiDoan = ?',
    whereArgs: [giaiDoan.toIso8601String()],
  );
  return maps.map((map) => ChamCongCNThangModel.fromMap(map)).toList();
}

Future<List<ChamCongCNThangModel>> getChamCongCNThangByMaNV(String maNV) async {
  final maps = await query(
    DatabaseTables.chamCongCNThangTable,
    where: 'MaNV = ?',
    whereArgs: [maNV],
  );
  return maps.map((map) => ChamCongCNThangModel.fromMap(map)).toList();
}

Future<int> updateChamCongCNThang(String uid, Map<String, dynamic> updates) async {
  return await update(
    DatabaseTables.chamCongCNThangTable,
    updates,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}

Future<int> deleteChamCongCNThang(String uid) async {
  return await delete(
    DatabaseTables.chamCongCNThangTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}

Future<void> batchInsertChamCongCNThang(List<ChamCongCNThangModel> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var item in items) {
      batch.insert(
        DatabaseTables.chamCongCNThangTable, 
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}
// ==================== HDChiTietYCMM CRUD Operations ====================
Future<void> insertHDChiTietYCMM(HDChiTietYCMMModel hdChiTietYCMM) async {
 await insert(DatabaseTables.hdChiTietYCMMTable, hdChiTietYCMM.toMap());
}

Future<List<HDChiTietYCMMModel>> getAllHDChiTietYCMM() async {
 final maps = await query(DatabaseTables.hdChiTietYCMMTable);
 return maps.map((map) => HDChiTietYCMMModel.fromMap(map)).toList();
}

Future<HDChiTietYCMMModel?> getHDChiTietYCMMByUID(String uid) async {
 final maps = await query(
   DatabaseTables.hdChiTietYCMMTable,
   where: 'UID = ?',
   whereArgs: [uid],
 );
 if (maps.isEmpty) return null;
 return HDChiTietYCMMModel.fromMap(maps.first);
}

Future<List<HDChiTietYCMMModel>> getHDChiTietYCMMBySoPhieuID(String soPhieuID) async {
 final maps = await query(
   DatabaseTables.hdChiTietYCMMTable,
   where: 'SoPhieuID = ?',
   whereArgs: [soPhieuID],
 );
 return maps.map((map) => HDChiTietYCMMModel.fromMap(map)).toList();
}

Future<int> updateHDChiTietYCMM(String uid, Map<String, dynamic> updates) async {
 return await update(
   DatabaseTables.hdChiTietYCMMTable,
   updates,
   where: 'UID = ?',
   whereArgs: [uid],
 );
}

Future<int> deleteHDChiTietYCMM(String uid) async {
 return await delete(
   DatabaseTables.hdChiTietYCMMTable,
   where: 'UID = ?',
   whereArgs: [uid],
 );
}

Future<void> batchInsertHDChiTietYCMM(List<HDChiTietYCMMModel> items) async {
 final db = await database;
 await db.transaction((txn) async {
   final batch = txn.batch();
   for (var item in items) {
     batch.insert(
       DatabaseTables.hdChiTietYCMMTable, 
       item.toMap(),
       conflictAlgorithm: ConflictAlgorithm.replace
     );
   }
   await batch.commit(noResult: true);
 });
}

// ==================== HDDuTru CRUD Operations ====================
Future<void> insertHDDuTru(HDDuTruModel hdDuTru) async {
 await insert(DatabaseTables.hdDuTruTable, hdDuTru.toMap());
}

Future<List<HDDuTruModel>> getAllHDDuTru() async {
 final maps = await query(DatabaseTables.hdDuTruTable);
 return maps.map((map) => HDDuTruModel.fromMap(map)).toList();
}

Future<HDDuTruModel?> getHDDuTruBySoPhieuID(String soPhieuID) async {
 final maps = await query(
   DatabaseTables.hdDuTruTable,
   where: 'SoPhieuID = ?',
   whereArgs: [soPhieuID],
 );
 if (maps.isEmpty) return null;
 return HDDuTruModel.fromMap(maps.first);
}

Future<List<HDDuTruModel>> getHDDuTruByNguoiDung(String nguoiDung) async {
 final maps = await query(
   DatabaseTables.hdDuTruTable,
   where: 'NguoiDung = ?',
   whereArgs: [nguoiDung],
 );
 return maps.map((map) => HDDuTruModel.fromMap(map)).toList();
}

Future<int> updateHDDuTru(String soPhieuID, Map<String, dynamic> updates) async {
 return await update(
   DatabaseTables.hdDuTruTable,
   updates,
   where: 'SoPhieuID = ?',
   whereArgs: [soPhieuID],
 );
}

Future<int> deleteHDDuTru(String soPhieuID) async {
 return await delete(
   DatabaseTables.hdDuTruTable,
   where: 'SoPhieuID = ?',
   whereArgs: [soPhieuID],
 );
}

Future<void> batchInsertHDDuTru(List<HDDuTruModel> items) async {
 final db = await database;
 await db.transaction((txn) async {
   final batch = txn.batch();
   for (var item in items) {
     batch.insert(
       DatabaseTables.hdDuTruTable, 
       item.toMap(),
       conflictAlgorithm: ConflictAlgorithm.replace
     );
   }
   await batch.commit(noResult: true);
 });
}

// ==================== HDYeuCauMM CRUD Operations ====================
Future<void> insertHDYeuCauMM(HDYeuCauMMModel hdYeuCauMM) async {
 await insert(DatabaseTables.hdYeuCauMMTable, hdYeuCauMM.toMap());
}

Future<List<HDYeuCauMMModel>> getAllHDYeuCauMM() async {
 final maps = await query(DatabaseTables.hdYeuCauMMTable);
 return maps.map((map) => HDYeuCauMMModel.fromMap(map)).toList();
}

Future<HDYeuCauMMModel?> getHDYeuCauMMBySoPhieuUID(String soPhieuUID) async {
 final maps = await query(
   DatabaseTables.hdYeuCauMMTable,
   where: 'SoPhieuUID = ?',
   whereArgs: [soPhieuUID],
 );
 if (maps.isEmpty) return null;
 return HDYeuCauMMModel.fromMap(maps.first);
}

Future<List<HDYeuCauMMModel>> getHDYeuCauMMByDuTruID(String duTruID) async {
 final maps = await query(
   DatabaseTables.hdYeuCauMMTable,
   where: 'DuTruID = ?',
   whereArgs: [duTruID],
 );
 return maps.map((map) => HDYeuCauMMModel.fromMap(map)).toList();
}

Future<List<HDYeuCauMMModel>> getHDYeuCauMMByNguoiDung(String nguoiDung) async {
 final maps = await query(
   DatabaseTables.hdYeuCauMMTable,
   where: 'NguoiDung = ?',
   whereArgs: [nguoiDung],
 );
 return maps.map((map) => HDYeuCauMMModel.fromMap(map)).toList();
}

Future<int> updateHDYeuCauMM(String soPhieuUID, Map<String, dynamic> updates) async {
 return await update(
   DatabaseTables.hdYeuCauMMTable,
   updates,
   where: 'SoPhieuUID = ?',
   whereArgs: [soPhieuUID],
 );
}

Future<int> deleteHDYeuCauMM(String soPhieuUID) async {
 return await delete(
   DatabaseTables.hdYeuCauMMTable,
   where: 'SoPhieuUID = ?',
   whereArgs: [soPhieuUID],
 );
}

Future<void> batchInsertHDYeuCauMM(List<HDYeuCauMMModel> items) async {
 final db = await database;
 await db.transaction((txn) async {
   final batch = txn.batch();
   for (var item in items) {
     batch.insert(
       DatabaseTables.hdYeuCauMMTable, 
       item.toMap(),
       conflictAlgorithm: ConflictAlgorithm.replace
     );
   }
   await batch.commit(noResult: true);
 });
}

// ==================== ChamCong CRUD Operations ====================
Future<void> insertChamCong(ChamCongModel chamCong) async {
 await insert(DatabaseTables.chamCongTable, chamCong.toMap());
}

Future<List<ChamCongModel>> getAllChamCong() async {
 final maps = await query(DatabaseTables.chamCongTable);
 return maps.map((map) => ChamCongModel.fromMap(map)).toList();
}

Future<List<ChamCongModel>> getChamCongByNguoiDung(String nguoiDung) async {
 final maps = await query(
   DatabaseTables.chamCongTable,
   where: 'NguoiDung = ?',
   whereArgs: [nguoiDung],
 );
 return maps.map((map) => ChamCongModel.fromMap(map)).toList();
}

Future<ChamCongModel?> getChamCongByNguoiDungAndPhanLoai(String nguoiDung, String phanLoai) async {
 final maps = await query(
   DatabaseTables.chamCongTable,
   where: 'NguoiDung = ? AND PhanLoai = ?',
   whereArgs: [nguoiDung, phanLoai],
 );
 if (maps.isEmpty) return null;
 return ChamCongModel.fromMap(maps.first);
}

Future<int> updateChamCong(String nguoiDung, String phanLoai, Map<String, dynamic> updates) async {
 return await update(
   DatabaseTables.chamCongTable,
   updates,
   where: 'NguoiDung = ? AND PhanLoai = ?',
   whereArgs: [nguoiDung, phanLoai],
 );
}

Future<int> deleteChamCong(String nguoiDung, String phanLoai) async {
 return await delete(
   DatabaseTables.chamCongTable,
   where: 'NguoiDung = ? AND PhanLoai = ?',
   whereArgs: [nguoiDung, phanLoai],
 );
}

Future<void> batchInsertChamCong(List<ChamCongModel> items) async {
 final db = await database;
 await db.transaction((txn) async {
   final batch = txn.batch();
   for (var item in items) {
     batch.insert(
       DatabaseTables.chamCongTable, 
       item.toMap(),
       conflictAlgorithm: ConflictAlgorithm.replace
     );
   }
   await batch.commit(noResult: true);
 });
}

// ==================== ChamCongGio CRUD Operations ====================
Future<void> insertChamCongGio(ChamCongGioModel chamCongGio) async {
 await insert(DatabaseTables.chamCongGioTable, chamCongGio.toMap());
}

Future<List<ChamCongGioModel>> getAllChamCongGio() async {
 final maps = await query(DatabaseTables.chamCongGioTable);
 return maps.map((map) => ChamCongGioModel.fromMap(map)).toList();
}

Future<List<ChamCongGioModel>> getChamCongGioByNguoiDung(String nguoiDung) async {
 final maps = await query(
   DatabaseTables.chamCongGioTable,
   where: 'NguoiDung = ?',
   whereArgs: [nguoiDung],
 );
 return maps.map((map) => ChamCongGioModel.fromMap(map)).toList();
}

Future<ChamCongGioModel?> getChamCongGioByNguoiDungAndPhanLoai(String nguoiDung, String phanLoai) async {
 final maps = await query(
   DatabaseTables.chamCongGioTable,
   where: 'NguoiDung = ? AND PhanLoai = ?',
   whereArgs: [nguoiDung, phanLoai],
 );
 if (maps.isEmpty) return null;
 return ChamCongGioModel.fromMap(maps.first);
}

Future<int> updateChamCongGio(String nguoiDung, String phanLoai, Map<String, dynamic> updates) async {
 return await update(
   DatabaseTables.chamCongGioTable,
   updates,
   where: 'NguoiDung = ? AND PhanLoai = ?',
   whereArgs: [nguoiDung, phanLoai],
 );
}

Future<int> deleteChamCongGio(String nguoiDung, String phanLoai) async {
 return await delete(
   DatabaseTables.chamCongGioTable,
   where: 'NguoiDung = ? AND PhanLoai = ?',
   whereArgs: [nguoiDung, phanLoai],
 );
}

Future<void> batchInsertChamCongGio(List<ChamCongGioModel> items) async {
 final db = await database;
 await db.transaction((txn) async {
   final batch = txn.batch();
   for (var item in items) {
     batch.insert(
       DatabaseTables.chamCongGioTable, 
       item.toMap(),
       conflictAlgorithm: ConflictAlgorithm.replace
     );
   }
   await batch.commit(noResult: true);
 });
}

// ==================== ChamCongLS CRUD Operations ====================
Future<int> getUnapprovedChamCongLSCount(String nguoiDung) async {
  final db = await database;
  
  final result = await db.rawQuery('''
    SELECT COUNT(*) as count 
    FROM ${DatabaseTables.chamCongLSTable} 
    WHERE NguoiDung = ? AND (TrangThaiBatDau = 'Chưa xem' OR TrangThaiKetThuc = 'Chưa xem')
  ''', [nguoiDung]);
  
  return Sqflite.firstIntValue(result) ?? 0;
}
Future<void> insertChamCongLS(ChamCongLSModel chamCongLS) async {
 await insert(DatabaseTables.chamCongLSTable, chamCongLS.toMap());
}

Future<List<ChamCongLSModel>> getAllChamCongLS() async {
 final maps = await query(DatabaseTables.chamCongLSTable);
 return maps.map((map) => ChamCongLSModel.fromMap(map)).toList();
}

Future<ChamCongLSModel?> getChamCongLSByUID(String uid) async {
 final maps = await query(
   DatabaseTables.chamCongLSTable,
   where: 'UID = ?',
   whereArgs: [uid],
 );
 if (maps.isEmpty) return null;
 return ChamCongLSModel.fromMap(maps.first);
}

Future<List<ChamCongLSModel>> getChamCongLSByNguoiDung(String nguoiDung) async {
 final maps = await query(
   DatabaseTables.chamCongLSTable,
   where: 'NguoiDung = ?',
   whereArgs: [nguoiDung],
 );
 return maps.map((map) => ChamCongLSModel.fromMap(map)).toList();
}

Future<List<ChamCongLSModel>> getChamCongLSByNguoiDungAndNgay(String nguoiDung, DateTime ngay) async {
 final ngayStr = ngay.toIso8601String().substring(0, 10);
 final maps = await query(
   DatabaseTables.chamCongLSTable,
   where: 'NguoiDung = ? AND Ngay = ?',
   whereArgs: [nguoiDung, ngayStr],
 );
 return maps.map((map) => ChamCongLSModel.fromMap(map)).toList();
}

Future<int> updateChamCongLS(String uid, Map<String, dynamic> updates) async {
 return await update(
   DatabaseTables.chamCongLSTable,
   updates,
   where: 'UID = ?',
   whereArgs: [uid],
 );
}

Future<int> deleteChamCongLS(String uid) async {
 return await delete(
   DatabaseTables.chamCongLSTable,
   where: 'UID = ?',
   whereArgs: [uid],
 );
}

Future<void> batchInsertChamCongLS(List<ChamCongLSModel> items) async {
 final db = await database;
 await db.transaction((txn) async {
   final batch = txn.batch();
   for (var item in items) {
     batch.insert(
       DatabaseTables.chamCongLSTable, 
       item.toMap(),
       conflictAlgorithm: ConflictAlgorithm.replace
     );
   }
   await batch.commit(noResult: true);
 });
}
// ==================== Order CRUD Operations ====================
Future<List<OrderModel>> getOrdersByDateRangeAndDetails(
  DateTime startDate,
  DateTime endDate,
  {String? boPhan, String? nguoiDung}
) async {
  final Database db = await database;
  
  String query = '''
    SELECT * FROM Orders 
    WHERE Ngay BETWEEN ? AND ?
  ''';
  
  List<String> whereArgs = [
    startDate.toIso8601String(),
    endDate.toIso8601String()
  ];
  
  if (boPhan != null) {
    query += ' AND BoPhan = ?';
    whereArgs.add(boPhan);
  }
  
  if (nguoiDung != null) {
    query += ' AND NguoiDung = ?';
    whereArgs.add(nguoiDung);
  }
  
  final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs);
  
  return List.generate(maps.length, (i) {
    return OrderModel.fromMap(maps[i]);
  });
}
Future<void> insertOrder(OrderModel order) async {
  await insert(DatabaseTables.orderTable, order.toMap());
}

Future<List<OrderModel>> getAllOrders() async {
  final maps = await query(DatabaseTables.orderTable);
  return maps.map((map) => OrderModel.fromMap(map)).toList();
}

Future<OrderModel?> getOrderByOrderId(String orderId) async {
  final maps = await query(
    DatabaseTables.orderTable,
    where: 'OrderID = ?',
    whereArgs: [orderId],
  );
  if (maps.isEmpty) return null;
  return OrderModel.fromMap(maps.first);
}

Future<List<OrderModel>> getOrdersByDepartment(String boPhan) async {
  print('Executing query for department: $boPhan');
  
  final maps = await query(
    DatabaseTables.orderTable,
    where: 'BoPhan = ?',
    whereArgs: [boPhan],
  );
  
  print('Query result count: ${maps.length}');
  if (maps.isNotEmpty) {
    print('Sample record: ${maps.first}');
  }
  
  return maps.map((map) => OrderModel.fromMap(map)).toList();
}

Future<int> updateOrder(String orderId, Map<String, dynamic> updates) async {
  return await update(
    DatabaseTables.orderTable,
    updates,
    where: 'OrderID = ?',
    whereArgs: [orderId],
  );
}

Future<void> deleteAllOrderChiTietByOrderId(String orderId) async {
  final db = await database;
  await db.delete(
    'ordervtchitiet',
    where: 'OrderID = ?',
    whereArgs: [orderId],
  );
}
Future<void> deleteOrder(String orderId) async {
  final db = await database;
  await db.delete(
    'ordervt',
    where: 'OrderID = ?',
    whereArgs: [orderId],
  );
}

Future<void> batchInsertOrders(List<OrderModel> orders) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var order in orders) {
      batch.insert(
        DatabaseTables.orderTable, 
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}
Future<void> insertHinhAnhZalo(HinhAnhZaloModel hinhAnh) async {
  await insert(DatabaseTables.hinhAnhZaloTable, hinhAnh.toMap());
}

Future<List<HinhAnhZaloModel>> getAllHinhAnhZalo() async {
  final maps = await query(DatabaseTables.hinhAnhZaloTable);
  return maps.map((map) => HinhAnhZaloModel.fromMap(map)).toList();
}

Future<HinhAnhZaloModel?> getHinhAnhZaloByUID(String uid) async {
  final maps = await query(
    DatabaseTables.hinhAnhZaloTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  if (maps.isEmpty) return null;
  return HinhAnhZaloModel.fromMap(maps.first);
}

Future<List<HinhAnhZaloModel>> getHinhAnhZaloByDepartment(String boPhan) async {
  final maps = await query(
    DatabaseTables.hinhAnhZaloTable,
    where: 'BoPhan = ?',
    whereArgs: [boPhan],
  );
  return maps.map((map) => HinhAnhZaloModel.fromMap(map)).toList();
}

Future<List<HinhAnhZaloModel>> getHinhAnhZaloByDateRange(
    DateTime startDate, DateTime endDate) async {
  final maps = await query(
    DatabaseTables.hinhAnhZaloTable,
    where: 'Ngay BETWEEN ? AND ?',
    whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
  );
  return maps.map((map) => HinhAnhZaloModel.fromMap(map)).toList();
}

Future<List<HinhAnhZaloModel>> getHinhAnhZaloByKhuVuc(String khuVuc) async {
  final maps = await query(
    DatabaseTables.hinhAnhZaloTable,
    where: 'KhuVuc = ?',
    whereArgs: [khuVuc],
  );
  return maps.map((map) => HinhAnhZaloModel.fromMap(map)).toList();
}

Future<List<HinhAnhZaloModel>> getQuanTrongHinhAnhZalo() async {
  final maps = await query(
    DatabaseTables.hinhAnhZaloTable,
    where: 'QuanTrong = ?',
    whereArgs: ['true'],
  );
  return maps.map((map) => HinhAnhZaloModel.fromMap(map)).toList();
}

Future<void> batchInsertHinhAnhZalo(List<HinhAnhZaloModel> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var item in items) {
      // Create a modified map with DateTime properly converted
      final itemMap = {
        'UID': item.uid,
        'Ngay': item.ngay?.toIso8601String(),
        'Gio': item.gio,
        'BoPhan': item.boPhan,
        'GiamSat': item.giamSat,
        'NguoiDung': item.nguoiDung,
        'HinhAnh': item.hinhAnh,
        'KhuVuc': item.khuVuc,
        'QuanTrong': item.quanTrong,
      };
      
      batch.insert(
        DatabaseTables.hinhAnhZaloTable, 
        itemMap,
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}

Future<int> updateHinhAnhZalo(String uid, Map<String, dynamic> updates) async {
  return await update(
    DatabaseTables.hinhAnhZaloTable,
    updates,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}

Future<int> deleteHinhAnhZalo(String uid) async {
  return await delete(
    DatabaseTables.hinhAnhZaloTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}
// ==================== OrderDinhMuc CRUD Operations ====================
Future<void> insertOrderDinhMuc(OrderDinhMucModel orderDinhMuc) async {
  await insert(DatabaseTables.orderDinhMucTable, orderDinhMuc.toMap());
}

Future<List<OrderDinhMucModel>> getAllOrderDinhMuc() async {
  final maps = await query(DatabaseTables.orderDinhMucTable);
  return maps.map((map) => OrderDinhMucModel.fromMap(map)).toList();
}

Future<OrderDinhMucModel?> getOrderDinhMucByKey(String boPhan, String thangDat) async {
  final maps = await query(
    DatabaseTables.orderDinhMucTable,
    where: 'BoPhan = ? AND ThangDat = ?',
    whereArgs: [boPhan, thangDat],
  );
  if (maps.isEmpty) return null;
  return OrderDinhMucModel.fromMap(maps.first);
}

Future<int> updateOrderDinhMuc(String boPhan, String thangDat, Map<String, dynamic> updates) async {
  return await update(
    DatabaseTables.orderDinhMucTable,
    updates,
    where: 'BoPhan = ? AND ThangDat = ?',
    whereArgs: [boPhan, thangDat],
  );
}

Future<int> deleteOrderDinhMuc(String boPhan, String thangDat) async {
  return await delete(
    DatabaseTables.orderDinhMucTable,
    where: 'BoPhan = ? AND ThangDat = ?',
    whereArgs: [boPhan, thangDat],
  );
}

Future<void> batchInsertOrderDinhMuc(List<OrderDinhMucModel> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var item in items) {
      batch.insert(
        DatabaseTables.orderDinhMucTable, 
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}

// ==================== OrderChiTiet CRUD Operations ====================
Future<void> insertOrderChiTiet(OrderChiTietModel orderChiTiet) async {
  await insert(DatabaseTables.orderChiTietTable, orderChiTiet.toMap());
}

Future<List<OrderChiTietModel>> getAllOrderChiTiet() async {
  final maps = await query(DatabaseTables.orderChiTietTable);
  return maps.map((map) => OrderChiTietModel.fromMap(map)).toList();
}

Future<OrderChiTietModel?> getOrderChiTietByUID(String uid) async {
  final maps = await query(
    DatabaseTables.orderChiTietTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  if (maps.isEmpty) return null;
  return OrderChiTietModel.fromMap(maps.first);
}

Future<List<OrderChiTietModel>> getOrderChiTietByOrderId(String orderId) async {
  final maps = await query(
    DatabaseTables.orderChiTietTable,
    where: 'OrderID = ?',
    whereArgs: [orderId],
  );
  return maps.map((map) => OrderChiTietModel.fromMap(map)).toList();
}

Future<int> updateOrderChiTiet(String uid, Map<String, dynamic> updates) async {
  return await update(
    DatabaseTables.orderChiTietTable,
    updates,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}

Future<int> deleteOrderChiTiet(String uid) async {
  return await delete(
    DatabaseTables.orderChiTietTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}

Future<void> batchInsertOrderChiTiet(List<OrderChiTietModel> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var item in items) {
      batch.insert(
        DatabaseTables.orderChiTietTable, 
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}
// ==================== OrderMatHang CRUD Operations ====================
Future<void> insertOrderMatHang(OrderMatHangModel item) async {
  await insert(DatabaseTables.orderMatHangTable, item.toMap());
}

Future<List<OrderMatHangModel>> getAllOrderMatHang() async {
  final maps = await query(DatabaseTables.orderMatHangTable);
  return maps.map((map) => OrderMatHangModel.fromMap(map)).toList();
}

Future<OrderMatHangModel?> getOrderMatHangByItemId(String itemId) async {
  final maps = await query(
    DatabaseTables.orderMatHangTable,
    where: 'ItemId = ?',
    whereArgs: [itemId],
  );
  if (maps.isEmpty) return null;
  return OrderMatHangModel.fromMap(maps.first);
}

Future<List<OrderMatHangModel>> getOrderMatHangByPhanLoai(String phanLoai) async {
  final maps = await query(
    DatabaseTables.orderMatHangTable,
    where: 'PhanLoai = ?',
    whereArgs: [phanLoai],
  );
  return maps.map((map) => OrderMatHangModel.fromMap(map)).toList();
}

Future<int> updateOrderMatHang(String itemId, Map<String, dynamic> updates) async {
  return await update(
    DatabaseTables.orderMatHangTable,
    updates,
    where: 'ItemId = ?',
    whereArgs: [itemId],
  );
}

Future<int> deleteOrderMatHang(String itemId) async {
  return await delete(
    DatabaseTables.orderMatHangTable,
    where: 'ItemId = ?',
    whereArgs: [itemId],
  );
}

Future<void> batchInsertOrderMatHang(List<OrderMatHangModel> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var item in items) {
      batch.insert(
        DatabaseTables.orderMatHangTable, 
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}

// ==================== ChamCongCN CRUD Operations ====================
Future<void> insertChamCongCN(ChamCongCNModel chamCong) async {
  await insert(DatabaseTables.chamCongCNTable, chamCong.toMap());
}

Future<List<ChamCongCNModel>> getAllChamCongCN() async {
  final maps = await query(DatabaseTables.chamCongCNTable);
  return maps.map((map) => ChamCongCNModel.fromMap(map)).toList();
}

Future<ChamCongCNModel?> getChamCongCNByUID(String uid) async {
  final maps = await query(
    DatabaseTables.chamCongCNTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  if (maps.isEmpty) return null;
  return ChamCongCNModel.fromMap(maps.first);
}

Future<List<ChamCongCNModel>> getChamCongCNByDepartment(String boPhan) async {
  final maps = await query(
    DatabaseTables.chamCongCNTable,
    where: 'BoPhan = ?',
    whereArgs: [boPhan],
  );
  return maps.map((map) => ChamCongCNModel.fromMap(map)).toList();
}

Future<List<ChamCongCNModel>> getChamCongCNByNhanVien(String maNV) async {
  final maps = await query(
    DatabaseTables.chamCongCNTable,
    where: 'MaNV = ?',
    whereArgs: [maNV],
  );
  return maps.map((map) => ChamCongCNModel.fromMap(map)).toList();
}

Future<List<ChamCongCNModel>> getChamCongCNByDateRange(
    DateTime startDate, DateTime endDate) async {
  final maps = await query(
    DatabaseTables.chamCongCNTable,
    where: 'Ngay BETWEEN ? AND ?',
    whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
  );
  return maps.map((map) => ChamCongCNModel.fromMap(map)).toList();
}

Future<int> updateChamCongCN(String uid, Map<String, dynamic> updates) async {
  return await update(
    DatabaseTables.chamCongCNTable,
    updates,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}

Future<int> deleteChamCongCN(String uid) async {
  return await delete(
    DatabaseTables.chamCongCNTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}

Future<void> batchInsertChamCongCN(List<ChamCongCNModel> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var item in items) {
      batch.insert(
        DatabaseTables.chamCongCNTable, 
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}
  Future<List<Map<String, dynamic>>> getStaffListByDepartment(String department) async {
  final db = await database;
  return await db.query(
    DatabaseTables.staffListTable,
    where: 'BoPhan = ?',
    whereArgs: [department],
  );
}
Future<List<Map<String, dynamic>>> getAllStaffbio() async {
    final db = await database;
    return await db.query(DatabaseTables.staffbioTable);
  }
  
Future<void> checkDatabaseStatus() async {
  try {
    final db = await database;
    // Check if taskhistory table exists
    final tables = await db.query('sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: ['table', DatabaseTables.taskHistoryTable]
    );
    print('Task history table exists: ${tables.isNotEmpty}');
    
    // Try a test query
    final testQuery = await db.query(DatabaseTables.taskHistoryTable, limit: 1);
    print('Test query successful, found ${testQuery.length} records');
  } catch (e) {
    print('Database status check failed: $e');
  }
}

Future<void> batchInsertInteraction(List<InteractionModel> interactions) async {
  final db = await database;
  final batch = db.batch();
  
  for (var interaction in interactions) {
    batch.insert(
      DatabaseTables.interactionTable,
      interaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  await batch.commit(noResult: true);
}
Future<void> insertInteraction(InteractionModel interaction) async {
  await insert(DatabaseTables.interactionTable, interaction.toMap());
}

Future<List<InteractionModel>> getAllInteractions() async {
  final maps = await query(DatabaseTables.interactionTable);
  return maps.map((map) => InteractionModel.fromMap(map)).toList();
}

Future<InteractionModel?> getInteractionByUID(String uid) async {
  final maps = await query(
    DatabaseTables.interactionTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  if (maps.isEmpty) return null;
  return InteractionModel.fromMap(maps.first);
}

Future<List<InteractionModel>> getInteractionsByDepartment(String boPhan) async {
  final maps = await query(
    DatabaseTables.interactionTable,
    where: 'BoPhan = ?',
    whereArgs: [boPhan],
  );
  return maps.map((map) => InteractionModel.fromMap(map)).toList();
}

Future<List<InteractionModel>> getInteractionsByDateRange(
    DateTime startDate, DateTime endDate) async {
  final maps = await query(
    DatabaseTables.interactionTable,
    where: 'Ngay BETWEEN ? AND ?',
    whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
  );
  return maps.map((map) => InteractionModel.fromMap(map)).toList();
}
Future<void> insertDongPhuc(DongPhucModel dongPhuc) async {
  await insert(DatabaseTables.dongPhucTable, dongPhuc.toMap());
}

Future<List<DongPhucModel>> getAllDongPhuc() async {
  final maps = await query(DatabaseTables.dongPhucTable);
  return maps.map((map) => DongPhucModel.fromMap(map)).toList();
}

Future<DongPhucModel?> getDongPhucByUID(String uid) async {
  final maps = await query(
    DatabaseTables.dongPhucTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  if (maps.isEmpty) return null;
  return DongPhucModel.fromMap(maps.first);
}

Future<List<DongPhucModel>> getDongPhucByDepartment(String boPhan) async {
  final maps = await query(
    DatabaseTables.dongPhucTable,
    where: 'BoPhan = ?',
    whereArgs: [boPhan],
  );
  return maps.map((map) => DongPhucModel.fromMap(map)).toList();
}

Future<void> batchInsertDongPhuc(List<DongPhucModel> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var item in items) {
      batch.insert(
        DatabaseTables.dongPhucTable, 
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}
Future<void> insertChiTietDP(ChiTietDPModel item) async {
  final db = await database;
  print('Inserting ChiTietDP with OrderUID: ${item.orderUid}');
  print('Current item details: ${item.toMap()}');
  
  try {
    // Use insert instead of insertOrReplace
    await db.insert(
      DatabaseTables.chiTietDPTable,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore  // Change from replace to ignore
    );
    
    // Verify after insert
    final allRecords = await db.query(DatabaseTables.chiTietDPTable);
    print('Total records in table after insert: ${allRecords.length}');
    print('All records: $allRecords');
    
    final orderRecords = await db.query(
      DatabaseTables.chiTietDPTable,
      where: 'OrderUID = ?',
      whereArgs: [item.orderUid],
    );
    print('Records for this order after insert: ${orderRecords.length}');
    
  } catch (e, stackTrace) {
    print('Error during insert: $e');
    print('Stack trace: $stackTrace');
  }
}

Future<List<ChiTietDPModel>> getAllChiTietDP() async {
  final maps = await query(DatabaseTables.chiTietDPTable);
  return maps.map((map) => ChiTietDPModel.fromMap(map)).toList();
}

Future<List<ChiTietDPModel>> getChiTietDPByOrderUID(String orderUid) async {
  final db = await database;
  print('Querying items for order: $orderUid');
  
  final maps = await db.query(
    DatabaseTables.chiTietDPTable,
    where: 'OrderUID = ?',
    whereArgs: [orderUid],
  );
  
  print('Found ${maps.length} items in database');
  return maps.map((map) => ChiTietDPModel.fromMap(map)).toList();
}

Future<List<ChiTietDPModel>> getChiTietDPByUID(String uid) async {
  final maps = await query(
    DatabaseTables.chiTietDPTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  return maps.map((map) => ChiTietDPModel.fromMap(map)).toList();
}

Future<void> batchInsertChiTietDP(List<ChiTietDPModel> items) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var item in items) {
      batch.insert(
        DatabaseTables.chiTietDPTable, 
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}
Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
  final db = await database;
  return await db.rawQuery(sql, arguments);
}
Future<List<Map<String, dynamic>>> getChecklistByVT(String vt) async {
  final db = await database;
  print('Querying checklist for VT: $vt');
  final results = await db.query(
    DatabaseTables.checklistTable,
    where: 'VITRI = ?',
    whereArgs: [vt],
  );
  print('Found ${results.length} tasks');
  return results;
}
Future<void> insertProjectList(ProjectListModel project) async {
    await insert(DatabaseTables.projectListTable, project.toMap());
  }
// Add these new methods for Baocao operations
Future<void> insertBaocao(BaocaoModel baocao) async {
  final db = await database;
  await db.insert('baocao', baocao.toMap());
}

Future<List<BaocaoModel>> getAllBaocao() async {
  final maps = await query(DatabaseTables.baocaoTable);
  return maps.map((map) => BaocaoModel.fromMap(map)).toList();
}

Future<BaocaoModel?> getBaocaoByUID(String uid) async {
  final maps = await query(
    DatabaseTables.baocaoTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  if (maps.isEmpty) return null;
  return BaocaoModel.fromMap(maps.first);
}

Future<List<BaocaoModel>> getBaocaoByDepartment(String boPhan) async {
  final maps = await query(
    DatabaseTables.baocaoTable,
    where: 'BoPhan = ?',
    whereArgs: [boPhan],
  );
  return maps.map((map) => BaocaoModel.fromMap(map)).toList();
}

Future<void> batchInsertBaocao(List<BaocaoModel> reports) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var report in reports) {
      batch.insert(
        DatabaseTables.baocaoTable, 
        report.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}

Future<List<BaocaoModel>> getBaocaoByDateRange(DateTime startDate, DateTime endDate) async {
  final maps = await query(
    DatabaseTables.baocaoTable,
    where: 'Ngay BETWEEN ? AND ?',
    whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
  );
  return maps.map((map) => BaocaoModel.fromMap(map)).toList();
}
  // Batch insert multiple projects
  Future<void> batchInsertProjectList(List<ProjectListModel> projects) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var project in projects) {
        batch.insert(
          DatabaseTables.projectListTable, 
          project.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // Get all projects
  Future<List<ProjectListModel>> getAllProjects() async {
    final maps = await query(DatabaseTables.projectListTable);
    return maps.map((map) => ProjectListModel.fromMap(map)).toList();
  }

  // Get project by MaBP
  Future<ProjectListModel?> getProjectByMaBP(String maBP) async {
    final maps = await query(
      DatabaseTables.projectListTable,
      where: 'MaBP = ?',
      whereArgs: [maBP],
    );
    if (maps.isEmpty) return null;
    return ProjectListModel.fromMap(maps.first);
  }

  // Get list of BoPhan for a user
  Future<List<String>> getUserBoPhanList() async {
    final db = await database;
    final results = await db.query(
      DatabaseTables.projectListTable,
      distinct: true,
      columns: ['BoPhan'],
      orderBy: 'BoPhan ASC'
    );
    
    return results.map((row) => row['BoPhan'] as String).toList();
  }

  // Delete project
  Future<int> deleteProject(String maBP) async {
    return await delete(
      DatabaseTables.projectListTable,
      where: 'MaBP = ?',
      whereArgs: [maBP],
    );
  }
Future<void> insertStaffList(StaffListModel staffList) async {
    await insert(DatabaseTables.staffListTable, staffList.toMap());
  }

  Future<List<StaffListModel>> getAllStaffList() async {
    final maps = await query(DatabaseTables.staffListTable);
    return maps.map((map) => StaffListModel.fromMap(map)).toList();
  }

  Future<StaffListModel?> getStaffListByUID(String uid) async {
    final maps = await query(
      DatabaseTables.staffListTable,
      where: 'UID = ?',
      whereArgs: [uid],
    );
    if (maps.isEmpty) return null;
    return StaffListModel.fromMap(maps.first);
  }

  // PositionList operations
  Future<void> insertPositionList(PositionListModel positionList) async {
    await insert(DatabaseTables.positionListTable, positionList.toMap());
  }

  Future<List<PositionListModel>> getAllPositionList() async {
    final maps = await query(DatabaseTables.positionListTable);
    return maps.map((map) => PositionListModel.fromMap(map)).toList();
  }

  Future<PositionListModel?> getPositionListByUID(String uid) async {
    final maps = await query(
      DatabaseTables.positionListTable,
      where: 'UID = ?',
      whereArgs: [uid],
    );
    if (maps.isEmpty) return null;
    return PositionListModel.fromMap(maps.first);
  }

  // Batch operations for new tables
  Future<void> batchInsertStaffList(List<StaffListModel> staffLists) async {
    final db = await database;
    final batch = db.batch();
    for (var staffList in staffLists) {
      batch.insert(DatabaseTables.staffListTable, staffList.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
Future<List<Map<String, dynamic>>> getVTHistoryByStaff(String maNV, String boPhan) async {
    final db = await database;
    return await db.query(
      DatabaseTables.vtHistoryTable,
      where: 'NhanVien = ? AND BoPhan = ?',
      whereArgs: [maNV, boPhan],
    );
}
Future<List<Map<String, dynamic>>> getVTHistoryByDepartment(String boPhan) async {
    final db = await database;
    return await db.query(
      DatabaseTables.vtHistoryTable,
      where: 'BoPhan = ?',
      whereArgs: [boPhan],
    );
}
  Future<void> batchInsertPositionList(List<PositionListModel> models) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var model in models) {
        batch.insert(
          DatabaseTables.positionListTable, 
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      await batch.commit(noResult: true);
    });
  }
  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, 
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(String table, 
    {String? where, List<dynamic>? whereArgs}) async {
  try {
    final db = await database;
    print('Executing query on table: $table');
    print('Where clause: $where');
    print('Where args: $whereArgs');
    return await db.query(table, where: where, whereArgs: whereArgs);
  } catch (e, stackTrace) {
    print('Error executing query:');
    print('Table: $table');
    print('Error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

  Future<int> update(String table, Map<String, dynamic> data,
      {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, 
      {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  // Staffbio operations
  Future<void> insertStaffbio(StaffbioModel staffbio) async {
    await insert(DatabaseTables.staffbioTable, staffbio.toMap());
  }
Future<StaffbioModel?> getStaffbioByUID(String uid) async {
    final maps = await query(
      DatabaseTables.staffbioTable,
      where: 'UID = ?',
      whereArgs: [uid],
    );
    if (maps.isEmpty) return null;
    return StaffbioModel.fromMap(maps.first);
  }
Future<int> updateStaffbioEditableFields(String uid, {
    double? chieuCao,
    double? canNang,
    DateTime? ngayCapDP,
  }) async {
    final Map<String, dynamic> updates = {};
    if (chieuCao != null) updates['ChieuCao'] = chieuCao;
    if (canNang != null) updates['CanNang'] = canNang;
    if (ngayCapDP != null) updates['NgayCapDP'] = ngayCapDP.toIso8601String();
    
    if (updates.isEmpty) return 0;
    
    final db = await database;
    return await db.update(
      DatabaseTables.staffbioTable,
      updates,
      where: 'UID = ?',
      whereArgs: [uid],
    );
  }
Future<Map<String, dynamic>?> getStaffbioEditableFields(String uid) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      DatabaseTables.staffbioTable,
      columns: ['ChieuCao', 'CanNang', 'NgayCapDP'],
      where: 'UID = ?',
      whereArgs: [uid],
    );
    if (result.isEmpty) return null;
    return result.first;
  }
  
  // Checklist operations
  Future<void> insertChecklist(ChecklistModel checklist) async {
    await insert(DatabaseTables.checklistTable, checklist.toMap());
  }

  Future<List<ChecklistModel>> getAllChecklists() async {
    final maps = await query(DatabaseTables.checklistTable);
    return maps.map((map) => ChecklistModel.fromMap(map)).toList();
  }

  Future<List<ChecklistModel>> getChecklistsByDuan(String duan) async {
    final maps = await query(
      DatabaseTables.checklistTable,
      where: 'DUAN = ?',
      whereArgs: [duan],
    );
    return maps.map((map) => ChecklistModel.fromMap(map)).toList();
  }

  // TaskHistory operations
  Future<void> insertTaskHistory(TaskHistoryModel taskHistory) async {
    await insert(DatabaseTables.taskHistoryTable, taskHistory.toMap());
  }

  Future<List<TaskHistoryModel>> getAllTaskHistory() async {
    final maps = await query(DatabaseTables.taskHistoryTable);
    return maps.map((map) => TaskHistoryModel.fromMap(map)).toList();
  }

  Future<List<TaskHistoryModel>> getTaskHistoryByUID(String uid) async {
    final maps = await query(
      DatabaseTables.taskHistoryTable,
      where: 'UID = ?',
      whereArgs: [uid],
    );
    return maps.map((map) => TaskHistoryModel.fromMap(map)).toList();
  }

  // VTHistory operations
  Future<void> insertVTHistory(VTHistoryModel vtHistory) async {
    await insert(DatabaseTables.vtHistoryTable, vtHistory.toMap());
  }

  Future<List<VTHistoryModel>> getAllVTHistory() async {
    final maps = await query(DatabaseTables.vtHistoryTable);
    return maps.map((map) => VTHistoryModel.fromMap(map)).toList();
  }

  Future<List<VTHistoryModel>> getVTHistoryByUID(String uid) async {
    final maps = await query(
      DatabaseTables.vtHistoryTable,
      where: 'UID = ?',
      whereArgs: [uid],
    );
    return maps.map((map) => VTHistoryModel.fromMap(map)).toList();
  }
Future<void> insertStaffbioSafe(Map<String, dynamic> staffbioData) async {
  final db = await database;
  await db.insert(
    DatabaseTables.staffbioTable,
    {
      'UID': staffbioData['UID'],
      'MaNV': staffbioData['MaNV'],
      'Ho_ten': staffbioData['Ho_ten'],
      'Ngay_vao': staffbioData['Ngay_vao'],
      'Thang_vao': staffbioData['Thang_vao'],
      'So_thang': staffbioData['So_thang'],
      'Loai_hinh_lao_dong': staffbioData['Loai_hinh_lao_dong'],
      'Chuc_vu': staffbioData['Chuc_vu'],
      'Gioi_tinh': staffbioData['Gioi_tinh'],
      'Ngay_sinh': staffbioData['Ngay_sinh'],
      'Tuoi': staffbioData['Tuoi'],
      'Can_cuoc_cong_dan': staffbioData['Can_cuoc_cong_dan'],
      'Ngay_cap': staffbioData['Ngay_cap'],
      'Noi_cap': staffbioData['Noi_cap'],
      'Nguyen_quan': staffbioData['Nguyen_quan'],
      'Thuong_tru': staffbioData['Thuong_tru'],
      'Dia_chi_lien_lac': staffbioData['Dia_chi_lien_lac'],
      'SDT': staffbioData['SDT'],
      'Don_vi': staffbioData['Don_vi'],
      'Giam_sat': staffbioData['Giam_sat'],
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
  // Batch insert operations
Future<void> batchInsertStaffbio(List<StaffbioModel> staffbios) async {
  final db = await database;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (var staffbio in staffbios) {
      final map = staffbio.toMap();
      // Let SQLite handle the empty strings and nulls
      batch.insert(
        DatabaseTables.staffbioTable,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);
  });
}
Map<String, dynamic> _getOrderedStaffbioMap(StaffbioModel model) {
  return {
    'UID': model.uid,
    'VungMien': model.vungMien,
    'LoaiNV': model.loaiNV,
    'MaNV': model.manv,
    'Ho_ten': model.hoTen,
    'Ngay_vao': model.ngayVao?.toIso8601String(),
    'Thang_vao': model.thangVao?.toIso8601String(),
    'So_thang': model.soThang,
    'Loai_hinh_lao_dong': model.loaiHinhLaoDong,
    'Chuc_vu': model.chucVu,
    'Gioi_tinh': model.gioiTinh,
    'Ngay_sinh': model.ngaySinh?.toIso8601String(),
    'Tuoi': model.tuoi,
    'Can_cuoc_cong_dan': model.canCuocCongDan,
    'Ngay_cap': model.ngayCap?.toIso8601String(),
    'Noi_cap': model.noiCap,
    'Nguyen_quan': model.nguyenQuan,
    'Thuong_tru': model.thuongTru,
    'Dia_chi_lien_lac': model.diaChiLienLac,
    'Ma_so_thue': model.maSoThue,
    'CMND_cu': model.cMNDCu,
    'ngay_cap_cu': model.ngay_cap_cu,
    'Noi_cap_cu': model.noiCapCu,
    'Nguyen_quan_cu': model.nguyenQuanCu,
    'Dia_chi_thuong_tru_cu': model.diaChiThuongTruCu,
    'MST_ghi_chu': model.mstGhiChu,
    'Dan_toc': model.danToc,
    'SDT': model.sdt,
    'SDT2': model.sdt2,
    'Email': model.email,
    'Dia_chinh_cap4': model.diaChinhCap4,
    'Dia_chinh_cap3': model.diaChinhCap3,
    'Dia_chinh_cap2': model.diaChinhCap2,
    'Dia_chinh_cap1': model.diaChinhCap1,
    'Don_vi': model.donVi,
    'Giam_sat': model.giamSat,
    'So_tai_khoan': model.soTaiKhoan,
    'Ngan_hang': model.nganHang,
    'MST_thu_nhap_ca_nhan': model.mstThuNhapCaNhan,
    'So_BHXH': model.soBHXH,
    'Bat_dau_tham_gia_BHXH': model.batDauThamGiaBHXH,
    'Ket_thuc_BHXH': model.ketThucBHXH,
    'Ghi_chu': model.ghiChu,
    'Tinh_trang': model.tinhTrang,
    'Ngay_nghi': model.ngayNghi?.toIso8601String(),
    'Tinh_trang_ho_so': model.tinhTrangHoSo,
    'Ho_so_con_thieu': model.hoSoConThieu,
    'Qua_trinh': model.quaTrinh,
    'Partime': model.partime,
    'Nguoi_gioi_thieu': model.nguoiGioiThieu,
    'Nguon_tuyen_dung': model.nguonTuyenDung,
    'CTV_30k': model.ctv30k,
    'Doanh_so_tuyen_dung': model.doanhSoTuyenDung,
    'Trinh_do': model.trinhDo,
    'Chuyen_nganh': model.chuyenNganh,
    'PL_dac_biet': model.plDacBiet,
    'Lam_2noi': model.lam2noi,
    'Loai_dt': model.loaiDt,
    'So_the_BH_huu_tri': model.soTheBHHuuTri,
    'Tinh_trang_tiem_chung': model.tinhTrangTiemChung,
    'Ngay_cap_giay_khamSK': model.ngayCapGiayKhamSK?.toIso8601String(),
    'SDT_nhan_than': model.sdtNhanThan,
    'Ho_ten_bo': model.hoTenBo,
    'Nam_sinh_bo': model.namSinhBo,
    'Ho_ten_me': model.hoTenMe,
    'Nam_sinh_me': model.namSinhMe,
    'Ho_ten_vochong': model.hoTenVoChong,
    'Nam_sinh_vochong': model.namSinhVoChong,
    'Con': model.con,
    'Nam_sinh_con': model.namSinhCon,
    'Chu_ho_khau': model.chuHoKhau,
    'Nam_sinh_chu_ho': model.namSinhChuHo,
    'Quan_he_voi_chu_ho': model.quanHeVoiChuHo,
    'Ho_so_thau': model.hoSoThau,
    'So_the_BHYT': model.soTheBHYT,
    'ChieuCao': model.chieuCao,
    'CanNang': model.canNang,
    'NgayCapDP': model.ngayCapDP?.toIso8601String(),
  };
}
  Future<void> batchInsertChecklist(List<ChecklistModel> checklists) async {
    final db = await database;
    final batch = db.batch();
    for (var checklist in checklists) {
      batch.insert(DatabaseTables.checklistTable, checklist.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> batchInsertTaskHistory(List<TaskHistoryModel> histories) async {
  final db = await database;
  try {
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var history in histories) {
        batch.insert(
          DatabaseTables.taskHistoryTable, 
          history.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      await batch.commit(noResult: true);
    });
  } catch (e) {
    print('Error in batch insert task history: $e');
    for (var history in histories) {
      try {
        await db.insert(
          DatabaseTables.taskHistoryTable,
          history.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      } catch (e) {
        print('Error inserting individual record: $e');
      }
    }
  }
}

  Future<void> batchInsertVTHistory(List<VTHistoryModel> histories) async {
    final db = await database;
    final batch = db.batch();
    for (var history in histories) {
      batch.insert(DatabaseTables.vtHistoryTable, history.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // Clear tables
  Future<void> clearTable(String tableName, {String? whereClause, List<dynamic>? whereArgs}) async {
  final db = await database;
  if (whereClause != null) {
    await db.delete(tableName, where: whereClause, whereArgs: whereArgs);
  } else {
    await db.delete(tableName);
  }
}

  Future<void> clearAllTables() async {
    await clearTable(DatabaseTables.staffbioTable);
    await clearTable(DatabaseTables.checklistTable);
    await clearTable(DatabaseTables.taskHistoryTable);
    await clearTable(DatabaseTables.vtHistoryTable);
    await clearTable(DatabaseTables.baocaoTable); 
  }
}
