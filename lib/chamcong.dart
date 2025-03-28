import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'user_credentials.dart';
import 'location_provider.dart';
import 'user_state.dart';
import 'table_models.dart';
import 'db_helper.dart';
import 'chamcong2.dart';
import 'package:confetti/confetti.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:video_player/video_player.dart';
import 'http_client.dart';

class ChamCongScreen extends StatefulWidget {
  const ChamCongScreen({Key? key}) : super(key: key);

  @override
  _ChamCongScreenState createState() => _ChamCongScreenState();
}

class _ChamCongScreenState extends State<ChamCongScreen> {
  bool _isInitialLoad = true;
  bool _locationsLoaded = false;
DateTime? _lastCheckInsLoadDate;
  bool _isLoading = false;
  String _message = '';
  String _username = '';
  List<ChamCongModel> _danhSachChamCong = [];
  ChamCongModel? _selectedLocation;
  double? _distanceToLocation;
  bool _isInRange = false;
  List<ChamCongLSModel> _previousCheckIns = [];
bool _loadingPreviousCheckIns = false;
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
bool _isBatThuongMode = false;
 String _userRole = '';
  bool _loadingUserRole = false;
  String _approverUsername = '';
  Map<String, String> _roleToApproverMap = {
    'HM-RD': 'hm.tason',
    'HM-CSKH': 'hm.tranminh',
    'HM-HS': 'hm.luukinh',
    'HM-KS': 'hm.trangiang',
    'HM-DV': 'hm.hahuong',
    'HM-KH': 'hm.phamthuy',
    'HM-DVV': 'hm.daotan',
    'HM-DL': 'hm.daotan',
    'HM-QA': 'hm.vuquyen',
    'HM-HCM2': 'hm.damlinh',
    'HM-TEST': 'BPthunghiem',
    'HM-KY': 'hm.duongloan',
    'HM-NS': 'hm.nguyengiang',
    'HM-KT': 'hm.luukinh',
    'HM-DA': 'hm.lehang',
    'HM-SX': 'hm.anhmanh',
    'HM-DN2': 'hm.nguyenhien',
    'HM-DN': 'hm.doannga',
    'HM-LX': 'hm.daotan',
    'HM-HSDN': 'hm.trangiang',
    'HM-HSNT': 'hm.trangiang',
    'DV-Loi': 'hm.phamloi',
    'DV-NHuyen': 'hm.nguyenhuyen',
    'DV-HThanh': 'hm.hanthanh',
    'DV-Hanh': 'hm.nguyenhanh',
    'DV-Hung': 'hm.nguyenhung',
    'DV-BHuyen': 'hm.buihuyen',
    'DV-Huong': 'hm.hahuong',
    'DV-NThanh': 'hm.ngothanh',
    'HM-HCM': 'hm.damlinh',
    'HM-TT': 'hm.vuquyen',
    'HM-TD': 'hm.tranhanh',
    'HM-MKT': 'hm.daotan',
    'HM-LC': 'hm.lethihoa',
    'DV-HaiAnh': 'hm.haianh',
  };
  List<String> _availableMonths = [];
  String? _selectedMonth;
  List<ChamCongLSModel> _filteredCheckIns = [];
    late ConfettiController _confettiController;

@override
void initState() {
  super.initState();
  _videoController = VideoPlayerController.asset('assets/appvideorobot.mp4')
    ..setVolume(0.0)
    ..initialize().then((_) {
      setState(() {
        _videoInitialized = true;
      });
      _videoController.play();
      _videoController.setLooping(true);
    });
  _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  
  // Use a post-frame callback to ensure context is available
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadUserInfo();
  });
}

@override
  void dispose() {
    _videoController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
Future<void> _loadFullData() async {
  if (_username.isEmpty) {
    setState(() {
      _message = 'Lỗi: Không tìm thấy thông tin người dùng';
    });
    return;
  }

  try {
    if (!_locationsLoaded) {
      await _loadCheckInLocations();
      _locationsLoaded = true;
    }
    await _findNearestCheckInLocation(checkForAuto: true);
  } catch (e) {
    setState(() {
      _message = 'Lỗi tải dữ liệu: $e';
    });
  }
}

Future<void> _loadUserInfo() async {
  try {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username;
    
    if (username.isNotEmpty) {
      setState(() {
        _username = username;
      });
      
      await _loadUserRole();
      
      if (!_locationsLoaded) {
        await _loadCheckInLocations();
        _locationsLoaded = true;
      }
      
      await _findNearestCheckInLocation(checkForAuto: true);
      
      if (_isInitialLoad) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if ((_lastCheckInsLoadDate == null || 
            _lastCheckInsLoadDate!.year != today.year || 
            _lastCheckInsLoadDate!.month != today.month || 
            _lastCheckInsLoadDate!.day != today.day) &&
            Random().nextDouble() < 0.55) {
          await _loadPreviousCheckIns();
          _lastCheckInsLoadDate = today;
        }
        _isInitialLoad = false;
      } else {
        await _loadPreviousCheckIns();
      }
    } else {
      setState(() {
        _message = 'Lỗi: Không tìm thấy thông tin người dùng';
      });
    }
  } catch (e) {
    print('Error loading user info: $e');
    setState(() {
      _message = 'Lỗi tải dữ liệu: $e';
    });
  }
}
Future<void> _loadUserRole() async {
    if (_username.isEmpty) return;
    
    setState(() {
      _loadingUserRole = true;
    });
    
    try {
      // First try to get from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('saved_username') ?? '';
      final savedRole = prefs.getString('user_role') ?? '';
      
      // If we have saved role for this user, use it
      if (savedUsername == _username && savedRole.isNotEmpty) {
        setState(() {
          _userRole = savedRole;
          _approverUsername = _roleToApproverMap[_userRole] ?? '';
          _loadingUserRole = false;
        });
        print('Loaded user role from cache: $_userRole, approver: $_approverUsername');
        return;
      }
      
      // Otherwise fetch from server
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/myrole/$_username');
      final response = await AuthenticatedHttpClient.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _userRole = data['Role'] ?? '';
        
        // Get approver based on role
        _approverUsername = _roleToApproverMap[_userRole] ?? '';
        
        // Save to shared preferences for future use
        await prefs.setString('saved_username', _username);
        await prefs.setString('user_role', _userRole);
        
        print('Fetched user role from server: $_userRole, approver: $_approverUsername');
      }
    } catch (e) {
      print('Error loading user role: $e');
    } finally {
      setState(() {
        _loadingUserRole = false;
      });
    }
  }

Future<void> _loadPreviousCheckIns() async {
    if (_username.isEmpty) return;
    
    setState(() {
      _loadingPreviousCheckIns = true;
    });
    
    try {
      // Load the user's own check-ins
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongls/${_username}');
      final response = await AuthenticatedHttpClient.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        _previousCheckIns = data.map((item) => ChamCongLSModel.fromMap(item)).toList();
        
        // Sort by date, most recent first
        _previousCheckIns.sort((a, b) {
          if (a.ngay == null || b.ngay == null) return 0;
          return b.ngay!.compareTo(a.ngay!);
        });
        
        // Process available months
        _generateAvailableMonths();
        
        // Apply initial filtering
        _filterCheckInsByMonth();
        
        // Try to sync team check-ins if the current user is a team leader
        await _syncTeamCheckInsIfNeeded();
        
        setState(() {
          _loadingPreviousCheckIns = false;
        });
      } else {
        setState(() {
          _loadingPreviousCheckIns = false;
        });
        print('Failed to load previous check-ins: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _loadingPreviousCheckIns = false;
      });
      print('Error loading previous check-ins: $e');
    }
  }

  Future<void> _syncTeamCheckInsIfNeeded() async {
    // Define which users should trigger the sync and for which user type
    Map<String, String> specialUserSyncMap = {
    'HM-RD': 'hm.tason',
    'HM-CSKH': 'hm.tranminh',
    'HM-HS': 'hm.luukinh',
    'HM-KS': 'hm.trangiang',
    'HM-DV': 'hm.hahuong',
    'HM-KH': 'hm.phamthuy',
    'HM-DVV': 'hm.daotan',
    'HM-DL': 'hm.daotan',
    'HM-QA': 'hm.vuquyen',
    'HM-HCM2': 'hm.damlinh',
    'HM-TEST': 'BPthunghiem',
    'HM-KY': 'hm.duongloan',
    'HM-NS': 'hm.nguyengiang',
    'HM-KT': 'hm.luukinh',
    'HM-DA': 'hm.lehang',
    'HM-SX': 'hm.anhmanh',
    'HM-DN2': 'hm.nguyenhien',
    'HM-DN': 'hm.doannga',
    'HM-LX': 'hm.daotan',
    'HM-HSDN': 'hm.trangiang',
    'HM-HSNT': 'hm.trangiang',
    'DV-Loi': 'hm.phamloi',
    'DV-NHuyen': 'hm.nguyenhuyen',
    'DV-HThanh': 'hm.hanthanh',
    'DV-Hanh': 'hm.nguyenhanh',
    'DV-Hung': 'hm.nguyenhung',
    'DV-BHuyen': 'hm.buihuyen',
    'DV-Huong': 'hm.hahuong',
    'DV-NThanh': 'hm.ngothanh',
    'HM-HCM': 'hm.damlinh',
    'HM-TT': 'hm.vuquyen',
    'HM-TD': 'hm.tranhanh',
    'HM-MKT': 'hm.daotan',
    'HM-LC': 'hm.lethihoa',
    'DV-HaiAnh': 'hm.haianh',
    };
    
     // Check if current user is one of the special users
  String? teamToSync = specialUserSyncMap[_username];
  
  if (teamToSync != null) {
    try {
      print('Starting team check-ins sync for team: $teamToSync');
      
      // Get the first day of current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final formattedFirstDay = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
      
      // Get team check-ins and write them to the same table as individual check-ins
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconglsnhomwrite/$teamToSync/$formattedFirstDay');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'teamCode': teamToSync,
          'requestor': _username,
          'syncTimestamp': DateTime.now().toIso8601String(),
          'writeToTable': 'ChamCongLS', // Explicitly specify the table to write to
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int recordsProcessed = data['recordsProcessed'] ?? 0;
        int recordsAdded = data['recordsAdded'] ?? 0;
        int recordsUpdated = data['recordsUpdated'] ?? 0;
        
        print('Team check-ins sync completed successfully for team: $teamToSync');
        print('Processed: $recordsProcessed, Added: $recordsAdded, Updated: $recordsUpdated');
        
        // Refresh the local data if any records were added or updated
        if (recordsAdded > 0 || recordsUpdated > 0) {
          await _loadPreviousCheckIns();
        }
      } else {
        print('Team check-ins sync failed for team: $teamToSync - Status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      // Just log the error, don't disrupt the user's experience
      print('Error syncing team check-ins for team: $teamToSync - $e');
    }
  }
}
  void _generateAvailableMonths() {
    Set<String> months = {};
    
    for (var checkIn in _previousCheckIns) {
      if (checkIn.ngay != null) {
        String monthYear = DateFormat('MM/yyyy').format(checkIn.ngay!);
        months.add(monthYear);
      }
    }
    
    _availableMonths = months.toList();
    _availableMonths.sort((a, b) => b.compareTo(a)); // Most recent first
    
    // Set initial selection to current month or most recent
    String currentMonth = DateFormat('MM/yyyy').format(DateTime.now());
    _selectedMonth = _availableMonths.contains(currentMonth) ? currentMonth : 
                   (_availableMonths.isNotEmpty ? _availableMonths.first : null);
  }

  // Filter check-ins by selected month
  void _filterCheckInsByMonth() {
    if (_selectedMonth == null) {
      _filteredCheckIns = List.from(_previousCheckIns);
      return;
    }
    
    List<String> monthParts = _selectedMonth!.split('/');
    int month = int.parse(monthParts[0]);
    int year = int.parse(monthParts[1]);
    
    _filteredCheckIns = _previousCheckIns.where((checkIn) {
  if (checkIn.ngay == null) return false;
  return checkIn.ngay!.month == month && 
         checkIn.ngay!.year == year &&
         checkIn.nguoiDung == _username;
}).toList();
  }
void _viewAllCheckIns() {
  // Navigate to a detailed history view
  // You can implement this in the future
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Lịch sử chấm công'),
      content: const Text('Chức năng xem tất cả lịch sử chấm công sẽ được thêm trong phiên bản sau.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

// Helper method to format a date
String _formatDate(DateTime? date) {
  if (date == null) return 'N/A';
  return DateFormat('dd/MM/yyyy').format(date);
}
Future<void> _loadCheckInLocations() async {
  try {
    // Get from local database first
    final dbHelper = DBHelper();
    _danhSachChamCong = await dbHelper.getChamCongByNguoiDung(_username);
    
    // If local data is empty, fetch from server
    if (_danhSachChamCong.isEmpty) {
      await _fetchCheckInLocationsFromServer();
      // Save fetched locations to database
      await dbHelper.batchInsertChamCong(_danhSachChamCong);
    }
  } catch (e) {
    // If local database access fails, fetch from server
    await _fetchCheckInLocationsFromServer();
  }
}

  Future<void> _fetchCheckInLocationsFromServer() async {
  final chamCongUrl = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcong/$_username');
  print('Fetching check-in locations for user: "$_username"');
  print('API URL: $chamCongUrl');
  
  try {
    final response = await AuthenticatedHttpClient.get(chamCongUrl);
    
    print('API response status code: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('API error response: ${response.body}');
      throw Exception('Failed to load check-in locations: ${response.statusCode}');
    }
    
    final data = json.decode(response.body) as List;
    print('Received ${data.length} locations from API');
    
    if (data.isEmpty) {
      print('WARNING: No locations returned for this user');
    } else {
      print('First location: ${data[0]['TenGoi'] ?? 'Unknown'}, PhanLoai: ${data[0]['PhanLoai'] ?? 'Unknown'}');
    }
    
    _danhSachChamCong = data.map((item) => ChamCongModel.fromMap(item)).toList();
    
    // Log all retrieved locations
    for (var i = 0; i < _danhSachChamCong.length; i++) {
      print('Location $i: ${_danhSachChamCong[i].tenGoi}, PhanLoai: ${_danhSachChamCong[i].phanLoai}, DinhVi: ${_danhSachChamCong[i].dinhVi}');
    }
  } catch (e) {
    print('Exception in _fetchCheckInLocationsFromServer: $e');
    throw e;
  }
}

  Future<void> _findNearestCheckInLocation({bool checkForAuto = false}) async {
  final locationProvider = Provider.of<LocationProvider>(context, listen: false);
  
  setState(() {
    if (_selectedLocation == null) {
      // Only show loading indicator for initial load, not refreshes
      _isLoading = true;
      _message = 'Đang xác định vị trí...';
    }
  });
  
  // Request location update
  await locationProvider.fetchLocation();
  
  // Get current location
  final currentLocation = locationProvider.locationData;
  
  if (currentLocation != null && currentLocation.latitude != null && currentLocation.longitude != null) {
    double nearestDistance = double.infinity;
    ChamCongModel? nearestLocation;
    
    for (var location in _danhSachChamCong) {
      // Parse DinhVi field which contains "latitude,longitude"
      if (location.dinhVi != null && location.dinhVi!.contains(',')) {
        List<String> coordinates = location.dinhVi!.split(',');
        if (coordinates.length == 2) {
          try {
            double locationLat = double.parse(coordinates[0]);
            double locationLng = double.parse(coordinates[1]);
            
            // Calculate distance
            double distance = Geolocator.distanceBetween(
              currentLocation.latitude!,
              currentLocation.longitude!,
              locationLat,
              locationLng,
            );
            
            // Update nearest location if this one is closer
            if (distance < nearestDistance) {
              nearestDistance = distance;
              nearestLocation = location;
            }
          } catch (e) {
            // Skip this location if coordinates are invalid
            print('Invalid coordinates for location: ${location.tenGoi}');
          }
        }
      }
    }
    
    bool wasInRange = _isInRange;
    setState(() {
      _selectedLocation = nearestLocation;
      _distanceToLocation = nearestDistance;
      _isInRange = nearestDistance <= 555;
      _isLoading = false;
      _message = '';
      
      if (_selectedLocation == null) {
        _message = 'Không tìm thấy điểm chấm công nào';
      } else if (!_isInRange) {
        // Just a notification that they're outside range but can still check in
        _message = 'Ngoài phạm vi chấm công (${_distanceToLocation?.toInt() ?? 0}m)';
      }
    });
    
    // Log the selected location
    print('Found nearest location: ${_selectedLocation?.tenGoi}, distance: $_distanceToLocation meters, in range: $_isInRange');
    
    // Check for auto check-in if we've come into range and it's requested
    if (checkForAuto && _isInRange && !wasInRange) {
      _checkForAutoCheckIn();
    }
  } else {
    setState(() {
      _isLoading = false;
      _message = 'Không thể xác định vị trí hiện tại';
    });
  }
}
Future<void> _checkForAutoCheckIn() async {
  if (!_isInRange || _selectedLocation == null) return;
  
  // Check if this is a "Chấm 24G" location - if so, skip auto check-in
  if (_selectedLocation!.phanLoai == 'Chấm 24G') {
    print('Skipping auto check-in for Chấm 24G location');
    return; // Exit the function early
  }
  
  // Get current date to check existing check-ins
  final now = DateTime.now();
  final formattedDate = DateFormat('yyyy-MM-dd').format(now);
  
  try {
    // Check if we already have a record for today
    final checkExistingUrl = Uri.parse(
      'https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongls/$_username/$formattedDate'
    );
    final existingResponse = await AuthenticatedHttpClient.get(checkExistingUrl);
    
    if (existingResponse.statusCode == 200) {
      final data = json.decode(existingResponse.body);
      if (data.isNotEmpty) {
        Map<String, dynamic> existingRecord = data[0];
        
        // Get day of week to determine work schedule type
        String dayType;
        int weekday = now.weekday; // 1 = Monday, 7 = Sunday
        if (weekday >= 1 && weekday <= 5) {
          dayType = 'T2T6'; // Monday to Friday
        } else if (weekday == 6) {
          dayType = 'T7';   // Saturday
        } else {
          dayType = 'CN';   // Sunday
        }
        
        // Get work hours from ChamCongGio for the day type
        final workHoursUrl = Uri.parse(
          'https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggio/$_username/$dayType'
        );
        final workHoursResponse = await AuthenticatedHttpClient.get(workHoursUrl);
        
        double maxCong = 0;
        
        if (workHoursResponse.statusCode == 200) {
          final workHoursData = json.decode(workHoursResponse.body);
          if (workHoursData.isNotEmpty) {
            maxCong = double.parse((workHoursData[0]['SoCong'] ?? 0).toString());
          }
        }
        
        // Current total work value
        double currentCong = double.parse((existingRecord['TongCongNgay'] ?? 0).toString());
        
        // Determine what we need to check in
        bool needBatDau = existingRecord['BatDau'] == null || existingRecord['BatDau'].toString().isEmpty;
        bool needKetThuc = existingRecord['KetThuc'] == null || existingRecord['KetThuc'].toString().isEmpty;
        
        // Only auto check-in if we're below max công and need either BatDau or KetThuc
        if (currentCong < maxCong && (needBatDau || needKetThuc)) {
          String checkInType = needBatDau ? 'BatDau' : 'KetThuc';
          
          // Show notification about auto check-in
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bạn đang trong phạm vi chấm công. Đang tự động chấm công "$checkInType"...'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.blue,
            ),
          );
          
          // Submit the check-in automatically
          await _submitCheckIn(checkInType, autoCheckIn: true);
        }
      } else {
        // No existing record, check in BatDau automatically
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn đang trong phạm vi chấm công. Đang tự động chấm công "Giờ vào"...'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.blue,
          ),
        );
        
        await _submitCheckIn('BatDau', autoCheckIn: true);
      }
    }
  } catch (e) {
    print('Error in auto check-in: $e');
  }
}
 Future<void> _submitCheckIn(String checkInType, {bool autoCheckIn = false}) async {
  print('==== SUBMIT CHECK-IN STARTED ====');
  print('Check-in type: $checkInType, Auto check-in: $autoCheckIn');
  print('Chấm bất thường mode: $_isBatThuongMode');
  print('User role: $_userRole, Approver: $_approverUsername');

  if (_approverUsername.isEmpty) {
    for (var entry in _roleToApproverMap.entries) {
      if (entry.value == _username) {
        _approverUsername = _username;
        break;
      }
    }
    
    if (_approverUsername.isEmpty) {
      _approverUsername = 'hm.tason';
    }
    
    print('Setting approver to: $_approverUsername');
  }

  if (_selectedLocation == null) {
    await _findNearestCheckInLocation();
    
    if (_selectedLocation == null) {
      setState(() {
        _message = 'Không thể chấm công: Không tìm thấy điểm chấm công';
      });
      return;
    }
  }

  bool requirePhoto = !autoCheckIn && Random().nextDouble() < 0.4;
  File? photoFile;
  
  if (requirePhoto) {
    try {
      photoFile = await _capturePhoto();
      if (photoFile == null) {
        setState(() {
          _message = 'Bắt buộc chụp ảnh để xác minh';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _message = 'Lỗi khi chụp ảnh: $e';
      });
      return;
    }
  }

  setState(() {
    _isLoading = true;
    _message = 'Đang xử lý chấm công...';
  });

  try {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.locationData;
    final currentAddress = locationProvider.address;
    
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final formattedTime = DateFormat('HH:mm:ss').format(now);
    
    bool is24HourShift = _selectedLocation!.phanLoai == 'Chấm 24G';
    
    String dayType;
    int weekday = now.weekday;
    if (weekday >= 1 && weekday <= 5) {
      dayType = 'T2T6';
    } else if (weekday == 6) {
      dayType = 'T7';
    } else {
      dayType = 'CN';
    }
    
    List<Map<String, dynamic>> existingRecords = [];
    Map<String, dynamic> existingRecord = {};
    String uid = '';
    bool isUpdate = false;
    
    if (checkInType != 'KetThuc' || !is24HourShift) {
      final checkExistingUrl = Uri.parse(
        'https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongls/$_username/$formattedDate'
      );
      
      final existingResponse = await AuthenticatedHttpClient.get(checkExistingUrl);
      
      if (existingResponse.statusCode == 200) {
        final data = json.decode(existingResponse.body);
        
        if (data.isNotEmpty) {
          existingRecords = List<Map<String, dynamic>>.from(data);
          
          if (is24HourShift) {
            existingRecords = existingRecords.where((record) => 
              record['PhanLoaiBatDau'] == 'Chấm 24G').toList();
          } else {
            existingRecords = existingRecords.where((record) => 
              record['PhanLoaiBatDau'] == 'Công thường').toList();
          }
          
          if (existingRecords.isNotEmpty) {
            existingRecord = existingRecords.first;
            
            uid = existingRecord['UID'] ?? '';
            
            isUpdate = uid.isNotEmpty;
          }
        }
      }
    } else if (checkInType == 'KetThuc' && is24HourShift) {
      bool foundValidRecord = false;
      
      final checkTodayUrl = Uri.parse(
        'https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongls/$_username/$formattedDate'
      );
      final todayResponse = await AuthenticatedHttpClient.get(checkTodayUrl);
      
      if (todayResponse.statusCode == 200) {
        final todayData = json.decode(todayResponse.body);
        
        List<Map<String, dynamic>> todayRecords = List<Map<String, dynamic>>.from(todayData)
          .where((record) => 
            record['PhanLoaiBatDau'] == 'Chấm 24G' && 
            (record['KetThuc'] == null || record['KetThuc'].toString().isEmpty))
          .toList();
        
        if (todayRecords.isNotEmpty) {
          existingRecord = todayRecords.first;
          uid = existingRecord['UID'] ?? '';
          isUpdate = uid.isNotEmpty;
          foundValidRecord = true;
        }
      }
      
      if (!foundValidRecord) {
        final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        final formattedYesterday = DateFormat('yyyy-MM-dd').format(yesterday);
        
        final checkYesterdayUrl = Uri.parse(
          'https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongls/$_username/$formattedYesterday'
        );
        final yesterdayResponse = await AuthenticatedHttpClient.get(checkYesterdayUrl);
        
        if (yesterdayResponse.statusCode == 200) {
          final yesterdayData = json.decode(yesterdayResponse.body);
          
          List<Map<String, dynamic>> yesterdayRecords = List<Map<String, dynamic>>.from(yesterdayData)
            .where((record) => 
              record['PhanLoaiBatDau'] == 'Chấm 24G' && 
              (record['KetThuc'] == null || record['KetThuc'].toString().isEmpty))
            .toList();
          
          if (yesterdayRecords.isNotEmpty) {
            existingRecord = yesterdayRecords.first;
            uid = existingRecord['UID'] ?? '';
            isUpdate = uid.isNotEmpty;
            foundValidRecord = true;
          }
        }
      }
      
      if (!foundValidRecord) {
        setState(() {
          _isLoading = false;
          _message = 'Không tìm thấy ca làm 24G nào để chấm giờ ra';
        });
        return;
      }
    }
    
    if (uid.isEmpty) {
      uid = '${_username}_${now.millisecondsSinceEpoch}';
      isUpdate = false;
    }
    
    final workHoursUrl = Uri.parse(
      'https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconggio/$_username/$dayType'
    );
    final workHoursResponse = await AuthenticatedHttpClient.get(workHoursUrl);
    
    DateTime? gioBatDau;
    DateTime? gioKetThuc;
    int soPhut = 0;
    double soCong = 0.0;
    
    if (workHoursResponse.statusCode == 200) {
      final workHoursData = json.decode(workHoursResponse.body);
      if (workHoursData.isNotEmpty) {
        String? startTime = workHoursData[0]['GioBatDau'];
        String? endTime = workHoursData[0]['GioKetThuc'];
        soPhut = workHoursData[0]['SoPhut'] ?? 0;
        
        if (is24HourShift) {
          var hourData24G = workHoursData.firstWhere(
            (data) => data['PhanLoai'] == 'Chấm 24G',
            orElse: () => workHoursData[0]
          );
          
          soPhut = hourData24G['SoPhut'] ?? soPhut;
          soCong = parseDouble(hourData24G['SoCong'], 1.0);
        } else {
          soCong = parseDouble(workHoursData[0]['SoCong']);
        }
        
        if (startTime != null && startTime.isNotEmpty) {
          List<String> startParts = startTime.split(':');
          if (startParts.length >= 2) {
            gioBatDau = DateTime(
              now.year, now.month, now.day, 
              int.parse(startParts[0]), int.parse(startParts[1])
            );
          }
        }
        
        if (endTime != null && endTime.isNotEmpty) {
          List<String> endParts = endTime.split(':');
          if (endParts.length >= 2) {
            gioKetThuc = DateTime(
              now.year, now.month, now.day, 
              int.parse(endParts[0]), int.parse(endParts[1])
            );
            
            if (is24HourShift) {
              if (gioKetThuc != null && gioBatDau != null) {
                if (gioKetThuc.hour < gioBatDau.hour || 
                    (gioKetThuc.hour == gioBatDau.hour && gioKetThuc.minute < gioBatDau.minute)) {
                  gioKetThuc = gioKetThuc.add(const Duration(days: 1));
                }
              } else if (gioKetThuc != null && gioKetThuc.hour < 12) {
                gioKetThuc = gioKetThuc.add(const Duration(days: 1));
              }
            }
          }
        }
      }
    }
    
    int diMuonBatDau = 0;
    int diMuonKetThuc = 0;
    double tongCongNgay = 0.0;
    
    Map<String, dynamic> checkInData = {
      'UID': uid,
      'NguoiDung': _username,
      'Ngay': formattedDate,
    };
    
    if (checkInType == 'BatDau') {
      DateTime batDau = now;
      
      if (isUpdate && existingRecord['BatDau'] != null && existingRecord['BatDau'].isNotEmpty) {
        DateTime existingBatDau = _parseDateTime(existingRecord['Ngay'] ?? formattedDate, existingRecord['BatDau']);
        if (existingBatDau.isBefore(now)) {
          batDau = existingBatDau;
        }
      }
      
      String batDauFormatted = DateFormat('HH:mm:ss').format(batDau);
      
      bool isSpecialShift = _isBatThuongMode || _selectedLocation!.phanLoai == 'Chấm 24G' || _selectedLocation!.phanLoai == 'Chấm bất thường';
      
      if (gioBatDau != null && batDau.isAfter(gioBatDau) && !isSpecialShift) {
        diMuonBatDau = batDau.difference(gioBatDau).inMinutes;
      } else {
        diMuonBatDau = 0;
      }
      
      String hopLe = _isInRange ? 'Hợp lệ' : 'Sai vị trí';
      String trangThai = _isInRange ? 'OK' : 'NOK';
        if (_isBatThuongMode) {
          trangThai = 'Chưa xem';
        }
      
      String phanLoai = _isBatThuongMode ? 'Chấm bất thường' : (_selectedLocation!.phanLoai ?? '');
      
      checkInData.addAll({
        'BatDau': batDauFormatted,
        'PhanLoaiBatDau': phanLoai,
        'DiemChamBatDau': _selectedLocation!.tenGoi ?? '',
        'DinhViBatDau': '${currentLocation?.latitude},${currentLocation?.longitude}',
        'KhoangCachBatDau': _distanceToLocation?.toInt() ?? 0,
        'HopLeBatDau': hopLe,
        'TrangThaiBatDau': trangThai,
        'NguoiDuyetBatDau': _approverUsername,
        'GioLamBatDau': gioBatDau != null ? DateFormat('HH:mm:ss').format(gioBatDau) : '',
        'DiMuonBatDau': diMuonBatDau,
      });
      
      if (isUpdate && existingRecord['KetThuc'] != null && existingRecord['KetThuc'].isNotEmpty) {
        DateTime ketThuc = _parseDateTime(existingRecord['Ngay'] ?? formattedDate, existingRecord['KetThuc']);
        
        if (is24HourShift && ketThuc.isBefore(batDau)) {
          ketThuc = ketThuc.add(const Duration(days: 1));
        }
        
        int totalMinutes;
        
        if (is24HourShift || phanLoai == 'Chấm bất thường') {
          totalMinutes = ketThuc.difference(batDau).inMinutes;
        } else {
          DateTime effectiveBatDau = batDau;
          DateTime effectiveKetThuc = ketThuc;
          
          if (gioBatDau != null && batDau.isBefore(gioBatDau)) {
            effectiveBatDau = gioBatDau;
          }
          
          if (gioKetThuc != null && ketThuc.isAfter(gioKetThuc)) {
            effectiveKetThuc = gioKetThuc;
          }
          
          totalMinutes = effectiveKetThuc.difference(effectiveBatDau).inMinutes;
        }
        
        if (soPhut > 0) {
          double percentComplete = totalMinutes / soPhut;
          tongCongNgay = percentComplete * soCong;
          
          tongCongNgay = tongCongNgay.clamp(0.5, soCong);
        }
        
        int existingDiMuonKetThuc = safeParseInt(existingRecord['DiMuonKetThuc']);
        String phanLoaiBatDau = _isBatThuongMode ? 'Chấm bất thường' : (_selectedLocation!.phanLoai ?? '');
        String phanLoaiKetThuc = existingRecord['PhanLoaiKetThuc'] ?? '';
        bool isSpecialMode = phanLoaiBatDau == 'Chấm bất thường' || phanLoaiKetThuc == 'Chấm bất thường';
        
        if (!isSpecialMode) {
          bool invalidBatDau = !_isInRange;
          bool invalidKetThuc = existingRecord['HopLeKetThuc'] != 'Hợp lệ';
          
          if (invalidBatDau && invalidKetThuc) {
            tongCongNgay = max(0, tongCongNgay - 1.0);
          } else if (invalidBatDau || invalidKetThuc) {
            tongCongNgay = max(0, tongCongNgay - 0.5);
          }
        }
        checkInData.addAll({
          'DiMuonKetThuc': existingDiMuonKetThuc,
          'TongDiMuonNgay': diMuonBatDau + existingDiMuonKetThuc,
          'TongCongNgay': tongCongNgay,
          'NguoiDuyetKetThuc': existingRecord['NguoiDuyetKetThuc'] ?? _approverUsername,
        });
      } else {
        checkInData['NguoiDuyetKetThuc'] = '';
      }
    } else {
      DateTime ketThuc = now;
      
      if (isUpdate && existingRecord['KetThuc'] != null && existingRecord['KetThuc'].isNotEmpty) {
        DateTime existingKetThuc = _parseDateTime(existingRecord['Ngay'] ?? formattedDate, existingRecord['KetThuc']);
        if (existingKetThuc.isAfter(now)) {
          ketThuc = existingKetThuc;
        }
      }
      
      String ketThucFormatted = DateFormat('HH:mm:ss').format(ketThuc);
      
      if (is24HourShift && existingRecord['Ngay'] != formattedDate) {
        if (gioKetThuc != null) {
          gioKetThuc = DateTime(
            now.year, now.month, now.day,
            gioKetThuc.hour, gioKetThuc.minute
          );
        }
      }
      
      bool isSpecialShift = _isBatThuongMode || 
                           existingRecord['PhanLoaiBatDau'] == 'Chấm 24G' || 
                           existingRecord['PhanLoaiBatDau'] == 'Chấm bất thường';
      
      if (gioKetThuc != null && ketThuc.isBefore(gioKetThuc) && !isSpecialShift) {
        diMuonKetThuc = gioKetThuc.difference(ketThuc).inMinutes;
      } else {
        diMuonKetThuc = 0;
      }
      
      String hopLe = _isInRange ? 'Hợp lệ' : 'Sai vị trí';
      String trangThai = _isInRange ? 'OK' : 'NOK';
        if (_isBatThuongMode) {
          trangThai = 'Chưa xem';
        }
      
      String phanLoai = _isBatThuongMode ? 'Chấm bất thường' : (_selectedLocation!.phanLoai ?? '');
      
      checkInData.addAll({
        'KetThuc': ketThucFormatted,
        'PhanLoaiKetThuc': phanLoai,
        'DiemChamKetThuc': _selectedLocation!.tenGoi ?? '',
        'DinhViKetThuc': '${currentLocation?.latitude},${currentLocation?.longitude}',
        'KhoangCachKetThuc': _distanceToLocation?.toInt() ?? 0,
        'HopLeKetThuc': hopLe,
        'TrangThaiKetThuc': trangThai,
        'NguoiDuyetKetThuc': _approverUsername,
        'GioLamKetThuc': gioKetThuc != null ? DateFormat('HH:mm:ss').format(gioKetThuc) : '',
        'DiMuonKetThuc': diMuonKetThuc,
      });
      
      if (isUpdate && existingRecord['BatDau'] != null && existingRecord['BatDau'].isNotEmpty) {
        DateTime batDau = _parseDateTime(existingRecord['Ngay'] ?? formattedDate, existingRecord['BatDau']);
        
        is24HourShift = existingRecord['PhanLoaiBatDau'] == 'Chấm 24G';
        bool isBatThuong = existingRecord['PhanLoaiBatDau'] == 'Chấm bất thường' || _isBatThuongMode;
        
        int totalMinutes;
        
        if (is24HourShift && existingRecord['Ngay'] != formattedDate) {
          totalMinutes = ketThuc.difference(batDau).inMinutes;
          
          if (soPhut > 0) {
            double percentComplete = totalMinutes / soPhut;
            tongCongNgay = percentComplete * soCong;
            
            tongCongNgay = tongCongNgay.clamp(0.5, soCong);
          }
        } else if (is24HourShift || isBatThuong) {
          totalMinutes = ketThuc.difference(batDau).inMinutes;
          
          if (soPhut > 0) {
            double percentComplete = totalMinutes / soPhut;
            tongCongNgay = percentComplete * soCong;
            
            tongCongNgay = tongCongNgay.clamp(0.5, soCong);
          }
        } else {
          DateTime effectiveBatDau = batDau;
          DateTime effectiveKetThuc = ketThuc;
          
          if (gioBatDau != null && batDau.isBefore(gioBatDau)) {
            effectiveBatDau = gioBatDau;
          }
          
          if (gioKetThuc != null && ketThuc.isAfter(gioKetThuc)) {
            effectiveKetThuc = gioKetThuc;
          }
          
          totalMinutes = effectiveKetThuc.difference(effectiveBatDau).inMinutes;
          
          if (soPhut > 0) {
            double percentComplete = totalMinutes / soPhut;
            tongCongNgay = percentComplete * soCong;
            
            tongCongNgay = tongCongNgay.clamp(0.5, soCong);
          }
        }
        
        int existingDiMuonBatDau = safeParseInt(existingRecord['DiMuonBatDau']);
        
        int tongDiMuonNgay = 0;
        if (!is24HourShift && !isBatThuong) {
          tongDiMuonNgay = existingDiMuonBatDau + diMuonKetThuc;
        }
        String phanLoaiBatDau = existingRecord['PhanLoaiBatDau'] ?? '';
        String phanLoaiKetThuc = _isBatThuongMode ? 'Chấm bất thường' : (_selectedLocation!.phanLoai ?? '');
        bool isSpecialMode = phanLoaiBatDau == 'Chấm bất thường' || phanLoaiKetThuc == 'Chấm bất thường';
        
        if (!isSpecialMode) {
          bool invalidBatDau = existingRecord['HopLeBatDau'] != 'Hợp lệ';
          bool invalidKetThuc = !_isInRange;
          
          if (invalidBatDau && invalidKetThuc) {
            tongCongNgay = max(0, tongCongNgay - 1.0);
          } else if (invalidBatDau || invalidKetThuc) {
            tongCongNgay = max(0, tongCongNgay - 0.5);
          }
        }
        checkInData.addAll({
          'DiMuonBatDau': existingDiMuonBatDau,
          'TongDiMuonNgay': tongDiMuonNgay,
          'TongCongNgay': tongCongNgay,
          'NguoiDuyetBatDau': existingRecord['NguoiDuyetBatDau'] ?? _approverUsername,
        });
      } else {
        checkInData['NguoiDuyetBatDau'] = '';
      }
    }
    
    if (isUpdate && existingRecord['Ngay'] != formattedDate) {
      checkInData['Ngay'] = existingRecord['Ngay'];
    }
    
    checkInData.addAll({
      'Ngay2': formattedDate,
      'HinhAnhBatDau': '',
      'HinhAnhKetThuc': '',
    });
    
    print('Final checkInData being sent: $checkInData');
    
    String? photoUrl;
    
    if (photoFile != null) {
      final Uri apiUrl = isUpdate 
        ? Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongupdate/$uid')
        : Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongmoi');
      
      var request = http.MultipartRequest('POST', apiUrl);
      
      var fileStream = http.ByteStream(photoFile.openRead());
      var fileLength = await photoFile.length();
      var multipartFile = http.MultipartFile(
        'photo',
        fileStream,
        fileLength,
        filename: path.basename(photoFile.path),
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);
      
      checkInData.forEach((key, value) {
        request.fields[key] = value.toString();
      });
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        photoUrl = responseData['photoUrl'];
        
        setState(() {
          _isLoading = false;
          _message = 'Chấm công thành công';
          
          if (checkInType == 'BatDau') {
            _hinhAnhBatDau = photoUrl;
          } else {
            _hinhAnhKetThuc = photoUrl;
          }
        });
        _confettiController.play();
        await Future.delayed(Duration(seconds: 1));
        
        await _loadPreviousCheckIns();
      } else {
        setState(() {
          _isLoading = false;
          _message = 'Lỗi chấm công: ${response.statusCode}';
        });
      }
    } else {
      final Uri apiUrl = isUpdate 
        ? Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongupdate/$uid')
        : Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongmoi');
      
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(checkInData),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _isLoading = false;
          _message = 'Chấm công thành công';
        });
        _confettiController.play();
        await _loadPreviousCheckIns();
      } else {
        setState(() {
          _isLoading = false;
          _message = 'Lỗi chấm công: ${response.statusCode}';
        });
      }
    }
    
    print('==== CHECK-IN PROCESS COMPLETE ====');
  } catch (e) {
    print('ERROR in check-in process: $e');
    setState(() {
      _isLoading = false;
      _message = 'Lỗi chấm công: $e';
    });
  }
}
int safeParseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  
  try {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
  } catch (e) {
    print('Error parsing int value: $value');
    print('Error: $e');
  }
  
  return defaultValue;
}
double parseDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null || value.toString().isEmpty) return fallback;
  try {
    return double.parse(value.toString());
  } catch (e) {
    print('Error parsing double: $e, value: $value');
    return fallback;
  }
}

// Add these variables to the class
String? _hinhAnhBatDau;
String? _hinhAnhKetThuc;

// Helper method to capture a photo
Future<File?> _capturePhoto() async {
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    imageQuality: 70,
  );
  
  if (image != null) {
    return File(image.path);
  }
  return null;
}

// Helper method to parse date and time strings
DateTime _parseDateTime(String date, String time) {
  final List<int> dateParts = date.split('-').map(int.parse).toList();
  final List<int> timeParts = time.split(':').map(int.parse).toList();
  
  return DateTime(
    dateParts[0], // year
    dateParts[1], // month
    dateParts[2], // day
    timeParts[0], // hour
    timeParts.length > 1 ? timeParts[1] : 0, // minute
    timeParts.length > 2 ? timeParts[2] : 0, // second
  );
}
  @override
Widget build(BuildContext context) {
 return Scaffold(
   appBar: AppBar(
     title: const Text('⌛ '),
     backgroundColor: Colors.transparent,
     elevation: 0,
   ),
   extendBodyBehindAppBar: true,
   body: RefreshIndicator(
     onRefresh: () => _findNearestCheckInLocation(checkForAuto: true),
     child: Stack(
       children: [
         if (_videoInitialized) 
           Positioned(
             top: 0,
             left: 0,
             right: 0,
             height: 1000,
             child: Opacity(
               opacity: 0.7,
               child: FittedBox(
                 fit: BoxFit.cover,
                 child: SizedBox(
                   width: _videoController.value.size.width,
                   height: _videoController.value.size.height,
                   child: VideoPlayer(_videoController),
                 ),
               ),
             ),
           ),
         
         SingleChildScrollView(
           physics: const AlwaysScrollableScrollPhysics(),
           padding: const EdgeInsets.only(top: kToolbarHeight + 12, left: 12, right: 12, bottom: 12),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               // User info card
               Card(
                 color: Colors.white.withOpacity(0.8),
                 child: Padding(
                   padding: const EdgeInsets.all(12.0),
                   child: Row(
                     children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Row(
                               children: [
                                 const Icon(Icons.person, size: 18),
                                 const SizedBox(width: 4),
                                 Text(
                                   _username.isEmpty ? 'Đang tải...' : _username,
                                   style: const TextStyle(
                                     fontWeight: FontWeight.bold,
                                     fontSize: 16,
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 4),
                             Consumer<LocationProvider>(
                               builder: (context, provider, child) {
                                 return Row(
                                   children: [
                                     const Icon(Icons.location_on, size: 18),
                                     const SizedBox(width: 4),
                                     Expanded(
                                       child: Text(
                                         provider.address.isEmpty ? 'Đang xác định vị trí...' : provider.address,
                                         style: const TextStyle(fontSize: 14),
                                         maxLines: 2,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     ),
                                   ],
                                 );
                               },
                             ),
                           ],
                         ),
                       ),
                       _isLoading 
                         ? const SizedBox(
                             width: 24,
                             height: 24,
                             child: CircularProgressIndicator(strokeWidth: 2.0),
                           )
                         :ElevatedButton.icon(
                           icon: const Icon(Icons.refresh, size: 12, color: Color.fromARGB(255, 50, 176, 0)),
                           label: const Text(
                             'Làm mới',
                             style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 50, 176, 0)),
                           ),
                           style: ElevatedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                             minimumSize: const Size(0, 28),
                             backgroundColor: const Color.fromARGB(255, 224, 255, 230),
                           ),
                           onPressed: () {
  _fetchCheckInLocationsFromServer().then((_) {
    _loadPreviousCheckIns().then((_) {
      _findNearestCheckInLocation(checkForAuto: true);
    });
  });
}
                         )
                     ],
                   ),
                 ),
               ),
               
               // Location info card
               if (_selectedLocation != null)
                 Card(
                   margin: const EdgeInsets.only(top: 8),
                   color: Colors.white.withOpacity(0.8),
                   child: Padding(
                     padding: const EdgeInsets.all(12.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             Icon(
                               _isInRange ? Icons.check_circle : Icons.error,
                               color: _isInRange ? Colors.green : Colors.red,
                               size: 20,
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 '${_selectedLocation!.tenGoi ?? "Unknown"}',
                                 style: const TextStyle(
                                   fontSize: 16,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Expanded(
                               child: Text(
                                 'Loại: ${_selectedLocation!.phanLoai ?? "N/A"}',
                                 style: const TextStyle(fontSize: 14),
                               ),
                             ),
                             Text(
                               '${_distanceToLocation != null ? _distanceToLocation!.toStringAsFixed(0) : "N/A"} mét',
                               style: TextStyle(
                                 color: _isInRange ? Colors.green : Colors.red,
                                 fontWeight: FontWeight.bold,
                                 fontSize: 14,
                               ),
                             ),
                           ],
                         ),
                         if (_message.isNotEmpty)
                           Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(
                               _message,
                               style: const TextStyle(
                                 color: Colors.red,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                           ),
                       ],
                     ),
                   ),
                 ),
               
               // Chấm bất thường toggle card
               Card(
  margin: const EdgeInsets.only(top: 8),
  color: Colors.white.withOpacity(0.8),
  child: Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
      children: [
        // Left section: Chấm bất thường toggle
        Expanded(
          flex: 3,
          child: Row(
            children: [
              const Text(
                'Chấm bất thường:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _isBatThuongMode,
                onChanged: (value) {
                  setState(() {
                    _isBatThuongMode = value;
                    print('Chấm bất thường mode: $_isBatThuongMode');
                  });
                },
                activeColor: Colors.orange,
              ),
            ],
          ),
        ),
        
        // Right section: Báo khác button
        Expanded(
  flex: 2,
  child: ElevatedButton.icon(
    icon: const Icon(Icons.note_add, size: 14),
    label: const Text('Báo khác', style: TextStyle(fontSize: 13)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      minimumSize: const Size(0, 32),
    ),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChamCong2Screen(
            username: _username,
            userRole: _userRole,
            approverUsername: _approverUsername,
          ),
        ),
      );
    },
  ),
),
      ],
    ),
  ),
),
               
               // Check-in buttons card
               Card(
                 margin: const EdgeInsets.only(top: 8),
                 color: Colors.white.withOpacity(0.8),
                 child: Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     children: [
                       Expanded(
                         child: ElevatedButton.icon(
                           icon: const Icon(Icons.login, size: 14),
                           label: const Text('Giờ vào'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: _isBatThuongMode ? const Color.fromARGB(255, 85, 0, 255) : Colors.green,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 8),
                             minimumSize: const Size(0, 30),
                           ),
                           onPressed: _isLoading ? null : () {
                             print('==== GIỜ VÀO BUTTON PRESSED ====');
                             print('Chấm bất thường mode: $_isBatThuongMode');
                             _submitCheckIn('BatDau');
                           },
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: ElevatedButton.icon(
                           icon: const Icon(Icons.logout, size: 14),
                           label: const Text('Giờ ra'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: _isBatThuongMode ? Colors.orange : Colors.red,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 8),
                             minimumSize: const Size(0, 30),
                           ),
                           onPressed: _isLoading ? null : () {
                             print('==== GIỜ RA BUTTON PRESSED ====');
                             print('Chấm bất thường mode: $_isBatThuongMode');
                             _submitCheckIn('KetThuc');
                           },
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
               
               // Photos card
               if (_hinhAnhBatDau != null || _hinhAnhKetThuc != null)
                 Card(
                   margin: const EdgeInsets.only(top: 8),
                   child: Padding(
                     padding: const EdgeInsets.all(12.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text(
                           'Ảnh xác minh:',
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             fontSize: 16,
                           ),
                         ),
                         const SizedBox(height: 8),
                         Row(
                           children: [
                             if (_hinhAnhBatDau != null)
                               Expanded(
                                 child: Column(
                                   children: [
                                     const Text('Giờ vào', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                     const SizedBox(height: 4),
                                     Image.network(
                                       _hinhAnhBatDau!,
                                       height: 100,
                                       fit: BoxFit.cover,
                                       loadingBuilder: (context, child, loadingProgress) {
                                         if (loadingProgress == null) return child;
                                         return Center(
                                           child: CircularProgressIndicator(
                                             value: loadingProgress.expectedTotalBytes != null
                                                 ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                 : null,
                                           ),
                                         );
                                       },
                                       errorBuilder: (context, error, stackTrace) {
                                         return const Center(
                                           child: Text('Không thể tải ảnh', style: TextStyle(color: Colors.red, fontSize: 12)),
                                         );
                                       },
                                     ),
                                   ],
                                 ),
                               ),
                             if (_hinhAnhBatDau != null && _hinhAnhKetThuc != null)
                               const SizedBox(width: 12),
                             if (_hinhAnhKetThuc != null)
                               Expanded(
                                 child: Column(
                                   children: [
                                     const Text('Giờ ra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                     const SizedBox(height: 4),
                                     Image.network(
                                       _hinhAnhKetThuc!,
                                       height: 100,
                                       fit: BoxFit.cover,
                                       loadingBuilder: (context, child, loadingProgress) {
                                         if (loadingProgress == null) return child;
                                         return Center(
                                           child: CircularProgressIndicator(
                                             value: loadingProgress.expectedTotalBytes != null
                                                 ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                 : null,
                                           ),
                                         );
                                       },
                                       errorBuilder: (context, error, stackTrace) {
                                         return const Center(
                                           child: Text('Không thể tải ảnh', style: TextStyle(color: Colors.red, fontSize: 12)),
                                         );
                                       },
                                     ),
                                   ],
                                 ),
                               ),
                           ],
                         ),
                       ],
                     ),
                   ),
                 ),
               
               // History card
               Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lịch sử chấm:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    if (_availableMonths.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedMonth,
                            icon: const Icon(Icons.arrow_drop_down, size: 16),
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedMonth = newValue;
                                _filterCheckInsByMonth();
                              });
                            },
                            items: _availableMonths.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Tải lại', style: TextStyle(fontSize: 14)),
                      onPressed: _loadPreviousCheckIns,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 30),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            _loadingPreviousCheckIns
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                  )
                : _filteredCheckIns.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'Không có dữ liệu chấm công trong tháng đã chọn.',
                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14)
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _filteredCheckIns.length > 5 ? 5 : _filteredCheckIns.length,
                          (index) {
                            final checkin = _filteredCheckIns[index];
                                       bool hasPhotoBatDau = checkin.hinhAnhBatDau != null && checkin.hinhAnhBatDau!.isNotEmpty;
                                       bool hasPhotoKetThuc = checkin.hinhAnhKetThuc != null && checkin.hinhAnhKetThuc!.isNotEmpty;
                                       
                                       return Card(
                                         margin: const EdgeInsets.only(top: 4, bottom: 4),
                                         elevation: 0,
                                         color: Colors.grey[100],
                                         child: Padding(
                                           padding: const EdgeInsets.all(8.0),
                                           child: Column(
                                             children: [
                                               Row(
                                                 children: [
                                                   const Icon(Icons.calendar_today, size: 16),
                                                   const SizedBox(width: 8),
                                                   Text(
                                                     _formatDate(checkin.ngay),
                                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                   ),
                                                   const Spacer(),
                                                   Column(
                                                     crossAxisAlignment: CrossAxisAlignment.end,
                                                     children: [
                                                       Row(
                                                         children: [
                                                           const Icon(Icons.login, size: 14, color: Colors.green),
                                                           const SizedBox(width: 4),
                                                           Text(checkin.batDau ?? 'N/A', style: const TextStyle(fontSize: 13)),
                                                         ],
                                                       ),
                                                       const SizedBox(height: 2),
                                                       Row(
                                                         children: [
                                                           const Icon(Icons.logout, size: 14, color: Colors.red),
                                                           const SizedBox(width: 4),
                                                           Text(checkin.ketThuc ?? 'N/A', style: const TextStyle(fontSize: 13)),
                                                         ],
                                                       ),
                                                     ],
                                                   ),
                                                 ],
                                               ),
                                               const SizedBox(height: 6),
                                               Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                   Expanded(
                                                     child: Row(
                                                       children: [
                                                         const Icon(Icons.access_time, size: 14, color: Colors.blue),
                                                         const SizedBox(width: 4),
                                                         Text(
                                                           'Công: ${checkin.tongCongNgay?.toStringAsFixed(1) ?? '0'}',
                                                           style: const TextStyle(fontSize: 13),
                                                         ),
                                                       ],
                                                     ),
                                                   ),
                                                   Expanded(
                                                     child: Row(
                                                       children: [
                                                         const Icon(Icons.timer_off, size: 14, color: Colors.orange),
                                                         const SizedBox(width: 4),
                                                         Text(
                                                           'Muộn: ${checkin.tongDiMuonNgay ?? '0'} phút',
                                                           style: const TextStyle(fontSize: 13),
                                                         ),
                                                       ],
                                                     ),
                                                   ),
                                                   if (hasPhotoBatDau || hasPhotoKetThuc)
                                                     Row(
                                                       children: [
                                                         const Icon(Icons.photo, size: 14, color: Colors.purple),
                                                         const SizedBox(width: 4),
                                                         const Text('Ảnh', style: TextStyle(fontSize: 13)),
                                                       ],
                                                     ),
                                                 ],
                                               ),
                                               const SizedBox(height: 6),
Row(
  children: [
    Icon(
      checkin.hopLeBatDau == 'Hợp lệ' ? Icons.check_circle : Icons.error,
      size: 14,
      color: checkin.hopLeBatDau == 'Hợp lệ' ? Colors.green : Colors.red,
    ),
    const SizedBox(width: 4),
    Expanded(
      child: Text(
        'Vào: ${checkin.hopLeBatDau ?? 'N/A'} (${checkin.phanLoaiBatDau ?? 'N/A'})',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
),
const SizedBox(height: 4),
Row(
  children: [
    Icon(
      checkin.hopLeKetThuc == 'Hợp lệ' ? Icons.check_circle : Icons.error,
      size: 14,
      color: checkin.hopLeKetThuc == 'Hợp lệ' ? Colors.green : Colors.red,
    ),
    const SizedBox(width: 4),
    Expanded(
      child: Text(
        'Ra: ${checkin.hopLeKetThuc ?? 'N/A'} (${checkin.phanLoaiKetThuc ?? 'N/A'})',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
),
                                               if (hasPhotoBatDau || hasPhotoKetThuc)
                                                 Padding(
                                                   padding: const EdgeInsets.only(top: 8.0),
                                                   child: Row(
                                                     children: [
                                                       if (hasPhotoBatDau)
                                                         Expanded(
                                                           child: GestureDetector(
                                                             onTap: () => _showFullImage(checkin.hinhAnhBatDau!),
                                                             child: ClipRRect(
                                                               borderRadius: BorderRadius.circular(4),
                                                               child: Image.network(
                                                                 checkin.hinhAnhBatDau!,
                                                                 height: 50,
                                                                 fit: BoxFit.cover,
                                                                 loadingBuilder: (context, child, loadingProgress) {
                                                                   if (loadingProgress == null) return child;
                                                                   return const SizedBox(
                                                                     height: 50,
                                                                     child: Center(
                                                                       child: CircularProgressIndicator(strokeWidth: 2),
                                                                     ),
                                                                   );
                                                                 },
                                                                 errorBuilder: (context, error, stackTrace) => 
                                                                   const SizedBox(
                                                                     height: 50,
                                                                     child: Center(child: Icon(Icons.broken_image, size: 20)),
                                                                   ),
                                                               ),
                                                             ),
                                                           ),
                                                         ),
                                                       if (hasPhotoBatDau && hasPhotoKetThuc)
                                                         const SizedBox(width: 8),
                                                       if (hasPhotoKetThuc)
                                                         Expanded(
                                                           child: GestureDetector(
                                                             onTap: () => _showFullImage(checkin.hinhAnhKetThuc!),
                                                             child: ClipRRect(
                                                               borderRadius: BorderRadius.circular(4),
                                                               child: Image.network(
                                                                 checkin.hinhAnhKetThuc!,
                                                                 height: 50,
                                                                 fit: BoxFit.cover,
                                                                 loadingBuilder: (context, child, loadingProgress) {
                                                                   if (loadingProgress == null) return child;
                                                                   return const SizedBox(
                                                                     height: 50,
                                                                     child: Center(
                                                                       child: CircularProgressIndicator(strokeWidth: 2),
                                                                     ),
                                                                   );
                                                                 },
                                                                 errorBuilder: (context, error, stackTrace) => 
                                                                   const SizedBox(
                                                                     height: 50,
                                                                     child: Center(child: Icon(Icons.broken_image, size: 20)),
                                                                   ),
                                                               ),
                                                             ),
                                                           ),
                                                         ),
                                                     ],
                                                   ),
                                                 ),
                                             ],
                                           ),
                                         ),
                                       );
                                     },
                                   ),
                                 ),
                       if (_previousCheckIns.length > 5)
                         Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Center(
                             child: TextButton(
                               onPressed: _viewAllCheckIns,
                               child: const Text('Xem tất cả'),
                             ),
                           ),
                         ),
                     ],
                   ),
                 ),
               ),
             ],
           ),
         ),
        Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 35,
                gravity: 0.1,
                colors: const [
                  Color.fromARGB(255, 49, 255, 183),
                  Color.fromARGB(255, 126, 255, 128),
                  Color.fromARGB(255, 255, 100, 151),
                  Color.fromARGB(255, 255, 201, 119),
                  Color.fromARGB(255, 255, 160, 247),
                  Color.fromARGB(255, 255, 248, 181),
                ],
                createParticlePath: (size) {
                  // You can use default particles or create custom ones
                  return Path()
                    ..addOval(Rect.fromCircle(
                      center: Offset.zero,
                      radius: 10.0,
                    ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

// Add this method to show full-size image when thumbnail is tapped
void _showFullImage(String imageUrl) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: const Text('Hình ảnh chấm công'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            automaticallyImplyLeading: false,
          ),
          Image.network(
            imageUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / 
                          loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Không thể tải ảnh', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
}