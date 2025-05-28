// db_helper.dart
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:core';
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
    bool hasReset = prefs.getBool('db_reset_v28') ?? false;
    
    if (!hasReset) {
      print('Forcing database reset for version 28...');
      try {
        await deleteDatabase(path);
        await prefs.setBool('db_reset_v28', true);
        print('Database reset successful');
      } catch (e) {
        print('Error during database reset: $e');
      }
    }
    
    await Directory(dirname(path)).create(recursive: true);
    
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 28,
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
          await db.execute(DatabaseTables.createDonHangTable);
        await db.execute(DatabaseTables.createChiTietDonTable);
          await db.execute(DatabaseTables.createDSHangTable);
        await db.execute(DatabaseTables.createGiaoDichKhoTable);
        await db.execute(DatabaseTables.createGiaoHangTable);
        await db.execute(DatabaseTables.createKhoTable);
        await db.execute(DatabaseTables.createKhuVucKhoTable);
        await db.execute(DatabaseTables.createLoHangTable);
        await db.execute(DatabaseTables.createTonKhoTable);
        await db.execute(DatabaseTables.createNewsActivityTable);
        await db.execute(DatabaseTables.createNewsTable);
        await db.execute(DatabaseTables.createKhuVucKhoChiTietTable);
       await db.execute(DatabaseTables.createGoCleanCongViecTable);
          await db.execute(DatabaseTables.createGoCleanTaiKhoanTable);
          await db.execute(DatabaseTables.createGoCleanYeuCauTable);
          await db.execute(DatabaseTables.createKhachHangTable);
          await db.execute(DatabaseTables.createKhachHangContactTable);
          print('Database tables created successfully');
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 28) {
          //await db.execute(DatabaseTables.createGoCleanCongViecTable);
          //await db.execute(DatabaseTables.createGoCleanTaiKhoanTable);
          //await db.execute(DatabaseTables.createGoCleanYeuCauTable);
          //await db.execute(DatabaseTables.createKhachHangTable);
          //await db.execute(DatabaseTables.createKhachHangContactTable);
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
//ADDONXNK
Future<void> clearChiTietDonTable() async {
  final db = await database; 
  await db.delete('chitietdon');
  print('DBHelper: Cleared all records from chitietdon table.');
}

Future<void> clearLoHangTable() async {
  final db = await database;
  await db.delete('lohang');
  print('DBHelper: Cleared all records from lohang table.');
}

Future<List<LoHangModel>> getAllLoHangByKhoID(String khoID) async {
  try {
    print('=== DB QUERY getAllLoHangByKhoID ===');
    print('Getting all batches for warehouse: $khoID');
    
    final db = await database;
    
    // First, let's check what columns exist in the LoHang table
    final tableInfo = await db.rawQuery("PRAGMA table_info(LoHang)");
    print('LoHang table columns: ${tableInfo.map((col) => col['name']).toList()}');
    
    // Try the simple query first with just khoHangID
    List<Map<String, dynamic>> maps;
    try {
      maps = await db.rawQuery('''
        SELECT * FROM LoHang 
        WHERE khoHangID = ?
        ORDER BY ngayNhap DESC
      ''', [khoID]);
      print('Query with khoHangID successful: ${maps.length} results');
    } catch (e) {
      print('Query with khoHangID failed: $e');
      
      // Try with KhoHangID (capital K)
      try {
        maps = await db.rawQuery('''
          SELECT * FROM LoHang 
          WHERE KhoHangID = ?
          ORDER BY ngayNhap DESC
        ''', [khoID]);
        print('Query with KhoHangID successful: ${maps.length} results');
      } catch (e2) {
        print('Query with KhoHangID also failed: $e2');
        
        // Let's see what warehouse IDs exist
        final allWarehouses = await db.rawQuery('SELECT DISTINCT khoHangID FROM LoHang LIMIT 10');
        print('Available warehouse IDs: ${allWarehouses.map((w) => w['khoHangID']).toList()}');
        
        // Try without NULLS LAST which might not be supported
        maps = await db.rawQuery('''
          SELECT * FROM LoHang 
          WHERE khoHangID = ?
        ''', [khoID]);
        print('Simple query successful: ${maps.length} results');
      }
    }
    
    print('Found ${maps.length} batches in database for warehouse $khoID');
    
    if (maps.isEmpty) {
      // Let's see a sample of all records to understand the data structure
      final sampleData = await db.rawQuery('SELECT * FROM LoHang LIMIT 5');
      print('Sample LoHang records:');
      for (var record in sampleData) {
        print('  Record: ${record}');
      }
    }
    
    final batches = List.generate(maps.length, (i) {
      try {
        return LoHangModel.fromMap(maps[i]);
      } catch (e) {
        print('Error creating LoHangModel from record ${i}: $e');
        print('Record data: ${maps[i]}');
        rethrow;
      }
    });
    
    // Log first few batches for debugging
    for (int i = 0; i < batches.length && i < 3; i++) {
      final batch = batches[i];
      print('Batch $i: ${batch.loHangID} - ${batch.maHangID} - Warehouse: ${batch.khoHangID} - Qty: ${batch.soLuongHienTai}');
    }
    
    return batches;
  } catch (e) {
    print('Error in getAllLoHangByKhoID: $e');
    print('Stack trace: ${StackTrace.current}');
    return [];
  }
}
Future<List<GiaoDichKhoModel>> getTransactionsByBatchIds(List<String> batchIds) async {
  final db = await database;
  if (batchIds.isEmpty) return [];
  
  final placeholders = batchIds.map((_) => '?').join(',');
  final result = await db.query(
    DatabaseTables.giaoDichKhoTable,
    where: 'loHangID IN ($placeholders)',
    whereArgs: batchIds,
    orderBy: 'ngay DESC, gio DESC', 
  );
  return result.map((map) => GiaoDichKhoModel.fromMap(map)).toList();
}
Future<KhuVucKhoChiTietModel?> getKhuVucKhoChiTietByChiTietID(String chiTietID) async {
  final db = await database;
  
  try {
    final List<Map<String, dynamic>> maps = await db.query(
      'KhuVucKhoChiTiet',
      where: 'chiTietID = ?',
      whereArgs: [chiTietID],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return KhuVucKhoChiTietModel.fromMap(maps.first);
    }
    
    return null;
  } catch (e) {
    print('Error getting KhuVucKhoChiTiet by chiTietID $chiTietID: $e');
    return null;
  }
}
Future<List<TonKhoModel>> getTonKhoByMaHangAndKho(String maHangID, List<String> khoHangIDs) async {
  final db = await database;
  String placeholders = khoHangIDs.map((_) => '?').join(',');
  List<String> args = [maHangID] + khoHangIDs;
  final List<Map<String, dynamic>> maps = await db.query(
    'TonKho',
    where: 'maHangID = ? AND khoHangID IN ($placeholders)',
    whereArgs: args,
  );
  return List.generate(maps.length, (i) {
    return TonKhoModel.fromMap(maps[i]);
  });
}
//ADDON DSHANG
Future<int> getMaxCounter() async {
  final db = await database;
  final result = await db.rawQuery('SELECT MAX(Counter) as maxCounter FROM DSHang');
  final maxCounter = result.isNotEmpty && result.first['maxCounter'] != null 
      ? int.tryParse(result.first['maxCounter'].toString()) 
      : 0;
  return maxCounter ?? 0;
} 
  // Get a DSHang record by UID
  Future<DSHangModel?> getDSHangByUID(String uid) async {
    final db = await database;
    final result = await db.query(
      'DSHang',
      where: 'UID = ?',
      whereArgs: [uid],
    );
    
    if (result.isNotEmpty) {
      return DSHangModel.fromMap(result.first);
    }
    return null;
  }
// ==================== KhachHangContact CRUD Operations ====================

/// Inserts a KhachHangContact record into the database.
Future<int> insertKhachHangContact(KhachHangContactModel contact) async {
  final db = await database;
  return await db.insert(
    DatabaseTables.khachHangContactTable,
    contact.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// Retrieves a KhachHangContact record by its uid.
Future<KhachHangContactModel?> getKhachHangContactById(String uid) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangContactTable,
    where: 'uid = ?',
    whereArgs: [uid],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return KhachHangContactModel.fromMap(maps.first);
  }
  return null;
}

/// Retrieves all KhachHangContact records from the database.
Future<List<KhachHangContactModel>> getAllKhachHangContacts() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(DatabaseTables.khachHangContactTable);
  return maps.map((map) => KhachHangContactModel.fromMap(map)).toList();
}

/// Updates a KhachHangContact record in the database.
Future<int> updateKhachHangContact(KhachHangContactModel contact) async {
  final db = await database;
  return await db.update(
    DatabaseTables.khachHangContactTable,
    contact.toMap(),
    where: 'uid = ?',
    whereArgs: [contact.uid],
  );
}

/// Deletes a KhachHangContact record from the database by its uid.
Future<int> deleteKhachHangContact(String uid) async {
  final db = await database;
  return await db.delete(
    DatabaseTables.khachHangContactTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
}

/// Clears all records from the KhachHangContact table.
Future<void> clearKhachHangContactTable() async {
  final db = await database;
  await db.delete(DatabaseTables.khachHangContactTable);
  print('Cleared KhachHangContact table');
}

/// Gets the total count of records in the KhachHangContact table.
Future<int> getKhachHangContactCount() async {
  final db = await database;
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.khachHangContactTable}');
  return Sqflite.firstIntValue(result) ?? 0;
}

/// Search KhachHangContact by name or phone number
Future<List<KhachHangContactModel>> searchKhachHangContacts(String searchTerm) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangContactTable,
    where: 'hoTen LIKE ? OR soDienThoai LIKE ? OR soDienThoai2 LIKE ? OR email LIKE ?',
    whereArgs: ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
  );
  return maps.map((map) => KhachHangContactModel.fromMap(map)).toList();
}

/// Get KhachHangContact records filtered by boPhan and tinhTrang
Future<List<KhachHangContactModel>> getFilteredKhachHangContacts({String? boPhan, String? tinhTrang}) async {
  final db = await database;
  String whereClause = '';
  List<String> whereArgs = [];
  
  if (boPhan != null) {
    whereClause += 'boPhan = ?';
    whereArgs.add(boPhan);
  }
  
  if (tinhTrang != null) {
    if (whereClause.isNotEmpty) {
      whereClause += ' AND ';
    }
    whereClause += 'tinhTrang = ?';
    whereArgs.add(tinhTrang);
  }
  
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangContactTable,
    where: whereClause.isNotEmpty ? whereClause : null,
    whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
  );
  
  return maps.map((map) => KhachHangContactModel.fromMap(map)).toList();
}

/// Get KhachHangContact records by a specific user (nguoiDung)
Future<List<KhachHangContactModel>> getKhachHangContactsByUser(String username) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangContactTable,
    where: 'nguoiDung = ? OR chiaSe LIKE ?',
    whereArgs: [username, '%$username%'],
  );
  return maps.map((map) => KhachHangContactModel.fromMap(map)).toList();
}

/// Get KhachHangContact records with upcoming birthdays (within next 30 days)
Future<List<KhachHangContactModel>> getUpcomingBirthdays() async {
  final db = await database;
  final now = DateTime.now();
  
  // Get the month and day for the next 30 days
  final List<String> dates = [];
  for (int i = 0; i < 30; i++) {
    final date = now.add(Duration(days: i));
    // Format as MM-DD for comparison
    final formattedDate = "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    dates.add(formattedDate);
  }
  
  // Build the SQL query to match birthdays regardless of year
  final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT * FROM ${DatabaseTables.khachHangContactTable}
    WHERE sinhNhat IS NOT NULL
    AND (
      ${dates.map((date) => "strftime('%m-%d', sinhNhat) = '$date'").join(' OR ')}
    )
  ''');
  
  return maps.map((map) => KhachHangContactModel.fromMap(map)).toList();
}
// ==================== KhachHang CRUD Operations ====================

/// Inserts a KhachHang record into the database.
Future<int> insertKhachHang(KhachHangModel khachHang) async {
  final db = await database;
  return await db.insert(
    DatabaseTables.khachHangTable,
    khachHang.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// Retrieves a KhachHang record by its uid.
Future<KhachHangModel?> getKhachHangById(String uid) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangTable,
    where: 'uid = ?',
    whereArgs: [uid],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return KhachHangModel.fromMap(maps.first);
  }
  return null;
}

/// Retrieves all KhachHang records from the database.
Future<List<KhachHangModel>> getAllKhachHang() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(DatabaseTables.khachHangTable);
  return maps.map((map) => KhachHangModel.fromMap(map)).toList();
}

/// Updates a KhachHang record in the database.
Future<int> updateKhachHang(KhachHangModel khachHang) async {
  final db = await database;
  return await db.update(
    DatabaseTables.khachHangTable,
    khachHang.toMap(),
    where: 'uid = ?',
    whereArgs: [khachHang.uid],
  );
}

/// Deletes a KhachHang record from the database by its uid.
Future<int> deleteKhachHang(String uid) async {
  final db = await database;
  return await db.delete(
    DatabaseTables.khachHangTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
}

/// Clears all records from the KhachHang table.
Future<void> clearKhachHangTable() async {
  final db = await database;
  await db.delete(DatabaseTables.khachHangTable);
  print('Cleared KhachHang table');
}

/// Gets the total count of records in the KhachHang table.
Future<int> getKhachHangCount() async {
  final db = await database;
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.khachHangTable}');
  return Sqflite.firstIntValue(result) ?? 0;
}

/// Searches KhachHang by tenDuAn, tenKyThuat, or tenRutGon
Future<List<KhachHangModel>> searchKhachHang(String searchTerm) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangTable,
    where: 'tenDuAn LIKE ? OR tenKyThuat LIKE ? OR tenRutGon LIKE ?',
    whereArgs: ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
  );
  return maps.map((map) => KhachHangModel.fromMap(map)).toList();
}

/// Get KhachHang records filtered by vungMien and phanLoai
Future<List<KhachHangModel>> getFilteredKhachHang({String? vungMien, String? phanLoai}) async {
  final db = await database;
  String whereClause = '';
  List<String> whereArgs = [];
  
  if (vungMien != null) {
    whereClause += 'vungMien = ?';
    whereArgs.add(vungMien);
  }
  
  if (phanLoai != null) {
    if (whereClause.isNotEmpty) {
      whereClause += ' AND ';
    }
    whereClause += 'phanLoai = ?';
    whereArgs.add(phanLoai);
  }
  
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangTable,
    where: whereClause.isNotEmpty ? whereClause : null,
    whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
  );
  
  return maps.map((map) => KhachHangModel.fromMap(map)).toList();
}

/// Get KhachHang records by loaiHinh
Future<List<KhachHangModel>> getKhachHangByLoaiHinh(String loaiHinh) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangTable,
    where: 'loaiHinh = ?',
    whereArgs: [loaiHinh],
  );
  return maps.map((map) => KhachHangModel.fromMap(map)).toList();
}

/// Get KhachHang records with pagination
Future<List<KhachHangModel>> getKhachHangPaginated(int limit, int offset) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseTables.khachHangTable,
    limit: limit,
    offset: offset,
    orderBy: 'tenDuAn ASC',
  );
  return maps.map((map) => KhachHangModel.fromMap(map)).toList();
}
// ==================== GoClean_CongViec CRUD Operations ====================

  /// Inserts a GoCleanCongViec record into the database.
  Future<int> insertGoCleanCongViec(GoCleanCongViecModel congViec) async {
    final db = await database;
    return await db.insert(
      'GoClean_CongViec', // Using string literal
      congViec.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a GoCleanCongViec record by its LichLamViecID.
  Future<GoCleanCongViecModel?> getGoCleanCongViecById(String lichLamViecID) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'GoClean_CongViec', // Using string literal
      where: 'LichLamViecID = ?',
      whereArgs: [lichLamViecID],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return GoCleanCongViecModel.fromMap(maps.first);
    }
    return null;
  }

  /// Retrieves all GoCleanCongViec records from the database.
  Future<List<GoCleanCongViecModel>> getAllGoCleanCongViec() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('GoClean_CongViec'); // Using string literal
    return maps.map((map) => GoCleanCongViecModel.fromMap(map)).toList();
  }

  /// Updates a GoCleanCongViec record in the database.
  Future<int> updateGoCleanCongViec(GoCleanCongViecModel congViec) async {
    final db = await database;
    return await db.update(
      'GoClean_CongViec', // Using string literal
      congViec.toMap(),
      where: 'LichLamViecID = ?',
      whereArgs: [congViec.lichLamViecID],
    );
  }

  /// Deletes a GoCleanCongViec record from the database by its LichLamViecID.
  Future<int> deleteGoCleanCongViec(String lichLamViecID) async {
    final db = await database;
    return await db.delete(
      'GoClean_CongViec', // Using string literal
      where: 'LichLamViecID = ?',
      whereArgs: [lichLamViecID],
    );
  }

  /// Clears all records from the GoClean_CongViec table.
  Future<void> clearGoCleanCongViecTable() async {
    final db = await database;
    await db.delete('GoClean_CongViec'); // Using string literal
    print('Cleared GoClean_CongViec table');
  }

  /// Gets the total count of records in the GoClean_CongViec table.
  Future<int> getGoCleanCongViecCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM GoClean_CongViec'); // Using string literal
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== GoClean_TaiKhoan CRUD Operations ====================

  /// Inserts a GoCleanTaiKhoan record into the database.
  Future<int> insertGoCleanTaiKhoan(GoCleanTaiKhoanModel taiKhoan) async {
    final db = await database;
    return await db.insert(
      'GoClean_TaiKhoan', // Using string literal
      taiKhoan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a GoCleanTaiKhoan record by its UID.
  Future<GoCleanTaiKhoanModel?> getGoCleanTaiKhoanByUID(String uid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'GoClean_TaiKhoan', // Using string literal
      where: 'UID = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return GoCleanTaiKhoanModel.fromMap(maps.first);
    }
    return null;
  }

  /// Retrieves all GoCleanTaiKhoan records from the database.
  Future<List<GoCleanTaiKhoanModel>> getAllGoCleanTaiKhoan() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('GoClean_TaiKhoan'); // Using string literal
    return maps.map((map) => GoCleanTaiKhoanModel.fromMap(map)).toList();
  }

  /// Updates a GoCleanTaiKhoan record in the database.
  Future<int> updateGoCleanTaiKhoan(GoCleanTaiKhoanModel taiKhoan) async {
    final db = await database;
    return await db.update(
      'GoClean_TaiKhoan', // Using string literal
      taiKhoan.toMap(),
      where: 'UID = ?',
      whereArgs: [taiKhoan.uid],
    );
  }

  /// Deletes a GoCleanTaiKhoan record from the database by its UID.
  Future<int> deleteGoCleanTaiKhoan(String uid) async {
    final db = await database;
    return await db.delete(
      'GoClean_TaiKhoan', // Using string literal
      where: 'UID = ?',
      whereArgs: [uid],
    );
  }

  /// Clears all records from the GoClean_TaiKhoan table.
  Future<void> clearGoCleanTaiKhoanTable() async {
    final db = await database;
    await db.delete('GoClean_TaiKhoan'); // Using string literal
    print('Cleared GoClean_TaiKhoan table');
  }

  /// Gets the total count of records in the GoClean_TaiKhoan table.
  Future<int> getGoCleanTaiKhoanCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM GoClean_TaiKhoan'); // Using string literal
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== GoClean_YeuCau CRUD Operations ====================

  /// Inserts a GoCleanYeuCau record into the database.
  Future<int> insertGoCleanYeuCau(GoCleanYeuCauModel yeuCau) async {
    final db = await database;
    return await db.insert(
      'GoClean_YeuCau', // Using string literal
      yeuCau.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a GoCleanYeuCau record by its GiaoViecID.
  Future<GoCleanYeuCauModel?> getGoCleanYeuCauByGiaoViecID(String giaoViecID) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'GoClean_YeuCau', // Using string literal
      where: 'GiaoViecID = ?',
      whereArgs: [giaoViecID],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return GoCleanYeuCauModel.fromMap(maps.first);
    }
    return null;
  }

  /// Retrieves all GoCleanYeuCau records from the database.
  Future<List<GoCleanYeuCauModel>> getAllGoCleanYeuCau() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('GoClean_YeuCau'); // Using string literal
    return maps.map((map) => GoCleanYeuCauModel.fromMap(map)).toList();
  }

  /// Updates a GoCleanYeuCau record in the database.
  Future<void> updateGoCleanYeuCau(GoCleanYeuCauModel yeuCau) async {
  final db = await database;
  
  if (yeuCau.giaoViecID == null) {
    throw Exception('Cannot update record without a giaoViecID');
  }
  
  await db.update(
    'GoCleanYeuCau',
    yeuCau.toMap(),
    where: 'GiaoViecID = ?',
    whereArgs: [yeuCau.giaoViecID],
  );
  
  print('Updated GoCleanYeuCau with ID: ${yeuCau.giaoViecID}');
}

  /// Deletes a GoCleanYeuCau record from the database by its GiaoViecID.
  Future<int> deleteGoCleanYeuCau(String giaoViecID) async {
    final db = await database;
    return await db.delete(
      'GoClean_YeuCau', // Using string literal
      where: 'GiaoViecID = ?',
      whereArgs: [giaoViecID],
    );
  }

  /// Clears all records from the GoClean_YeuCau table.
  Future<void> clearGoCleanYeuCauTable() async {
    final db = await database;
    await db.delete('GoClean_YeuCau'); // Using string literal
    print('Cleared GoClean_YeuCau table');
  }

  /// Gets the total count of records in the GoClean_YeuCau table.
  Future<int> getGoCleanYeuCauCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM GoClean_YeuCau'); // Using string literal
    return Sqflite.firstIntValue(result) ?? 0;
  }
//ADDON:
// Get all branches from ChiTietDon
Future<List<String>> getAllBranches() async {
  final db = await database;
  final results = await db.rawQuery('SELECT DISTINCT chiNhanh FROM chitietdon WHERE chiNhanh IS NOT NULL');
  
  List<String> branches = [];
  for (var row in results) {
    final branch = row['chiNhanh']?.toString();
    if (branch != null && branch.isNotEmpty && !branches.contains(branch)) {
      branches.add(branch);
    }
  }
  
  return branches;
}

// Get all completed order items
Future<List<Map<String, dynamic>>> getCompletedOrderItems() async {
  final db = await database;
  return await db.rawQuery('''
    SELECT * FROM chitietdon 
    WHERE duyet = 'Hoàn thành' AND soLuongYeuCau > 0 AND idHang IS NOT NULL
  ''');
}

// Get all products
Future<List<Map<String, dynamic>>> getAllProducts() async {
  final db = await database;
  return await db.query('dshang');
}

// Get all stock levels
Future<List<Map<String, dynamic>>> getAllStockLevels() async {
  final db = await database;
  return await db.query('tonkho');
}

// Get product by ID
Future<Map<String, dynamic>?> getProductById(String id) async {
  final db = await database;
  final results = await db.query(
    'dshang',
    where: 'uid = ?',
    whereArgs: [id],
  );
  
  if (results.isNotEmpty) {
    return results.first;
  }
  return null;
}

// Get stock level for a specific product and branch
Future<Map<String, dynamic>?> getStockLevel(String productId, String branch) async {
  final db = await database;
  final results = await db.query(
    'tonkho',
    where: 'maHangID = ? AND khoHangID = ?',
    whereArgs: [productId, branch],
  );
  
  if (results.isNotEmpty) {
    return results.first;
  }
  return null;
}
Future<void> diagnoseMissingKhuVucKhoID(String khuVucKhoID) async {
  try {
    final db = await database;
    print('\n======= DIAGNOSING MISSING KHUVUCKHOID: $khuVucKhoID =======');
    
    // 1. Check if the khuVucKhoID exists in the LoHang table
    final loHangCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.loHangTable} WHERE khuVucKhoID = ?',
      [khuVucKhoID]
    );
    final loHangMatches = Sqflite.firstIntValue(loHangCount) ?? 0;
    print('Found $loHangMatches records in LoHang with khuVucKhoID = $khuVucKhoID');
    
    // 2. Check if the khuVucKhoID exists in the KhuVucKho table
    final khuVucKhoCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.khuVucKhoTable} WHERE khuVucKhoID = ?',
      [khuVucKhoID]
    );
    final khuVucKhoMatches = Sqflite.firstIntValue(khuVucKhoCount) ?? 0;
    print('Found $khuVucKhoMatches records in KhuVucKho with khuVucKhoID = $khuVucKhoID');
    
    // 3. Check if the khuVucKhoID exists in the KhuVucKhoChiTiet table
    final chiTietCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.khuVucKhoChiTietTable} WHERE khuVucKhoID = ?',
      [khuVucKhoID]
    );
    final chiTietMatches = Sqflite.firstIntValue(chiTietCount) ?? 0;
    print('Found $chiTietMatches records in KhuVucKhoChiTiet with khuVucKhoID = $khuVucKhoID');
    
    // 4. List all distinct khuVucKhoID in KhuVucKhoChiTiet to see what format they have
    final distinctIDs = await db.rawQuery(
      'SELECT DISTINCT khuVucKhoID FROM ${DatabaseTables.khuVucKhoChiTietTable} LIMIT 10'
    );
    print('Sample distinct khuVucKhoID values in KhuVucKhoChiTiet:');
    for (var record in distinctIDs) {
      print('- ${record['khuVucKhoID']}');
    }
    
    // 5. Check if there's a case-sensitive issue with the khuVucKhoID
    if (chiTietMatches == 0) {
      print('Checking for case-insensitive matches...');
      final lowerCaseQuery = await db.rawQuery(
        'SELECT * FROM ${DatabaseTables.khuVucKhoChiTietTable} WHERE LOWER(khuVucKhoID) = LOWER(?)',
        [khuVucKhoID]
      );
      print('Found ${lowerCaseQuery.length} records with case-insensitive match');
      
      if (lowerCaseQuery.isNotEmpty) {
        print('Case-sensitive ID in database: ${lowerCaseQuery.first['khuVucKhoID']}');
      }
    }
    
    print('======= END DIAGNOSIS =======\n');
  } catch (e) {
    print('Error during diagnosis: $e');
  }
}
Future<KhuVucKhoModel?> getTangFromKhuVucKhoID(String khuVucKhoID) async {
  try {
    final db = await database;
    
    // Check if the ID directly exists in KhuVucKho
    final directMatches = await db.query(
      DatabaseTables.khuVucKhoTable,
      where: 'khuVucKhoID = ?',
      whereArgs: [khuVucKhoID],
    );
    
    if (directMatches.isNotEmpty) {
      return KhuVucKhoModel.fromMap(directMatches.first);
    }
    
    // Try to extract a floor number if the ID follows a pattern like "a0000X"
    if (khuVucKhoID.startsWith('a0000')) {
      final floorNumber = khuVucKhoID.substring(5);
      if (int.tryParse(floorNumber) != null) {
        print('Extracted floor number $floorNumber from $khuVucKhoID');
        
        // Look for a record with Tang="Tầng X" or similar pattern
        final tangMatches = await db.query(
          DatabaseTables.khuVucKhoTable,
          where: 'tang LIKE ?',
          whereArgs: ['%$floorNumber%'],
        );
        
        if (tangMatches.isNotEmpty) {
          print('Found match by floor number: ${tangMatches.first}');
          return KhuVucKhoModel.fromMap(tangMatches.first);
        }
      }
    }
    
    return null;
  } catch (e) {
    print('Error in getTangFromKhuVucKhoID: $e');
    return null;
  }
}
// Get all products by brand
Future<List<DSHangModel>> getDSHangByThuongHieu(String thuongHieu) async {
  try {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.dsHangTable,
      where: 'thuongHieu = ?',
      whereArgs: [thuongHieu],
    );
    
    return List.generate(maps.length, (i) {
      return DSHangModel.fromMap(maps[i]);
    });
  } catch (e) {
    print('Error loading products by brand: $e');
    return [];
  }
}
// Get all batches for a warehouse
Future<List<LoHangModel>> getLoHangByKhoID(String khoHangID) async {
  try {
    print('=== getLoHangByKhoID for warehouse: $khoHangID ===');
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.loHangTable,
      where: 'khoHangID = ?',
      whereArgs: [khoHangID],
    );
    
    print('Found ${maps.length} batches for khoHangID: $khoHangID');
    
    if (maps.isNotEmpty) {
      print('Sample batch data:');
      print('loHangID: ${maps[0]['loHangID']}');
      print('maHangID: ${maps[0]['maHangID']}');
      print('khuVucKhoID: ${maps[0]['khuVucKhoID']}');
    }
    
    final batches = maps.map((map) => LoHangModel.fromMap(map)).toList();
    return batches;
  } catch (e) {
    print('Error loading batches for warehouse: $e');
    return [];
  }
}
// Add this method to check database tables structure
Future<void> checkDatabaseTables() async {
  try {
    final db = await database;
    
    // Check LoHang table structure
    print('\n=== CHECKING LOHANG TABLE ===');
    final loHangInfo = await db.rawQuery('PRAGMA table_info(${DatabaseTables.loHangTable})');
    print('LoHang table columns:');
    for (var col in loHangInfo) {
      print('${col['name']} (${col['type']})');
    }
    
    // Check DSHang table structure
    print('\n=== CHECKING DSHANG TABLE ===');
    final dsHangInfo = await db.rawQuery('PRAGMA table_info(${DatabaseTables.dsHangTable})');
    print('DSHang table columns:');
    for (var col in dsHangInfo) {
      print('${col['name']} (${col['type']})');
    }
    
    // Check KhuVucKhoChiTiet table structure
    print('\n=== CHECKING KHUVUCKHOCHITIET TABLE ===');
    final khuvucInfo = await db.rawQuery('PRAGMA table_info(${DatabaseTables.khuVucKhoChiTietTable})');
    print('KhuVucKhoChiTiet table columns:');
    for (var col in khuvucInfo) {
      print('${col['name']} (${col['type']})');
    }
    
    // Sample data from each table
    print('\n=== SAMPLE DATA FROM TABLES ===');
    
    final loHangSample = await db.query(DatabaseTables.loHangTable, limit: 2);
    print('LoHang sample (${loHangSample.length} records):');
    for (var record in loHangSample) {
      print(record);
    }
    
    final dsHangSample = await db.query(DatabaseTables.dsHangTable, limit: 2);
    print('DSHang sample (${dsHangSample.length} records):');
    for (var record in dsHangSample) {
      print(record);
    }
    
    final khuvucSample = await db.query(DatabaseTables.khuVucKhoChiTietTable, limit: 2);
    print('KhuVucKhoChiTiet sample (${khuvucSample.length} records):');
    for (var record in khuvucSample) {
      print(record);
    }
  } catch (e, stackTrace) {
    print('Error checking database tables: $e');
    print('Stack trace: $stackTrace');
  }
}
// Fetch all brands from products in the warehouse
Future<List<String>> getAllBrands() async {
  try {
    final db = await database;
    // Modified query to explicitly handle nulls and use correct field name
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT ThuongHieu FROM ${DatabaseTables.dsHangTable} 
      WHERE ThuongHieu IS NOT NULL AND ThuongHieu != ''
      ORDER BY ThuongHieu
    ''');
    
    // Debug what we're getting from the database
    print('Raw brand results from DB: ${maps.length} brands');
    if (maps.isNotEmpty) {
      print('Sample brand fields: ${maps[0].keys.toList()}');
    }
    
    // Filter out null values
    final brands = <String>[];
    for (var map in maps) {
      final thuongHieu = map['ThuongHieu'];
      if (thuongHieu != null && thuongHieu is String && thuongHieu.isNotEmpty) {
        brands.add(thuongHieu);
        print('Brand added: $thuongHieu');
      }
    }
    
    print('Final brand list: ${brands.join(', ')}');
    return brands;
  } catch (e) {
    print('Error loading brands: $e');
    return [];
  }
}
// Fetch products by brand
Future<List<String>> getProductNamesByBrand(String brand) async {
  try {
    final db = await database;
    // Modified query to use correct field names
    print('Querying products for brand: $brand');
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT TenSanPham FROM ${DatabaseTables.dsHangTable} 
      WHERE ThuongHieu = ? AND TenSanPham IS NOT NULL AND TenSanPham != ''
      ORDER BY TenSanPham
    ''', [brand]);
    
    print('Raw product results for brand $brand: ${maps.length} products');
    
    // Filter out null values
    final products = <String>[];
    for (var map in maps) {
      final tenSanPham = map['TenSanPham'];
      if (tenSanPham != null && tenSanPham is String && tenSanPham.isNotEmpty) {
        products.add(tenSanPham);
        print('Product added for brand $brand: $tenSanPham');
      }
    }
    
    print('Final product list for brand $brand: ${products.join(', ')}');
    return products;
  } catch (e) {
    print('Error loading product names: $e');
    return [];
  }
}

// Get all product names in warehouse
Future<List<String>> getAllProductNames() async {
  try {
    final db = await database;
    // Modified query to use correct field name
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT TenSanPham FROM ${DatabaseTables.dsHangTable} 
      WHERE TenSanPham IS NOT NULL AND TenSanPham != ''
      ORDER BY TenSanPham
    ''');
    
    print('Raw all products results from DB: ${maps.length} products');
    
    // Filter out null values
    final products = <String>[];
    for (var map in maps) {
      final tenSanPham = map['TenSanPham'];
      if (tenSanPham != null && tenSanPham is String && tenSanPham.isNotEmpty) {
        products.add(tenSanPham);
      }
    }
    
    print('Final all products list count: ${products.length}');
    if (products.length > 0) {
      print('Sample products: ${products.take(5).join(', ')}...');
    }
    
    return products;
  } catch (e) {
    print('Error loading all product names: $e');
    return [];
  }
}
Map<String, dynamic> normalizeProductFields(Map<String, dynamic> product) {
  final normalized = <String, dynamic>{};
  
  // Define field mappings (original DB field -> normalized field)
  final fieldMap = {
    'uid': 'uid',
    'sku': 'sku',
    'Counter': 'counter',
    'MaNhapKho': 'maNhapKho',
    'TenModel': 'tenModel',
    'TenSanPham': 'tenSanPham',
    'SanPhamGoc': 'sanPhamGoc',
    'PhanLoai1': 'phanLoai1',
    'CongDung': 'congDung',
    'ChatLieu': 'chatLieu',
    'MauSac': 'mauSac',
    'KichThuoc': 'kichThuoc',
    'DungTich': 'dungTich',
    'KhoiLuong': 'khoiLuong',
    'QuyCachDongGoi': 'quyCachDongGoi',
    'SoLuongDongGoi': 'soLuongDongGoi',
    'DonVi': 'donVi',
    'KichThuocDongGoi': 'kichThuocDongGoi',
    'ThuongHieu': 'thuongHieu',
    'NhaCungCap': 'nhaCungCap',
    'XuatXu': 'xuatXu',
    'MoTa': 'moTa',
    'HinhAnh': 'hinhAnh',
    'HangTieuHao': 'hangTieuHao',
    'CoThoiHan': 'coThoiHan',
    'ThoiHanSuDung': 'thoiHanSuDung',
  };
  
  // Debug print to see original product keys
  print('Original product keys: ${product.keys.toList()}');
  
  // Map each field, handling case where original field might be missing
  fieldMap.forEach((originalField, normalizedField) {
    // First check if the original field exists
    if (product.containsKey(originalField)) {
      normalized[normalizedField] = product[originalField];
    } else {
      // Try case-insensitive lookup
      final originalLower = originalField.toLowerCase();
      for (var key in product.keys) {
        if (key.toLowerCase() == originalLower) {
          normalized[normalizedField] = product[key];
          break;
        }
      }
    }
  });
  
  // Debug the normalized fields
  print('Normalized product fields:');
  print('- tenSanPham: ${normalized['tenSanPham']}');
  print('- thuongHieu: ${normalized['thuongHieu']}');
  print('- phanLoai1: ${normalized['phanLoai1']}');
  
  return normalized;
}
Future<Map<String, dynamic>?> getProductDetailsByMaHangID(String maHangID) async {
  try {
    print('=== getProductDetailsByMaHangID for: $maHangID ===');
    final db = await database;
    
    // Use case-insensitive query with rawQuery
    print('Trying case-insensitive match for uid or sku...');
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT * FROM ${DatabaseTables.dsHangTable} WHERE LOWER(uid) = LOWER(?) OR LOWER(sku) = LOWER(?) LIMIT 1',
      [maHangID, maHangID]
    );
    
    print('Found ${results.length} matches with case-insensitive query');
    
    if (results.isNotEmpty) {
      final product = results.first;
      
      // Debug what the brand is
      final thuongHieu = product['ThuongHieu'];
      print('Product found: ${product['TenSanPham']} (Brand: $thuongHieu)');
      
      // Print all keys and values to debug
      print('Product details:');
      product.forEach((key, value) {
        print('$key: $value');
      });
      
      return product;
    }
    
    // If still no match found, try a direct lookup by exact maHangID
    print('Trying exact match for maHangID...');
    final exactMatches = await db.query(
      DatabaseTables.dsHangTable,
      where: 'MaNhapKho = ?',
      whereArgs: [maHangID],
      limit: 1
    );
    
    if (exactMatches.isNotEmpty) {
      print('Found product by exact MaNhapKho match');
      return exactMatches.first;
    }
    
    // If still no match found, dump some sample products to see what's in the database
    print('No product found. Checking sample products in database...');
    final sampleProducts = await db.query(
      DatabaseTables.dsHangTable,
      limit: 3
    );
    
    if (sampleProducts.isNotEmpty) {
      print('Sample products in database:');
      for (var prod in sampleProducts) {
        print('uid: ${prod['uid']}, sku: ${prod['sku']}, tenSanPham: ${prod['TenSanPham']}');
      }
    } else {
      print('No products found in database');
    }
    
    // Count total products
    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.dsHangTable}');
    final count = Sqflite.firstIntValue(countResult) ?? 0;
    print('Total products in database: $count');
    
    print('No product found for maHangID: $maHangID');
    return null;
  } catch (e, stackTrace) {
    print('Error getting product details by maHangID: $e');
    print('Stack trace: $stackTrace');
    return null;
  }
}
// Get location details for a khuVucKhoID and position (viTri)
Future<KhuVucKhoChiTietModel?> getLocationByKhuVucAndViTri(String khuVucKhoID, String? viTri) async {
  try {
    final db = await database;
    List<Map<String, dynamic>> maps;
    
    if (viTri != null && viTri.isNotEmpty) {
      maps = await db.query(
        DatabaseTables.khuVucKhoChiTietTable,
        where: 'khuVucKhoID = ? AND viTri = ?',
        whereArgs: [khuVucKhoID, viTri],
      );
    } else {
      maps = await db.query(
        DatabaseTables.khuVucKhoChiTietTable,
        where: 'khuVucKhoID = ?',
        whereArgs: [khuVucKhoID],
        limit: 1,
      );
    }
    
    if (maps.isNotEmpty) {
      return KhuVucKhoChiTietModel.fromMap(maps.first);
    }
    
    return null;
  } catch (e) {
    print('Error getting location details: $e');
    return null;
  }
}

// ==================== KhuVucKhoChiTiet CRUD Operations ====================

Future<List<KhuVucKhoModel>> getUniqueKhoHangIDs() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT DISTINCT khoHangID 
    FROM khuvuckho
    ORDER BY khoHangID
  ''');
  
  return List.generate(maps.length, (i) {
    return KhuVucKhoModel(
      khuVucKhoID: '',
      khoHangID: maps[i]['khoHangID'] as String?
    );
  });
}

// Get floors by warehouse ID
Future<List<KhuVucKhoModel>> getFloorsByWarehouseID(String khoHangID) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'khuvuckho',
    where: 'khoHangID = ?',
    whereArgs: [khoHangID],
  );
  
  return List.generate(maps.length, (i) {
    return KhuVucKhoModel.fromMap(maps[i]);
  });
}

// Get floor details
Future<List<KhuVucKhoChiTietModel>> getFloorDetails(String khuVucKhoID) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'khuvuckhochitiet',
    where: 'khuVucKhoID = ?',
    whereArgs: [khuVucKhoID],
  );
  
  return List.generate(maps.length, (i) {
    return KhuVucKhoChiTietModel.fromMap(maps[i]);
  });
}
Future<void> clearKhuVucKhoChiTietTable() async {
  final db = await database;
  await db.execute('DELETE FROM khuvuckhochitiet');
  print('Cleared KhuVucKhoChiTiet table');
}

// Add this method to DBHelper class
Future<int> getKhuVucKhoChiTietCount() async {
  final db = await database;
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM khuvuckhochitiet');
  return Sqflite.firstIntValue(result) ?? 0;
}
Future<List<KhuVucKhoChiTietModel>> getAllKhuVucKhoChiTiet() async {
  try {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(DatabaseTables.khuVucKhoChiTietTable);
    
    print("Raw database query result for KhuVucKhoChiTiet: ${maps.length} items");
    if (maps.isNotEmpty) {
      print("First raw item: ${maps[0]}");
      print("Keys in first item: ${maps[0].keys.toList()}");
    }
    
    return maps.map((e) => KhuVucKhoChiTietModel.fromMap(e)).toList();
  } catch (e) {
    print("Error getting all KhuVucKhoChiTiet: $e");
    return [];
  }
}

Future<Map<String, dynamic>?> getHangHoaByID(String maHangID) async {
  if (maHangID == null || maHangID.isEmpty) return null;
  
  final db = await database;
  try {
    // Fix: Use the correct table name and column for DSHang table
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.dsHangTable,  // Use DSHang table instead of lo_hang
      where: 'uid = ?',            // Try matching by uid first
      whereArgs: [maHangID],
      limit: 1,
    );

    if (maps.isEmpty) {
      // If not found by uid, try by sku
      final skuMaps = await db.query(
        DatabaseTables.dsHangTable,
        where: 'sku = ?',
        whereArgs: [maHangID],
        limit: 1,
      );
      
      return skuMaps.isNotEmpty ? skuMaps.first : null;
    }

    return maps.first;
  } catch (e) {
    print('Error querying HangHoa: $e');
    return null;
  }
}
Future<List<LoHangModel>> getLoHangByKhuVucKhoID(String khuVucKhoID) async {
  final db = await database;
  try {
    // Fix: Use the correct table name constant and query parameter
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.loHangTable,  // Use the constant defined in DatabaseTables
      where: 'khuVucKhoID = ?',    // Match the column name in the database
      whereArgs: [khuVucKhoID],
    );

    print('Found ${maps.length} lô hàng for khuVucKhoID: $khuVucKhoID');
    return maps.map((map) => LoHangModel.fromMap(map)).toList();
  } catch (e) {
    print('Error querying LoHang: $e');
    return [];
  }
}
Future<List<KhuVucKhoChiTietModel>> getKhuVucKhoChiTietByKhuVucKhoID(String khuVucKhoID) async {
  try {
    print('=== getKhuVucKhoChiTietByKhuVucKhoID for: $khuVucKhoID ===');
    
    final db = await database;
    
    // Try an exact match
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.khuVucKhoChiTietTable,
      where: 'khuVucKhoID = ?',
      whereArgs: [khuVucKhoID],
    );
    
    print('Found ${maps.length} location details with exact match');
    
    if (maps.isNotEmpty) {
      return maps.map((map) => KhuVucKhoChiTietModel.fromMap(map)).toList();
    }
    
    // No match found, run diagnostics
    await diagnoseMissingKhuVucKhoID(khuVucKhoID);
    
    // Return empty list if no match was found
    return [];
  } catch (e, stackTrace) {
    print('Error getting location details: $e');
    print('Stack trace: $stackTrace');
    return [];
  }
}
Future<List<Map<String, dynamic>>> getFullBatchesInfo(String khoHangID) async {
  final results = <Map<String, dynamic>>[];
  
  try {
    print('==== getFullBatchesInfo starting for khoHangID: $khoHangID ====');
    
    // First get all batches in the warehouse
    final batches = await getLoHangByKhoID(khoHangID);
    print('Found ${batches.length} batches in warehouse $khoHangID');
    
    final db = await database;
    
    // DEBUG: Check what's in the KhuVucKhoChiTiet table
    print('===== DIAGNOSING KhuVucKhoChiTiet TABLE =====');
    try {
      // Check if table exists
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='KhuVucKhoChiTiet'"
      );
      print('KhuVucKhoChiTiet table exists: ${tableCheck.isNotEmpty}');
      
      if (tableCheck.isNotEmpty) {
        // Check table structure
        final tableInfo = await db.rawQuery('PRAGMA table_info(KhuVucKhoChiTiet)');
        print('KhuVucKhoChiTiet columns:');
        for (var col in tableInfo) {
          print('${col['name']} (${col['type']})');
        }
        
        // Check for actual records
        final countCheck = await db.rawQuery('SELECT COUNT(*) as count FROM KhuVucKhoChiTiet');
        final count = Sqflite.firstIntValue(countCheck) ?? 0;
        print('KhuVucKhoChiTiet record count: $count');
        
        // Get sample records
        if (count > 0) {
          final sampleRecords = await db.query('KhuVucKhoChiTiet', limit: 3);
          print('Sample KhuVucKhoChiTiet records:');
          for (var record in sampleRecords) {
            print(record);
          }
          
          // Check what khuVucKhoID values exist
          final distinctIDs = await db.rawQuery(
            'SELECT DISTINCT khuVucKhoID FROM KhuVucKhoChiTiet LIMIT 10'
          );
          print('Sample distinct khuVucKhoID values:');
          for (var id in distinctIDs) {
            print('- ${id['khuVucKhoID']}');
          }
        }
      }
    } catch (e) {
      print('Error diagnosing KhuVucKhoChiTiet table: $e');
    }
    
    // For each batch, fetch the product and location info
    for (var batch in batches) {
      print('\n--- Processing batch: ${batch.loHangID} ---');
      
      // Get product details
      final product = await getProductDetailsByMaHangID(batch.maHangID ?? '');
      
      // Create productInfo map
      final Map<String, dynamic> productInfo;
      if (product != null) {
        productInfo = normalizeProductFields(product);
      } else {
        productInfo = {
          'tenSanPham': batch.maHangID,
          'thuongHieu': 'Không xác định',
          'donVi': '',
          'phanLoai1': '',
          'xuatXu': '',
          'moTa': '',
        };
      }
      
      // Get location info - Try various approaches with detailed logging
      String locationInfo = 'Khu vực: ${batch.khuVucKhoID ?? ""}';
      
      if (batch.khuVucKhoID != null) {
        print('Looking up location for khuVucKhoID: ${batch.khuVucKhoID}');
        
        // Try the table name with exact capitalization from schema
        try {
          print('Trying query on table KhuVucKhoChiTiet...');
          final exactQuery = await db.rawQuery(
            'SELECT * FROM KhuVucKhoChiTiet WHERE chiTietID = ?',
            [batch.khuVucKhoID]
          );
          print('Query result count: ${exactQuery.length}');
          
          if (exactQuery.isNotEmpty) {
            print('Found location record: ${exactQuery.first}');
            
            final location = exactQuery.first;
            List<String> parts = [];
            
            // Try all possible capitalization patterns for columns
            // You should adjust these based on the actual column names from the diagnostic output
            Object? tang = location['Tang'] ?? location['tang'] ?? location['TANG'];
            Object? phong = location['Phong'] ?? location['phong'] ?? location['PHONG'];
            Object? ke = location['Ke'] ?? location['ke'] ?? location['KE'];
            Object? tangke = location['TangKe'] ?? location['tangke'] ?? location['TANGKE'];
            Object? gio = location['Gio'] ?? location['gio'] ?? location['GIO'];

            print('Extracted fields - Tang: $tang, Phong: $phong, Ke: $ke $tangke $gio');
            
            if (tang != null && tang.toString().isNotEmpty) {
              parts.add('$tang');
            }
            
            if (phong != null && phong.toString().isNotEmpty) {
              parts.add('$phong');
            }
            
            if (ke != null && ke.toString().isNotEmpty) {
              parts.add('$ke');
            }
            if (tangke != null && tangke.toString().isNotEmpty) {
              parts.add('Tầng kệ: $tangke');
            }
            if (gio != null && gio.toString().isNotEmpty) {
              parts.add('Giỏ: $gio');
            }
            if (parts.isNotEmpty) {
              locationInfo = parts.join(', ');
              print('Final location info: $locationInfo');
            } else {
              print('No location parts found in record');
            }
          } else {
            print('No location record found for khuVucKhoID: ${batch.khuVucKhoID}');
            
            // Try with lowercase table name
            print('Trying query on table khuvuckhochitiet...');
            final lowercaseQuery = await db.rawQuery(
              'SELECT * FROM khuvuckhochitiet WHERE khuVucKhoID = ?',
              [batch.khuVucKhoID]
            );
            print('Lowercase query result count: ${lowercaseQuery.length}');
            
            if (lowercaseQuery.isNotEmpty) {
              print('Found location record with lowercase table name: ${lowercaseQuery.first}');
              // Processing continues similar to above...
            }
          }
        } catch (e) {
          print('Error querying location: $e');
        }
      }
      
      // Add to results
      results.add({
        'batch': batch,
        'product': productInfo,
        'location': locationInfo,
      });
    }
    
    return results;
  } catch (e) {
    print('Error getting full batch info: $e');
    return [];
  }
}
// Helper function to find field value with various capitalizations
String? findFieldValueWithVariations(Map<String, dynamic> map, List<String> variations) {
  for (var variation in variations) {
    if (map.containsKey(variation) && map[variation] != null) {
      return map[variation].toString();
    }
  }
  return null;
}
Future<KhuVucKhoChiTietModel?> getKhuVucKhoChiTietByID(String chiTietID) async {
  final chiTiets = await query(
    DatabaseTables.khuVucKhoChiTietTable,
    where: 'chiTietID = ?',
    whereArgs: [chiTietID],
  );
  if (chiTiets.isNotEmpty) {
    return KhuVucKhoChiTietModel.fromMap(chiTiets.first);
  }
  return null;
}

Future<void> insertKhuVucKhoChiTiet(KhuVucKhoChiTietModel chiTiet) async {
  await insert(DatabaseTables.khuVucKhoChiTietTable, chiTiet.toMap());
}

Future<void> updateKhuVucKhoChiTiet(KhuVucKhoChiTietModel chiTiet) async {
  await update(
    DatabaseTables.khuVucKhoChiTietTable,
    chiTiet.toMap(),
    where: 'chiTietID = ?',
    whereArgs: [chiTiet.chiTietID],
  );
}

Future<void> deleteKhuVucKhoChiTiet(String chiTietID) async {
  await delete(
    DatabaseTables.khuVucKhoChiTietTable,
    where: 'chiTietID = ?',
    whereArgs: [chiTietID],
  );
}
// ==================== DSHang CRUD Operations ====================
Future<List<LoHangModel>> getLoHangByMaHangAndKho(String maHangID, String khoHangID) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'LoHang',
    where: 'maHangID = ? AND khoHangID = ? AND soLuongHienTai > 0',
    whereArgs: [maHangID, khoHangID],
  );
  return List.generate(maps.length, (i) {
    return LoHangModel.fromMap(maps[i]);
  });
}
Future<List<DSHangModel>> getAllDSHang() async {
  try {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('dshang');
    
    print("Raw database query result for DSHang: ${maps.length} items");
    if (maps.isNotEmpty) {
      print("First raw item: ${maps[0]}");
      
      // Debug: Print all keys from the first item to see actual case
      print("Keys in first item: ${maps[0].keys.toList()}");
    }
    
    return maps.map((e) => DSHangModel.fromMap(e)).toList();
  } catch (e) {
    print("Error getting all DSHang: $e");
    return [];
  }
}

Future<DSHangModel?> getDSHangBySKU(String sku) async {
  final dshangs = await query(
    DatabaseTables.dsHangTable,
    where: 'sku = ?',
    whereArgs: [sku],
  );
  if (dshangs.isNotEmpty) {
    return DSHangModel.fromMap(dshangs.first);
  }
  return null;
}
Future<int> insertDSHang(DSHangModel item) async {
  final db = await database;
  
  // Convert boolean values to integer for SQLite
  final map = item.toMap();
  
  // Make sure boolean values are converted to integers
  if (map['CoThoiHan'] != null) {
    map['CoThoiHan'] = map['CoThoiHan'] == true ? 1 : 0;
  }
  if (map['HangTieuHao'] != null) {
    map['HangTieuHao'] = map['HangTieuHao'] == true ? 1 : 0;
  }
  
  return await db.insert('DSHang', map);
}

Future<int> updateDSHang(DSHangModel item) async {
  final db = await database;
  
  // Convert boolean values to integer for SQLite
  final map = item.toMap();
  
  // Make sure boolean values are converted to integers
  if (map['CoThoiHan'] != null) {
    map['CoThoiHan'] = map['CoThoiHan'] == true ? 1 : 0;
  }
  if (map['HangTieuHao'] != null) {
    map['HangTieuHao'] = map['HangTieuHao'] == true ? 1 : 0;
  }
  
  return await db.update(
    'DSHang',
    map,
    where: 'UID = ?',
    whereArgs: [item.uid],
  );
}
Future<void> deleteDSHang(String uid) async {
  await delete(
    DatabaseTables.dsHangTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
}

// ==================== GiaoDichKho CRUD Operations ====================
Future<List<GiaoDichKhoModel>> getAllGiaoDichKho() async {
  final giaodichkhos = await query(DatabaseTables.giaoDichKhoTable);
  return giaodichkhos.map((giaodichkho) => GiaoDichKhoModel.fromMap(giaodichkho)).toList();
}

Future<GiaoDichKhoModel?> getGiaoDichKhoById(String giaoDichID) async {
  final giaodichkhos = await query(
    DatabaseTables.giaoDichKhoTable,
    where: 'giaoDichID = ?',
    whereArgs: [giaoDichID],
  );
  if (giaodichkhos.isNotEmpty) {
    return GiaoDichKhoModel.fromMap(giaodichkhos.first);
  }
  return null;
}

Future<List<GiaoDichKhoModel>> getGiaoDichKhoByLoHang(String loHangID) async {
  final giaodichkhos = await query(
    DatabaseTables.giaoDichKhoTable,
    where: 'loHangID = ?',
    whereArgs: [loHangID],
  );
  return giaodichkhos.map((giaodichkho) => GiaoDichKhoModel.fromMap(giaodichkho)).toList();
}

Future<void> insertGiaoDichKho(GiaoDichKhoModel giaodichkho) async {
  await insert(DatabaseTables.giaoDichKhoTable, giaodichkho.toMap());
}

Future<void> updateGiaoDichKho(GiaoDichKhoModel giaodichkho) async {
  await update(
    DatabaseTables.giaoDichKhoTable,
    giaodichkho.toMap(),
    where: 'giaoDichID = ?',
    whereArgs: [giaodichkho.giaoDichID],
  );
}

Future<void> deleteGiaoDichKho(String giaoDichID) async {
  await delete(
    DatabaseTables.giaoDichKhoTable,
    where: 'giaoDichID = ?',
    whereArgs: [giaoDichID],
  );
}

// ==================== GiaoHang CRUD Operations ====================
Future<List<GiaoHangModel>> getAllGiaoHang() async {
  final giaohangs = await query(DatabaseTables.giaoHangTable);
  return giaohangs.map((giaohang) => GiaoHangModel.fromMap(giaohang)).toList();
}

Future<GiaoHangModel?> getGiaoHangByUID(String uid) async {
  final giaohangs = await query(
    DatabaseTables.giaoHangTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
  if (giaohangs.isNotEmpty) {
    return GiaoHangModel.fromMap(giaohangs.first);
  }
  return null;
}

Future<List<Map<String, dynamic>>> getGiaoHangBySoPhieu(String soPhieu) async {
  final db = await database;
  return await db.query(
    'GiaoHang',
    where: 'SoPhieu = ?',
    whereArgs: [soPhieu],
    orderBy: 'Ngay DESC, Gio DESC',
  );
}

Future<int> insertGiaoHang(Map<String, dynamic> giaoHang) async {
  final db = await database;
  return await db.insert('GiaoHang', giaoHang);
}

Future<void> updateGiaoHang(GiaoHangModel giaohang) async {
  await update(
    DatabaseTables.giaoHangTable,
    giaohang.toMap(),
    where: 'UID = ?',
    whereArgs: [giaohang.uid],
  );
}

Future<void> deleteGiaoHang(String uid) async {
  await delete(
    DatabaseTables.giaoHangTable,
    where: 'UID = ?',
    whereArgs: [uid],
  );
}

// ==================== Kho CRUD Operations ====================
Future<List<KhoModel>> getAllKho() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query('kho');
  return List.generate(maps.length, (i) {
    return KhoModel.fromMap(maps[i]);
  });
}

Future<KhoModel?> getKhoById(String khoHangID) async {
  final khos = await query(
    DatabaseTables.khoTable,
    where: 'khoHangID = ?',
    whereArgs: [khoHangID],
  );
  if (khos.isNotEmpty) {
    return KhoModel.fromMap(khos.first);
  }
  return null;
}

Future<void> insertKho(KhoModel kho) async {
  await insert(DatabaseTables.khoTable, kho.toMap());
}

Future<void> updateKho(KhoModel kho) async {
  await update(
    DatabaseTables.khoTable,
    kho.toMap(),
    where: 'khoHangID = ?',
    whereArgs: [kho.khoHangID],
  );
}

Future<void> deleteKho(String khoHangID) async {
  // First delete all related KhuVucKho
  await delete(
    DatabaseTables.khuVucKhoTable,
    where: 'khoHangID = ?',
    whereArgs: [khoHangID],
  );
  
  // Then delete the Kho
  await delete(
    DatabaseTables.khoTable,
    where: 'khoHangID = ?',
    whereArgs: [khoHangID],
  );
}

// ==================== KhuVucKho CRUD Operations ====================
Future<List<KhuVucKhoModel>> getAllKhuVucKho() async {
  final khuvuckhos = await query(DatabaseTables.khuVucKhoTable);
  return khuvuckhos.map((khuvuckho) => KhuVucKhoModel.fromMap(khuvuckho)).toList();
}
Future<List<KhuVucKhoModel>> getKhuVucKhoByKhoID(String khoHangID) async {
  final db = await database;
  
  // Add debugging query to check what's in the khuvuckho table
  print('Querying khuvuckho for khoHangID: $khoHangID');
  final checkData = await db.query('khuvuckho');
  print('All records in khuvuckho: $checkData');
  
  // Now try to get the specific records
  final List<Map<String, dynamic>> maps = await db.query(
    'khuvuckho',
    where: 'khoHangID = ?',
    whereArgs: [khoHangID],
  );
  
  print('Found ${maps.length} matching records for khoHangID: $khoHangID');
  
  return List.generate(maps.length, (i) {
    print('Record $i: ${maps[i]}');
    return KhuVucKhoModel.fromMap(maps[i]);
  });
}
Future<List<KhuVucKhoModel>> getKhuVucKhoById(String khuVucKhoID) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'khuvuckho',
    where: 'khuVucKhoID = ?',
    whereArgs: [khuVucKhoID],
  );
  return List.generate(maps.length, (i) {
    return KhuVucKhoModel.fromMap(maps[i]);
  });
}
Future<List<KhuVucKhoModel>> getKhuVucKhoByKhoHang(String khoHangID) async {
  final khuvuckhos = await query(
    DatabaseTables.khuVucKhoTable,
    where: 'khoHangID = ?',
    whereArgs: [khoHangID],
  );
  return khuvuckhos.map((khuvuckho) => KhuVucKhoModel.fromMap(khuvuckho)).toList();
}

Future<void> insertKhuVucKho(KhuVucKhoModel khuvuckho) async {
  await insert(DatabaseTables.khuVucKhoTable, khuvuckho.toMap());
}

Future<void> updateKhuVucKho(KhuVucKhoModel khuvuckho) async {
  await update(
    DatabaseTables.khuVucKhoTable,
    khuvuckho.toMap(),
    where: 'khuVucKhoID = ?',
    whereArgs: [khuvuckho.khuVucKhoID],
  );
}

Future<void> deleteKhuVucKho(String khuVucKhoID) async {
  await delete(
    DatabaseTables.khuVucKhoTable,
    where: 'khuVucKhoID = ?',
    whereArgs: [khuVucKhoID],
  );
}
Future<int> getKhuVucKhoCount() async {
  final db = await database;
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM khuvuckho');
  return Sqflite.firstIntValue(result) ?? 0;
}

Future<void> clearKhuVucKhoTable() async {
  final db = await database;
  await db.delete('khuvuckho');
}

Future<Batch> startBatch() async {
  final db = await database;
  return db.batch();
}

void addToBatch(Batch batch, String sql, List<dynamic> arguments) {
  batch.rawInsert(sql, arguments);
}

Future<void> commitBatch(Batch batch) async {
  await batch.commit(noResult: true);
}
// ==================== LoHang CRUD Operations ====================
Future<List<LoHangModel>> getAllLoHang() async {
  final lohangs = await query(DatabaseTables.loHangTable);
  return lohangs.map((lohang) => LoHangModel.fromMap(lohang)).toList();
}

Future<LoHangModel?> getLoHangById(String loHangID) async {
  final lohangs = await query(
    DatabaseTables.loHangTable,
    where: 'loHangID = ?',
    whereArgs: [loHangID],
  );
  if (lohangs.isNotEmpty) {
    return LoHangModel.fromMap(lohangs.first);
  }
  return null;
}

Future<void> insertLoHang(LoHangModel lohang) async {
  await insert(DatabaseTables.loHangTable, lohang.toMap());
}

Future<void> updateLoHang(LoHangModel lohang) async {
  await update(
    DatabaseTables.loHangTable,
    lohang.toMap(),
    where: 'loHangID = ?',
    whereArgs: [lohang.loHangID],
  );
}

Future<void> deleteLoHang(String loHangID) async {
  // First delete all related GiaoDichKho
  await delete(
    DatabaseTables.giaoDichKhoTable,
    where: 'loHangID = ?',
    whereArgs: [loHangID],
  );
  
  // Then delete the LoHang
  await delete(
    DatabaseTables.loHangTable,
    where: 'loHangID = ?',
    whereArgs: [loHangID],
  );
}
Future<List<LoHangModel>> getLoHangForProduct(String maHangID, String khoHangID) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'lohang',
    where: 'MaHangID = ? AND KhoHangID = ?',
    whereArgs: [maHangID, khoHangID],
  );
  
  return List.generate(maps.length, (i) {
    return LoHangModel.fromMap(maps[i]);
  });
}
// ==================== TonKho CRUD Operations ====================
Future<List<TonKhoModel>> getAllTonKho() async {
  final tonkhos = await query(DatabaseTables.tonKhoTable);
  return tonkhos.map((tonkho) => TonKhoModel.fromMap(tonkho)).toList();
}

Future<TonKhoModel?> getTonKhoById(String tonKhoID) async {
  final tonkhos = await query(
    DatabaseTables.tonKhoTable,
    where: 'tonKhoID = ?',
    whereArgs: [tonKhoID],
  );
  if (tonkhos.isNotEmpty) {
    return TonKhoModel.fromMap(tonkhos.first);
  }
  return null;
}

Future<List<TonKhoModel>> getTonKhoByMaHang(String maHangID) async {
  final tonkhos = await query(
    DatabaseTables.tonKhoTable,
    where: 'maHangID = ?',
    whereArgs: [maHangID],
  );
  return tonkhos.map((tonkho) => TonKhoModel.fromMap(tonkho)).toList();
}

Future<List<TonKhoModel>> getTonKhoByKhoHang(String khoHangID) async {
  final tonkhos = await query(
    DatabaseTables.tonKhoTable,
    where: 'khoHangID = ?',
    whereArgs: [khoHangID],
  );
  return tonkhos.map((tonkho) => TonKhoModel.fromMap(tonkho)).toList();
}

Future<void> insertTonKho(TonKhoModel tonkho) async {
  await insert(DatabaseTables.tonKhoTable, tonkho.toMap());
}

Future<void> updateTonKho(TonKhoModel tonkho) async {
  await update(
    DatabaseTables.tonKhoTable,
    tonkho.toMap(),
    where: 'tonKhoID = ?',
    whereArgs: [tonkho.tonKhoID],
  );
}

Future<void> deleteTonKho(String tonKhoID) async {
  // First delete all related LoHang records
  await delete(
    DatabaseTables.loHangTable,
    where: 'tonKhoID = ?',
    whereArgs: [tonKhoID],
  );
  
  // Then delete the TonKho record
  await delete(
    DatabaseTables.tonKhoTable,
    where: 'tonKhoID = ?',
    whereArgs: [tonKhoID],
  );
}

// ==================== News CRUD Operations ====================
Future<List<NewsModel>> getAllNews() async {
  final news = await query(DatabaseTables.newsTable);
  return news.map((item) => NewsModel.fromMap(item)).toList();
}

Future<NewsModel?> getNewsById(String newsID) async {
  final news = await query(
    DatabaseTables.newsTable,
    where: 'NewsID = ?',
    whereArgs: [newsID],
  );
  if (news.isNotEmpty) {
    return NewsModel.fromMap(news.first);
  }
  return null;
}

Future<void> insertNews(NewsModel news) async {
  await insert(DatabaseTables.newsTable, news.toMap());
}

Future<void> updateNews(NewsModel news) async {
  await update(
    DatabaseTables.newsTable,
    news.toMap(),
    where: 'NewsID = ?',
    whereArgs: [news.newsID],
  );
}

Future<void> deleteNews(String newsID) async {
  // First delete all related NewsActivity
  await delete(
    DatabaseTables.newsActivityTable,
    where: 'NewsID = ?',
    whereArgs: [newsID],
  );
  
  // Then delete the News
  await delete(
    DatabaseTables.newsTable,
    where: 'NewsID = ?',
    whereArgs: [newsID],
  );
}

// ==================== NewsActivity CRUD Operations ====================
Future<List<NewsActivityModel>> getAllNewsActivity() async {
  final activities = await query(DatabaseTables.newsActivityTable);
  return activities.map((activity) => NewsActivityModel.fromMap(activity)).toList();
}

Future<NewsActivityModel?> getNewsActivityById(String likeID) async {
  final activities = await query(
    DatabaseTables.newsActivityTable,
    where: 'LikeID = ?',
    whereArgs: [likeID],
  );
  if (activities.isNotEmpty) {
    return NewsActivityModel.fromMap(activities.first);
  }
  return null;
}

Future<List<NewsActivityModel>> getNewsActivityByNews(String newsID) async {
  final activities = await query(
    DatabaseTables.newsActivityTable,
    where: 'NewsID = ?',
    whereArgs: [newsID],
  );
  return activities.map((activity) => NewsActivityModel.fromMap(activity)).toList();
}

Future<List<NewsActivityModel>> getNewsActivityByUser(String nguoiDung) async {
  final activities = await query(
    DatabaseTables.newsActivityTable,
    where: 'NguoiDung = ?',
    whereArgs: [nguoiDung],
  );
  return activities.map((activity) => NewsActivityModel.fromMap(activity)).toList();
}

Future<void> insertNewsActivity(NewsActivityModel activity) async {
  await insert(DatabaseTables.newsActivityTable, activity.toMap());
}

Future<void> updateNewsActivity(NewsActivityModel activity) async {
  await update(
    DatabaseTables.newsActivityTable,
    activity.toMap(),
    where: 'LikeID = ?',
    whereArgs: [activity.likeID],
  );
}

Future<void> deleteNewsActivity(String likeID) async {
  await delete(
    DatabaseTables.newsActivityTable,
    where: 'LikeID = ?',
    whereArgs: [likeID],
  );
}
// ==================== DonHang CRUD Operations ====================
Future<List<DonHangModel>> getAllDonHang() async {
  final donhangs = await query(DatabaseTables.donHangTable);
  return donhangs.map((donhang) => DonHangModel.fromMap(donhang)).toList();
}

Future<DonHangModel?> getDonHangBySoPhieu(String soPhieu) async {
  final donhangs = await query(
    DatabaseTables.donHangTable,
    where: 'soPhieu = ?',
    whereArgs: [soPhieu],
  );
  if (donhangs.isNotEmpty) {
    return DonHangModel.fromMap(donhangs.first);
  }
  return null;
}

Future<List<DonHangModel>> getDonHangByNguoiTao(String nguoiTao) async {
  final donhangs = await query(
    DatabaseTables.donHangTable,
    where: 'nguoiTao = ?',
    whereArgs: [nguoiTao],
  );
  return donhangs.map((donhang) => DonHangModel.fromMap(donhang)).toList();
}

Future<List<DonHangModel>> getDonHangByTrangThai(String trangThai) async {
  final donhangs = await query(
    DatabaseTables.donHangTable,
    where: 'trangThai = ?',
    whereArgs: [trangThai],
  );
  return donhangs.map((donhang) => DonHangModel.fromMap(donhang)).toList();
}

Future<void> insertDonHang(DonHangModel donhang) async {
  await insert(DatabaseTables.donHangTable, donhang.toMap());
}

Future<void> updateDonHang(DonHangModel donhang) async {
  await update(
    DatabaseTables.donHangTable,
    donhang.toMap(),
    where: 'soPhieu = ?',
    whereArgs: [donhang.soPhieu],
  );
}

Future<void> deleteDonHang(String soPhieu) async {
  // First delete all related ChiTietDon records
  await delete(
    DatabaseTables.chiTietDonTable,
    where: 'soPhieu = ?',
    whereArgs: [soPhieu],
  );
  
  // Then delete the DonHang record
  await delete(
    DatabaseTables.donHangTable,
    where: 'soPhieu = ?',
    whereArgs: [soPhieu],
  );
}

// ==================== ChiTietDon CRUD Operations ====================
Future<List<ChiTietDonModel>> getAllChiTietDon() async {
  final chitietdons = await query(DatabaseTables.chiTietDonTable);
  return chitietdons.map((chitiet) => ChiTietDonModel.fromMap(chitiet)).toList();
}

Future<ChiTietDonModel?> getChiTietDonByUID(String uid) async {
  final chitietdons = await query(
    DatabaseTables.chiTietDonTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
  if (chitietdons.isNotEmpty) {
    return ChiTietDonModel.fromMap(chitietdons.first);
  }
  return null;
}

Future<List<ChiTietDonModel>> getChiTietDonBySoPhieu(String soPhieu) async {
  final chitietdons = await query(
    DatabaseTables.chiTietDonTable,
    where: 'soPhieu = ?',
    whereArgs: [soPhieu],
  );
  return chitietdons.map((chitiet) => ChiTietDonModel.fromMap(chitiet)).toList();
}

Future<List<ChiTietDonModel>> getChiTietDonByTrangThai(String trangThai) async {
  final chitietdons = await query(
    DatabaseTables.chiTietDonTable,
    where: 'trangThai = ?',
    whereArgs: [trangThai],
  );
  return chitietdons.map((chitiet) => ChiTietDonModel.fromMap(chitiet)).toList();
}

Future<void> insertChiTietDon(ChiTietDonModel chitietdon) async {
  await insert(DatabaseTables.chiTietDonTable, chitietdon.toMap());
}

Future<void> updateChiTietDon(ChiTietDonModel chitietdon) async {
  await update(
    DatabaseTables.chiTietDonTable,
    chitietdon.toMap(),
    where: 'uid = ?',
    whereArgs: [chitietdon.uid],
  );
}

Future<void> deleteChiTietDon(String uid) async {
  await delete(
    DatabaseTables.chiTietDonTable,
    where: 'uid = ?',
    whereArgs: [uid],
  );
}

Future<void> deleteChiTietDonBySoPhieu(String soPhieu) async {
  await delete(
    DatabaseTables.chiTietDonTable,
    where: 'soPhieu = ?',
    whereArgs: [soPhieu],
  );
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
