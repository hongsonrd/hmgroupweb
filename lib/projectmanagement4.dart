// projectmanagement4.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'table_models.dart';
import 'db_helper.dart';
import 'projectmanagement4kh.dart';
import 'projectmanagement4kt.dart';
import 'projectmanagement4ad.dart';

class ProjectManagement4 extends StatefulWidget {
  const ProjectManagement4({Key? key}) : super(key: key);

  @override
  _ProjectManagement4State createState() => _ProjectManagement4State();
}

class _ProjectManagement4State extends State<ProjectManagement4> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _isSyncing = false;
  int _currentSyncStep = 0;
  List<bool> _syncStepsCompleted = [false, false, false];
  String _username = '';
  bool _shouldNavigateAway = false;
  final DBHelper _dbHelper = DBHelper();
  String _userRole = '';
  int _syncedRecordsCount = 0;
  bool _syncFailed = false;
  String _syncErrorMessage = '';
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

Future<void> _checkSyncNeeded() async {
  final needToSync = await _needToSync();
  if (!needToSync) {
    // Auto-navigate to the appropriate screen based on saved role
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role') ?? '';
    
    if (mounted && userRole.isNotEmpty) {
      // Navigate based on user role
      switch (userRole.toLowerCase()) {
        case 'admin':
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
          break;
        case 'thụ hưởng':
        case 'thu huong':
          Navigator.pushReplacementNamed(context, '/customer_dashboard');
          break;
        case 'kỹ thuật':
        case 'ky thuat':
          Navigator.pushReplacementNamed(context, '/worker_dashboard');
          break;
        default:
          // If role is unknown, stay on current screen
          break;
      }
    }
  }
}
  Future<void> _initializeVideo() async {
  _videoController = VideoPlayerController.asset('assets/appvideogoclean.mp4');
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
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/current-user'),
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
  
  // Check if username is a JSON string and extract just the username
  try {
    final userData = json.decode(_username);
    final usernameValue = userData['username'] ?? '';
    if (usernameValue.isNotEmpty) {
      _username = usernameValue;
      print("Updated username to extracted value: $_username");
    }
  } catch (e) {
    // If it's not valid JSON, use it as is
    print("Username is not JSON, using as is: $_username");
  }
  
  setState(() {
    _isSyncing = true;
    _currentSyncStep = 0;
    _syncStepsCompleted = [false, false, false];
  });
  
  try {
    // Start the sync process
    print("Starting sync process for user: $_username");
    await _performSync();
    print("Sync process completed successfully");
    
    // After sync completion
    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role') ?? '';
      print("User role after sync: $userRole");
      
      // Save the last sync time
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      await prefs.setString('current_user', _username);
      
      // Make sure we properly handle the Vietnamese characters in the role comparison
      String normalizedRole = userRole.toLowerCase();
      
      // Add a try-catch around navigation to catch any errors
      try {
        // Navigate based on user role with better handling of Vietnamese characters
        if (normalizedRole.contains('admin')) {
  print("Navigating to admin dashboard");
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => AdminDashboard()),
  );
} else if (normalizedRole.contains('thu huong') || 
          normalizedRole.contains('thụ hưởng') ||
          normalizedRole.contains('hưởng')) {
  print("Navigating to customer dashboard");
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CustomerDashboard()),
  );
} else if (normalizedRole.contains('ky thuat') || 
          normalizedRole.contains('kỹ thuật') ||
          normalizedRole.contains('thuật')) {
  print("Navigating to worker dashboard");
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => WorkerDashboard()),
  );
} else {
  // If role is unknown, stay on current screen
  print("Unknown user role: $userRole, staying on current screen");
  setState(() {
    _isSyncing = false;
  });
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("Không xác định được vai trò người dùng: $userRole"),
      backgroundColor: Colors.orange,
    ),
  );
}
      } catch (navError) {
        print("Navigation error: $navError");
        setState(() {
          _isSyncing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi khi chuyển trang: ${navError.toString()}"),
            backgroundColor: Colors.red,
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
      
      // Show error dialog with details
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Sync Error"),
          content: Text("Error during sync process: ${e.toString()}"),
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
Future<bool> _needToSync() async {
  final prefs = await SharedPreferences.getInstance();
  final lastSyncTimeStr = prefs.getString('last_sync_time');
  final currentUsername = prefs.getString('current_user');
  
  // If username changed, we need to sync
  if (currentUsername != _username) {
    return true;
  }
  
  // If no last sync time, we need to sync
  if (lastSyncTimeStr == null) {
    return true;
  }
  
  // Parse last sync time
  final lastSyncTime = DateTime.tryParse(lastSyncTimeStr);
  if (lastSyncTime == null) {
    return true;
  }
  
  // If last sync was more than 15 minutes ago, we need to sync
  final now = DateTime.now();
  final difference = now.difference(lastSyncTime);
  return difference.inMinutes > 15;
}
  Future<void> _performSync() async {
  // Perform each step sequentially
  for (int step = 0; step < 3; step++) {
    // Check if video is still playing and restart if needed
    if (_isVideoInitialized && !_videoController.value.isPlaying && mounted) {
      _videoController.play();
    }
    
    setState(() {
      _currentSyncStep = step;
    });
    
    try {
      // Execute each step with a small delay to allow UI updates
      await Future.microtask(() => _executeSyncStep(step));
      
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
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi trong quá trình đồng bộ bước ${step + 1}: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      break;
    }
  }
  
  // Wait a moment after sync completion
  await Future.delayed(Duration(seconds: 1));
  
  // Save the last sync time
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
  await prefs.setString('current_user', _username);
}

  Future<void> _executeSyncStep(int step) async {
  if (_username.isEmpty) {
    throw Exception('Username not available');
  }
  
  // Extract just the username value if it's in JSON format
  String usernameValue = _username;
  try {
    final userData = json.decode(_username);
    usernameValue = userData['username'] ?? '';
    print("Extracted username from JSON: $usernameValue");
  } catch (e) {
    // If it's not valid JSON, use it as is
    print("Using username directly: $usernameValue");
  }
  
  // If still empty after extraction, throw error
  if (usernameValue.isEmpty) {
    throw Exception('Could not extract valid username');
  }
  
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  try {
    switch (step) {
      case 0:
        // First sync step - Get user role and account info
        final url = '$baseUrl/cleanrole/$usernameValue';
        print("REQUEST URL (Step 1): $url");
        
        final userResponse = await http.get(Uri.parse(url));
        
        print("RESPONSE STATUS (Step 1): ${userResponse.statusCode}");
        print("RESPONSE BODY (Step 1): ${userResponse.body}");
        
        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          
          if (userData == null) {
            throw Exception('Invalid user. No data returned from server.');
          }
          
          // Check if the response is a list or a single object
          if (userData is List) {
            print("Multiple users returned, finding the correct one");
            // If it's a list, find the user with matching username
            bool userFound = false;
            for (var user in userData) {
              if (user['Username'] == usernameValue) {
                // Found the matching user
                _userRole = user['PhanLoai'] ?? 'Unknown';
                userFound = true;
                print("Found matching user, role: $_userRole");
                break;
              }
            }
            
            if (!userFound) {
              throw Exception('User not found in the returned list');
            }
          } else {
            // It's a single user object
            _userRole = userData['PhanLoai'] ?? 'Unknown';
            print("Single user returned, role: $_userRole");
          }
          
          // Save user role information to shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', _userRole);
          
          // Create the TaiKhoanModel with correct parameters
          final taiKhoan = GoCleanTaiKhoanModel(
            uid: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['UID'] ?? '' : userData['UID'] ?? '',
            taiKhoan: usernameValue,
            phanLoai: _userRole,
            sdt: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['SDT'] ?? '' : userData['SDT'] ?? '',
            email: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['Email'] ?? '' : userData['Email'] ?? '',
            diaChi: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['DiaChi'] ?? '' : userData['DiaChi'] ?? '',
            trangThai: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['TrangThai'] ?? '' : userData['TrangThai'] ?? '',
            dinhVi: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['DinhVi'] ?? '' : userData['DinhVi'] ?? '',
            loaiDinhVi: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['LoaiDinhVi'] ?? '' : userData['LoaiDinhVi'] ?? '',
            diaDiem: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['DiaDiem'] ?? '' : userData['DiaDiem'] ?? '',
            hinhAnh: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['HinhAnh'] ?? '' : userData['HinhAnh'] ?? '',
            nhom: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['Nhom'] ?? '' : userData['Nhom'] ?? '',
            admin: userData is List ? userData.firstWhere((u) => u['Username'] == usernameValue, orElse: () => {})['Admin'] ?? '' : userData['Admin'] ?? '',
          );
          
          // Clear existing data first
          await _dbHelper.clearGoCleanTaiKhoanTable();
          
          // Insert new user data
          await _dbHelper.insertGoCleanTaiKhoan(taiKhoan);
          
          print("User role saved: $_userRole");
        } else {
          throw Exception('Failed to load user data: ${userResponse.statusCode}, Body: ${userResponse.body}');
        }
        break;
        
      case 1:
        // Second sync step - Get work assignments (CongViec)
        final url = '$baseUrl/cleancongviec/$usernameValue';
        print("REQUEST URL (Step 2): $url");
        
        final congViecResponse = await http.get(Uri.parse(url));
        // Rest of implementation
        break;
        
      case 2:
        // Third sync step - Get work requirements (YeuCau)
        final url = '$baseUrl/cleanyeucau';
        print("REQUEST URL (Step 3): $url");
        
        final yeuCauResponse = await http.get(Uri.parse(url));
        // Rest of implementation
        break;
    }
  } catch (e) {
    print("ERROR in sync step ${step + 1}: $e");
    throw e;
  }
}
  Widget _buildSyncOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //Text(
            //  'Đang đồng bộ dữ liệu',
            //  style: TextStyle(
            //    color: Colors.white,
            //    fontSize: 20,
            //    fontWeight: FontWeight.bold,
            //  ),
            //),
            //SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSyncStepIndicator(0, 'Bước 1'),
                _buildSyncStepIndicator(1, 'Bước 2'),
                _buildSyncStepIndicator(2, 'Bước 3'),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStepIndicator(int step, String label) {
    final bool isActive = _currentSyncStep == step;
    final bool isCompleted = _syncStepsCompleted[step];
    
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted 
                ? Colors.green 
                : (isActive ? Colors.blue : Colors.grey.withOpacity(0.7)),
          ),
          child: Center(
            child: isCompleted 
                ? Icon(Icons.check, color: Colors.white, size: 30)
                : (isActive 
                    ? SpinKitDoubleBounce(color: Colors.white, size: 40)
                    : Text(
                        '${step + 1}',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      )
                )
          ),
        ),
        SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
          if (!_isSyncing)
            Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 80.0), // Adjust as needed
        child: Center(
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
      ),
    ],
  ),
          
          // Sync overlay (lower third)
          if (_isSyncing)
            _buildSyncOverlay(),
        ],
      ),
    );
  }
}