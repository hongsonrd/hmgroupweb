import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class PayPage extends StatefulWidget {
  const PayPage({Key? key}) : super(key: key);

  @override
  _PayPageState createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isSyncing = false;
  int _currentSyncStep = 0;
  List<bool> _syncStepsCompleted = List.filled(1, false); // Only 1 step for now
  String _username = '';
  String _userPayRole = '';
  int _syncedRecordsCount = 0;
  bool _syncFailed = false;
  String _syncErrorMessage = '';
  Map<String, int> _syncedCounts = {};
  Database? _database;

  final List<String> _stepLabels = [
    'Công chuẩn', // CongChuan sync
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadUsername();
    _initializeDatabase();

    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _startSyncProcess();
      }
    });
  }

  Future<void> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'pay_database.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE PayCongChuan (
            uid TEXT PRIMARY KEY,
            giaiDoan TEXT,
            congGs REAL,
            congVp REAL,
            congCn REAL,
            congKhac REAL,
            chiNhanh TEXT
          )
        ''');
      },
    );
  }

  Future<void> _initializeVideo() async {
    if (Platform.isWindows) {
      setState(() {
        _isVideoInitialized = true;
      });
      return;
    }
    
    try {
      _videoController = VideoPlayerController.asset('assets/appvideohopdong.mp4');
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
      _syncStepsCompleted = List.filled(1, false);
      _syncFailed = false;
      _syncErrorMessage = '';
      _syncedRecordsCount = 0;
      _syncedCounts.clear();
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
          // Navigate to pay dashboard (you'll need to create this)
          // Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => PayDashboard(
          //       username: _username,
          //       userRole: _userPayRole,
          //     ),
          //   ),
          // );
          
          // For now, show success message
          setState(() {
            _isSyncing = false;
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
    final prefs = await SharedPreferences.getInstance();
    final originalUserState = prefs.getString('current_user');
    print("ORIGINAL USER STATE in _performSync: $originalUserState");

    // First step: Get user role
    setState(() {
      _currentSyncStep = 0;
      _syncStepsCompleted[0] = false;
      _syncFailed = false;
    });

    try {
      await _executeSyncStep(0, _username);
      setState(() {
        _syncStepsCompleted[0] = true;
      });
      await Future.delayed(Duration(milliseconds: 800));
    } catch (e) {
      print("Error in sync step 1: $e");
      if (mounted) {
        setState(() {
          _syncFailed = true;
          _syncErrorMessage = "Lỗi đồng bộ bước 1: ${e.toString()}";
        });
      }
      throw e;
    }

    await Future.delayed(Duration(seconds: 1));

    if (_syncStepsCompleted.every((step) => step == true)) {
      await prefs.setString('last_pay_sync_time', DateTime.now().toIso8601String());
    }

    final finalUserState = prefs.getString('current_user');
    if (originalUserState != finalUserState) {
      print("WARNING: User state changed during _performSync! Original: $originalUserState, Final: $finalUserState");
      await prefs.setString('current_user', originalUserState ?? '');
      print("RESTORED original user state in _performSync");
    }
  }

  Future<void> _executeSyncStep(int step, String usernameForSync) async {
    if (usernameForSync.isEmpty) {
      throw Exception('Username for sync not available');
    }

    final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

    try {
      switch (step) {
        case 0:
          // Get user role first
          final roleUrl = '$baseUrl/payrole/$usernameForSync';
          print("REQUEST URL (Pay Role): $roleUrl");

          final roleResponse = await http.get(Uri.parse(roleUrl));
          print("RESPONSE STATUS (Pay Role): ${roleResponse.statusCode}");
          print("RESPONSE BODY (Pay Role): ${roleResponse.body}");

          if (roleResponse.statusCode == 200) {
            final roleText = roleResponse.body.trim();
            
            final validRoles = ['Admin', 'HR', 'AC', 'Viewer'];
            if (!validRoles.contains(roleText)) {
              setState(() {
                _syncFailed = true;
                _syncErrorMessage = 'Vai trò người dùng không hợp lệ: $roleText';
              });
              throw Exception('Invalid role returned: $roleText');
            }

            _userPayRole = roleText;
            print("Pay role received: $_userPayRole");

            // Now sync CongChuan data
            await _syncCongChuanData(usernameForSync);

          } else if (roleResponse.statusCode == 404) {
            setState(() {
              _syncFailed = true;
              _syncErrorMessage = 'Người dùng chưa được đăng ký với hệ thống lương';
            });
            throw Exception('User not found in Pay system');
          } else {
            throw Exception(
                'Failed to load user Pay role: ${roleResponse.statusCode}, Body: ${roleResponse.body}');
          }
          break;
      }
    } catch (e) {
      print("ERROR in sync step ${step + 1}: $e");
      throw e;
    }
  }

  Future<void> _syncCongChuanData(String username) async {
    final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
    final url = '$baseUrl/paycongchuan/$username';
    print("REQUEST URL (CongChuan): $url");

    final response = await http.get(Uri.parse(url));
    print("RESPONSE STATUS (CongChuan): ${response.statusCode}");
    
    String responseBody = response.body;
    String truncatedBody = responseBody.length > 1000 
        ? "${responseBody.substring(0, 1000)}..." 
        : responseBody;
    print("RESPONSE BODY (CongChuan) [first 1000 chars]: $truncatedBody");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data == null) {
        print("Received null data for CongChuan, treating as empty list");
        setState(() {
          _syncedCounts['CongChuan'] = 0;
        });
        return;
      }

      List<dynamic> dataList;
      if (data is List) {
        dataList = data;
      } else {
        dataList = [data];
      }

      print("Processing ${dataList.length} CongChuan records");
      await _saveCongChuanData(dataList);

      setState(() {
        _syncedCounts['CongChuan'] = dataList.length;
      });
    } else {
      print("API returned error status for CongChuan: ${response.statusCode}");
      throw Exception(
          'Failed to load CongChuan data: ${response.statusCode}, Body: ${response.body}');
    }
  }

  Future<void> _saveCongChuanData(List<dynamic> dataList) async {
    if (_database == null) return;

    try {
      print("Saving ${dataList.length} records to PayCongChuan table");
      
      // Clear existing data
      await _database!.delete('PayCongChuan');
      print("Cleared old PayCongChuan data");
      
      // Insert new data
      for (var item in dataList) {
        await _database!.insert(
          'PayCongChuan',
          {
            'uid': item['uid']?.toString() ?? '',
            'giaiDoan': item['giaiDoan']?.toString() ?? '',
            'congGs': _parseDouble(item['congGs']),
            'congVp': _parseDouble(item['congVp']),
            'congCn': _parseDouble(item['congCn']),
            'congKhac': _parseDouble(item['congKhac']),
            'chiNhanh': item['chiNhanh']?.toString() ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      print("Inserted ${dataList.length} PayCongChuan records");
    } catch (e) {
      print("Error saving PayCongChuan data: $e");
      throw Exception('Failed to save PayCongChuan data: $e');
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
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
                    value: _syncStepsCompleted.where((completed) => completed).length / 1.0,
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
                  '${_syncStepsCompleted.where((completed) => completed).length}/1 bước hoàn thành',
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
                          'Người dùng chưa đăng ký hệ thống lương',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                          // Navigate to PayDashboard when ready
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đồng bộ hoàn thành! Role: $_userPayRole'),
                              backgroundColor: Colors.green,
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
      if (!Platform.isWindows && _isVideoInitialized && _videoController != null) {
        _videoController!.removeListener(() {});
        _videoController!.pause();
        _videoController!.dispose();
      }
    } catch (e) {
      print("Error disposing video controller: $e");
    }
    _database?.close();
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

          if (_isSyncing || _syncFailed || _syncStepsCompleted.every((step) => step == true))
            _buildSyncOverlay(),
        ],
      ),
    );
  }
}