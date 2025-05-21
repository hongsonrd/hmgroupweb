import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'user_credentials.dart';
import 'package:vibration/vibration.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'table_models.dart';
import 'db_helper.dart';
import 'hs_donhang.dart';
import 'hs_donhangdaily.dart';
import 'hs_scan.dart';
import 'hs_kho.dart';
import 'hs_dshang.dart';
import 'http_client.dart';
import 'hs_kho2.dart';
import 'hs_stat.dart';
import 'hs_donhangmoi.dart';
import 'hs_donhangxnkdaily.dart';

class AppVersion {
  final String version;
  final int buildNumber;
  
  AppVersion(this.version, this.buildNumber);
  
  factory AppVersion.fromString(String versionString) {
    final parts = versionString.split('+');
    return AppVersion(parts[0], int.parse(parts[1]));
  }
  
  int compareWith(AppVersion other) {
    return buildNumber - other.buildNumber;
  }
  
  @override
  String toString() => '$version+$buildNumber';
}
class HSPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  
  const HSPage({Key? key, this.userData}) : super(key: key);

  @override
  _HSPageState createState() => _HSPageState();
}

class _HSPageState extends State<HSPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _username = '';
  String _message = '';
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  late TabController _tabController;
  final DBHelper _dbHelper = DBHelper();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _initializeVideo();
    _playVibrationPattern();
    _tabController = TabController(length: 2, vsync: this);
    _checkAndPerformDailySync();
  }
  Future<void> _checkAndPerformDailySync() async {
  final prefs = await SharedPreferences.getInstance();
  final lastSyncDateStr = prefs.getString('last_sync_date');
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  
  // If we haven't synced today yet, perform sync
  if (lastSyncDateStr != today) {
    await checkVersionAndSyncData();
    await checkVersionAndSyncKhoData();
    await prefs.setString('last_sync_date', today);
  }
}
  Future<void> _playVibrationPattern() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
  pattern: [
    0, 100, 50, 100, // da da
    50, 100, 50, 150, // da da (slightly longer)
    50, 100, 50, 200, // da da (emphasize)
    50, 250,          // final "DAAA!"
  ],
  intensities: [
    0, 200, 0, 200,
    0, 200, 0, 220,
    0, 220, 0, 230,
    0, 255
  ],
);

    }
  }
  Future<void> checkVersionAndSyncData() async {
  // Show progress dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _buildSyncProgressDialog(),
  );

  try {
    // Step 1: Check for app updates
    setState(() {
      _message = 'Đang kiểm tra cập nhật...';
    });
    await _checkForUpdates();
    
    // Step 2: Sync DonHang data
    setState(() {
      _message = 'Đang đồng bộ đơn hàng...';
    });
    await _syncDonHangData();
    
    // Step 3: Sync ChiTietDon data
    setState(() {
      _message = 'Đang đồng bộ chi tiết đơn...';
    });
    await _syncChiTietDonData();
    
    // Update last sync time
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final formattedNow = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    await prefs.setString('last_donhang_sync', formattedNow);
    await prefs.setString('last_chitietdon_sync', formattedNow);
    
    // Close dialog and update state
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    setState(() {
      _isLoading = false;
      _message = 'Đồng bộ thành công lúc ${DateFormat('HH:mm').format(now)}';
    });
    
    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đồng bộ thành công'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  } catch (e) {
    // Close dialog on error
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    setState(() {
      _isLoading = false;
      _message = 'Lỗi đồng bộ: ${e.toString()}';
    });
    
    // Show error snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi đồng bộ: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    
    print('Error in checkVersionAndSyncData: $e');
  }
}
Future<void> checkVersionAndSyncKhoData() async {
  // Show progress dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _buildSyncProgressDialog(),
  );

  try {
    // Step 1: Sync DSHang data
    setState(() {
      _message = 'Đang đồng bộ danh sách hàng...';
    });
    await _syncDSHangData();
    
    // Step 2: Sync GiaoDichKho data
    setState(() {
      _message = 'Đang đồng bộ giao dịch kho...';
    });
    await _syncGiaoDichKhoData();
    
    // Step 3: Sync GiaoHang data
    setState(() {
      _message = 'Đang đồng bộ giao hàng...';
    });
    await _syncGiaoHangData();
    
    // Step 4: Sync Kho data
    setState(() {
      _message = 'Đang đồng bộ kho...';
    });
    await _syncKhoData();
    
    // Step 5: Sync KhuVucKho data
    setState(() {
      _message = 'Đang đồng bộ khu vực kho...';
    });
    await _syncKhuVucKhoData();
    
    // Step 6: Sync LoHang data
    setState(() {
      _message = 'Đang đồng bộ lô hàng...';
    });
    await _syncLoHangData();
    
    // Step 7: Sync TonKho data
    setState(() {
      _message = 'Đang đồng bộ tồn kho...';
    });
    await _syncTonKhoData();
    
    // Update last sync time
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final formattedNow = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    await prefs.setString('last_dshang_sync', formattedNow);
    await prefs.setString('last_giaodichkho_sync', formattedNow);
    await prefs.setString('last_giaohang_sync', formattedNow);
    await prefs.setString('last_kho_sync', formattedNow);
    await prefs.setString('last_khuvuckho_sync', formattedNow);
    await prefs.setString('last_lohang_sync', formattedNow);
    await prefs.setString('last_tonkho_sync', formattedNow);
    
    // Close dialog and update state
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    setState(() {
      _isLoading = false;
      _message = 'Đồng bộ dữ liệu kho thành công lúc ${DateFormat('HH:mm').format(now)}';
    });
    
    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đồng bộ dữ liệu kho thành công'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  } catch (e) {
    // Close dialog on error
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    setState(() {
      _isLoading = false;
      _message = 'Lỗi đồng bộ: ${e.toString()}';
    });
    
    // Show error snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi đồng bộ: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    
    print('Error in checkVersionAndSyncKhoData: $e');
  }
}

Future<void> _syncDSHangData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_dshang_sync') ?? '2023-01-01 00:00:00';
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldshang/?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        print("Retrieved ${data.length} DSHang items from server");
        
        for (var item in data) {
          // Debug logging
          print("Processing DSHang item - UID: ${item['uid']}, tenSanPham: ${item['tenSanPham']}");
          
          final dsHang = DSHangModel.fromMap(item);
          
          // Check if record exists by UID
          if (dsHang.uid != null && dsHang.uid!.isNotEmpty) {
            final existingRecord = await _dbHelper.getDSHangByUID(dsHang.uid!);
            if (existingRecord != null) {
              // Update existing record
              await _dbHelper.updateDSHang(dsHang);
              print("Updated DSHang record with UID: ${dsHang.uid}");
            } else {
              // Insert new record
              await _dbHelper.insertDSHang(dsHang);
              print("Inserted new DSHang record with UID: ${dsHang.uid}");
            }
          } else {
            print("Skipping DSHang item with empty UID");
          }
        }
      } else {
        print("No DSHang data received from server or empty list");
      }
    } else {
      throw Exception('Failed to sync DSHang data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing DSHang data: $e');
    throw e;
  }
}

Future<void> _syncGiaoDichKhoData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_giaodichkho_sync') ?? '2023-01-01 00:00:00';
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelgiaodichkho/?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        for (var item in data) {
          final giaoDichKho = GiaoDichKhoModel.fromMap(item);
          
          // Check if record exists
          final existingRecord = await _dbHelper.getGiaoDichKhoById(giaoDichKho.giaoDichID!);
          if (existingRecord != null) {
            // Update existing record
            await _dbHelper.updateGiaoDichKho(giaoDichKho);
          } else {
            // Insert new record
            await _dbHelper.insertGiaoDichKho(giaoDichKho);
          }
        }
      }
    } else {
      throw Exception('Failed to sync GiaoDichKho data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing GiaoDichKho data: $e');
    throw e;
  }
}

Future<void> _syncGiaoHangData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_giaohang_sync') ?? '2023-01-01 00:00:00';
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelgiaohang/?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        for (var item in data) {
          final giaoHang = GiaoHangModel.fromMap(item);
          
          // Check if record exists
          final existingRecord = await _dbHelper.getGiaoHangByUID(giaoHang.uid!);
          if (existingRecord != null) {
            // Update existing record
            await _dbHelper.updateGiaoHang(giaoHang);
          } else {
            // Insert new record
            await _dbHelper.insertGiaoHang(giaoHang.toMap());
          }
        }
      }
    } else {
      throw Exception('Failed to sync GiaoHang data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing GiaoHang data: $e');
    throw e;
  }
}

Future<void> _syncKhoData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_kho_sync') ?? '2023-01-01 00:00:00';
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkho/?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        for (var item in data) {
          final kho = KhoModel.fromMap(item);
          
          // Check if record exists
          final existingRecord = await _dbHelper.getKhoById(kho.khoHangID!);
          if (existingRecord != null) {
            // Update existing record
            await _dbHelper.updateKho(kho);
          } else {
            // Insert new record
            await _dbHelper.insertKho(kho);
          }
        }
      }
    } else {
      throw Exception('Failed to sync Kho data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing Kho data: $e');
    throw e;
  }
}

Future<void> _syncKhuVucKhoData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_khuvuckho_sync') ?? '2023-01-01 00:00:00';
    
    // Debug log
    print('Syncing KhuVucKho data. Last sync: $lastSync');
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhuvuckho')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Debug log
      print('Received ${data is List ? data.length : 0} KhuVucKho records from API');
      print('Sample data: ${data is List && data.isNotEmpty ? data[0] : "No data"}');
      
      if (data is List && data.isNotEmpty) {
        // Clear existing data to prevent any stale records
        await _dbHelper.clearKhuVucKhoTable();
        
        // Insert all records in batch
        final batch = await _dbHelper.startBatch();
        
        for (var item in data) {
          if (item['khuVucKhoID'] != null && item['khuVucKhoID'].toString().isNotEmpty &&
              item['khoHangID'] != null && item['khoHangID'].toString().isNotEmpty) {
            
            // Debug log for each item
            print('Processing KhuVucKho: ${item['khuVucKhoID']} for warehouse ${item['khoHangID']}');
            
            final khuVucKho = KhuVucKhoModel(
              khuVucKhoID: item['khuVucKhoID'].toString(),
              khoHangID: item['khoHangID'].toString(),
            );
            
            // Insert record in batch
            _dbHelper.addToBatch(batch, 'INSERT INTO khuvuckho (khuVucKhoID, khoHangID) VALUES (?, ?)',
                [khuVucKho.khuVucKhoID, khuVucKho.khoHangID]);
          } else {
            print('Skipping invalid KhuVucKho record: $item');
          }
        }
        
        // Commit batch
        await _dbHelper.commitBatch(batch);
        
        // Debug: Verify data was inserted correctly
        final count = await _dbHelper.getKhuVucKhoCount();
        print('After sync: $count KhuVucKho records in database');
      } else {
        print('No KhuVucKho data received from server or empty list');
      }
    } else {
      throw Exception('Failed to sync KhuVucKho data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing KhuVucKho data: $e');
    throw e;
  }
}
Future<void> _syncLoHangData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_lohang_sync') ?? '2023-01-01 00:00:00';
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotellohang/?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        for (var item in data) {
          final loHang = LoHangModel.fromMap(item);
          
          // Check if record exists
          final existingRecord = await _dbHelper.getLoHangById(loHang.loHangID!);
          if (existingRecord != null) {
            // Update existing record
            await _dbHelper.updateLoHang(loHang);
          } else {
            // Insert new record
            await _dbHelper.insertLoHang(loHang);
          }
        }
      }
    } else {
      throw Exception('Failed to sync LoHang data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing LoHang data: $e');
    throw e;
  }
}

Future<void> _syncTonKhoData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_tonkho_sync') ?? '2023-01-01 00:00:00';
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteltonkho/?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        for (var item in data) {
          final tonKho = TonKhoModel.fromMap(item);
          
          // Check if record exists
          final existingRecord = await _dbHelper.getTonKhoById(tonKho.tonKhoID!);
          if (existingRecord != null) {
            // Update existing record
            await _dbHelper.updateTonKho(tonKho);
          } else {
            // Insert new record
            await _dbHelper.insertTonKho(tonKho);
          }
        }
      }
    } else {
      throw Exception('Failed to sync TonKho data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing TonKho data: $e');
    throw e;
  }
}
Widget _buildSyncProgressDialog() {
  return AlertDialog(
    title: Text(
  '🧡 Đang đồng bộ dữ liệu',
  style: TextStyle(fontSize: 16),textAlign: TextAlign.center,
),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
        SizedBox(height: 32),
        Text(_message, textAlign: TextAlign.center),
      ],
    ),
  );
}
Future<void> _checkForUpdates() async {
  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = AppVersion(packageInfo.version, int.parse(packageInfo.buildNumber));
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://yourworldtravel.vn/api/document/versionhotel2.txt'),
      headers: {'Cache-Control': 'no-cache'}
    ).timeout(Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final serverVersion = AppVersion.fromString(response.body.trim());
      final versionDiff = serverVersion.compareWith(currentVersion);
      
      if (versionDiff > 0 && mounted) {
        // Show update dialog based on version difference
        await showDialog(
          context: context,
          barrierDismissible: versionDiff <= 1, // Only allow dismissal for minor updates
          builder: (context) => AlertDialog(
            title: Text('Cập nhật mới'),
            content: Text(
              'Phiên bản mới (${serverVersion.toString()}) đã có sẵn.\n' +
              'Phiên bản hiện tại: ${currentVersion.toString()}\n\n' +
              (versionDiff > 1 ? 'Bạn cần cập nhật để tiếp tục sử dụng ứng dụng.' : 'Bạn có muốn cập nhật ngay không?')
            ),
            actions: [
              if (versionDiff <= 1) 
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Để sau'),
                ),
              ElevatedButton(
                onPressed: () async {
                  final url = Platform.isIOS 
                    ? 'https://testflight.apple.com/join/Y99sg4cY'
                    : 'https://play.google.com/store/apps/details?id=com.hoanmyrd.hmcamera';
                  
                  final Uri uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (versionDiff <= 1 && mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                child: Text('Cập nhật ngay'),
              ),
            ],
          ),
        );
      }
    }
  } catch (e) {
    print('Error checking for updates: $e');
    // Continue with sync even if version check fails
  }
}

Future<void> _syncDonHangData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_donhang_sync') ?? '2023-01-01 00:00:00';
    
    // Encode the username for safe inclusion in URL
    final encodedUsername = Uri.encodeComponent(_username);
    
    final response = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldonhang/$encodedUsername?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        for (var item in data) {
          final donHang = DonHangModel.fromMap(item);
          
          // Check if record exists
          final existingRecord = await _dbHelper.getDonHangBySoPhieu(donHang.soPhieu!);
          if (existingRecord != null) {
            // Update existing record
            await _dbHelper.updateDonHang(donHang);
          } else {
            // Insert new record
            await _dbHelper.insertDonHang(donHang);
          }
        }
      }
    } else {
      throw Exception('Failed to sync DonHang data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing DonHang data: $e');
    throw e;
  }
}

Future<void> _syncChiTietDonData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_chitietdon_sync') ?? '2023-01-01 00:00:00';
    
    // Encode the username for safe inclusion in URL
    final encodedUsername = Uri.encodeComponent(_username);
    
    final response = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelchitietdon/$encodedUsername?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List && data.isNotEmpty) {
        for (var item in data) {
          final chiTietDon = ChiTietDonModel.fromMap(item);
          
          // Check if record exists
          final existingRecord = await _dbHelper.getChiTietDonByUID(chiTietDon.uid!);
          if (existingRecord != null) {
            // Update existing record
            await _dbHelper.updateChiTietDon(chiTietDon);
          } else {
            // Insert new record
            await _dbHelper.insertChiTietDon(chiTietDon);
          }
        }
      }
    } else {
      throw Exception('Failed to sync ChiTietDon data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing ChiTietDon data: $e');
    throw e;
  }
}
  void _initializeVideo() {
    _videoController = VideoPlayerController.asset('assets/appvideohotel.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
        setState(() {
          _videoInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      // First check if userData was passed to the widget
      if (widget.userData != null && widget.userData!.containsKey('username')) {
        setState(() {
          _username = widget.userData!['username'] ?? '';
        });
      } else {
        // Fall back to UserCredentials provider if no userData was passed
        final userCredentials = Provider.of<UserCredentials>(context, listen: false);
        setState(() {
          _username = userCredentials.username;
        });
      }
      
      if (_username.isEmpty) {
        setState(() {
          _message = 'Lỗi: Không tìm thấy thông tin người dùng';
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
      setState(() {
        _message = 'Lỗi: Không thể tải thông tin người dùng';
      });
    }
  }
  @override
Widget build(BuildContext context) {
  // Colors with hex values
  final Color appBarTop = Color(0xFF534b0d);
  final Color appBarBottom = Color(0xFFb2a41f);
  final Color videoOverlayTop = Color(0xFF7c7318);
  final Color videoOverlayMiddle = Color(0xFF554d0e);
  final Color videoOverlayBottom = Color(0xFF5a530f);
  final Color searchBarColor = Color(0xFF6e6834);
  final Color buttonColor = Color(0xFF837826);
  final Color smallTextColor = Color(0xFFcdc473);
  final Color tabBarColor = Color(0xFF5a530f);
  final List<List<Color>> iconGradients = [
      [appBarTop, appBarBottom],
      [videoOverlayTop, videoOverlayMiddle],
      [videoOverlayMiddle, videoOverlayBottom],
      [appBarBottom, videoOverlayTop],
      [appBarTop, videoOverlayBottom],
      [videoOverlayTop, appBarBottom],
      [appBarBottom, videoOverlayMiddle],
      [videoOverlayMiddle, appBarTop],
    ];
  final List<Map<String, dynamic>> operationItems = [
  {
    'title': 'Đơn hàng của tôi / Duyệt đơn',
    'icon': Icons.shopping_bag,
    'colors': iconGradients[0],
    'route': 'donhang', // Route identifier
  },
  {
    'title': 'Tổng hợp đơn hàng theo ngày',
    'icon': Icons.calendar_today,
    'colors': iconGradients[1],
    'route': 'tonghop',
  },
  {
    'title': 'Danh sách hàng & tồn kho',
    'icon': Icons.inventory,
    'colors': iconGradients[2],
    'route': 'tonkho',
  },
  {
    'title': 'Xuất, nhập, thao tác kho',
    'icon': Icons.swap_horiz,
    'colors': iconGradients[3],
    'route': 'xuatnhap',
  },
  {
    'title': 'Tra cứu kho hàng',
    'icon': Icons.search,
    'colors': iconGradients[4],
    'route': 'tracuu',
  },
  {
    'title': 'XNK đặt hàng',
    'icon': Icons.price_check,
    'colors': iconGradients[5],
    'route': 'xnk',
  },
  {
    'title': 'Dự trù mặt hàng',
    'icon': Icons.store,
    'colors': iconGradients[6],
    'route': 'dutru',
  },
  {
    'title': 'Chỉ số tháng của tôi',
    'icon': Icons.insights,
    'colors': iconGradients[7],
    'route': 'chiso',
  },
];
  // Check if we're on a large screen (tablet/desktop)
  final bool isLargeScreen = MediaQuery.of(context).size.width > 600;
  
  final double bodyTextSize = 16.0;  
  final double searchBarTextSize = 14.0;
  final double smallTextSize = bodyTextSize * 0.6;  
  final double buttonTextSize = bodyTextSize - 1.0;  
  
  final now = DateTime.now();
  final formattedDate = DateFormat('dd/MM/yyyy').format(now);
  final formattedTime = DateFormat('HH:mm').format(now);
  void _showComingSoonDialog(String feature) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Tính năng đang phát triển'),
      content: Text('Tính năng "$feature" đang được phát triển và sẽ sớm được ra mắt.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Đóng'),
        ),
      ],
    ),
  );
}
  void _navigateToScreen(String route) {
  switch (route) {
    case 'donhang':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HSDonHangScreen(username: _username)),
      );
      break;
    case 'tonghop':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HSDonHangDailyScreen(username: _username)),
      );
      break;
    case 'tonkho':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HSDSHangScreen()),
      );
      break;
    case 'xuatnhap':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HSKhoScreen(username: _username)),
      );
      break;
    case 'tracuu':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HSKho2Screen(username: _username)),
      );
      break;
    case 'xnk':
      Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HSDonHangXNKDailyScreen(username: _username),
                ),
              );
      break;
    case 'dutru':
      _showComingSoonDialog('Dự trù mặt hàng');
      break;
    case 'chiso':
      _showComingSoonDialog('Chỉ số tháng của tôi');
      break;
    default:
      print('Unknown route: $route');
  }
}
Future<void> _syncKhuVucKhoChiTietData() async {
  try {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSyncProgressDialog(),
    );

    setState(() {
      _message = 'Đang đồng bộ chi tiết khu vực kho...';
    });

    // Debug log
    print('Syncing KhuVucKhoChiTiet data');
    
    final response = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhuvuckhochitiet')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Debug log
      print('Received ${data is List ? data.length : 0} KhuVucKhoChiTiet records from API');
      print('Sample data: ${data is List && data.isNotEmpty ? data[0] : "No data"}');
      
      if (data is List && data.isNotEmpty) {
        // Clear existing data to prevent any stale records
        await _dbHelper.clearKhuVucKhoChiTietTable();
        
        // Insert all records in batch
        final batch = await _dbHelper.startBatch();
        
        for (var item in data) {
          if (item['chiTietID'] != null && item['chiTietID'].toString().isNotEmpty &&
              item['khuVucKhoID'] != null && item['khuVucKhoID'].toString().isNotEmpty) {
            
            // Debug log for each item
            print('Processing KhuVucKhoChiTiet: ${item['chiTietID']} for khu vuc ${item['khuVucKhoID']}');
            
            final khuVucKhoChiTiet = KhuVucKhoChiTietModel(
              chiTietID: item['chiTietID'].toString(),
              khuVucKhoID: item['khuVucKhoID'].toString(),
              tang: item['tang']?.toString(),
              tangSize: item['tangSize']?.toString(),
              phong: item['phong']?.toString(),
              ke: item['ke']?.toString(),
              tangKe: item['tangKe']?.toString(),
              gio: item['gio']?.toString(),
              noiDung: item['noiDung']?.toString(),
              viTri: item['viTri']?.toString(),
              dungTich: item['dungTich'] != null ? int.tryParse(item['dungTich'].toString()) : null,
            );
            
            // Add to batch with parameterized query
            _dbHelper.addToBatch(batch, 
              'INSERT INTO khuvuckhochitiet (chiTietID, khuVucKhoID, tang, tangSize, phong, ke, tangKe, gio, noiDung, viTri, dungTich) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [
                khuVucKhoChiTiet.chiTietID, 
                khuVucKhoChiTiet.khuVucKhoID,
                khuVucKhoChiTiet.tang,
                khuVucKhoChiTiet.tangSize,
                khuVucKhoChiTiet.phong,
                khuVucKhoChiTiet.ke,
                khuVucKhoChiTiet.tangKe,
                khuVucKhoChiTiet.gio,
                khuVucKhoChiTiet.noiDung,
                khuVucKhoChiTiet.viTri,
                khuVucKhoChiTiet.dungTich
              ]
            );
          } else {
            print('Skipping invalid KhuVucKhoChiTiet record: $item');
          }
        }
        
        // Commit batch
        await _dbHelper.commitBatch(batch);
        
        // Debug: Verify data was inserted correctly
        final count = await _dbHelper.getKhuVucKhoChiTietCount();
        print('After sync: $count KhuVucKhoChiTiet records in database');
        
        // Update last sync time
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now();
        final formattedNow = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
        await prefs.setString('last_khuvuckhochitiet_sync', formattedNow);
        
        // Close dialog and update state
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        setState(() {
          _isLoading = false;
          _message = 'Đồng bộ chi tiết khu vực kho thành công lúc ${DateFormat('HH:mm').format(now)}';
        });
        
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đồng bộ chi tiết khu vực kho thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Close dialog on empty data
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        print('No KhuVucKhoChiTiet data received from server or empty list');
        
        // Show info snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không có dữ liệu chi tiết khu vực kho mới'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Close dialog on error
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      throw Exception('Failed to sync KhuVucKhoChiTiet data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    // Close dialog on error
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    print('Error syncing KhuVucKhoChiTiet data: $e');
    
    // Show error snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi đồng bộ chi tiết khu vực kho: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    
    throw e;
  }
}
  // Build the operations list widget
  Widget operationsList = SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        final item = operationItems[index];
        return Container(
          color: index % 2 == 0 ? Colors.white : Color(0xFFF8F8F8),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: item['colors'],
                ),
              ),
              child: Icon(
                item['icon'],
                color: Colors.white,
                size: 22,
              ),
            ),
            title: Text(
              item['title'],
              style: TextStyle(
                fontSize: bodyTextSize,
                fontWeight: FontWeight.normal,
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            onTap: () {
              _navigateToScreen(item['route']);
            },
          ),
        );
      },
      childCount: operationItems.length,
    ),
  );
  
  // Build the welcome section widget
  Widget welcomeSection = Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [videoOverlayTop, videoOverlayMiddle, videoOverlayBottom],
        stops: [0.0, 0.5, 1.0],
      ),
    ),
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: Column(
      children: [
        // Welcome text
        Text(
          'Chào mừng đến với Hotel Supply',
          style: TextStyle(
            fontSize: bodyTextSize,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        
        // Username text
        Padding(
          padding: const EdgeInsets.only(top: 3.0, bottom: 6.0),
          child: Text(
            _username,
            style: TextStyle(
              fontSize: bodyTextSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Last sync time
        Text(
          'Dữ liệu đồng bộ lần cuối lúc $formattedTime - $formattedDate',
          style: TextStyle(
            fontSize: smallTextSize,
            color: smallTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: 11),
        
        // Action buttons
        Row(
          children: [
            // Track orders button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HSScanScreen(username: _username)),
      );
                },
                icon: Icon(
                  Icons.qr_code_scanner, 
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  'Tra cứu đơn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: buttonTextSize,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            SizedBox(width: 16),
            
            // Warehouse button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
        context,
                MaterialPageRoute(builder: (context) => HSKhoScreen(username: _username)),
      );
                },
                icon: Icon(
                  Icons.shopping_cart,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  'Vào kho hàng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: buttonTextSize,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Instructions text
        Padding(
          padding: EdgeInsets.only(top: 11),
          child: Text(
            'Vui lòng bấm nút đồng bộ nhanh (trên cùng bên phải) để lấy dữ liệu mới\nNếu bạn là nhân viên kinh doanh, bấm nút + để tạo đơn hàng mới',
            style: TextStyle(
              fontSize: smallTextSize,
              color: smallTextColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
  
  // Video section widget
  Widget videoSection = Container(
    width: double.infinity,
    child: _videoInitialized
      ? AspectRatio(
          aspectRatio: _videoController.value.aspectRatio,
          child: VideoPlayer(_videoController),
        )
      : Container(
          height: 300,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
  );

  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          // App bar section with multi-color gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [appBarTop, appBarBottom],
                stops: [0.0, 1.0],
              ),
            ),
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
            child: Column(
              children: [
                // Top row with navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: searchBarColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.arrow_back, color: Colors.white, size: 18),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    
                    // Right side buttons
                    Row(
                      children: [
                        // Add button
                        Container(
                          width: 32,
                          height: 32,
                          margin: EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: searchBarColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.add, color: Colors.white, size: 18),
                            onPressed: () {
                              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HSDonHangMoiScreen(),
                ),
              );
                            },
                          ),
                        ),
                        Container(
      width: 32,
      height: 32,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: searchBarColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.tips_and_updates, color: Colors.white, size: 18),
        onPressed: () {
          _syncKhuVucKhoChiTietData();
        },
      ),
    ),
                        Container(
      width: 32,
      height: 32,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: searchBarColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.storefront, color: Colors.white, size: 18),
        onPressed: () {
          checkVersionAndSyncKhoData();
        },
      ),
    ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: searchBarColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.refresh, color: Colors.white, size: 18),
                            onPressed: () {
                              checkVersionAndSyncData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            color: tabBarColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              tabs: [
                Tab(text: 'Công việc'),
                Tab(text: 'Chỉ số KD'),
              ],
            ),
          ),
          
          // Main content - now responsive based on screen size
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // First tab - Responsive layout
                isLargeScreen
                    ? Row(
                        children: [
                          // Left side with video and welcome section
                          Expanded(
                            flex: 1,
                            child: CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(child: videoSection),
                                SliverToBoxAdapter(child: welcomeSection),
                                SliverToBoxAdapter(child: SizedBox(height: 20)),
                              ],
                            ),
                          ),
                          // Right side with operations list
                          Expanded(
                            flex: 1,
                            child: CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    color: Colors.grey[100],
                                    child: Text(
                                      'Danh sách chức năng',
                                      style: TextStyle(
                                        fontSize: bodyTextSize + 2,
                                        fontWeight: FontWeight.bold,
                                        color: appBarTop,
                                      ),
                                    ),
                                  ),
                                ),
                                operationsList,
                                SliverToBoxAdapter(child: SizedBox(height: 20)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : CustomScrollView(
                        slivers: [
                          // Mobile layout - stacked vertically
                          SliverToBoxAdapter(child: videoSection),
                          SliverToBoxAdapter(child: welcomeSection),
                          operationsList,
                          SliverToBoxAdapter(child: SizedBox(height: 20)),
                        ],
                      ),
                
                // Second tab - Coming soon message
                HSStatScreen(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}