import 'package:flutter/material.dart' hide Border;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'hs_khachhangsua.dart';
import 'dart:math';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
class HSKhachHangScreen extends StatefulWidget {
  @override
  _HSKhachHangScreenState createState() => _HSKhachHangScreenState();
}

class _HSKhachHangScreenState extends State<HSKhachHangScreen> {
  final DBHelper _dbHelper = DBHelper();
  List<KhachHangModel> _khachHangList = [];
  List<KhachHangModel> _filteredList = [];
  bool _isLoading = true;
  String _searchText = '';
  String _filterBy = 'Tất cả';
  String _sortBy = 'tenDuAn';
  bool _sortAscending = true;
  String? username;
    bool _canEdit = false;
  bool _canAdd = false;
  Set<String> _allNguoiDungValues = <String>{};
  // Color scheme to match main app
  final Color appBarTop = Color(0xFF024965);
  final Color appBarBottom = Color(0xFF03a6cf);
  final Color buttonColor = Color(0xFF33a7ce);
  final Color searchBarColor = Color(0xFF35abb5);
  final Color tabBarColor = Color(0xFF034d58);
  
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadKhachHangData();
    _checkAndPerformDailySync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _exportToExcel() async {
  try {
    // Show choice dialog for desktop or direct export for mobile
    final choice = await _showExportChoiceDialog();
    if (choice == null) return; // User cancelled
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Create Excel workbook
    var excel = Excel.createExcel();
    
    // Create new sheet with custom name
    var sheetObject = excel['Khách hàng'];

    // Add headers
    List<String> headers = [
      'STT',
      'UID',
      'Tên dự án',
      'Tên kỹ thuật', 
      'Tên rút gọn',
      'Người dùng',
      'Phân loại',
      'Vùng miền',
      'Loại hình',
      'Loại công trình',
      'Trạng thái HĐ',
      'Địa chỉ',
      'Địa chỉ VP',
      'Tỉnh thành',
      'Quận huyện',
      'Phường xã',
      'Điện thoại',
      'Fax',
      'Website',
      'Email',
      'Mã số thuế',
      'Số tài khoản',
      'Ngân hàng',
      'Loại mua hàng',
      'Kênh tiếp cận',
      'Dự kiến triển khai',
      'Tiềm năng DVTM',
      'Giám sát',
      'QLDV',
      'Yêu cầu nhân sự',
      'Cách thức tuyển',
      'Mức lương tuyển',
      'Lương BP',
      'Ghi chú',
      'Đánh dấu',
      'Ngày khởi tạo',
      'Ngày cập nhật cuối',
    ];

    // Add headers to Excel (no styling)
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }

    // Get ordered customer list (same as display)
    final orderedList = _getOrderedCustomerList();

    // Add data rows
    for (int rowIndex = 0; rowIndex < orderedList.length; rowIndex++) {
      final customer = orderedList[rowIndex];
      final excelRowIndex = rowIndex + 1;

      List<String> rowData = [
        (rowIndex + 1).toString(), // STT
        customer.uid ?? '',
        customer.tenDuAn ?? '',
        customer.tenKyThuat ?? '',
        customer.tenRutGon ?? '',
        customer.nguoiDung ?? '',
        customer.phanLoai ?? '',
        customer.vungMien ?? '',
        customer.loaiHinh ?? '',
        customer.loaiCongTrinh ?? '',
        customer.trangThaiHopDong ?? '',
        customer.diaChi ?? '',
        customer.diaChiVanPhong ?? '',
        customer.tinhThanh ?? '',
        customer.quanHuyen ?? '',
        customer.phuongXa ?? '',
        customer.soDienThoai ?? '',
        customer.fax ?? '',
        customer.website ?? '',
        customer.email ?? '',
        customer.maSoThue ?? '',
        customer.soTaiKhoan ?? '',
        customer.nganHang ?? '',
        customer.loaiMuaHang ?? '',
        customer.kenhTiepCan ?? '',
        customer.duKienTrienKhai ?? '',
        customer.tiemNangDVTM ?? '',
        customer.giamSat ?? '',
        customer.qldv ?? '',
        customer.yeuCauNhanSu ?? '',
        customer.cachThucTuyen ?? '',
        customer.mucLuongTuyen ?? '',
        customer.luongBP ?? '',
        customer.ghiChu ?? '',
        customer.danhDau ?? '',
        customer.ngayKhoiTao != null ? DateFormat('dd/MM/yyyy HH:mm').format(customer.ngayKhoiTao!) : '',
        customer.ngayCapNhatCuoi != null ? DateFormat('dd/MM/yyyy HH:mm').format(customer.ngayCapNhatCuoi!) : '',
      ];

      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: excelRowIndex));
        cell.value = rowData[colIndex];
      }
    }

    // Generate filename
    final fileName = 'DanhSachKhachHang_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.xlsx';
    
    // Save and handle based on user choice
    final fileBytes = excel.encode()!;
    
    // Close loading dialog
    Navigator.pop(context);
    
    if (choice == 'share') {
      await _handleShare(fileBytes, fileName);
    } else {
      await _handleSaveToAppFolder(fileBytes, fileName);
    }

  } catch (e) {
    // Close loading dialog if still open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('Error exporting to Excel: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi xuất Excel: $e')),
    );
  }
}
Future<String?> _showExportChoiceDialog() async {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Xuất file Excel'),
        content: Text('Bạn muốn chia sẻ file hay lưu vào thư mục ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('share'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.share, size: 16),
                SizedBox(width: 4),
                Text('Chia sẻ'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder, size: 16),
                SizedBox(width: 4),
                Text('Lưu vào thư mục'),
              ],
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _handleShare(List<int> fileBytes, String fileName) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(fileBytes);
    
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Danh sách khách hàng được xuất từ ứng dụng',
      subject: 'Danh sách khách hàng - $fileName',
      sharePositionOrigin: box != null 
          ? Rect.fromLTWH(
              box.localToGlobal(Offset.zero).dx,
              box.localToGlobal(Offset.zero).dy,
              box.size.width,
              box.size.height / 2,
            )
          : null,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xuất ${_filteredList.length} khách hàng ra Excel')),
    );
  } catch (e) {
    print('Error sharing file: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi chia sẻ file: $e')),
    );
  }
}

Future<void> _handleSaveToAppFolder(List<int> fileBytes, String fileName) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final appFolder = Directory('${directory.path}/DanhSach_KhachHang');
    
    // Create folder if it doesn't exist
    if (!await appFolder.exists()) {
      await appFolder.create(recursive: true);
    }
    
    final filePath = '${appFolder.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    
    // Show success dialog with option to open folder
    await _showSaveSuccessDialog(appFolder.path, fileName);
    
  } catch (e) {
    print('Error saving to app folder: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi lưu file: $e')),
    );
  }
}

Future<void> _showSaveSuccessDialog(String folderPath, String fileName) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Lưu thành công'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File đã được lưu:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                fileName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 8),
            Text('Đường dẫn thư mục:'),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                folderPath,
                style: TextStyle(fontSize: 12),
              ),
            ),
            SizedBox(height: 8),
            Text('Đã xuất ${_filteredList.length} khách hàng'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _openFolder(folderPath);
            },
            icon: Icon(Icons.folder_open, size: 16),
            label: Text('Mở thư mục'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _openFolder(String folderPath) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [folderPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [folderPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [folderPath]);
    }
  } catch (e) {
    print('Error opening folder: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể mở thư mục: $e')),
    );
  }
}

Future<void> _shareExcelFile(String filePath, String fileName) async {
  try {
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Danh sách khách hàng được xuất từ ứng dụng',
      subject: 'Danh sách khách hàng - $fileName',
    );
  } catch (e) {
    print('Error sharing file: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi chia sẻ file: $e')),
    );
  }
}
  Future<void> _loadUsername() async {
    print('=== LOADING USERNAME ===');
    final prefs = await SharedPreferences.getInstance();
    final userObj = prefs.getString('current_user');
    print('Raw user object from prefs: $userObj');

    if (userObj != null && userObj.isNotEmpty) {
      try {
        final userData = json.decode(userObj);
        setState(() {
          username = userData['username']?.toString().toUpperCase() ?? '';
          print("Loaded username from JSON prefs: $username");
        });
      } catch (e) {
        setState(() {
          username = userObj.toUpperCase();
          print("Loaded username directly from prefs: $username");
        });
      }
    } else {
      print('No user data in SharedPreferences, trying UserCredentials provider');
      try {
        final userCredentials = Provider.of<UserCredentials>(context, listen: false);
        setState(() {
          username = userCredentials.username.toUpperCase();
          print("Loaded username from UserCredentials: $username");
        });
        
        await prefs.setString('current_user', username!);
        print("Saved username to SharedPreferences: $username");
      } catch (e) {
        print('Error loading username from UserCredentials: $e');
        setState(() {
          username = '';
          print("Using empty username");
        });
      }
    }
    print('=== USERNAME LOADING COMPLETE ===');
  }
void _checkPermissions() {
  print('=== CHECKING PERMISSIONS ===');
  print('Current username: "$username"');
  print('Username length: ${username?.length ?? 0}');
  
  if (username == null || username!.isEmpty) {
    print('Username is null or empty, cannot check permissions');
    setState(() {
      _canAdd = false;
      _canEdit = false;
    });
    return;
  }
  // Get all unique nguoiDung values from the customer list
  _allNguoiDungValues = _khachHangList
      .where((customer) => customer.nguoiDung != null && customer.nguoiDung!.isNotEmpty)
      .map((customer) => customer.nguoiDung!.toUpperCase())
      .toSet();
  print('Total customers: ${_khachHangList.length}');
  print('Customers with nguoiDung: ${_khachHangList.where((c) => c.nguoiDung != null && c.nguoiDung!.isNotEmpty).length}');
  print('All nguoiDung values found: $_allNguoiDungValues');
  print('Username for comparison: "${username!.toUpperCase()}"');
  // Add permission: current user exists in any nguoiDung value
  _canAdd = _allNguoiDungValues.contains(username!.toUpperCase());
  print('Can add permission: $_canAdd');
  // Also log some sample customers for debugging
  if (_khachHangList.isNotEmpty) {
    print('Sample customer nguoiDung values:');
    for (int i = 0; i < min(5, _khachHangList.length); i++) {
      final customer = _khachHangList[i];
      print('  Customer $i: ${customer.tenDuAn} - nguoiDung: "${customer.nguoiDung}"');
    }
  }
  print('=== PERMISSIONS CHECK COMPLETE ===');
  setState(() {
    // Permissions are now calculated
  });
}
bool _canEditCustomer(KhachHangModel customer) {
  print('--- Checking edit permission for customer ---');
  print('Customer UID: ${customer.uid}');
  print('Customer tenDuAn: ${customer.tenDuAn}');
  print('Customer nguoiDung: ${customer.nguoiDung}');
  print('Current username: $username');
  if (username == null || customer.nguoiDung == null) {
    print('Username or customer.nguoiDung is null - no edit permission');
    return false;
  }
  bool canEdit = username!.toUpperCase() == customer.nguoiDung!.toUpperCase();
  print('Username uppercase: ${username!.toUpperCase()}');
  print('Customer nguoiDung uppercase: ${customer.nguoiDung!.toUpperCase()}');
  print('Can edit: $canEdit');
  print('--- Edit permission check complete ---');
  
  return canEdit;
}
  Future<void> _checkAndPerformDailySync() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); 
    final lastSyncDate = prefs.getString('last_sync_date');
    
    if (lastSyncDate != today) {
      print('Performing daily auto-sync...');
      await _refreshData();
      await prefs.setString('last_sync_date', today);
      print('Daily sync completed and date saved');
    } else {
      print('Daily sync already performed today');
    }
  }

  Future<void> _loadKhachHangData() async {
  print('=== LOADING KHACH HANG DATA ===');
  setState(() {
    _isLoading = true;
  });
  
  try {
    final List<KhachHangModel> khachHangData = await _dbHelper.getAllKhachHang();
    print('Loaded ${khachHangData.length} customers from database');
    
    // Log some sample data
    if (khachHangData.isNotEmpty) {
      print('Sample customer data:');
      for (int i = 0; i < min(3, khachHangData.length); i++) {
        final customer = khachHangData[i];
        print('  Customer $i: ${customer.tenDuAn} - nguoiDung: "${customer.nguoiDung}"');
      }
    }
    
    setState(() {
      _khachHangList = khachHangData;
      _filteredList = List.from(khachHangData);
      _applyFiltersAndSort();
      _isLoading = false;
    });
    
    // Check permissions after loading data
    _checkPermissions();
  } catch (e) {
    print('Error loading customer data: $e');
    setState(() {
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể tải dữ liệu khách hàng: $e'))
    );
  }
}

  void _applyFiltersAndSort() {
    // First apply filters
    if (_filterBy == 'Tất cả') {
      _filteredList = List.from(_khachHangList);
    } else {
      _filteredList = _khachHangList.where((customer) => 
        customer.phanLoai == _filterBy || 
        customer.loaiHinh == _filterBy || 
        customer.vungMien == _filterBy
      ).toList();
    }
    
    // Then apply search
    if (_searchText.isNotEmpty) {
      _filteredList = _filteredList.where((customer) {
        final search = _searchText.toLowerCase();
        return (customer.tenDuAn?.toLowerCase().contains(search) ?? false) ||
               (customer.tenKyThuat?.toLowerCase().contains(search) ?? false) ||
               (customer.tenRutGon?.toLowerCase().contains(search) ?? false) ||
               (customer.diaChi?.toLowerCase().contains(search) ?? false) ||
               (customer.soDienThoai?.toLowerCase().contains(search) ?? false);
      }).toList();
    }
    
    // Finally, sort the data
    _filteredList.sort((a, b) {
      dynamic valA, valB;
      
      switch (_sortBy) {
        case 'tenDuAn':
          valA = a.tenDuAn ?? '';
          valB = b.tenDuAn ?? '';
          break;
        case 'vungMien':
          valA = a.vungMien ?? '';
          valB = b.vungMien ?? '';
          break;
        case 'phanLoai':
          valA = a.phanLoai ?? '';
          valB = b.phanLoai ?? '';
          break;
        case 'ngayCapNhatCuoi':
          valA = a.ngayCapNhatCuoi ?? DateTime(1900);
          valB = b.ngayCapNhatCuoi ?? DateTime(1900);
          break;
        default:
          valA = a.tenDuAn ?? '';
          valB = b.tenDuAn ?? '';
      }
      
      int result;
      if (valA is String && valB is String) {
        result = valA.compareTo(valB);
      } else if (valA is DateTime && valB is DateTime) {
        result = valA.compareTo(valB);
      } else if (valA is num && valB is num) {
        result = valA.compareTo(valB);
      } else {
        result = 0;
      }
      
      return _sortAscending ? result : -result;
    });
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchText = query;
      _applyFiltersAndSort();
    });
  }

  void _updateFilter(String filter) {
    setState(() {
      _filterBy = filter;
      _applyFiltersAndSort();
    });
  }

  void _updateSort(String sortField) {
    setState(() {
      if (_sortBy == sortField) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sortField;
        _sortAscending = true;
      }
      _applyFiltersAndSort();
    });
  }

  Future<void> _refreshData() async {
  print('=== REFRESH DATA STARTED ===');
  
  // Make sure we have username before proceeding
  if (username == null || username!.isEmpty) {
    print('Username not available, reloading...');
    await _loadUsername();
  }
  
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  final usernameForSync = userCredentials.username;
  print('Refresh - username for sync: $usernameForSync');
  print('Refresh - stored username: $username');
  
  try {
    setState(() {
      _isLoading = true;
    });
    
    await Future.wait([
      _syncKhachHang(usernameForSync),
      _syncKhachHangContact(usernameForSync)
    ]);
    
    await _loadKhachHangData(); // This will call _checkPermissions()
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dữ liệu đã được cập nhật'))
    );
  } catch (e) {
    print('Error during refresh: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi cập nhật dữ liệu: $e'))
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
  print('=== REFRESH DATA COMPLETE ===');
}

  Future<void> _syncKhachHang(String username) async {
    final String requestUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhachhang/$username';
    print('Making request to: $requestUrl');
    
    final response = await http.get(
      Uri.parse(requestUrl),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> khachHangData = json.decode(response.body);
      
      if (khachHangData.isNotEmpty) {
        await _dbHelper.clearKhachHangTable();
        
        for (var item in khachHangData) {
          final khachHang = KhachHangModel.fromMap(item);
          await _dbHelper.insertKhachHang(khachHang);
        }
        
        print('KhachHang sync completed successfully');
      }
    } else {
      throw Exception('Failed to sync KhachHang data: ${response.statusCode}');
    }
  }

  Future<void> _syncKhachHangContact(String username) async {
    final String requestUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelkhachhangcontact/$username';
    print('Making request to: $requestUrl');
    
    final response = await http.get(
      Uri.parse(requestUrl),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> contactData = json.decode(response.body);
      
      if (contactData.isNotEmpty) {
        await _dbHelper.clearKhachHangContactTable();
        
        for (var item in contactData) {
          final contact = KhachHangContactModel.fromMap(item);
          await _dbHelper.insertKhachHangContact(contact);
        }
        
        print('KhachHangContact sync completed successfully');
      }
    } else {
      throw Exception('Failed to sync KhachHangContact data: ${response.statusCode}');
    }
  }
    
  Future<void> _callCustomer(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Số điện thoại không có sẵn'))
      );
      return;
    }
    
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await url_launcher.canLaunchUrl(telUri)) {
      await url_launcher.launchUrl(telUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gọi số $phoneNumber'))
      );
    }
  }

  void _editCustomer(KhachHangModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddKhachHangScreen(
          editingCustomer: customer, 
        ),
      ),
    ).then((value) {
      if (value == true) {
        _refreshData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [appBarTop, appBarBottom],
            ),
          ),
        ),
        title: Text('DS khách hàng', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white), 
        actions: [
          TextButton.icon(
            icon: Icon(Icons.filter_list, color: Colors.white),
            label: Text('Lọc', style: TextStyle(color: Colors.white)),
            onPressed: () {
              _showFilterDialog();
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.sort, color: Colors.white),
            label: Text('Sắp xếp', style: TextStyle(color: Colors.white)),
            onPressed: () {
              _showSortDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildCustomerList(),
          ),
        ],
      ),
      floatingActionButton: Column(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    if (_canAdd) 
      FloatingActionButton(
        backgroundColor: Colors.blue[200],
        heroTag: "add",
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddKhachHangScreen()),
          ).then((value) {
            if (value == true) {
              _refreshData();
            }
          });
        },
      ),
    if (_canAdd) SizedBox(height: 16), 
    FloatingActionButton(
      backgroundColor: Colors.blue[200],
      heroTag: "refresh",
      child: Icon(Icons.refresh),
      onPressed: _refreshData,
    ),
  ],
),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: searchBarColor.withOpacity(0.1),
      padding: EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm theo tên, địa chỉ, số điện thoại...',
          prefixIcon: Icon(Icons.search, color: searchBarColor),
          suffixIcon: _searchText.isNotEmpty 
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _updateSearchQuery('');
                },
              )
            : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 0.0),
        ),
        onChanged: _updateSearchQuery,
      ),
    );
  }

  Widget _buildFilterChips() {
  final Set<String> phanLoaiSet = _khachHangList
      .where((c) => c.phanLoai != null && c.phanLoai!.isNotEmpty)
      .map((c) => c.phanLoai!)
      .toSet();
  
  final Set<String> vungMienSet = _khachHangList
      .where((c) => c.vungMien != null && c.vungMien!.isNotEmpty)
      .map((c) => c.vungMien!)
      .toSet();
  
  final List<String> filterOptions = ['Tất cả', ...phanLoaiSet, ...vungMienSet];
  
  return Column(
    children: [
      // Filter chips row
      Container(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: filterOptions.length,
          itemBuilder: (context, index) {
            final option = filterOptions[index];
            final isSelected = _filterBy == option;
            
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: buttonColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                onSelected: (selected) {
                  if (selected) {
                    _updateFilter(option);
                  }
                },
              ),
            );
          },
        ),
      ),
      
      // Download button row
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Text(
              'Tìm thấy ${_filteredList.length} khách hàng',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Spacer(),
            ElevatedButton.icon(
              onPressed: _filteredList.isNotEmpty ? _exportToExcel : null,
              icon: Icon(Icons.download, size: 18),
              label: Text('Xuất Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size(0, 36),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  int _getItemsToShow(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 1; 
    if (screenWidth < 900) return 2; 
    if (screenWidth < 1200) return 3; 
    if (screenWidth < 1500) return 4; 
    return 5;
  }

  Map<String, List<KhachHangModel>> _groupCustomersByDanhDau() {
    final Map<String, List<KhachHangModel>> grouped = {
      'marked': [], 
      'unmarked': [], 
    };
    for (var customer in _filteredList) {
      if (customer.danhDau != null && customer.danhDau!.isNotEmpty) {
        grouped['marked']!.add(customer);
      } else {
        grouped['unmarked']!.add(customer);
      }
    }
    return grouped;
  }

  List<KhachHangModel> _getOrderedCustomerList() {
    final grouped = _groupCustomersByDanhDau();
    final List<KhachHangModel> orderedList = [];
    orderedList.addAll(grouped['marked']!);
    orderedList.addAll(grouped['unmarked']!);
    return orderedList;
  }

  Widget _buildCustomerList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Không tìm thấy khách hàng',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_searchText.isNotEmpty || _filterBy != 'Tất cả')
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchText = '';
                    _filterBy = 'Tất cả';
                    _applyFiltersAndSort();
                  });
                },
                child: Text('Xóa bộ lọc'),
              ),
          ],
        ),
      );
    }
    
    final orderedList = _getOrderedCustomerList();
    final itemsToShow = _getItemsToShow(context);
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (itemsToShow > 1) {
            return GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: itemsToShow,
                childAspectRatio: 4.5,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: orderedList.length,
              itemBuilder: (context, index) {
                final customer = orderedList[index];
                return _buildCustomerCard(customer);
              },
            );
          } else {
            return ListView.builder(
              itemCount: orderedList.length,
              itemBuilder: (context, index) {
                final customer = orderedList[index];
                return _buildCustomerCard(customer);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildCustomerCard(KhachHangModel customer) {
  Color vungMienColor;
  String vungMienText = '?';
  
  if (customer.vungMien != null && customer.vungMien!.isNotEmpty) {
    vungMienText = customer.vungMien!.substring(0, 1).toUpperCase();
    switch (customer.vungMien!.toLowerCase()) {
      case 'bắc':
        vungMienColor = Colors.blue;
        break;
      case 'trung':
        vungMienColor = Colors.red;
        break;
      default:
        vungMienColor = Colors.green;
    }
  } else {
    vungMienColor = Colors.grey;
  }

  final bool isMarked = customer.danhDau != null && customer.danhDau!.isNotEmpty;
  final Color titleColor = isMarked ? Colors.blueAccent : Colors.black87;
  final FontWeight titleWeight = isMarked ? FontWeight.w900 : FontWeight.bold;

  return Card(
    margin: EdgeInsets.all(3),
    elevation: isMarked ? 3 : 1,
    child: InkWell(
      onTap: () => _showCustomerDetailDialog(customer),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.all(8), 
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: vungMienColor,
                  radius: 16,
                  child: Text(
                    vungMienText,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isMarked)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.star, size: 6, color: Colors.white),
                    ),
                  ),
              ],
            ),
            
            SizedBox(width: 8),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Text(
                    customer.tenDuAn ?? 'Không có tên',
                    style: TextStyle(
                      fontWeight: titleWeight,
                      color: titleColor,
                      fontSize: 13, 
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  SizedBox(height: 2), 
                  
                  Text(
                    [
                      customer.nguoiDung ?? '',
                      customer.phanLoai ?? '',
                      customer.loaiCongTrinh ?? '',
                    ].where((text) => text.isNotEmpty).join(' • '),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
      ),
    ),
  );
}

  void _showCustomerDetailDialog(KhachHangModel customer) async {
    List<KhachHangContactModel> contacts = [];
    try {
      contacts = await _dbHelper.getContactsByCustomerUid(customer.uid!);
    } catch (e) {
      print('Error loading contacts: $e');
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.85,
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [appBarTop, appBarBottom],
                    ),
                  ),
                ),
                title: Text(
                  customer.tenDuAn ?? 'Chi tiết khách hàng',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                actions: [
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_canEditCustomer(customer)) 
        IconButton(
          icon: Icon(Icons.edit, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            _editCustomer(customer);
          },
          tooltip: 'Sửa',
        ),
      
      if (customer.soDienThoai != null && customer.soDienThoai!.isNotEmpty)
        IconButton(
          icon: Icon(Icons.call, color: Colors.white),
          onPressed: () => _callCustomer(customer.soDienThoai!),
          tooltip: 'Gọi',
        ),
      
      IconButton(
        icon: Icon(Icons.directions, color: Colors.white),
        onPressed: () => _openMaps(customer.diaChi ?? ''),
        tooltip: 'Chỉ đường',
      ),
      
      IconButton(
        icon: Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Đóng',
      ),
    ],
  ),
],
                bottom: TabBar(
                  indicatorColor: Colors.orange,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: 'Thông tin khách hàng'),
                    Tab(text: 'Người liên hệ (${contacts.length})'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _buildCustomerInfoTab(customer),
                  _buildContactsTab(contacts),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerInfoTab(KhachHangModel customer) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Thông tin cơ bản'),
          _buildDetailRow('UID:', customer.uid ?? ''),
          _buildDetailRow('Tên dự án:', customer.tenDuAn ?? ''),
          _buildDetailRow('Tên kỹ thuật:', customer.tenKyThuat ?? ''),
          _buildDetailRow('Tên rút gọn:', customer.tenRutGon ?? ''),
          _buildDetailRow('Người dùng:', customer.nguoiDung ?? ''),
          _buildDetailRow('Phân loại:', customer.phanLoai ?? ''),
          _buildDetailRow('Vùng miền:', customer.vungMien ?? ''),
          _buildDetailRow('Loại hình:', customer.loaiHinh ?? ''),
          _buildDetailRow('Loại công trình:', customer.loaiCongTrinh ?? ''),
          _buildDetailRow('Trạng thái HĐ:', customer.trangThaiHopDong ?? ''),
          
          SizedBox(height: 20),
          
          _buildSectionHeader('Thông tin liên hệ'),
          _buildDetailRow('Địa chỉ:', customer.diaChi ?? ''),
          _buildDetailRow('Địa chỉ VP:', customer.diaChiVanPhong ?? ''),
          _buildDetailRow('Tỉnh thành:', customer.tinhThanh ?? ''),
          _buildDetailRow('Quận huyện:', customer.quanHuyen ?? ''),
          _buildDetailRow('Phường xã:', customer.phuongXa ?? ''),
          _buildDetailRow('Điện thoại:', customer.soDienThoai ?? '', isPhone: true),
          _buildDetailRow('Fax:', customer.fax ?? ''),
          _buildDetailRow('Website:', customer.website ?? ''),
          _buildDetailRow('Email:', customer.email ?? ''),
          
          SizedBox(height: 20),
          
          _buildSectionHeader('Thông tin doanh nghiệp'),
          _buildDetailRow('Mã số thuế:', customer.maSoThue ?? ''),
          _buildDetailRow('Số tài khoản:', customer.soTaiKhoan ?? ''),
          _buildDetailRow('Ngân hàng:', customer.nganHang ?? ''),
          _buildDetailRow('Loại mua hàng:', customer.loaiMuaHang ?? ''),
          _buildDetailRow('Kênh tiếp cận:', customer.kenhTiepCan ?? ''),
          
          SizedBox(height: 20),
          
          _buildSectionHeader('Thông tin dự án'),
          _buildDetailRow('Dự kiến triển khai:', customer.duKienTrienKhai ?? ''),
          _buildDetailRow('Tiềm năng DVTM:', customer.tiemNangDVTM ?? ''),
          _buildDetailRow('Giám sát:', customer.giamSat ?? ''),
          _buildDetailRow('QLDV:', customer.qldv ?? ''),
          
          SizedBox(height: 20),
          
          _buildSectionHeader('Thông tin nhân sự'),
          _buildDetailRow('Yêu cầu nhân sự:', customer.yeuCauNhanSu ?? ''),
          _buildDetailRow('Cách thức tuyển:', customer.cachThucTuyen ?? ''),
          _buildDetailRow('Mức lương tuyển:', customer.mucLuongTuyen ?? ''),
          _buildDetailRow('Lương BP:', customer.luongBP ?? ''),
          
          SizedBox(height: 20),
          
          _buildSectionHeader('Thông tin khác'),
          _buildDetailRow('Ghi chú:', customer.ghiChu ?? ''),
          _buildDetailRow('Đánh dấu:', customer.danhDau ?? ''),
          if (customer.ngayKhoiTao != null)
            _buildDetailRow('Ngày khởi tạo:', DateFormat('dd/MM/yyyy HH:mm').format(customer.ngayKhoiTao!)),
          if (customer.ngayCapNhatCuoi != null)
            _buildDetailRow('Cập nhật cuối:', DateFormat('dd/MM/yyyy HH:mm').format(customer.ngayCapNhatCuoi!)),
        ],
      ),
    );
  }

  Widget _buildContactsTab(List<KhachHangContactModel> contacts) {
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
             'Không có người liên hệ',
             style: TextStyle(fontSize: 18, color: Colors.grey),
           ),
         ],
       ),
     );
   }

   return ListView.builder(
     padding: EdgeInsets.all(16),
     itemCount: contacts.length,
     itemBuilder: (context, index) {
       final contact = contacts[index];
       return Card(
         margin: EdgeInsets.only(bottom: 12),
         child: Padding(
           padding: EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 children: [
                   CircleAvatar(
                     backgroundColor: buttonColor,
                     child: Text(
                       contact.hoTen?.isNotEmpty == true
                           ? contact.hoTen!.substring(0, 1).toUpperCase()
                           : '?',
                       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                     ),
                   ),
                   SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           contact.hoTen ?? 'Không có tên',
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             fontSize: 16,
                           ),
                         ),
                         if (contact.chucDanh != null && contact.chucDanh!.isNotEmpty)
                           Text(
                             contact.chucDanh!,
                             style: TextStyle(
                               color: Colors.grey[600],
                               fontSize: 14,
                             ),
                           ),
                       ],
                     ),
                   ),
                 ],
               ),
               
               if (contact.gioiTinh != null && contact.gioiTinh!.isNotEmpty ||
                   contact.soDienThoai != null && contact.soDienThoai!.isNotEmpty ||
                   contact.email != null && contact.email!.isNotEmpty ||
                   contact.nguonGoc != null && contact.nguonGoc!.isNotEmpty)
                 Padding(
                   padding: EdgeInsets.only(top: 12),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       if (contact.gioiTinh != null && contact.gioiTinh!.isNotEmpty)
                         _buildContactDetailRow('Giới tính:', contact.gioiTinh!),
                       if (contact.soDienThoai != null && contact.soDienThoai!.isNotEmpty)
                         _buildContactDetailRow('Điện thoại:', contact.soDienThoai!, isPhone: true),
                       if (contact.email != null && contact.email!.isNotEmpty)
                         _buildContactDetailRow('Email:', contact.email!),
                       if (contact.nguonGoc != null && contact.nguonGoc!.isNotEmpty)
                         _buildContactDetailRow('Nguồn gốc:', contact.nguonGoc!),
                       if (contact.ngayTao != null)
                         _buildContactDetailRow('Ngày tạo:', DateFormat('dd/MM/yyyy').format(contact.ngayTao!)),
                     ],
                   ),
                 ),
             ],
           ),
         ),
       );
     },
   );
 }

 Widget _buildSectionHeader(String title) {
   return Padding(
     padding: EdgeInsets.only(bottom: 12),
     child: Text(
       title,
       style: TextStyle(
         fontSize: 18,
         fontWeight: FontWeight.bold,
         color: appBarTop,
       ),
     ),
   );
 }

 Widget _buildDetailRow(String label, String value, {bool isPhone = false}) {
   if (value.isEmpty) return SizedBox.shrink();
   
   return Padding(
     padding: EdgeInsets.only(bottom: 8),
     child: Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         SizedBox(
           width: 120,
           child: Text(
             label,
             style: TextStyle(
               fontSize: 14,
               color: Colors.grey[700],
               fontWeight: FontWeight.w500,
             ),
           ),
         ),
         Expanded(
           child: isPhone
               ? GestureDetector(
                   onTap: () => _callCustomer(value),
                   child: Text(
                     value,
                     style: TextStyle(
                       fontSize: 14,
                       color: Colors.blue,
                       decoration: TextDecoration.underline,
                     ),
                   ),
                 )
               : SelectableText(
                   value,
                   style: TextStyle(fontSize: 14),
                 ),
         ),
       ],
     ),
   );
 }

 Widget _buildContactDetailRow(String label, String value, {bool isPhone = false}) {
   return Padding(
     padding: EdgeInsets.only(bottom: 4),
     child: Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         SizedBox(
           width: 100,
           child: Text(
             label,
             style: TextStyle(
               fontSize: 12,
               color: Colors.grey[600],
               fontWeight: FontWeight.w500,
             ),
           ),
         ),
         Expanded(
           child: isPhone
               ? GestureDetector(
                   onTap: () => _callCustomer(value),
                   child: Text(
                     value,
                     style: TextStyle(
                       fontSize: 12,
                       color: Colors.blue,
                       decoration: TextDecoration.underline,
                     ),
                   ),
                 )
               : Text(
                   value,
                   style: TextStyle(fontSize: 12),
                 ),
         ),
       ],
     ),
   );
 }

 Future<void> _openMaps(String address) async {
   if (address.isEmpty) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Không có địa chỉ để mở bản đồ'))
     );
     return;
   }
   
   final encodedAddress = Uri.encodeComponent(address);
   final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
   
   if (await url_launcher.canLaunchUrl(mapsUrl)) {
     await url_launcher.launchUrl(mapsUrl, mode: url_launcher.LaunchMode.externalApplication);
   } else {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Không thể mở bản đồ cho địa chỉ này'))
     );
   }
 }

 void _showFilterDialog() {
   showDialog(
     context: context,
     builder: (context) {
       return AlertDialog(
         title: Text('Lọc khách hàng'),
         content: Container(
           width: double.maxFinite,
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               _buildFilterOption('Tất cả'),
               Divider(),
               Text('Phân loại:', style: TextStyle(fontWeight: FontWeight.bold)),
               ..._getUniqueValues('phanLoai').map((value) => _buildFilterOption(value)),
               SizedBox(height: 8),
               Text('Vùng miền:', style: TextStyle(fontWeight: FontWeight.bold)),
               ..._getUniqueValues('vungMien').map((value) => _buildFilterOption(value)),
               SizedBox(height: 8),
               Text('Loại hình:', style: TextStyle(fontWeight: FontWeight.bold)),
               ..._getUniqueValues('loaiHinh').map((value) => _buildFilterOption(value)),
             ],
           ),
         ),
         actions: [
           TextButton(
             child: Text('Đóng'),
             onPressed: () {
               Navigator.of(context).pop();
             },
           ),
         ],
       );
     },
   );
 }

 List<String> _getUniqueValues(String field) {
   final Set<String> values = Set<String>();
   
   for (var customer in _khachHangList) {
     String? value;
     
     switch (field) {
       case 'phanLoai':
         value = customer.phanLoai;
         break;
       case 'vungMien':
         value = customer.vungMien;
         break;
       case 'loaiHinh':
         value = customer.loaiHinh;
         break;
     }
     
     if (value != null && value.isNotEmpty) {
       values.add(value);
     }
   }
   
   return values.toList()..sort();
 }

 Widget _buildFilterOption(String value) {
   return RadioListTile<String>(
     title: Text(value),
     value: value,
     groupValue: _filterBy,
     onChanged: (newValue) {
       Navigator.pop(context);
       if (newValue != null) {
         _updateFilter(newValue);
       }
     },
   );
 }

 void _showSortDialog() {
   showDialog(
     context: context,
     builder: (context) {
       return AlertDialog(
         title: Text('Sắp xếp theo'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             _buildSortOption('tenDuAn', 'Tên dự án'),
             _buildSortOption('vungMien', 'Vùng miền'),
             _buildSortOption('phanLoai', 'Phân loại'),
             _buildSortOption('ngayCapNhatCuoi', 'Ngày cập nhật'),
           ],
         ),
         actions: [
           TextButton(
             child: Text('Đóng'),
             onPressed: () {
               Navigator.of(context).pop();
             },
           ),
         ],
       );
     },
   );
 }

 Widget _buildSortOption(String field, String label) {
   return RadioListTile<String>(
     title: Row(
       children: [
         Text(label),
         SizedBox(width: 8),
         if (_sortBy == field)
           Icon(
             _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
             size: 16,
           ),
       ],
     ),
     value: field,
     groupValue: _sortBy,
     onChanged: (newValue) {
       Navigator.pop(context);
       if (newValue != null) {
         _updateSort(newValue);
       }
     },
   );
 }
}