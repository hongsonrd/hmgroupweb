// hd_page.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'table_models.dart';
import 'db_helper.dart';
import 'hd_dashboard.dart';
import 'package:flutter/cupertino.dart';

class HDPage extends StatefulWidget {
  const HDPage({Key? key}) : super(key: key);

  @override
  _HDPageState createState() => _HDPageState();
}

class _HDPageState extends State<HDPage> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _isSyncing = false;
  int _currentSyncStep = 0;
  List<bool> _syncStepsCompleted = List.filled(9, false); // Now 9 steps total
  String _username = '';
  bool _shouldNavigateAway = false;
  final DBHelper _dbHelper = DBHelper();
  String _userHdRole = '';
  String _currentPeriod = '';
  String _nextPeriod = '';
  int _syncedRecordsCount = 0;
  bool _syncFailed = false;
  String _syncErrorMessage = '';
  Map<String, int> _syncedCounts = {}; // Track synced counts per table

  // Step labels for UI
  final List<String> _stepLabels = [
    'Xác thực',
    'Hợp đồng',
    'Vật tư',
    'Định kỳ',
    'Lễ tết TC',
    'Phụ cấp',
    'Ngoại giao',
    'Máy móc',
    'Lương'
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadUsername();

    // Add a small delay before triggering sync automatically
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _startSyncProcess();
      }
    });
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset('assets/appvideohopdong.mp4');
    await _videoController.initialize();
    _videoController.setLooping(true);
    _videoController.setVolume(1.0);
    _videoController.play();

    setState(() {
      _isVideoInitialized = true;
    });
    _videoController.addListener(() {
      if (!_videoController.value.isPlaying && mounted) {
        _videoController.play();
      }
    });
  }

  Future<void> _loadUsername() async {
    // Load username from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final userObj = prefs.getString('current_user');

    if (userObj != null && userObj.isNotEmpty) {
      try {
        // Try to parse it as JSON if it's stored that way
        final userData = json.decode(userObj);
        setState(() {
          // Extract just the username string
          _username = userData['username'] ?? '';
          print("Loaded username from prefs: $_username");
        });
      } catch (e) {
        // If it's not JSON, use it directly as username
        setState(() {
          _username = userObj;
          print("Loaded username directly from prefs: $_username");
        });
      }
    } else {
      // If no username in shared prefs, try to get it from another source
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
            // Save for future use (only the username string)
            await prefs.setString('current_user', _username);
          }
        }
      } catch (e) {
        print('Error loading username: $e');
        // Fall back to a default if needed
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
      _syncStepsCompleted = List.filled(9, false); // Reset all 9 steps
      _syncFailed = false;
      _syncErrorMessage = '';
      _syncedRecordsCount = 0;
      _syncedCounts.clear(); // Reset synced counts
    });

    try {
      // Start the sync process
      print("Starting sync process for user: $_username");
      await _performSync();
      print("Sync process completed successfully");

      // After sync completion
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final userHdRole = prefs.getString('user_hd_role') ?? '';
        print("User HD role after sync: $userHdRole");

        // Save the last sync time ONLY
        await prefs.setString('last_sync_time', DateTime.now().toIso8601String());

        // Check if all steps are completed before navigating
        if (_syncStepsCompleted.every((step) => step == true)) {
          try {
            print("Navigating to HD dashboard");
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HDDashboard(
                  currentPeriod: _currentPeriod,
                  nextPeriod: _nextPeriod,
                )
              ),
            );
          } catch (navError) {
            print("Navigation error: $navError");
            setState(() {
              _isSyncing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Lỗi khi chuyển trang: ${navError.toString()}"),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          // If sync failed at some step, stay on the page and show error
          print("Sync process did not complete all steps.");
          setState(() {
            _isSyncing = false;
            _syncFailed = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Đồng bộ dữ liệu không hoàn thành. Vui lòng thử lại."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
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

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Lỗi đồng bộ"),
            content: Text(
                "Đã xảy ra lỗi trong quá trình đồng bộ: ${e.toString()}"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _performSync() async {
    // Store the original login state at the beginning
    final prefs = await SharedPreferences.getInstance();
    final originalUserState = prefs.getString('current_user');
    print("ORIGINAL USER STATE in _performSync: $originalUserState");

    // Perform each step sequentially (9 steps total)
    for (int step = 0; step < 9; step++) {
      // Check if video is still playing and restart if needed
      if (_isVideoInitialized && !_videoController.value.isPlaying && mounted) {
        _videoController.play();
      }

      setState(() {
        _currentSyncStep = step;
        _syncStepsCompleted[step] = false; // Mark current step as not completed yet
        _syncFailed = false; // Reset failure state for the new sync attempt
      });

      try {
        // Execute each step with a small delay to allow UI updates
        await Future.microtask(() => _executeSyncStep(step, _username));

        setState(() {
          _syncStepsCompleted[step] = true;
        });

        // Add a small delay between steps for better UX
        await Future.delayed(Duration(milliseconds: 800));

        // Check again if video is playing
        if (_isVideoInitialized && !_videoController.value.isPlaying && mounted) {
          _videoController.play();
        }
      } catch (e) {
        print("Error in sync step ${step + 1}: $e");
        if (mounted) {
          setState(() {
            _syncFailed = true;
            _syncErrorMessage =
                "Lỗi đồng bộ bước ${step + 1}: ${e.toString()}";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Lỗi trong quá trình đồng bộ bước ${step + 1}"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        // Stop the sync process if a step fails
        break;
      }
    }

    // Wait a moment after sync completion
    await Future.delayed(Duration(seconds: 1));

    // ONLY save the last sync time if ALL steps completed successfully
    if (_syncStepsCompleted.every((step) => step == true)) {
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
    }

    // Double check current_user wasn't changed during sync
    final finalUserState = prefs.getString('current_user');
    if (originalUserState != finalUserState) {
      print(
          "WARNING: User state changed during _performSync! Original: $originalUserState, Final: $finalUserState");
      // Restore the original state
      await prefs.setString('current_user', originalUserState ?? '');
      print("RESTORED original user state in _performSync");
    }
  }

  Future<void> _executeSyncStep(int step, String usernameForSync) async {
    if (usernameForSync.isEmpty) {
      throw Exception('Username for sync not available');
    }

    // Store original username value before any manipulation
    final prefs = await SharedPreferences.getInstance();
    final originalUserState = prefs.getString('current_user');
    print(
        "ORIGINAL USER STATE in _executeSyncStep for step $step: $originalUserState");

    final baseUrl =
        'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

    try {
      switch (step) {
        case 0:
          // First sync step - Get user HD role and periods
          final url = '$baseUrl/hdrole/$usernameForSync';
          print("REQUEST URL (Step 1): $url");

          final userResponse = await http.get(Uri.parse(url));

          print("RESPONSE STATUS (Step 1): ${userResponse.statusCode}");
          print("RESPONSE BODY (Step 1): ${userResponse.body}");

          if (userResponse.statusCode == 200) {
            // Server now returns JSON object
            final userData = json.decode(userResponse.body);
            
            if (userData == null || userData['role'] == null) {
              setState(() {
                _syncFailed = true;
                _syncErrorMessage = 'Người dùng chưa được đăng ký với hệ thống';
              });
              throw Exception('Invalid user. No role returned from server.');
            }

            // Validate the role is one of the expected values
            final validRoles = ['Admin', 'Manager', 'KinhDoanh'];
            if (!validRoles.contains(userData['role'])) {
              setState(() {
                _syncFailed = true;
                _syncErrorMessage = 'Vai trò người dùng không hợp lệ: ${userData['role']}';
              });
              throw Exception('Invalid role returned: ${userData['role']}');
            }

            _userHdRole = userData['role'];
            _currentPeriod = userData['currentPeriod'] ?? '';
            _nextPeriod = userData['nextPeriod'] ?? '';
            
            print("HD role received: $_userHdRole");
            print("Current period: $_currentPeriod");
            print("Next period: $_nextPeriod");

            // Save all the HD-specific data with different keys
            await prefs.setString('user_hd_role', _userHdRole);
            await prefs.setString('hd_current_period', _currentPeriod);
            await prefs.setString('hd_next_period', _nextPeriod);
            
            print("User HD data saved - Role: $_userHdRole, Current: $_currentPeriod, Next: $_nextPeriod");
          } else if (userResponse.statusCode == 404) {
            setState(() {
              _syncFailed = true;
              _syncErrorMessage = 'Người dùng chưa được đăng ký với hệ thống';
            });
            throw Exception('User not found in HD system');
          } else {
            throw Exception(
                'Failed to load user HD data: ${userResponse.statusCode}, Body: ${userResponse.body}');
          }
          break;

        case 1:
          // Second sync step - Get contracts (HopDong)
          await _syncTableData('hdhopdong', usernameForSync, 'LinkHopDong');
          break;

        case 2:
          // Third sync step - Get materials (VatTu)
          await _syncTableData('hdvattu', usernameForSync, 'LinkVatTu');
          break;

        case 3:
          // Fourth sync step - Get periodic work (DinhKy)
          await _syncTableData('hddinhky', usernameForSync, 'LinkDinhKy');
          break;

        case 4:
          // Fifth sync step - Get holiday work (LeTetTC)
          await _syncTableData('hdletettc', usernameForSync, 'LinkLeTetTC');
          break;

        case 5:
          // Sixth sync step - Get allowances (PhuCap)
          await _syncTableData('hdphucap', usernameForSync, 'LinkPhuCap');
          break;

        case 6:
          // Seventh sync step - Get external work (NgoaiGiao)
          await _syncTableData('hdngoaigiao', usernameForSync, 'LinkNgoaiGiao');
          break;

        case 7:
          // Eighth sync step - Get machinery (MayMoc)
          await _syncTableData('hdmaymoc', usernameForSync, 'LinkMayMoc');
          break;

        case 8:
          // Ninth sync step - Get salary (Luong)
          await _syncTableData('hdluong', usernameForSync, 'LinkLuong');
          break;
      }

      // Double check current_user wasn't changed during this step
      final finalUserState = prefs.getString('current_user');
      if (originalUserState != finalUserState) {
        print(
            "WARNING: User state changed during step $step! Original: $originalUserState, Final: $finalUserState");
        // Restore the original state
        await prefs.setString('current_user', originalUserState ?? '');
        print("RESTORED original user state in step $step");
      }
    } catch (e) {
      print("ERROR in sync step ${step + 1}: $e");
      throw e;
    }
  }

  Future<void> _syncTableData(String endpoint, String username, String tableName) async {
    final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
    final url = '$baseUrl/$endpoint/$username';
    print("REQUEST URL ($tableName): $url");

    final response = await http.get(Uri.parse(url));
    print("RESPONSE STATUS ($tableName): ${response.statusCode}");
    print("RESPONSE BODY ($tableName): ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // If the API returns null or empty JSON, consider it a success with 0 records
      if (data == null) {
        print("Received null data for $tableName, treating as empty list");
        setState(() {
          _syncedCounts[tableName] = 0;
        });
        return;
      }

      List<dynamic> dataList;
      if (data is List) {
        dataList = data;
      } else {
        dataList = [data]; // Single object
      }

      print("Processing ${dataList.length} $tableName records");

      // Clear old data first
      await _clearTableData(tableName);

      // Save new data to local database
      await _saveTableData(tableName, dataList);

      setState(() {
        _syncedCounts[tableName] = dataList.length;
      });
    } else {
      print("API returned error status for $tableName: ${response.statusCode}");
      throw Exception(
          'Failed to load $tableName data: ${response.statusCode}, Body: ${response.body}');
    }
  }

  Future<void> _clearTableData(String tableName) async {
    switch (tableName) {
      case 'LinkHopDong':
        await _dbHelper.clearLinkHopDongTable();
        break;
      case 'LinkVatTu':
        await _dbHelper.clearAllLinkTables(); // This clears all, but we'll call individual clears
        break;
      // Note: clearAllLinkTables clears everything, so we'll do individual table clearing
      default:
        print("No clear method for table: $tableName");
    }
  }

  Future<void> _saveTableData(String tableName, List<dynamic> dataList) async {
    try {
      switch (tableName) {
        case 'LinkHopDong':
          final models = dataList.map((item) => LinkHopDongModel.fromMap(item)).toList();
          await _dbHelper.batchInsertLinkHopDongs(models);
          break;
        case 'LinkVatTu':
          final models = dataList.map((item) => LinkVatTuModel.fromMap(item)).toList();
          await _dbHelper.batchInsertLinkVatTus(models);
          break;
        case 'LinkDinhKy':
          final models = dataList.map((item) => LinkDinhKyModel.fromMap(item)).toList();
          await _dbHelper.batchInsertLinkDinhKys(models);
          break;
        case 'LinkLeTetTC':
          final models = dataList.map((item) => LinkLeTetTCModel.fromMap(item)).toList();
          await _dbHelper.batchInsertLinkLeTetTCs(models);
          break;
        case 'LinkPhuCap':
          final models = dataList.map((item) => LinkPhuCapModel.fromMap(item)).toList();
          await _dbHelper.batchInsertLinkPhuCaps(models);
          break;
        case 'LinkNgoaiGiao':
          final models = dataList.map((item) => LinkNgoaiGiaoModel.fromMap(item)).toList();
          await _dbHelper.batchInsertLinkNgoaiGiaos(models);
          break;
        case 'LinkMayMoc':
          final models = dataList.map((item) => LinkMayMocModel.fromMap(item)).toList();
          await _dbHelper.batchInsertLinkMayMocs(models);
          break;
        case 'LinkLuong':
          final models = dataList.map((item) => LinkLuongModel.fromMap(item)).toList();
          await _dbHelper.batchInsertLinkLuongs(models);
          break;
        default:
          print("No save method for table: $tableName");
      }
    } catch (e) {
      print("Error saving $tableName data: $e");
      throw Exception('Failed to save $tableName data: $e');
    }
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
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Đồng bộ hợp đồng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              // Current step indicator
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

              // Progress bar
              Container(
                height: 6,
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _syncStepsCompleted.where((completed) => completed).length / 9.0,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _syncFailed ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ),

              // Progress text
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  '${_syncStepsCompleted.where((completed) => completed).length}/9 bước hoàn thành',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),

              // Sync counts display
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
                              entry.key.replaceAll('Link', ''),
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

              // Warning message for failed authentication
              if (_currentSyncStep == 0 && _syncFailed)
                Container(
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0x33FF3B30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFF3B30), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Người dùng chưa đăng ký',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Tính năng đang phát triển')),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Color(0xFFFF3B30),
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          minimumSize: Size(60, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Đăng ký',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Proceed and Sync Again buttons
              if (_syncStepsCompleted.every((step) => step == true))
                Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 16, bottom: 8),
                      width: double.infinity,
                      height: 36,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: Color(0xFF34C759),
                        borderRadius: BorderRadius.circular(18),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HDDashboard(
                                currentPeriod: _currentPeriod,
                                nextPeriod: _nextPeriod,
                              )
                            ),
                          );
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
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 8, bottom: 8),
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
      if (_videoController != null) {
        _videoController.removeListener(() {});
        _videoController.pause();
        _videoController.dispose();
      }
    } catch (e) {
      print("Error disposing video controller: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video background - always playing
          if (_isVideoInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            ),

          // Back button
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

          // Start sync button (centered on screen)
          if (!_isSyncing && !_syncFailed)
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
                      'Bắt đầu đồng bộ',
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

          // Sync overlay (top of screen)
         if (_isSyncing || _syncFailed || _syncStepsCompleted.every((step) => step == true))
           _buildSyncOverlay(),
       ],
     ),
   );
 }
}