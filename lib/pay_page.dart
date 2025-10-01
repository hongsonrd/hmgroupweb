import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'pay_account.dart';
import 'pay_account2.dart';
import 'pay_hour.dart';
import 'pay_location.dart';
import 'pay_standard.dart';
import 'chamcongthanghr.dart';
import 'chamcongthang.dart';
import 'pay_policy.dart';
import 'pay_history.dart';
import 'pay_historyac.dart';

class PayPage extends StatefulWidget {
  const PayPage({Key? key}) : super(key: key);

  @override
  _PayPageState createState() => _PayPageState();
}

class PayMenuItem {
  final String title;
  final IconData icon;
  final List<String> allowedRoles;
  final VoidCallback? onTap;

  PayMenuItem({
    required this.title,
    required this.icon,
    required this.allowedRoles,
    this.onTap,
  });
}

class _PayPageState extends State<PayPage> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isSyncing = false;
  int _currentSyncStep = 0;
  List<bool> _syncStepsCompleted = List.filled(6, false); 
  String _username = '';
  String _userPayRole = '';
  bool _syncFailed = false;
  String _syncErrorMessage = '';
  Map<String, int> _syncedCounts = {};
  bool _showDashboard = false;

  // In-memory data storage
  List<Map<String, dynamic>> _taiKhoanData = [];
  List<Map<String, dynamic>> _gioLamData = [];
  List<Map<String, dynamic>> _congLamData = [];
  List<Map<String, dynamic>> _congChuanData = [];
  List<Map<String, dynamic>> _luongCheDoData = [];
  List<Map<String, dynamic>> _luongLichSuData = [];

  final List<String> _stepLabels = [
    'Tài khoản',
    'Giờ làm việc', 
    'Vị trí chấm công',
    'Công chuẩn',
    'Chế độ lương',
    'Lịch sử lương'
  ];

  late List<PayMenuItem> _menuItems;

  @override
  void initState() {
    super.initState();
    _initializeMenuItems();
    _initializeVideo();
    _loadUsername();

    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _startSyncProcess();
      }
    });
  }

  void _initializeMenuItems() {
    _menuItems = [
      PayMenuItem(
        title: 'Tài khoản app',
        icon: Icons.manage_accounts,
        allowedRoles: ['Admin', 'HR'],
        onTap: () => _navigateToPage('TaiKhoanApp'),
      ),
      PayMenuItem(
        title: 'Xem tài khoản',
        icon: Icons.account_circle,
        allowedRoles: ['Viewer', 'AC','Admin'],
        onTap: () => _navigateToPage('XemTaiKhoan'),
      ),
      PayMenuItem(
        title: 'Quy định giờ làm',
        icon: Icons.access_time,
        allowedRoles: ['Admin', 'HR'],
        onTap: () => _navigateToPage('QuyDinhGioLam'),
      ),
      PayMenuItem(
        title: 'Xem quy định giờ',
        icon: Icons.schedule,
        allowedRoles: ['Viewer', 'AC','Admin'],
        onTap: () => _navigateToPage('XemQuyDinhGio'),
      ),
      PayMenuItem(
        title: 'Vị trí chấm công',
        icon: Icons.location_on,
        allowedRoles: ['Admin', 'HR','Admin'],
        onTap: () => _navigateToPage('ViTriChamCong'),
      ),
      PayMenuItem(
        title: 'Xem điểm chấm',
        icon: Icons.location_searching,
        allowedRoles: ['Viewer', 'AC','Admin'],
        onTap: () => _navigateToPage('XemDiemCham'),
      ),
      PayMenuItem(
        title: 'Sửa công chuẩn',
        icon: Icons.edit_calendar,
        allowedRoles: ['Admin', 'HR'],
        onTap: () => _navigateToPage('SuaCongChuan'),
      ),
      PayMenuItem(
        title: 'Xem công chuẩn',
        icon: Icons.calendar_view_day,
        allowedRoles: ['Viewer', 'AC','Admin'],
        onTap: () => _navigateToPage('XemCongChuan'),
      ),
      PayMenuItem(
        title: 'Sửa chế độ lương',
        icon: Icons.edit_note,
        allowedRoles: ['Admin', 'AC'],
        onTap: () => _navigateToPage('SuaCheDo'),
      ),
      PayMenuItem(
        title: 'Lịch sử lương HR',
        icon: Icons.history_edu,
        allowedRoles: ['Admin', 'HR'],
        onTap: () => _navigateToPage('LichSuLuongHR'),
      ),
      PayMenuItem(
        title: 'Lịch sử lương KT',
        icon: Icons.receipt_long,
        allowedRoles: ['AC','Admin'],
        onTap: () => _navigateToPage('LichSuLuongKT'),
      ),
      PayMenuItem(
        title: 'Lịch sử chấm công HR',
        icon: Icons.access_time_filled,
        allowedRoles: ['Admin', 'HR'],
        onTap: () => _navigateToPage('LichSuChamCongHR'),
      ),
      PayMenuItem(
        title: 'Lịch sử chấm công',
        icon: Icons.timer,
        allowedRoles: ['AC', 'Viewer','Admin'],
        onTap: () => _navigateToPage('LichSuChamCong'),
      ),
    ];
  }

void _navigateToPage(String pageName) {
  Map<String, dynamic> pageData = {};
  
  switch (pageName) {
    case 'TaiKhoanApp':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PayAccountScreen(
            username: _username,
            userRole: _userPayRole,
            accountData: _taiKhoanData,
          ),
        ),
      );
      return;
    case 'XemTaiKhoan':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PayAccountScreen2(
            username: _username,
            userRole: _userPayRole,
            accountData: _taiKhoanData,
          ),
        ),
      );
      break;
      case 'QuyDinhGioLam':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayHourScreen(
        username: _username,
        userRole: _userPayRole,
        hourData: _gioLamData,
      ),
    ),
  );
  return;
      case 'XemQuyDinhGio':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayHourScreen(
        username: _username,
        userRole: _userPayRole,
        hourData: _gioLamData,
      ),
    ),
  );
  return;
        pageData = {'data': _gioLamData, 'userRole': _userPayRole};
        break;
      case 'ViTriChamCong':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayLocationScreen(
        username: _username,
        userRole: _userPayRole,
        locationData: _congLamData,
      ),
    ),
  );
  return;
      case 'XemDiemCham':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayLocationScreen(
        username: _username,
        userRole: _userPayRole,
        locationData: _congLamData,
      ),
    ),
  );
  return;
      case 'SuaCongChuan':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayStandardScreen(
        username: _username,
        userRole: _userPayRole,
        standardData: _congChuanData,
      ),
    ),
  );
  return;
case 'XemCongChuan':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayStandardScreen(
        username: _username,
        userRole: _userPayRole,
        standardData: _congChuanData,
      ),
    ),
  );
  return;
      case 'SuaCheDo':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayPolicyScreen(
        username: _username,
        userRole: _userPayRole,
        policyData: _luongCheDoData,
        accountData: _taiKhoanData,
      ),
    ),
  );
  return;
      case 'LichSuLuongHR':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayHistoryScreen(
        username: _username,
        userRole: _userPayRole,
        historyData: _luongLichSuData,
        policyData: _luongCheDoData,
        standardData: _congChuanData,
      ),
    ),
  );
  return;
case 'LichSuLuongKT':
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PayHistoryACScreen(
        username: _username,
        userRole: _userPayRole,
        historyData: _luongLichSuData,
        policyData: _luongCheDoData,
        standardData: _congChuanData,
      ),
    ),
  );
  return;
      case 'LichSuChamCongHR':
      Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChamCongThangHRScreen(
        username: _username,
        userRole: _userPayRole,
        approverUsername: 'hm.tason',
        standardData: _congChuanData,
      ),
    ),
  );
  return;
      case 'LichSuChamCong':
      Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChamCongThangScreen(
        username: _username,
        userRole: _userPayRole,
        approverUsername: 'hm.tason',
      ),
    ),
  );
  return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to $pageName with ${pageData['data']?.length ?? 0} records'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  List<PayMenuItem> _getFilteredMenuItems() {
    return _menuItems.where((item) => 
      item.allowedRoles.contains(_userPayRole)
    ).toList();
  }

  Future<void> _initializeVideo() async {
    if (Platform.isWindows) {
      setState(() {
        _isVideoInitialized = true;
      });
      return;
    }
    
    try {
      _videoController = VideoPlayerController.asset('assets/apphr.mp4');
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(1.0);
      _videoController!.play();

      setState(() {
        _isVideoInitialized = true;
      });
      
      _videoController!.addListener(() {
        if (!_videoController!.value.isPlaying && mounted) {
          _videoController!.play();
        }
      });
    } catch (e) {
      print("Error initializing video: $e");
      setState(() {
        _isVideoInitialized = true;
      });
    }
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final userObj = prefs.getString('current_user');

    if (userObj != null && userObj.isNotEmpty) {
      try {
        final userData = json.decode(userObj);
        setState(() {
          _username = userData['username'] ?? '';
          print("Loaded username from prefs: $_username");
        });
      } catch (e) {
        setState(() {
          _username = userObj;
          print("Loaded username directly from prefs: $_username");
        });
      }
    } else {
      try {
        final response = await http.get(
          Uri.parse(
              'https://hmclourdrun1-81200125587.asia-southeast1.run.app/current-user'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['username'] != null) {
            setState(() {
              _username = data['username'];
              print("Loaded username from API: $_username");
            });
            await prefs.setString('current_user', _username);
          }
        }
      } catch (e) {
        print('Error loading username: $e');
        setState(() {
          _username = 'default_user';
          print("Using default username: $_username");
        });
      }
    }
  }

  Future<void> _startSyncProcess() async {
    if (_username.isEmpty) {
      print("Username empty, attempting to load...");
      await _loadUsername();
      print("Username after loading: $_username");
    }

    setState(() {
      _isSyncing = true;
      _currentSyncStep = 0;
      _syncStepsCompleted = List.filled(6, false);
      _syncFailed = false;
      _syncErrorMessage = '';
      _syncedCounts.clear();
      _showDashboard = false;
      
      // Clear previous data
      _taiKhoanData.clear();
      _gioLamData.clear();
      _congLamData.clear();
      _congChuanData.clear();
      _luongCheDoData.clear();
      _luongLichSuData.clear();
    });

    try {
      print("Starting sync process for user: $_username");
      await _performSync();
      print("Sync process completed successfully");

      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_pay_role', _userPayRole);
        await prefs.setString('last_pay_sync_time', DateTime.now().toIso8601String());

        if (_syncStepsCompleted.every((step) => step == true)) {
          setState(() {
            _isSyncing = false;
            _showDashboard = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Đồng bộ hoàn thành! Role: $_userPayRole"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          setState(() {
            _isSyncing = false;
            _syncFailed = true;
          });
        }
      }
    } catch (e) {
      print("CRITICAL ERROR in sync process: $e");
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncFailed = true;
          _syncErrorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _performSync() async {
    final prefs = await SharedPreferences.getInstance();
    final originalUserState = prefs.getString('current_user');

    try {
      await _getUserRole(_username);
      
      // Sync all data types
      for (int i = 0; i < 6; i++) {
        setState(() {
          _currentSyncStep = i;
        });
        
        await _executeSyncStep(i, _username);
        
        setState(() {
          _syncStepsCompleted[i] = true;
        });
        
        await Future.delayed(Duration(milliseconds: 800));
      }
      
    } catch (e) {
      print("Error in sync process: $e");
      if (mounted) {
        setState(() {
          _syncFailed = true;
          _syncErrorMessage = e.toString();
        });
      }
      throw e;
    }

    if (_syncStepsCompleted.every((step) => step == true)) {
      await prefs.setString('last_pay_sync_time', DateTime.now().toIso8601String());
    }

    final finalUserState = prefs.getString('current_user');
    if (originalUserState != finalUserState) {
      await prefs.setString('current_user', originalUserState ?? '');
    }
  }

  Future<void> _getUserRole(String username) async {
    final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
    final roleUrl = '$baseUrl/payrole/$username';

    final roleResponse = await http.get(Uri.parse(roleUrl));

    if (roleResponse.statusCode == 200) {
      final roleText = roleResponse.body.trim();
      
      final validRoles = ['Admin', 'HR', 'AC', 'Viewer'];
      if (!validRoles.contains(roleText)) {
        throw Exception('Invalid role returned: $roleText');
      }

      _userPayRole = roleText;
      print("Pay role received: $_userPayRole");

    } else if (roleResponse.statusCode == 404) {
      throw Exception('User not found in Pay system');
    } else {
      throw Exception('Failed to load user Pay role: ${roleResponse.statusCode}');
    }
  }

  Future<void> _executeSyncStep(int step, String username) async {
    final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

    try {
      switch (step) {
        case 0: // TaiKhoan
          await _syncDataToMemory('$baseUrl/paytaikhoan/$username', 'TaiKhoan', _taiKhoanData);
          break;
        case 1: // GioLam
          await _syncDataToMemory('$baseUrl/paygiolam/$username', 'GioLam', _gioLamData);
          break;
        case 2: // CongLam
          await _syncDataToMemory('$baseUrl/payconglam/$username', 'CongLam', _congLamData);
          break;
        case 3: // CongChuan
          await _syncDataToMemory('$baseUrl/paycongchuan/$username', 'CongChuan', _congChuanData);
          break;
        case 4: // LuongCheDo
          await _syncDataToMemory('$baseUrl/paychedo/$username', 'LuongCheDo', _luongCheDoData);
          break;
        case 5: // LuongLichSu
          await _syncDataToMemory('$baseUrl/luonglichsu/$username', 'LuongLichSu', _luongLichSuData);
          break;
      }
    } catch (e) {
      print("ERROR in sync step ${step + 1}: $e");
      throw e;
    }
  }

  Future<void> _syncDataToMemory(String url, String displayName, List<Map<String, dynamic>> dataList) async {
    print("REQUEST URL ($displayName): $url");

    final response = await http.get(Uri.parse(url));
    print("RESPONSE STATUS ($displayName): ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data == null) {
        print("Received null data for $displayName");
        setState(() {
          _syncedCounts[displayName] = 0;
        });
        return;
      }

      List<dynamic> apiDataList;
      if (data is List) {
        apiDataList = data;
      } else {
        apiDataList = [data];
      }

      // Store data in memory
      dataList.clear();
      dataList.addAll(apiDataList.map((item) => Map<String, dynamic>.from(item)).toList());

      print("Loaded ${dataList.length} $displayName records to memory");
      setState(() {
        _syncedCounts[displayName] = dataList.length;
      });
    } else {
      print("API returned error status for $displayName: ${response.statusCode}");
      throw Exception('Failed to load $displayName data: ${response.statusCode}');
    }
  }

  // Helper methods to access data from other screens
  List<Map<String, dynamic>> get taiKhoanData => _taiKhoanData;
  List<Map<String, dynamic>> get gioLamData => _gioLamData;
  List<Map<String, dynamic>> get congLamData => _congLamData;
  List<Map<String, dynamic>> get congChuanData => _congChuanData;
  List<Map<String, dynamic>> get luongCheDoData => _luongCheDoData;
  List<Map<String, dynamic>> get luongLichSuData => _luongLichSuData;

  Widget _buildDashboard() {
    final filteredItems = _getFilteredMenuItems();
    
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Hệ thống quản lý lương',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Vai trò: $_userPayRole',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    onPressed: _startSyncProcess,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Grid Menu
            Expanded(
  child: Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.grey.withOpacity(0.2),
        width: 0.5,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Auto-detect screen size for responsive grid
        int crossAxisCount;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 6; // Desktop: 6 items per row
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 4; // Tablet: 4 items per row
        } else {
          crossAxisCount = 2; // Mobile: 2 items per row
        }
        
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.0,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _buildMenuItem(item);
          },
        );
      },
    ),
  ),
),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(PayMenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                size: 32,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 12),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        child: Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Spacer(),
                ],
              ),
              
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Đồng bộ dữ liệu lương',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              if (_isSyncing && _currentSyncStep < _stepLabels.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Đang đồng bộ: ${_stepLabels[_currentSyncStep]}',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              Container(
                height: 6,
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _syncStepsCompleted.where((completed) => completed).length / 6.0,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _syncFailed ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  '${_syncStepsCompleted.where((completed) => completed).length}/6 bước hoàn thành',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),

              if (_syncedCounts.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _syncedCounts.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              '${entry.value} bản ghi',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              if (_syncStepsCompleted.every((step) => step == true))
                Container(
                  margin: EdgeInsets.only(top: 16, bottom: 8),
                  width: double.infinity,
                  height: 36,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(18),
                    onPressed: () {
                      setState(() {
                        _showDashboard = true;
                      });
                    },
                    child: Text(
                      'Tiếp tục',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else if (_syncFailed && !_isSyncing)
                Container(
                  margin: EdgeInsets.only(top: 16, bottom: 8),
                  width: double.infinity,
                  height: 36,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(18),
                    onPressed: _startSyncProcess,
                    child: Text(
                      'Đồng bộ lại',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      if (!Platform.isWindows && _isVideoInitialized && _videoController != null) {
        _videoController!.removeListener(() {});
        _videoController!.pause();
        _videoController!.dispose();
      }
    } catch (e) {
      print("Error disposing video controller: $e");
    }
    super.dispose();
  }

  Widget _buildBackgroundMedia() {
    if (Platform.isWindows) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        child: Image.asset(
          'assets/vidhopdong.png',
          fit: BoxFit.cover,
        ),
      );
    } else {
      if (_isVideoInitialized && _videoController != null && _videoController!.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        );
      } else {
        return Container(
          width: double.infinity,
          height: double.infinity,
          child: Image.asset(
            'assets/vidhopdong.png',
            fit: BoxFit.cover,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBackgroundMedia(),

          if (_showDashboard)
            _buildDashboard()
          else if (!_isSyncing && !_syncFailed)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: ElevatedButton(
                    onPressed: _startSyncProcess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Bắt đầu đồng bộ lương',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          if (_isSyncing || _syncFailed || (_syncStepsCompleted.every((step) => step == true) && !_showDashboard))
            _buildSyncOverlay(),

          if (!_showDashboard)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}