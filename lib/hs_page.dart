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
//import 'hs_donhangmoi.dart';
import 'hs_donhangxnkdaily.dart';
import 'projectmanagement2.dart';
import 'hs_khachhang.dart';
import 'dart:io';

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
  
  // Add variables for sidebar navigation
  String _selectedRoute = '';
  Widget _currentWidget = Container(); 
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _initializeVideo();
    _playVibrationPattern();
    _tabController = TabController(length: 2, vsync: this);
    _checkAndPerformDailySync();
    _currentWidget = _buildBlankWidget();
    _syncDonHangAndChiTietOnEnter();
  }
  
Future<void> _syncDonHangAndChiTietOnEnter() async {
  try {
    // Only show loading for user feedback, but don't block UI
    setState(() {
      _isLoading = true;
      _message = 'Đang tải dữ liệu đơn hàng...';
    });
    
    // Sync DonHang data
    await _syncDonHangData();
    
    // Sync ChiTietDon data
    await _syncChiTietDonData();
    
    // Update state
    setState(() {
      _isLoading = false;
      _message = 'Đã cập nhật dữ liệu đơn hàng';
    });
    
    // Optional: Show a brief success indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật dữ liệu đơn hàng'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  } catch (e) {
    print('Error syncing DonHang data on enter: $e');
    setState(() {
      _isLoading = false;
      _message = 'Lỗi tải dữ liệu: ${e.toString()}';
    });
  }
}
  // [Keep all your existing methods unchanged - _checkAndPerformDailySync, _playVibrationPattern, etc.]
  Future<void> _checkAndPerformDailySync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncDateStr = prefs.getString('last_sync_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastSyncDateStr != today) {
      await checkVersionAndSyncData();
      await checkVersionAndSyncKhoData();
      await prefs.setString('last_sync_date', today);
    }
  }

  Future<void> _playVibrationPattern() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
        pattern: [0, 100, 50, 100, 50, 100, 50, 150, 50, 100, 50, 200, 50, 250],
        intensities: [0, 200, 0, 200, 0, 200, 0, 220, 0, 220, 0, 230, 0, 255],
      );
    }
  }

  // [Keep all your existing sync methods - I'll skip them for brevity]

  void _initializeVideo() {
  if (Platform.isWindows) {
    setState(() {
      _videoInitialized = false; 
    });
    return;
  }
  _videoController = VideoPlayerController.asset('assets/appvideohotel.mp4')
    ..initialize().then((_) {
      _videoController.setLooping(true);
      _videoController.setVolume(0.0);
      _videoController.play();
      setState(() {
        _videoInitialized = true;
      });
    }).catchError((error) {
      print('Video initialization error: $error');
      setState(() {
        _videoInitialized = false; // Fallback to image on error
      });
    });
}

  @override
void dispose() {
  if (!Platform.isWindows && _videoInitialized) {
    _videoController.dispose();
  }
  _tabController.dispose();
  super.dispose();
}

  Future<void> _loadUserInfo() async {
    try {
      if (widget.userData != null && widget.userData!.containsKey('username')) {
        setState(() {
          _username = widget.userData!['username'] ?? '';
        });
      } else {
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

  // Modified navigation method to update the right panel
  void _navigateToScreen(String route) {
    setState(() {
      _selectedRoute = route;
      switch (route) {
        case 'donhang':
          _currentWidget = HSDonHangScreen(username: _username);
          break;
        case 'tonghop':
          _currentWidget = HSDonHangDailyScreen(username: _username);
          break;
        case 'tonkho':
          _currentWidget = HSDSHangScreen();
          break;
        case 'xuatnhap':
          _currentWidget = HSKhoScreen(username: _username);
          break;
        case 'tracuu':
          _currentWidget = HSKho2Screen(username: _username);
          break;
        case 'xnk':
          _currentWidget = HSDonHangXNKDailyScreen(username: _username);
          break;
        case 'dutru':
          _currentWidget = _buildComingSoonWidget('Dự trù mặt hàng');
          break;
        case 'chiso':
          _currentWidget = _buildComingSoonWidget('Chỉ số tháng của tôi');
          break;
        case 'stat':
          _currentWidget = HSStatScreen();
          break;
        case 'baocaocongviec':
          _currentWidget = ProjectManagement2();
          break;
        case 'dskhachhang':
          _currentWidget = HSKhachHangScreen();
          break;
        default:
          _currentWidget = _buildBlankWidget();
      }
    });
  }

  // Build blank widget for default state
  Widget _buildBlankWidget() {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hotel,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Chọn một chức năng từ menu bên trái',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vui lòng chọn một mục từ danh sách bên trái để bắt đầu',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build coming soon widget
  Widget _buildComingSoonWidget(String feature) {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Tính năng đang phát triển',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Tính năng "$feature" đang được phát triển và sẽ sớm được ra mắt.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build sidebar with video and welcome content
  Widget _buildSidebar() {
    final Color appBarTop = Color(0xFF534b0d);
    final Color appBarBottom = Color(0xFFb2a41f);
    final Color videoOverlayTop = Color(0xFF7c7318);
    final Color videoOverlayMiddle = Color(0xFF554d0e);
    final Color videoOverlayBottom = Color(0xFF5a530f);
    final Color buttonColor = Color(0xFF837826);
    final Color smallTextColor = Color(0xFFcdc473);

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
        'title': 'Đơn hàng của tôi',
        'icon': Icons.shopping_bag,
        'colors': iconGradients[0],
        'route': 'donhang',
      },
      {
        'title': 'Tổng hợp đơn hàng',
        'icon': Icons.calendar_today,
        'colors': iconGradients[1],
        'route': 'tonghop',
      },
      {
        'title': 'DS hàng & tồn kho',
        'icon': Icons.inventory,
        'colors': iconGradients[2],
        'route': 'tonkho',
      },
      {
        'title': 'Xuất, nhập kho',
        'icon': Icons.swap_horiz,
        'colors': iconGradients[3],
        'route': 'xuatnhap',
      },
      {
        'title': 'Tra cứu kho',
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
        'title': '★ Chỉ số KD ★',
        'icon': Icons.insights,
        'colors': iconGradients[6],
        'route': 'stat',
      },
      {
        'title': 'Báo cáo công việc',
        'icon': Icons.feed,
        'colors': iconGradients[7],
        'route': 'baocaocongviec',
      },
      {
        'title': 'DS khách hàng',
        'icon': Icons.local_library,
        'colors': iconGradients[1],
        'route': 'dskhachhang',
      },
    ];

    final double bodyTextSize = 14.0;
    final double buttonTextSize = bodyTextSize - 1.0;
    final double smallTextSize = bodyTextSize * 0.7;
    
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);

    return Container(
      width: MediaQuery.of(context).size.width * 0.15,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: [
          // Video section
          Container(
  width: double.infinity,
  child: Platform.isWindows || !_videoInitialized
      ? Container(
          height: 120,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/vidhcm.png'),
              fit: BoxFit.cover,
            ),
          ),
        )
      : AspectRatio(
          aspectRatio: _videoController.value.aspectRatio,
          child: VideoPlayer(_videoController),
        ),
),
          
          // Welcome section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [videoOverlayTop, videoOverlayMiddle, videoOverlayBottom],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Text(
                  'Chào mừng đến với Hotel Supply',
                  style: TextStyle(fontSize: bodyTextSize, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
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
                Text(
                  'Đồng bộ lúc $formattedTime\n$formattedDate',
                  style: TextStyle(fontSize: smallTextSize, color: smallTextColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 11),
                
                // Action buttons in column
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedRoute = 'scan';
                            _currentWidget = HSScanScreen(username: _username);
                          });
                        },
                        icon: Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
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
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _navigateToScreen('xuatnhap');
                        },
                        icon: Icon(Icons.shopping_cart, color: Colors.white, size: 16),
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
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
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
                    'Bấm nút đồng bộ (góc phải trên) để lấy dữ liệu mới',
                    style: TextStyle(
                      fontSize: smallTextSize,
                      color: smallTextColor,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: operationItems.length,
              itemBuilder: (context, index) {
                final item = operationItems[index];
                final isSelected = _selectedRoute == item['route'];
                
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[100] : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isSelected ? Border.all(color: Colors.blue[300]!, width: 2) : null,
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: item['colors'],
                        ),
                      ),
                      child: Icon(
                        item['icon'],
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      item['title'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blue[800] : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      _navigateToScreen(item['route']);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarTop = Color(0xFF534b0d);
    final Color appBarBottom = Color(0xFFb2a41f);
    final Color searchBarColor = Color(0xFF6e6834);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // App bar section
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [appBarTop, appBarBottom],
                ),
              ),
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 12),
              child: Row(
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
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  
                  // Title
                  Text(
                    'Hotel Supply Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Action buttons
                  Row(
                    children: [
                      //_buildActionButton(Icons.add, 'Đơn mới', () {
                      //  setState(() {
                      //    _selectedRoute = 'add';
                      //    _currentWidget = HSDonHangMoiScreen();
                      //  });
                      //}),
                      //SizedBox(width: 8),
                      _buildActionButton(Icons.tips_and_updates, ' Sơ đồ kho', () {
                        _syncKhuVucKhoChiTietData();
                      }),
                      SizedBox(width: 8),
                      _buildActionButton(Icons.storefront, ' DS Hàng, Tồn kho', () {
                        checkVersionAndSyncKhoData();
                      }),
                      SizedBox(width: 8),
                      _buildActionButton(Icons.refresh, ' Đơn, Chi tiết đơn', () {
                        checkVersionAndSyncData();
                      }),
                    ],
                  ),
                ],
              ),
            ),
            
            // Main content area with sidebar
            Expanded(
              child: Row(
                children: [
                  // Left sidebar (15% width)
                  _buildSidebar(),
                  
                  // Right content area (85% width)
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: _currentWidget,
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

Widget _buildActionButton(IconData icon, String text, VoidCallback onPressed) {
  return GestureDetector(
    onTap: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Color(0xFF6e6834),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.yellow,
          ),
        ),
      ],
    ),
  );
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

      if (data is List) {
        await _dbHelper.clearLoHangTable();
        print('Local LoHang table cleared.');

        if (data.isNotEmpty) {
          final batch = await _dbHelper.startBatch();
          for (var item in data) {
            final loHang = LoHangModel.fromMap(item);
            _dbHelper.addToBatch(batch,
              'INSERT INTO lohang (loHangID, soLuongBanDau, soLuongHienTai, ngayNhap, ngayCapNhat, hanSuDung, trangThai, maHangID, khoHangID, khuVucKhoID) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [
                loHang.loHangID,
                loHang.soLuongBanDau,
                loHang.soLuongHienTai,
                loHang.ngayNhap,
                loHang.ngayCapNhat,
                loHang.hanSuDung,
                loHang.trangThai,
                loHang.maHangID,
                loHang.khoHangID,
                loHang.khuVucKhoID,
              ]
            );
          }
          await _dbHelper.commitBatch(batch);
          print('Inserted ${data.length} new LoHang records.');
        } else {
          print('No LoHang records received from server to insert after clearing.');
        }
      } else {
        print('Received non-list data for LoHang, sync aborted for this table.');
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
    
    final encodedUsername = Uri.encodeComponent(_username);
    
    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldonhang/$encodedUsername?last_sync=$lastSync')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data is List) {
        await _dbHelper.clearDonHangTable();  // Clear all existing data
        print('Local DonHang table cleared.');

        if (data.isNotEmpty) {
          final batch = await _dbHelper.startBatch();
          for (var item in data) {
            final donHang = DonHangModel.fromMap(item);
            
            // Add to batch insert with all DonHang fields
            _dbHelper.addToBatch(batch,
              'INSERT INTO donhang (soPhieu, nguoiTao, ngay, tenKhachHang, sdtKhachHang, soPO, diaChi, mst, tapKH, tenNguoiGiaoDich, boPhanGiaoDich, sdtNguoiGiaoDich, thoiGianDatHang, ngayYeuCauGiao, thoiGianCapNhatTrangThai, phuongThucThanhToan, thanhToanSauNhanHangXNgay, datCocSauXNgay, giayToCanKhiGiaoHang, thoiGianVietHoaDon, thongTinVietHoaDon, diaChiGiaoHang, hoTenNguoiNhanHoaHong, sdtNguoiNhanHoaHong, hinhThucChuyenHoaHong, thongTinNhanHoaHong, ngaySeGiao, thoiGianCapNhatMoiNhat, phuongThucGiaoHang, phuongTienGiaoHang, hoTenNguoiGiaoHang, ghiChu, giaNet, tongTien, vat10, tongCong, hoaHong10, tienGui10, thueTNDN, vanChuyen, thucThu, nguoiNhanHang, sdtNguoiNhanHang, phieuXuatKho, trangThai, tenKhachHang2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [
                donHang.soPhieu,
                donHang.nguoiTao,
                donHang.ngay,
                donHang.tenKhachHang,
                donHang.sdtKhachHang,
                donHang.soPO,
                donHang.diaChi,
                donHang.mst,
                donHang.tapKH,
                donHang.tenNguoiGiaoDich,
                donHang.boPhanGiaoDich,
                donHang.sdtNguoiGiaoDich,
                donHang.thoiGianDatHang,
                donHang.ngayYeuCauGiao,
                donHang.thoiGianCapNhatTrangThai,
                donHang.phuongThucThanhToan,
                donHang.thanhToanSauNhanHangXNgay,
                donHang.datCocSauXNgay,
                donHang.giayToCanKhiGiaoHang,
                donHang.thoiGianVietHoaDon,
                donHang.thongTinVietHoaDon,
                donHang.diaChiGiaoHang,
                donHang.hoTenNguoiNhanHoaHong,
                donHang.sdtNguoiNhanHoaHong,
                donHang.hinhThucChuyenHoaHong,
                donHang.thongTinNhanHoaHong,
                donHang.ngaySeGiao,
                donHang.thoiGianCapNhatMoiNhat,
                donHang.phuongThucGiaoHang,
                donHang.phuongTienGiaoHang,
                donHang.hoTenNguoiGiaoHang,
                donHang.ghiChu,
                donHang.giaNet,
                donHang.tongTien,
                donHang.vat10,
                donHang.tongCong,
                donHang.hoaHong10,
                donHang.tienGui10,
                donHang.thueTNDN,
                donHang.vanChuyen,
                donHang.thucThu,
                donHang.nguoiNhanHang,
                donHang.sdtNguoiNhanHang,
                donHang.phieuXuatKho,
                donHang.trangThai,
                donHang.tenKhachHang2,
              ]
            );
          }
          await _dbHelper.commitBatch(batch);
          print('Inserted ${data.length} new DonHang records.');
        } else {
          print('No DonHang records received from server to insert after clearing.');
        }
      } else {
        print('Received non-list data for DonHang, sync aborted for this table.');
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
    final encodedUsername = Uri.encodeComponent(_username);
    final lastSync = prefs.getString('last_chitietdon_sync') ?? '2023-01-01 00:00:00';

    final response = await AuthenticatedHttpClient.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelchitietdon/$encodedUsername?last_sync=$lastSync')
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        await _dbHelper.clearChiTietDonTable();
        print('Local ChiTietDon table cleared.');

        if (data.isNotEmpty) {
          final batch = await _dbHelper.startBatch();
          for (var item in data) {
            final chiTietDon = ChiTietDonModel.fromMap(item);
            _dbHelper.addToBatch(batch,
              'INSERT INTO chitietdon (uid, soPhieu, trangThai, tenHang, maHang, donViTinh, soLuongYeuCau, donGia, thanhTien, soLuongThucGiao, chiNhanh, idHang, soLuongKhachNhan, duyet, xuatXuHangKhac, baoGia, hinhAnh, ghiChu, phanTramVAT, vat, tenKhachHang, updateTime) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [
                chiTietDon.uid,
                chiTietDon.soPhieu,
                chiTietDon.trangThai,
                chiTietDon.tenHang,
                chiTietDon.maHang,
                chiTietDon.donViTinh,
                chiTietDon.soLuongYeuCau,
                chiTietDon.donGia,
                chiTietDon.thanhTien,
                chiTietDon.soLuongThucGiao,
                chiTietDon.chiNhanh,
                chiTietDon.idHang,
                chiTietDon.soLuongKhachNhan,
                chiTietDon.duyet,
                chiTietDon.xuatXuHangKhac,
                chiTietDon.baoGia,
                chiTietDon.hinhAnh,
                chiTietDon.ghiChu,
                chiTietDon.phanTramVAT,
                chiTietDon.vat,
                chiTietDon.tenKhachHang,
                chiTietDon.updateTime,
              ]
            );
          }
          await _dbHelper.commitBatch(batch);
          print('Inserted ${data.length} new ChiTietDon records.');
        } else {
          print('No ChiTietDon records received from server to insert after clearing.');
        }
      } else {
        print('Received non-list data for ChiTietDon, sync aborted for this table.');
      }
    } else {
      throw Exception('Failed to sync ChiTietDon data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing ChiTietDon data: $e');
    throw e;
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
    
    final response = await AuthenticatedHttpClient.get(
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
}