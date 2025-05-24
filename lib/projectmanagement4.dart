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
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/cupertino.dart';

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
          case 'nghiệm thu':
          case 'nghiem thu':
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
      _syncStepsCompleted = [false, false, false];
      _syncFailed = false;
      _syncErrorMessage = '';
      _syncedRecordsCount = 0; // Reset synced count on new sync
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

        // Save the last sync time ONLY
        await prefs.setString('last_sync_time', DateTime.now().toIso8601String());

        // Navigate based on user role
        String normalizedRole = userRole.toLowerCase();

        // Check if all steps are completed before navigating
        if (_syncStepsCompleted.every((step) => step == true)) {
          try {
            if (normalizedRole.contains('admin')) {
              print("Navigating to admin dashboard");
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AdminDashboard()),
              );
            } else if (normalizedRole.contains('nghiem thu') ||
                normalizedRole.contains('nghiệm thu') ||
                normalizedRole.contains('nghiệm')) {
              print("Navigating to customer dashboard");
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => CustomerDashboard()),
              );
            } else if (normalizedRole.contains('ky thuat') ||
                normalizedRole.contains('kỹ thuật') ||
                normalizedRole.contains('thuật')) {
              print("Navigating to worker dashboard");
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => WorkerDashboard()),
              );
            } else {
              // If role is unknown, stay on current screen and show message
              print("Unknown user role: $userRole, staying on current screen");
              setState(() {
                _isSyncing = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      "Đồng bộ hoàn thành, nhưng vai trò người dùng không xác định: $userRole"),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
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
          // If sync failed at some step, stay on the page and show error
          print("Sync process did not complete all steps.");
           setState(() {
            _isSyncing = false;
            _syncFailed = true; // Ensure _syncFailed is true if not all steps completed
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
    // Store the original login state at the beginning
    final prefs = await SharedPreferences.getInstance();
    final originalUserState = prefs.getString('current_user');
    print("ORIGINAL USER STATE in _performSync: $originalUserState");

    // Perform each step sequentially
    for (int step = 0; step < 3; step++) {
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
          // First sync step - Get user role and account info
          final url = '$baseUrl/cleanrole/$usernameForSync';
          print("REQUEST URL (Step 1): $url");

          final userResponse = await http.get(Uri.parse(url));

          print("RESPONSE STATUS (Step 1): ${userResponse.statusCode}");
          print("RESPONSE BODY (Step 1): ${userResponse.body}");

          if (userResponse.statusCode == 200) {
            final userData = json.decode(userResponse.body);

            if (userData == null) {
              setState(() {
                _syncFailed = true;
                _syncErrorMessage = 'Người dùng chưa được đăng ký với hệ thống';
              });
              throw Exception('Invalid user. No data returned from server.');
            }

            // Check if the response is a list or a single object
            if (userData is List) {
              print("Multiple users returned, finding the correct one");
              // If it's a list, find the user with matching username
              bool userFound = false;
              for (var user in userData) {
                if (user['Username'] == usernameForSync) {
                  // Found the matching user
                  _userRole = user['PhanLoai'] ?? 'Unknown';
                  userFound = true;
                  print("Found matching user, role: $_userRole");
                  break;
                }
              }

              if (!userFound) {
                setState(() {
                  _syncFailed = true;
                  _syncErrorMessage = 'Người dùng chưa được đăng ký với hệ thống';
                });
                throw Exception('User not found in the returned list');
              }
            } else {
              // It's a single user object
              _userRole = userData['PhanLoai'] ?? 'Unknown';
              print("Single user returned, role: $_userRole");
            }

            // IMPORTANT: Only update the user_role, keeping the current_user value intact
            await prefs.setString('user_role', _userRole);

            // Process and insert data as before, but don't touch the current_user in SharedPreferences
            if (userData is List) {
              // Clear table before bulk insert
              await _dbHelper.clearGoCleanTaiKhoanTable();
              print("GoCleanTaiKhoan table cleared for bulk insert");

              for (var user in userData) {
                final taiKhoan = GoCleanTaiKhoanModel(
                  uid: user['UID'] ?? '',
                  taiKhoan: user['Username'] ?? '',
                  phanLoai: user['PhanLoai'] ?? '',
                  sdt: user['SDT'] ?? '',
                  email: user['Email'] ?? '',
                  diaChi: user['DiaChi'] ?? '',
                  trangThai: user['TrangThai'] ?? '',
                  dinhVi: user['DinhVi'] ?? '',
                  loaiDinhVi: user['LoaiDinhVi'] ?? '',
                  diaDiem: user['DiaDiem'] ?? '',
                  hinhAnh: user['HinhAnh'] ?? '',
                  nhom: user['Nhom'] ?? '',
                  admin: user['Admin'] ?? '',
                );
                await _dbHelper.insertGoCleanTaiKhoan(taiKhoan);
              }

              // Log the count after insertion
              final taiKhoanCount = await _dbHelper.getGoCleanTaiKhoanCount();
              print("Successfully inserted $taiKhoanCount TaiKhoan records");
              setState(() {
                _syncedRecordsCount = taiKhoanCount; // Update count
              });
            } else {
              // Single user object - clear and insert
              await _dbHelper.clearGoCleanTaiKhoanTable();
              print("GoCleanTaiKhoan table cleared for single insert");

              final taiKhoan = GoCleanTaiKhoanModel(
                uid: userData['UID'] ?? '',
                taiKhoan: userData['Username'] ?? '',
                phanLoai: userData['PhanLoai'] ?? '',
                sdt: userData['SDT'] ?? '',
                email: userData['Email'] ?? '',
                diaChi: userData['DiaChi'] ?? '',
                trangThai: userData['TrangThai'] ?? '',
                dinhVi: userData['DinhVi'] ?? '',
                loaiDinhVi: userData['LoaiDinhVi'] ?? '',
                diaDiem: userData['DiaDiem'] ?? '',
                hinhAnh: userData['HinhAnh'] ?? '',
                nhom: userData['Nhom'] ?? '',
                admin: userData['Admin'] ?? '',
              );
              await _dbHelper.insertGoCleanTaiKhoan(taiKhoan);

              // Log the count after insertion
              final taiKhoanCount = await _dbHelper.getGoCleanTaiKhoanCount();
              print("Successfully inserted $taiKhoanCount TaiKhoan records");
               setState(() {
                _syncedRecordsCount = taiKhoanCount; // Update count
              });
            }

            print("User role saved: $_userRole");
          } else {
            throw Exception(
                'Failed to load user data: ${userResponse.statusCode}, Body: ${userResponse.body}');
          }
          break;

        case 1:
          // Second sync step - Get work assignments (CongViec)
          final url = '$baseUrl/cleancongviec/$usernameForSync';
          print("REQUEST URL (Step 2): $url");

          final congViecResponse = await http.get(Uri.parse(url));
          print("RESPONSE STATUS (Step 2): ${congViecResponse.statusCode}");
          print("RESPONSE BODY (Step 2): ${congViecResponse.body}");

          if (congViecResponse.statusCode == 200) {
            // Clear the existing CongViec table
            await _dbHelper.clearGoCleanCongViecTable();
            print("GoClean_CongViec table cleared for new data");

            final congViecData = json.decode(congViecResponse.body);

            // If the API returns null or empty JSON, consider it a success with 0 records
            if (congViecData == null) {
              print("Received null data for CongViec, treating as empty list");
              setState(() {
                _syncedRecordsCount = 0;
              });
              break;
            }

            // Check if it's a list and process accordingly
            if (congViecData is List) {
              print("Processing ${congViecData.length} CongViec records");

              int successCount = 0;
              for (var i = 0; i < congViecData.length; i++) {
                var congViec = congViecData[i];
                try {
                  // Log the raw record for debugging
                  // print("Processing CongViec record $i: ${json.encode(congViec)}");

                  // Parse the date strings
                  DateTime? ngayDate;
                  if (congViec['Ngay'] != null &&
                      congViec['Ngay'].toString().isNotEmpty) {
                    try {
                      ngayDate = DateTime.parse(congViec['Ngay'].toString());
                      // print("Successfully parsed date: ${congViec['Ngay']} to $ngayDate");
                    } catch (e) {
                      print("Error parsing date ${congViec['Ngay']}: $e");
                    }
                  }

                  // Create model object
                  final congViecModel = GoCleanCongViecModel(
                    lichLamViecID: congViec['LichLamViecID']?.toString(),
                    giaoViecID: congViec['GiaoViecID']?.toString(),
                    ngay: ngayDate,
                    nguoiThucHien: congViec['NguoiThucHien']?.toString(),
                    xacNhan: congViec['XacNhan']?.toString(),
                    qrCode: congViec['QRcode']?.toString(),
                    mocBatDau: congViec['MocBatDau']?.toString(),
                    hinhAnhTruoc: congViec['HinhAnhTruoc']?.toString(),
                    mocKetThuc: congViec['MocKetThuc']?.toString(),
                    hinhAnhSau: congViec['HinhAnhSau']?.toString(),
                    thucHienDanhGia: congViec['ThucHienDanhGia'] != null
                        ? int.tryParse(congViec['ThucHienDanhGia'].toString())
                        : null,
                    moTaThucHien: congViec['MoTaThucHien']?.toString(),
                    khachHang: congViec['KhachHang']?.toString(),
                    khachHangDanhGia: congViec['KhachHangDanhGia'] != null
                        ? int.tryParse(congViec['KhachHangDanhGia'].toString())
                        : null,
                    thoiGianDanhGia: congViec['ThoiGianDanhGia']?.toString(),
                    khachHangMoTa: congViec['KhachHangMoTa']?.toString(),
                    khachHangChupAnh: congViec['KhachHangChupAnh']?.toString(),
                    trangThai: congViec['TrangThai']?.toString(),
                  );

                  // Insert into database
                  final result =
                      await _dbHelper.insertGoCleanCongViec(congViecModel);
                  // print("Inserted CongViec with ID ${congViecModel.lichLamViecID}, result: $result");
                  successCount++;
                } catch (e) {
                  print("Error processing CongViec record $i: $e");
                  if (e is Error) {
                    print("Stack trace: ${e.stackTrace}");
                  }
                }
              }

              setState(() {
                _syncedRecordsCount = successCount;
              });

              // Verify records were inserted
              final congViecCount = await _dbHelper.getGoCleanCongViecCount();
              print("GoClean_CongViec table now contains $congViecCount records");

              if (congViecCount != successCount) {
                print(
                    "WARNING: Expected $successCount records but found $congViecCount in the database");
              }
            } else {
              // Single object - convert to an array of one and process
              print(
                  "Received single object for CongViec, processing as a single record");

              try {
                // Parse the date string
                DateTime? ngayDate;
                if (congViecData['Ngay'] != null &&
                    congViecData['Ngay'].toString().isNotEmpty) {
                  try {
                    ngayDate = DateTime.parse(congViecData['Ngay'].toString());
                  } catch (e) {
                    print("Error parsing date ${congViecData['Ngay']}: $e");
                  }
                }

                // Create model object
                final congViecModel = GoCleanCongViecModel(
                  lichLamViecID: congViecData['LichLamViecID']?.toString(),
                  giaoViecID: congViecData['GiaoViecID']?.toString(),
                  ngay: ngayDate,
                  nguoiThucHien: congViecData['NguoiThucHien']?.toString(),
                  xacNhan: congViecData['XacNhan']?.toString(),
                  qrCode: congViecData['QRcode']?.toString(),
                  mocBatDau: congViecData['MocBatDau']?.toString(),
                  hinhAnhTruoc: congViecData['HinhAnhTruoc']?.toString(),
                  mocKetThuc: congViecData['MocKetThuc']?.toString(),
                  hinhAnhSau: congViecData['HinhAnhSau']?.toString(),
                  thucHienDanhGia: congViecData['ThucHienDanhGia'] != null
                      ? int.tryParse(congViecData['ThucHienDanhGia'].toString())
                      : null,
                  moTaThucHien: congViecData['MoTaThucHien']?.toString(),
                  khachHang: congViecData['KhachHang']?.toString(),
                  khachHangDanhGia: congViecData['KhachHangDanhGia'] != null
                      ? int.tryParse(congViecData['KhachHangDanhGia'].toString())
                      : null,
                  thoiGianDanhGia: congViecData['ThoiGianDanhGia']?.toString(),
                  khachHangMoTa: congViecData['KhachHangMoTa']?.toString(),
                  khachHangChupAnh: congViecData['KhachHangChupAnh']?.toString(),
                  trangThai: congViecData['TrangThai']?.toString(),
                );

                // Insert into database
                final result =
                    await _dbHelper.insertGoCleanCongViec(congViecModel);
                print(
                    "Inserted single CongViec with ID ${congViecModel.lichLamViecID}, result: $result");

                setState(() {
                  _syncedRecordsCount = 1;
                });

                // Verify the record was inserted
                final congViecCount = await _dbHelper.getGoCleanCongViecCount();
                print("GoClean_CongViec table now contains $congViecCount records");
              } catch (e) {
                print("Error processing single CongViec record: $e");
                if (e is Error) {
                  print("Stack trace: ${e.stackTrace}");
                }
              }
            }
          } else {
            print(
                "API returned error status for CongViec: ${congViecResponse.statusCode}");
            throw Exception(
                'Failed to load CongViec data: ${congViecResponse.statusCode}, Body: ${congViecResponse.body}');
          }
          break;

        case 2:
          // Third sync step - Get work requirements (YeuCau)
          final url = '$baseUrl/cleanyeucau/$usernameForSync';
          print("REQUEST URL (Step 3): $url");

          final yeuCauResponse = await http.get(Uri.parse(url));
          print("RESPONSE STATUS (Step 3): ${yeuCauResponse.statusCode}");
          print("RESPONSE BODY (Step 3): ${yeuCauResponse.body}");

          if (yeuCauResponse.statusCode == 200) {
            // Clear the existing YeuCau table
            await _dbHelper.clearGoCleanYeuCauTable();
            print("GoClean_YeuCau table cleared for new data");

            final yeuCauData = json.decode(yeuCauResponse.body);

            // If the API returns null or empty JSON, consider it a success with 0 records
            if (yeuCauData == null) {
              print("Received null data for YeuCau, treating as empty list");
              setState(() {
                _syncedRecordsCount = 0;
              });
              break;
            }

            // Check if it's a list and process accordingly
            if (yeuCauData is List) {
              print("Processing ${yeuCauData.length} YeuCau records");

              int successCount = 0;
              for (var i = 0; i < yeuCauData.length; i++) {
                var yeuCau = yeuCauData[i];
                try {
                  // Log the raw record for debugging
                  // print("Processing YeuCau record $i: ${json.encode(yeuCau)}");

                  // Parse the date strings
                  DateTime? ngayBatDau;
                  if (yeuCau['NgayBatDau'] != null &&
                      yeuCau['NgayBatDau'].toString().isNotEmpty) {
                    try {
                      ngayBatDau =
                          DateTime.parse(yeuCau['NgayBatDau'].toString());
                      // print("Successfully parsed start date: ${yeuCau['NgayBatDau']} to $ngayBatDau");
                    } catch (e) {
                      print("Error parsing start date ${yeuCau['NgayBatDau']}: $e");
                    }
                  }

                  DateTime? ngayKetThuc;
                  if (yeuCau['NgayKetThuc'] != null &&
                      yeuCau['NgayKetThuc'].toString().isNotEmpty) {
                    try {
                      ngayKetThuc =
                          DateTime.parse(yeuCau['NgayKetThuc'].toString());
                      // print("Successfully parsed end date: ${yeuCau['NgayKetThuc']} to $ngayKetThuc");
                    } catch (e) {
                      print("Error parsing end date ${yeuCau['NgayKetThuc']}: $e");
                    }
                  }

                  // Create model object
                  final yeuCauModel = GoCleanYeuCauModel(
                    giaoViecID: yeuCau['GiaoViecID']?.toString(),
                    nguoiTao: yeuCau['NguoiTao']?.toString(),
                    nguoiNghiemThu: yeuCau['NguoiNghiemThu']?.toString(),
                    diaDiem: yeuCau['DiaDiem']?.toString(),
                    diaChi: yeuCau['DiaChi']?.toString(),
                    dinhVi: yeuCau['DinhVi']?.toString(),
                    lapLai: yeuCau['LapLai']?.toString(),
                    ngayBatDau: ngayBatDau,
                    ngayKetThuc: ngayKetThuc,
                    hinhThucNghiemThu: yeuCau['HinhThucNghiemThu']?.toString(),
                    moTaCongViec: yeuCau['MoTaCongViec']?.toString(),
                    soNguoiThucHien: yeuCau['SoNguoiThucHien'] != null
                        ? int.tryParse(yeuCau['SoNguoiThucHien'].toString())
                        : null,
                    khuVucThucHien: yeuCau['KhuVucThucHien']?.toString(),
                    khoiLuongCongViec: yeuCau['KhoiLuongCongViec'] != null
                        ? int.tryParse(yeuCau['KhoiLuongCongViec'].toString())
                        : null,
                    yeuCauCongViec: yeuCau['YeuCauCongViec']?.toString(),
                    thoiGianBatDau: yeuCau['ThoiGianBatDau']?.toString(),
                    thoiGianKetThuc: yeuCau['ThoiGianKetThuc']?.toString(),
                    loaiMaySuDung: yeuCau['LoaiMaySuDung']?.toString(),
                    congCuSuDung: yeuCau['CongCuSuDung']?.toString(),
                    hoaChatSuDung: yeuCau['HoaChatSuDung']?.toString(),
                    ghiChu: yeuCau['GhiChu']?.toString(),
                    xacNhan: yeuCau['XacNhan']?.toString(),
                    chiDinh: yeuCau['ChiDinh']?.toString(),
                    huongDan: yeuCau['HuongDan']?.toString(),
                    nhomThucHien: yeuCau['NhomThucHien']?.toString(),
                    caNhanThucHien: yeuCau['CaNhanThucHien']?.toString(),
                    listNguoiThucHien: yeuCau['ListNguoiThucHien']?.toString(),
                  );

                  // Insert into database
                  final result = await _dbHelper.insertGoCleanYeuCau(yeuCauModel);
                  // print("Inserted YeuCau with ID ${yeuCauModel.giaoViecID}, result: $result");
                  successCount++;
                } catch (e) {
                  print("Error processing YeuCau record $i: $e");
                  if (e is Error) {
                    print("Stack trace: ${e.stackTrace}");
                  }
                }
              }

              setState(() {
                _syncedRecordsCount = successCount;
              });

              // Verify records were inserted
              final yeuCauCount = await _dbHelper.getGoCleanYeuCauCount();
              print("GoClean_YeuCau table now contains $yeuCauCount records");

              if (yeuCauCount != successCount) {
                print(
                    "WARNING: Expected $successCount records but found $yeuCauCount in the database");
              }
            } else {
              // Single object - convert to an array of one and process
              print(
                  "Received single object for YeuCau, processing as a single record");

              try {
                // Parse the date strings
                DateTime? ngayBatDau;
                if (yeuCauData['NgayBatDau'] != null &&
                    yeuCauData['NgayBatDau'].toString().isNotEmpty) {
                  try {
                    ngayBatDau =
                        DateTime.parse(yeuCauData['NgayBatDau'].toString());
                  } catch (e) {
                    print("Error parsing start date ${yeuCauData['NgayBatDau']}: $e");
                  }
                }

                DateTime? ngayKetThuc;
                if (yeuCauData['NgayKetThuc'] != null &&
                    yeuCauData['NgayKetThuc'].toString().isNotEmpty) {
                  try {
                    ngayKetThuc =
                        DateTime.parse(yeuCauData['NgayKetThuc'].toString());
                  } catch (e) {
                    print("Error parsing end date ${yeuCauData['NgayKetThuc']}: $e");
                  }
                }

                // Create model object
                final yeuCauModel = GoCleanYeuCauModel(
                  giaoViecID: yeuCauData['GiaoViecID']?.toString(),
                  nguoiTao: yeuCauData['NguoiTao']?.toString(),
                  nguoiNghiemThu: yeuCauData['NguoiNghiemThu']?.toString(),
                  diaDiem: yeuCauData['DiaDiem']?.toString(),
                  diaChi: yeuCauData['DiaChi']?.toString(),
                  dinhVi: yeuCauData['DinhVi']?.toString(),
                  lapLai: yeuCauData['LapLai']?.toString(),
                  ngayBatDau: ngayBatDau,
                  ngayKetThuc: ngayKetThuc,
                  hinhThucNghiemThu: yeuCauData['HinhThucNghiemThu']?.toString(),
                  moTaCongViec: yeuCauData['MoTaCongViec']?.toString(),
                  soNguoiThucHien: yeuCauData['SoNguoiThucHien'] != null
                      ? int.tryParse(yeuCauData['SoNguoiThucHien'].toString())
                      : null,
                  khuVucThucHien: yeuCauData['KhuVucThucHien']?.toString(),
                  khoiLuongCongViec: yeuCauData['KhoiLuongCongViec'] != null
                      ? int.tryParse(yeuCauData['KhoiLuongCongViec'].toString())
                      : null,
                  yeuCauCongViec: yeuCauData['YeuCauCongViec']?.toString(),
                  thoiGianBatDau: yeuCauData['ThoiGianBatDau']?.toString(),
                  thoiGianKetThuc: yeuCauData['ThoiGianKetThuc']?.toString(),
                  loaiMaySuDung: yeuCauData['LoaiMaySuDung']?.toString(),
                  congCuSuDung: yeuCauData['CongCuSuDung']?.toString(),
                  hoaChatSuDung: yeuCauData['HoaChatSuDung']?.toString(),
                  ghiChu: yeuCauData['GhiChu']?.toString(),
                  xacNhan: yeuCauData['XacNhan']?.toString(),
                  chiDinh: yeuCauData['ChiDinh']?.toString(),
                  huongDan: yeuCauData['HuongDan']?.toString(),
                  nhomThucHien: yeuCauData['NhomThucHien']?.toString(),
                  caNhanThucHien: yeuCauData['CaNhanThucHien']?.toString(),
                  listNguoiThucHien: yeuCauData['ListNguoiThucHien']?.toString(),
                );

                // Insert into database
                final result = await _dbHelper.insertGoCleanYeuCau(yeuCauModel);
                print(
                    "Inserted single YeuCau with ID ${yeuCauModel.giaoViecID}, result: $result");

                setState(() {
                  _syncedRecordsCount = 1;
                });

                // Verify the record was inserted
                final yeuCauCount = await _dbHelper.getGoCleanYeuCauCount();
                print("GoClean_YeuCau table now contains $yeuCauCount records");
              } catch (e) {
                print("Error processing single YeuCau record: $e");
                if (e is Error) {
                  print("Stack trace: ${e.stackTrace}");
                }
              }
            }
          } else {
            print(
                "API returned error status for YeuCau: ${yeuCauResponse.statusCode}");
            throw Exception(
                'Failed to load YeuCau data: ${yeuCauResponse.statusCode}, Body: ${yeuCauResponse.body}');
          }
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

  Widget _buildSyncOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
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
                'Đồng bộ dữ liệu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            // Progress tracker line - more compact
            Container(
              height: 3,
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Stack(
                children: [
                  // Background track
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Progress indicator
                  Row(
                    children: [
                      Flexible(
                        flex: _syncStepsCompleted[0]
                            ? 1
                            : (_currentSyncStep == 0 ? 1 : 0),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: _syncStepsCompleted[0] ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: _syncStepsCompleted[1]
                            ? 1
                            : (_currentSyncStep == 1 && _syncStepsCompleted[0] ? 1 : 0),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: _syncStepsCompleted[1] ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: _syncStepsCompleted[2]
                            ? 1
                            : (_currentSyncStep == 2 && _syncStepsCompleted[1] ? 1 : 0),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: _syncStepsCompleted[2] ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Tighter step indicators with Cupertino style
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCupertinoSyncStepIndicator(0, 'Xác thực'),
                _buildThinConnectingLine(_syncStepsCompleted[0]),
                _buildCupertinoSyncStepIndicator(1, 'Công việc'),
                _buildThinConnectingLine(_syncStepsCompleted[1]),
                _buildCupertinoSyncStepIndicator(2, 'Yêu cầu'),
              ],
            ),

            // Warning message - more compact Cupertino style
            if (_currentSyncStep == 0 && _syncFailed)
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0x33FF3B30), // Cupertino red with transparency
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
                        // Do nothing as per requirements
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
                      color: Color(0xFF34C759), // Cupertino green
                      borderRadius: BorderRadius.circular(18),
                      onPressed: () {
                        // Navigate based on user role
                        final normalizedRole = _userRole.toLowerCase();

                        if (normalizedRole.contains('admin')) {
                          Navigator.pushReplacement( // Use pushReplacement to avoid stacking
                            context,
                            MaterialPageRoute(builder: (context) => AdminDashboard()),
                          );
                        } else if (normalizedRole.contains('nghiem thu') ||
                            normalizedRole.contains('nghiệm thu') ||
                            normalizedRole.contains('nghiệm')) {
                           Navigator.pushReplacement( // Use pushReplacement
                            context,
                            MaterialPageRoute(builder: (context) => CustomerDashboard()),
                          );
                        } else if (normalizedRole.contains('ky thuat') ||
                            normalizedRole.contains('kỹ thuật') ||
                            normalizedRole.contains('thuật')) {
                           Navigator.pushReplacement( // Use pushReplacement
                            context,
                            MaterialPageRoute(builder: (context) => WorkerDashboard()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Không xác định được vai trò người dùng"),
                              backgroundColor: Colors.orange,
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
                  // New "Đồng bộ lại" button
                  Container(
                    margin: EdgeInsets.only(top: 8, bottom: 8),
                    width: double.infinity,
                    height: 36,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: Color(0xFF007AFF), // Cupertino blue
                      borderRadius: BorderRadius.circular(18),
                      onPressed: _startSyncProcess, // Call sync process again
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
            else if (_syncFailed && !_isSyncing) // Only show Retry if failed and not currently syncing
                 Container(
                    margin: EdgeInsets.only(top: 16, bottom: 8),
                    width: double.infinity,
                    height: 36,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: Color(0xFF007AFF), // Cupertino blue
                      borderRadius: BorderRadius.circular(18),
                      onPressed: _startSyncProcess, // Call sync process again
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
    );
  }

  Widget _buildThinConnectingLine(bool completed) {
    return Container(
      width: 20,
      height: 1.5,
      color: completed ? Color(0xFF34C759) : Colors.grey.withOpacity(0.3),
    );
  }

  Widget _buildCupertinoSyncStepIndicator(int step, String label) {
    final bool isActive = _currentSyncStep == step && _isSyncing && !_syncFailed;
    final bool isCompleted = _syncStepsCompleted[step];
    final bool hasFailed = _syncFailed && _currentSyncStep == step;

    final Color activeColor = isCompleted
        ? Color(0xFF34C759) // Cupertino green
        : (hasFailed ? Colors.red : (isActive ? Color(0xFF007AFF) : Colors.grey.withOpacity(0.5))); // Cupertino blue or red

    final Widget indicatorWidget = isCompleted
        ? Icon(
            Icons.check_rounded,
            color: Color(0xFF34C759),
            size: 28,
          )
        : (hasFailed
            ? Icon(
                Icons.close_rounded,
                color: Colors.red,
                size: 28,
              )
            : (isActive
                ? SpinKitRing(
                    color: Color(0xFF007AFF),
                    lineWidth: 2,
                    size: 30,
                  )
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  )));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(
              color: activeColor,
              width: 2,
            ),
          ),
          child: Center(child: indicatorWidget),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: activeColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ))),
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
          if (!_isSyncing && !_syncFailed)
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
          if (_isSyncing || _syncFailed || _syncStepsCompleted.every((step) => step == true)) // Show overlay if syncing, failed, or completed
            _buildSyncOverlay(),
        ],
      ),
    );
  }
}
