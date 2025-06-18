import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'table_models.dart';
import 'db_helper.dart';
import 'hd_dashboard.dart';
import 'hd_dashboard2.dart';
import 'dart:io'; 
class HDPage extends StatefulWidget {
 const HDPage({Key? key}) : super(key: key);

 @override
 _HDPageState createState() => _HDPageState();
}

class _HDPageState extends State<HDPage> {
 VideoPlayerController? _videoController;
 bool _isVideoInitialized = false;
 bool _isSyncing = false;
 int _currentSyncStep = 0;
 List<bool> _syncStepsCompleted = List.filled(9, false);
 String _username = '';
 bool _shouldNavigateAway = false;
 final DBHelper _dbHelper = DBHelper();
 String _userHdRole = '';
 String _currentPeriod = '';
 String _nextPeriod = '';
 int _syncedRecordsCount = 0;
 bool _syncFailed = false;
 String _syncErrorMessage = '';
 Map<String, int> _syncedCounts = {};

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

   Future.delayed(Duration(milliseconds: 500), () {
     if (mounted) {
       _startSyncProcess();
     }
   });
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
     _syncStepsCompleted = List.filled(9, false);
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
       final userHdRole = prefs.getString('user_hd_role') ?? '';
       print("User HD role after sync: $userHdRole");

       await prefs.setString('last_sync_time', DateTime.now().toIso8601String());

       if (_syncStepsCompleted.every((step) => step == true)) {
         try {
           print("Navigating to HD dashboard");
           if (_userHdRole == 'Manager2') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HDDashboard2(
            currentPeriod: _currentPeriod,
            nextPeriod: _nextPeriod,
            username: _username,
            userRole: _userHdRole,
          )
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HDDashboard(
            currentPeriod: _currentPeriod,
            nextPeriod: _nextPeriod,
            username: _username,
            userRole: _userHdRole,
          )
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
               duration: Duration(seconds: 5),
             ),
           );
         }
       } else {
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
    final prefs = await SharedPreferences.getInstance();
    final originalUserState = prefs.getString('current_user');
    print("ORIGINAL USER STATE in _performSync: $originalUserState");

    for (int step = 0; step < 9; step++) {
      // Add null check before accessing video controller
      if (!Platform.isWindows && _isVideoInitialized && _videoController != null && !_videoController!.value.isPlaying && mounted) {
        _videoController!.play();
      }

      setState(() {
        _currentSyncStep = step;
        _syncStepsCompleted[step] = false;
        _syncFailed = false;
      });

      try {
        await Future.microtask(() => _executeSyncStep(step, _username));

        setState(() {
          _syncStepsCompleted[step] = true;
          // Enable skip after HopDong sync (step 1) is completed
          if (step == 1) {
            _allowSkipSync = true;
          }
        });

        await Future.delayed(Duration(milliseconds: 800));

        // Add null check here too
        if (!Platform.isWindows && _isVideoInitialized && _videoController != null && !_videoController!.value.isPlaying && mounted) {
          _videoController!.play();
        }
      } catch (e) {
        print("Error in sync step ${step + 1}: $e");
        if (mounted) {
          setState(() {
            _syncFailed = true;
            _syncErrorMessage = "Lỗi đồng bộ bước ${step + 1}: ${e.toString()}";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Lỗi trong quá trình đồng bộ bước ${step + 1}"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        break;
      }
    }

    await Future.delayed(Duration(seconds: 1));

    if (_syncStepsCompleted.every((step) => step == true)) {
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
    }

    final finalUserState = prefs.getString('current_user');
    if (originalUserState != finalUserState) {
      print("WARNING: User state changed during _performSync! Original: $originalUserState, Final: $finalUserState");
      await prefs.setString('current_user', originalUserState ?? '');
      print("RESTORED original user state in _performSync");
    }
  }

  bool _allowSkipSync = false;
  Future<void> _skipRemainingSync() async {
  setState(() {
    _isSyncing = false;
    // Mark all remaining steps as completed
    for (int i = 0; i < _syncStepsCompleted.length; i++) {
      _syncStepsCompleted[i] = true;
    }
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_sync_time', DateTime.now().toIso8601String());

  // Navigate to appropriate dashboard based on user role
  if (mounted) {
    if (_userHdRole == 'Manager2') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HDDashboard2(
            currentPeriod: _currentPeriod,
            nextPeriod: _nextPeriod,
            username: _username,
            userRole: _userHdRole,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HDDashboard(
            currentPeriod: _currentPeriod,
            nextPeriod: _nextPeriod,
            username: _username,
            userRole: _userHdRole,
          ),
        ),
      );
    }
  }
}

 Future<void> _executeSyncStep(int step, String usernameForSync) async {
   if (usernameForSync.isEmpty) {
     throw Exception('Username for sync not available');
   }

   final prefs = await SharedPreferences.getInstance();
   final originalUserState = prefs.getString('current_user');
   print(
       "ORIGINAL USER STATE in _executeSyncStep for step $step: $originalUserState");

   final baseUrl =
       'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

   try {
     switch (step) {
       case 0:
         final url = '$baseUrl/hdrole/$usernameForSync';
         print("REQUEST URL (Step 1): $url");

         final userResponse = await http.get(Uri.parse(url));

         print("RESPONSE STATUS (Step 1): ${userResponse.statusCode}");
         print("RESPONSE BODY (Step 1): ${userResponse.body}");

         if (userResponse.statusCode == 200) {
           final userData = json.decode(userResponse.body);
           
           if (userData == null || userData['role'] == null) {
             setState(() {
               _syncFailed = true;
               _syncErrorMessage = 'Người dùng chưa được đăng ký với hệ thống';
             });
             throw Exception('Invalid user. No role returned from server.');
           }

           final validRoles = ['Admin', 'Manager', 'KinhDoanh', 'Manager2'];
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
         await _syncTableData('hdhopdong', usernameForSync, 'LinkHopDong');
         break;

       case 2:
         await _syncTableData('hdvattu', usernameForSync, 'LinkVatTu');
         break;

       case 3:
         await _syncTableData('hddinhky', usernameForSync, 'LinkDinhKy');
         break;

       case 4:
         await _syncTableData('hdletettc', usernameForSync, 'LinkLeTetTC');
         break;

       case 5:
         await _syncTableData('hdphucap', usernameForSync, 'LinkPhuCap');
         break;

       case 6:
         await _syncTableData('hdngoaigiao', usernameForSync, 'LinkNgoaiGiao');
         break;

       case 7:
         await _syncTableData('hdmaymoc', usernameForSync, 'LinkMayMoc');
         break;

       case 8:
         await _syncTableData('hdluong', usernameForSync, 'LinkLuong');
         break;
     }

     final finalUserState = prefs.getString('current_user');
     if (originalUserState != finalUserState) {
       print(
           "WARNING: User state changed during step $step! Original: $originalUserState, Final: $finalUserState");
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
   
   String responseBody = response.body;
   String truncatedBody = responseBody.length > 1000 
       ? "${responseBody.substring(0, 1000)}..." 
       : responseBody;
   print("RESPONSE BODY ($tableName) [first 1000 chars]: $truncatedBody");

   if (response.statusCode == 200) {
     final data = json.decode(response.body);

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
       dataList = [data];
     }

     print("Processing ${dataList.length} $tableName records");

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

 Future<void> _saveTableData(String tableName, List<dynamic> dataList) async {
   try {
     print("Saving ${dataList.length} records to $tableName table");
     
     switch (tableName) {
       case 'LinkHopDong':
         await _dbHelper.clearLinkHopDongTable();
         print("Cleared old LinkHopDong data");
         
         final models = dataList.map((item) => LinkHopDongModel.fromMap(item)).toList();
         await _dbHelper.batchInsertLinkHopDongs(models);
         print("Inserted ${models.length} LinkHopDong records");
         break;
         
       case 'LinkVatTu':
         await _dbHelper.clearLinkVatTuTable();
         print("Cleared old LinkVatTu data");
         
         final models = dataList.map((item) => LinkVatTuModel.fromMap(item)).toList();
         await _dbHelper.batchInsertLinkVatTus(models);
         print("Inserted ${models.length} LinkVatTu records");
         break;
         
       case 'LinkDinhKy':
         await _dbHelper.clearLinkDinhKyTable();
         print("Cleared old LinkDinhKy data");
         
         final models = dataList.map((item) => LinkDinhKyModel.fromMap(item)).toList();
         await _dbHelper.batchInsertLinkDinhKys(models);
         print("Inserted ${models.length} LinkDinhKy records");
         break;
         
       case 'LinkLeTetTC':
         await _dbHelper.clearLinkLeTetTCTable();
         print("Cleared old LinkLeTetTC data");
         
         final models = dataList.map((item) => LinkLeTetTCModel.fromMap(item)).toList();
         await _dbHelper.batchInsertLinkLeTetTCs(models);
         print("Inserted ${models.length} LinkLeTetTC records");
         break;
         
       case 'LinkPhuCap':
         await _dbHelper.clearLinkPhuCapTable();
         print("Cleared old LinkPhuCap data");
         
         final models = dataList.map((item) => LinkPhuCapModel.fromMap(item)).toList();
         await _dbHelper.batchInsertLinkPhuCaps(models);
         print("Inserted ${models.length} LinkPhuCap records");
         break;
         
       case 'LinkNgoaiGiao':
         await _dbHelper.clearLinkNgoaiGiaoTable();
         print("Cleared old LinkNgoaiGiao data");
         
         final models = dataList.map((item) => LinkNgoaiGiaoModel.fromMap(item)).toList();
         await _dbHelper.batchInsertLinkNgoaiGiaos(models);
         print("Inserted ${models.length} LinkNgoaiGiao records");
         break;
         
       case 'LinkMayMoc':
         await _dbHelper.clearLinkMayMocTable();
         print("Cleared old LinkMayMoc data");
         
         final models = dataList.map((item) => LinkMayMocModel.fromMap(item)).toList();
         await _dbHelper.batchInsertLinkMayMocs(models);
         print("Inserted ${models.length} LinkMayMoc records");
         break;
         
       case 'LinkLuong':
         await _dbHelper.clearLinkLuongTable();
         print("Cleared old LinkLuong data");
         
         final models = dataList.map((item) => LinkLuongModel.fromMap(item)).toList();
         await _dbHelper.batchInsertLinkLuongs(models);
         print("Inserted ${models.length} LinkLuong records");
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
                    value: _syncStepsCompleted.where((completed) => completed).length / 9.0,
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
                  '${_syncStepsCompleted.where((completed) => completed).length}/9 bước hoàn thành',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),

              // Add skip button after HopDong sync is completed
              if (_allowSkipSync && _isSyncing && _syncStepsCompleted[1] == true)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  width: double.infinity,
                  height: 36,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: Color(0xFFFF9500), // Orange color for skip button
                    borderRadius: BorderRadius.circular(18),
                    onPressed: _skipRemainingSync,
                    child: Text(
                      'Bỏ qua đồng bộ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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
    if (_userHdRole == 'Manager2') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HDDashboard2(
            currentPeriod: _currentPeriod,
            nextPeriod: _nextPeriod,
            username: _username,
            userRole: _userHdRole,
          )
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HDDashboard(
            currentPeriod: _currentPeriod,
            nextPeriod: _nextPeriod,
            username: _username,
            userRole: _userHdRole,
          )
        ),
      );
    }
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
         // Replace the video widget with the new background media widget
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

        if (_isSyncing || _syncFailed || _syncStepsCompleted.every((step) => step == true))
          _buildSyncOverlay(),
      ],
    ),
  );
}
}