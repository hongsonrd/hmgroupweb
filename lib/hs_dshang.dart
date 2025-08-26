import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'db_helper.dart';
import 'table_models.dart';
import 'dart:async';
import 'dart:math';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
class HSDSHangScreen extends StatefulWidget {
  const HSDSHangScreen({Key? key}) : super(key: key);

  @override
  _HSDSHangScreenState createState() => _HSDSHangScreenState();
}

class _HSDSHangScreenState extends State<HSDSHangScreen> with SingleTickerProviderStateMixin {
  final DBHelper _dbHelper = DBHelper();
  late TabController _tabController;
  String _currentUser = '';
  bool _canEditItems = false; 
  // Danh sách hàng tab variables
  List<DSHangModel> _allDSHang = [];
  List<DSHangModel> _filteredDSHang = [];
  bool _isLoadingDSHang = true;
  String _searchQueryDSHang = '';
    List<String> _phanLoai1List = [];
  List<String> _donViList = [];
  // Tồn kho tab variables
  List<TonKhoModel> _allTonKho = [];
  List<TonKhoModel> _filteredTonKho = [];
  bool _isLoadingTonKho = true;
  String _searchQueryTonKho = '';
  List<String> _warehouseList = [];
  String? _selectedWarehouse;
  
  // Filter values for DSHang tab
  String? _selectedNhaCungCap;
  String? _selectedThuongHieu;
  String? _selectedTrangThai;
  String? _selectedThoiHan;
  
  // Lists for filter dropdowns
  List<String> _nhaCungCapList = [];
  List<String> _thuongHieuList = [];
  List<String> _trangThaiList = ['Đang kinh doanh', 'Ngừng kinh doanh', 'Hết hàng'];
  List<String> _thoiHanList = ['Có thời hạn', 'Không thời hạn'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCurrentUser();
    _loadDSHangData();
  }
  Future<void> _exportDSHangToExcel() async {
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
    var sheetObject = excel['Danh sách hàng'];

    // Add headers
    List<String> headers = [
      'STT',
      'UID',
      'SKU',
      'Mã nhập kho',
      'Tên sản phẩm',
      'Phân loại',
      'Chất liệu',
      'Màu sắc',
      'Thương hiệu',
      'Nhà cung cấp',
      'Xuất xứ',
      'Đơn vị',
      'Kích thước',
      'Dung tích',
      'Khối lượng',
      'Quy cách đóng gói',
      'Số lượng đóng gói',
      'Kích thước đóng gói',
      'Công dụng',
      'Mô tả',
      'Có thời hạn',
      'Hàng tiêu hao',
      'Thời hạn sử dụng',
    ];

    // Add headers to Excel
    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
    }

    // Add data rows
    for (int rowIndex = 0; rowIndex < _filteredDSHang.length; rowIndex++) {
      final item = _filteredDSHang[rowIndex];
      final excelRowIndex = rowIndex + 1;

      List<String> rowData = [
        (rowIndex + 1).toString(), // STT
        item.uid ?? '',
        item.sku ?? '',
        item.maNhapKho ?? '',
        item.tenSanPham ?? '',
        item.phanLoai1 ?? '',
        item.chatLieu ?? '',
        item.mauSac ?? '',
        item.thuongHieu ?? '',
        item.nhaCungCap ?? '',
        item.xuatXu ?? '',
        item.donVi ?? '',
        item.kichThuoc ?? '',
        item.dungTich ?? '',
        item.khoiLuong ?? '',
        item.quyCachDongGoi ?? '',
        item.soLuongDongGoi?.toString() ?? '',
        item.kichThuocDongGoi ?? '',
        item.congDung ?? '',
        item.moTa ?? '',
        item.coThoiHan == true ? 'Có' : 'Không',
        item.hangTieuHao == true ? 'Có' : 'Không',
        item.thoiHanSuDung ?? '',
      ];

      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: excelRowIndex));
        cell.value = rowData[colIndex];
      }
    }

    // Generate filename
    final fileName = 'DanhSachHang_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.xlsx';
    
    // Save and handle based on user choice
    final fileBytes = excel.encode()!;
    
    // Close loading dialog
    Navigator.pop(context);
    
    if (choice == 'share') {
      await _handleShareDSHang(fileBytes, fileName);
    } else {
      await _handleSaveToAppFolderDSHang(fileBytes, fileName);
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

Future<void> _handleShareDSHang(List<int> fileBytes, String fileName) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(fileBytes);
    
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Danh sách hàng được xuất từ ứng dụng',
      subject: 'Danh sách hàng - $fileName',
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
      SnackBar(content: Text('Đã xuất ${_filteredDSHang.length} sản phẩm ra Excel')),
    );
  } catch (e) {
    print('Error sharing file: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi chia sẻ file: $e')),
    );
  }
}

Future<void> _handleSaveToAppFolderDSHang(List<int> fileBytes, String fileName) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final appFolder = Directory('${directory.path}/DanhSach_Hang');
    
    // Create folder if it doesn't exist
    if (!await appFolder.exists()) {
      await appFolder.create(recursive: true);
    }
    
    final filePath = '${appFolder.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    
    // Show success dialog with option to open folder
    await _showSaveSuccessDialogDSHang(appFolder.path, fileName);
    
  } catch (e) {
    print('Error saving to app folder: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi lưu file: $e')),
    );
  }
}

Future<void> _showSaveSuccessDialogDSHang(String folderPath, String fileName) async {
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
            Text('Đã xuất ${_filteredDSHang.length} sản phẩm'),
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
              await _openFolderDSHang(folderPath);
            },
            icon: Icon(Icons.folder_open, size: 16),
            label: Text('Mở thư mục'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF837826),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _openFolderDSHang(String folderPath) async {
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
  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';
      
      setState(() {
        _currentUser = username;
        // Check if user has edit permissions - specifically for the authorized users
        _canEditItems = ['hm.tason', 'hm.manhha', 'hm.lehoa' , 'hm.thanhthao', 'hm.thanhhao', 'hm.phiminh']
            .contains(_currentUser);
      });
      
      print('Current user: $_currentUser, Can edit items: $_canEditItems');
    } catch (e) {
      print('Error loading user credentials: $e');
      setState(() {
        _currentUser = '';
        _canEditItems = false;
      });
    }
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && _isLoadingTonKho) {
      _loadTonKhoData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDSHangData() async {
    setState(() {
      _isLoadingDSHang = true;
    });

    try {
      final dshangList = await _dbHelper.getAllDSHang();
      print("Loaded ${dshangList.length} DSHang items from database");
      
      // Extract unique values for filters and dropdowns
      final nhaCungCapSet = <String>{};
      final thuongHieuSet = <String>{};
      final phanLoai1Set = <String>{};
      final donViSet = <String>{};
      
      for (var item in dshangList) {
        if (item.nhaCungCap != null && item.nhaCungCap!.isNotEmpty) {
          nhaCungCapSet.add(item.nhaCungCap!);
        }
        if (item.thuongHieu != null && item.thuongHieu!.isNotEmpty) {
          thuongHieuSet.add(item.thuongHieu!);
        }
        if (item.phanLoai1 != null && item.phanLoai1!.isNotEmpty) {
          phanLoai1Set.add(item.phanLoai1!);
        }
        if (item.donVi != null && item.donVi!.isNotEmpty) {
          donViSet.add(item.donVi!);
        }
      }
      
      setState(() {
        _allDSHang = dshangList;
        _applyDSHangFilters();
        
        // Update all dropdown lists
        _nhaCungCapList = nhaCungCapSet.toList()..sort();
        _thuongHieuList = thuongHieuSet.toList()..sort();
        _phanLoai1List = phanLoai1Set.toList()..sort();
        _donViList = donViSet.toList()..sort();
        
        _isLoadingDSHang = false;
      });
    } catch (e) {
      print('Error loading DSHang data: $e');
      setState(() {
        _isLoadingDSHang = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải dữ liệu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _loadTonKhoData() async {
    setState(() {
      _isLoadingTonKho = true;
    });

    try {
      final tonKhoList = await _dbHelper.getAllTonKho();
      print("Loaded ${tonKhoList.length} TonKho items from database");
      
      // Extract unique warehouse IDs for filters
      final warehouseSet = <String>{};
      for (var item in tonKhoList) {
        if (item.khoHangID != null && item.khoHangID!.isNotEmpty) {
          warehouseSet.add(item.khoHangID!);
        }
      }
      
      setState(() {
        _allTonKho = tonKhoList;
        _applyTonKhoFilters();
        _warehouseList = warehouseSet.toList()..sort();
        _isLoadingTonKho = false;
      });
    } catch (e) {
      print('Error loading TonKho data: $e');
      setState(() {
        _isLoadingTonKho = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải dữ liệu tồn kho: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyDSHangFilters() {
    setState(() {
      _filteredDSHang = _allDSHang.where((item) {
        // Apply search filter
        final matchesSearch = _searchQueryDSHang.isEmpty ||
            (item.tenSanPham?.toLowerCase().contains(_searchQueryDSHang.toLowerCase()) ?? false) ||
            (item.sku?.toLowerCase().contains(_searchQueryDSHang.toLowerCase()) ?? false) ||
            (item.maNhapKho?.toLowerCase().contains(_searchQueryDSHang.toLowerCase()) ?? false);
        
        // Apply supplier filter
        final matchesNhaCungCap = _selectedNhaCungCap == null ||
            item.nhaCungCap == _selectedNhaCungCap;
        
        // Apply brand filter
        final matchesThuongHieu = _selectedThuongHieu == null ||
            item.thuongHieu == _selectedThuongHieu;
        
        // Apply status filter (simplified for demonstration)
        bool matchesTrangThai = true;
        if (_selectedTrangThai != null) {
          // This is a simplification - you would need to map your actual status values
          if (_selectedTrangThai == 'Đang kinh doanh') {
            matchesTrangThai = true; // Replace with actual condition
          } else if (_selectedTrangThai == 'Ngừng kinh doanh') {
            matchesTrangThai = false; // Replace with actual condition
          } else if (_selectedTrangThai == 'Hết hàng') {
            matchesTrangThai = false; // Replace with actual condition
          }
        }
        
        // Apply expiration filter
        bool matchesThoiHan = true;
        if (_selectedThoiHan != null) {
          if (_selectedThoiHan == 'Có thời hạn') {
            matchesThoiHan = item.coThoiHan == true;
          } else if (_selectedThoiHan == 'Không thời hạn') {
            matchesThoiHan = item.coThoiHan == false;
          }
        }
        
        return matchesSearch && matchesNhaCungCap && matchesThuongHieu && 
               matchesTrangThai && matchesThoiHan;
      }).toList();
    });
  }

  void _applyTonKhoFilters() {
    setState(() {
      _filteredTonKho = _allTonKho.where((item) {
        // Apply search filter
        bool matchesSearch = true;
        if (_searchQueryTonKho.isNotEmpty) {
          // Get product details to search by product name
          DSHangModel? product = _getProductById(item.maHangID);
          matchesSearch = item.maHangID?.toLowerCase().contains(_searchQueryTonKho.toLowerCase()) ?? false ||
                         (product?.tenSanPham?.toLowerCase().contains(_searchQueryTonKho.toLowerCase()) ?? false);
        }
        
        // Apply warehouse filter
        final matchesWarehouse = _selectedWarehouse == null ||
            item.khoHangID == _selectedWarehouse;
        
        return matchesSearch && matchesWarehouse;
      }).toList();
      
      // Sort by lowest stock first
      _filteredTonKho.sort((a, b) => (a.soLuongHienTai ?? 0).compareTo(b.soLuongHienTai ?? 0));
    });
  }

  // Helper method to get product details by ID
  DSHangModel? _getProductById(String? productId) {
    if (productId == null) return null;
    try {
      return _allDSHang.firstWhere((element) => element.uid == productId);
    } catch (e) {
      return null;
    }
  }

  void _resetDSHangFilters() {
    setState(() {
      _searchQueryDSHang = '';
      _selectedNhaCungCap = null;
      _selectedThuongHieu = null;
      _selectedTrangThai = null;
      _selectedThoiHan = null;
      _applyDSHangFilters();
    });
  }

  void _resetTonKhoFilters() {
    setState(() {
      _searchQueryTonKho = '';
      _selectedWarehouse = null;
      _applyTonKhoFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Colors with hex values
    final Color appBarTop = Color(0xFFb8cc32);
    final Color appBarBottom = Color(0xFFe1ff72);
    final Color tabBarColor = Color(0xFF5a530f);
    final Color buttonColor = Color(0xFF837826);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Hàng & Tồn kho', style: TextStyle(color: Colors.black)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [appBarTop, appBarBottom],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black.withOpacity(0.6),
          tabs: [
            Tab(text: 'Danh sách hàng'),
            Tab(text: 'Tồn kho'),
          ],
        ),
        actions: [
          // Add "Thêm hàng" button for authorized users when in the first tab
          if (_canEditItems && _tabController.index == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: OutlinedButton(
                onPressed: () => _showEditItemDialog(null), // Pass null for new item
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.orange),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text('Thêm hàng'),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _tabController.index == 0 ? _loadDSHangData() : _loadTonKhoData();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Danh sách hàng
          _buildDanhSachHangTab(),
          
          // Tab 2: Tồn kho
          _buildTonKhoTab(),
        ],
      ),
    );
  }

  Color _getColorFromName(String color) {
    final colorName = color.toLowerCase();
    if (colorName.contains('đỏ')) return Colors.red;
    if (colorName.contains('xanh') && colorName.contains('dương')) return Colors.blue;
    if (colorName.contains('xanh') && colorName.contains('lá')) return Colors.green;
    if (colorName.contains('xanh')) return Colors.blue;
    if (colorName.contains('vàng')) return Colors.yellow;
    if (colorName.contains('cam')) return Colors.orange;
    if (colorName.contains('tím')) return Colors.purple;
    if (colorName.contains('hồng')) return Colors.pink;
    if (colorName.contains('nâu')) return Colors.brown;
    if (colorName.contains('đen')) return Colors.black;
    if (colorName.contains('trắng')) return Colors.white;
    if (colorName.contains('xám')) return Colors.grey;
    // Default color
    return Colors.grey.shade300;
  }

  Widget _buildDanhSachHangTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm tên sản phẩm, mã hàng...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              _searchQueryDSHang = value;
              _applyDSHangFilters();
            },
          ),
        ),
        // Results count and download button
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
  child: Row(
    children: [
      Text(
        'Kết quả: ${_filteredDSHang.length} / ${_allDSHang.length}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
      Spacer(),
      ElevatedButton.icon(
        onPressed: _filteredDSHang.isNotEmpty ? _exportDSHangToExcel : null,
        icon: Icon(Icons.download, size: 18),
        label: Text('Xuất Excel'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF837826),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size(0, 36),
        ),
      ),
    ],
  ),
),

SizedBox(height: 4),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: Text(
    'Cập nhật: ${DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now())}',
    style: TextStyle(
      fontSize: 12,
      color: Colors.grey[500],
    ),
  ),
),
        // Filter section
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Brand filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownButton<String>(
                        hint: Text('Thương hiệu'),
                        value: _selectedThuongHieu,
                        items: [null, ..._thuongHieuList].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value ?? 'Tất cả thương hiệu'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedThuongHieu = value;
                            _applyDSHangFilters();
                          });
                        },
                      ),
                    ),
                    
                    // Supplier filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownButton<String>(
                        hint: Text('Nhà cung cấp'),
                        value: _selectedNhaCungCap,
                        items: [null, ..._nhaCungCapList].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value ?? 'Tất cả nhà cung cấp'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedNhaCungCap = value;
                            _applyDSHangFilters();
                          });
                        },
                      ),
                    ),
                    
                    // Status filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownButton<String>(
                        hint: Text('Trạng thái'),
                        value: _selectedTrangThai,
                        items: [null, ..._trangThaiList].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value ?? 'Tất cả trạng thái'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTrangThai = value;
                            _applyDSHangFilters();
                          });
                        },
                      ),
                    ),
                    
                    // Expiration filter
                    DropdownButton<String>(
                      hint: Text('Thời hạn'),
                      value: _selectedThoiHan,
                      items: [null, ..._thoiHanList].map((value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value ?? 'Tất cả loại hạn'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedThoiHan = value;
                          _applyDSHangFilters();
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // Reset filters button
              if (_selectedNhaCungCap != null || _selectedThuongHieu != null || 
                  _selectedTrangThai != null || _selectedThoiHan != null || _searchQueryDSHang.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  icon: Icon(Icons.clear, size: 16),
                  label: Text('Xóa bộ lọc'),
                  onPressed: _resetDSHangFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Divider(),
        
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kết quả: ${_filteredDSHang.length} / ${_allDSHang.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Cập nhật: ${DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        
        Divider(),
        
        // Product list
        Expanded(
          child: _isLoadingDSHang
              ? Center(child: CircularProgressIndicator())
              : _filteredDSHang.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy sản phẩm',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredDSHang.length,
                      itemBuilder: (context, index) {
                        final item = _filteredDSHang[index];
                        return buildItemCard(item);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTonKhoTab() {
    if (_isLoadingTonKho && _allTonKho.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm tên sản phẩm, mã hàng...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              _searchQueryTonKho = value;
              _applyTonKhoFilters();
            },
          ),
        ),
        
        // Filter section
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Warehouse filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: DropdownButton<String>(
                        hint: Text('Kho hàng'),
                        value: _selectedWarehouse,
                        items: [null, ..._warehouseList].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value ?? 'Tất cả kho hàng'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedWarehouse = value;
                            _applyTonKhoFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // Reset filters button
              if (_selectedWarehouse != null || _searchQueryTonKho.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  icon: Icon(Icons.clear, size: 16),
                  label: Text('Xóa bộ lọc'),
                  onPressed: _resetTonKhoFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Divider(),
        
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kết quả: ${_filteredTonKho.length} / ${_allTonKho.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Cập nhật: ${DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        
        Divider(),
        
        // Ton kho list
        Expanded(
          child: _isLoadingTonKho
              ? Center(child: CircularProgressIndicator())
              : _filteredTonKho.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy sản phẩm',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTonKho.length,
                      itemBuilder: (context, index) {
                        final tonKhoItem = _filteredTonKho[index];
                        final productInfo = _getProductById(tonKhoItem.maHangID);
                        return buildTonKhoCard(tonKhoItem, productInfo);
                      },
                    ),
        ),
      ],
    );
  }

  Widget buildItemCard(DSHangModel item) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(
              item.tenSanPham ?? 'Không có tên',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('Xuất xứ: ${item.xuatXu ?? 'Chưa có thông tin'}'),
                SizedBox(height: 2),
                Text('Phân loại: ${item.phanLoai1 ?? 'Chưa phân loại'}'),
              ],
            ),
            trailing: item.mauSac != null && item.mauSac!.isNotEmpty
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                      color: _getColorFromName(item.mauSac!),
                    ),
                  )
                : null,
            onTap: () => _showItemDetails(item),
          ),
          
          // Show "Sửa hàng" button for authorized users
          if (_canEditItems) 
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('Sửa hàng'),
                    onPressed: () => _showEditItemDialog(item),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  Future<void> _showEditItemDialog(DSHangModel? item) async {
  final bool isNewItem = item == null;
  
  // Generate temporary random UID for new items
  String? tempUid;
  if (isNewItem) {
    tempUid = 'SP${DateTime.now().millisecondsSinceEpoch}';
  }
  
  // Define controllers for text fields with existing values if editing
  final TextEditingController maNhapKhoController = TextEditingController(text: item?.maNhapKho ?? '');
  final TextEditingController skuController = TextEditingController(text: item?.sku ?? '');
  final TextEditingController tenSanPhamController = TextEditingController(text: item?.tenSanPham ?? '');
  final TextEditingController chatLieuController = TextEditingController(text: item?.chatLieu ?? '');
  final TextEditingController mauSacController = TextEditingController(text: item?.mauSac ?? '');
  final TextEditingController xuatXuController = TextEditingController(text: item?.xuatXu ?? '');
  final TextEditingController uidController = TextEditingController(text: item?.uid ?? tempUid);
  
  // Initial values for dropdowns
  String? selectedPhanLoai = item?.phanLoai1;
  String? selectedThuongHieu = item?.thuongHieu;
  String? selectedNhaCungCap = item?.nhaCungCap;
  String? selectedDonVi = item?.donVi;
  
  // Initial values for checkboxes (converted from int/boolean)
  bool hasExpiration = item?.coThoiHan == true;
  bool isConsumable = item?.hangTieuHao == true;
  
  // Title of the dialog based on whether we're adding or editing
  final String dialogTitle = isNewItem ? 'Thêm hàng mới' : 'Sửa thông tin hàng';
  
  // Function to update UID based on MaNhapKho and TenSanPham
  void updateUID() {
    final maNhapKho = maNhapKhoController.text.trim();
    final tenSanPham = tenSanPhamController.text.trim();
    
    // Only update UID if both fields have values and it's a new item,
    // or if we're editing and the UID follows the expected pattern
    if (maNhapKho.isNotEmpty && tenSanPham.isNotEmpty) {
      if (isNewItem || (item?.uid == null) || !item!.uid!.contains(' - ')) {
        uidController.text = '$maNhapKho - $tenSanPham';
      }
    }
  }
  
  // Show the dialog
  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(dialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UID field (read-only)
                  TextField(
                    controller: uidController,
                    readOnly: true, // Always read-only
                    decoration: InputDecoration(
                      labelText: 'Mã sản phẩm (UID)',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // MaNhapKho field (required)
                  TextField(
                    controller: maNhapKhoController,
                    decoration: InputDecoration(
                      labelText: 'Mã nhập kho *',
                      border: OutlineInputBorder(),
                      hintText: 'Nhập mã nhập kho',
                    ),
                    onChanged: (value) {
                      updateUID();
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // SKU field
                  TextField(
                    controller: skuController,
                    decoration: InputDecoration(
                      labelText: 'SKU',
                      border: OutlineInputBorder(),
                      hintText: 'Nhập mã SKU',
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Product name field (required)
                  TextField(
                    controller: tenSanPhamController,
                    decoration: InputDecoration(
                      labelText: 'Tên sản phẩm *',
                      border: OutlineInputBorder(),
                      hintText: 'Nhập tên sản phẩm',
                    ),
                    onChanged: (value) {
                      updateUID();
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Category dropdown (PhanLoai1) - now required
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Phân loại *',  // Added asterisk to indicate it's required
                      border: OutlineInputBorder(),
                      errorText: selectedPhanLoai == null ? 'Vui lòng chọn phân loại' : null,
                    ),
                    value: selectedPhanLoai,
                    hint: Text('Chọn phân loại'),
                    items: _phanLoai1List.isEmpty 
                        ? [DropdownMenuItem<String>(value: 'Chưa phân loại', child: Text('Chưa phân loại'))]
                        : _phanLoai1List.map((value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPhanLoai = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Material field
                  TextField(
                    controller: chatLieuController,
                    decoration: InputDecoration(
                      labelText: 'Chất liệu',
                      border: OutlineInputBorder(),
                      hintText: 'Nhập chất liệu',
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Color field
                  TextField(
                    controller: mauSacController,
                    decoration: InputDecoration(
                      labelText: 'Màu sắc',
                      border: OutlineInputBorder(),
                      hintText: 'Nhập màu sắc',
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Brand dropdown - now required
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Thương hiệu *',  // Added asterisk to indicate it's required
                      border: OutlineInputBorder(),
                      errorText: selectedThuongHieu == null ? 'Vui lòng chọn thương hiệu' : null,
                    ),
                    value: selectedThuongHieu,
                    hint: Text('Chọn thương hiệu'),
                    items: _thuongHieuList.isEmpty 
                        ? [DropdownMenuItem<String>(value: 'Chưa xác định', child: Text('Chưa xác định'))]
                        : _thuongHieuList.map((value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedThuongHieu = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Supplier dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Nhà cung cấp',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedNhaCungCap,
                    hint: Text('Chọn nhà cung cấp'),
                    items: _nhaCungCapList.isEmpty 
                        ? [DropdownMenuItem<String>(value: 'Chưa xác định', child: Text('Chưa xác định'))]
                        : _nhaCungCapList.map((value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedNhaCungCap = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // DonVi dropdown - now required
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Đơn vị *',  // Added asterisk to indicate it's required
                      border: OutlineInputBorder(),
                      errorText: selectedDonVi == null ? 'Vui lòng chọn đơn vị' : null,
                    ),
                    value: selectedDonVi,
                    hint: Text('Chọn đơn vị'),
                    items: _donViList.isEmpty 
                        ? [DropdownMenuItem<String>(value: 'Cái', child: Text('Cái'))]
                        : _donViList.map((value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDonVi = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Origin field
                  TextField(
                    controller: xuatXuController,
                    decoration: InputDecoration(
                      labelText: 'Xuất xứ',
                      border: OutlineInputBorder(),
                      hintText: 'Nhập xuất xứ',
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Checkbox for expiration
                  CheckboxListTile(
                    title: Text('Có thời hạn sử dụng'),
                    value: hasExpiration,
                    onChanged: (value) {
                      setState(() {
                        hasExpiration = value ?? false;
                      });
                    },
                  ),
                  
                  // Checkbox for consumable
                  CheckboxListTile(
                    title: Text('Hàng tiêu hao'),
                    value: isConsumable,
                    onChanged: (value) {
                      setState(() {
                        isConsumable = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validate required fields
                  if (maNhapKhoController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Vui lòng nhập mã nhập kho'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  if (tenSanPhamController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Vui lòng nhập tên sản phẩm'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  // Validate the newly required fields
                  if (selectedPhanLoai == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Vui lòng chọn phân loại'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  if (selectedThuongHieu == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Vui lòng chọn thương hiệu'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  if (selectedDonVi == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Vui lòng chọn đơn vị'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  // Create a product object
                  final updatedProduct = DSHangModel(
                    uid: uidController.text,
                    sku: skuController.text.trim(),
                    counter: item?.counter,
                    maNhapKho: maNhapKhoController.text.trim(),
                    tenSanPham: tenSanPhamController.text.trim(),
                    phanLoai1: selectedPhanLoai,
                    chatLieu: chatLieuController.text.trim(),
                    mauSac: mauSacController.text.trim(),
                    thuongHieu: selectedThuongHieu,
                    nhaCungCap: selectedNhaCungCap,
                    xuatXu: xuatXuController.text.trim(),
                    donVi: selectedDonVi,
                    coThoiHan: hasExpiration,
                    hangTieuHao: isConsumable,
                    // Preserve other fields if editing
                    tenModel: item?.tenModel,
                    sanPhamGoc: item?.sanPhamGoc,
                    congDung: item?.congDung,
                    kichThuoc: item?.kichThuoc,
                    dungTich: item?.dungTich,
                    khoiLuong: item?.khoiLuong,
                    quyCachDongGoi: item?.quyCachDongGoi,
                    soLuongDongGoi: item?.soLuongDongGoi,
                    kichThuocDongGoi: item?.kichThuocDongGoi,
                    moTa: item?.moTa,
                    hinhAnh: item?.hinhAnh,
                    thoiHanSuDung: item?.thoiHanSuDung,
                  );
                  
                  // Send to server and save to database
                  _saveItemToServerAndDatabase(updatedProduct, isNewItem);
                  
                  Navigator.pop(context);
                },
                child: Text(isNewItem ? 'Thêm' : 'Lưu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF837826),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    },
  );
  
  // Clean up controllers
  maNhapKhoController.dispose();
  skuController.dispose();
  tenSanPhamController.dispose();
  chatLieuController.dispose();
  mauSacController.dispose();
  xuatXuController.dispose();
  uidController.dispose();
}
  Future<void> _saveItemToServerAndDatabase(DSHangModel item, bool isNewItem) async {
  setState(() {
    _isLoadingDSHang = true;
  });
  
  try {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('🧡 Đang xử lý'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            SizedBox(height: 16),
            Text(isNewItem ? 'Đang thêm sản phẩm mới...' : 'Đang cập nhật sản phẩm...'),
          ],
        ),
      ),
    );
    
    // Encode UID for URL
    final encodedUID = Uri.encodeComponent(item.uid!);
    
    // Prepare request body
    final Map<String, dynamic> requestBody = item.toMap();
    print(jsonEncode(requestBody));
    // Send to server
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldshangupdate/$encodedUID'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    
    // Close progress dialog
    Navigator.pop(context);
    
    if (response.statusCode == 200) {
      // Save to local database
      if (isNewItem) {
        await _dbHelper.insertDSHang(item);
      } else {
        await _dbHelper.updateDSHang(item);
      }
      
      // Reload data
      _loadDSHangData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNewItem ? 'Thêm sản phẩm thành công' : 'Cập nhật sản phẩm thành công'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      throw Exception('Server responded with status code ${response.statusCode}. Message: ${response.body}');
    }
  } catch (e) {
    print('Error saving item to server: $e');
    
    // Close progress dialog if still showing
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    setState(() {
      _isLoadingDSHang = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  Widget buildTonKhoCard(TonKhoModel tonKhoItem, DSHangModel? productInfo) {
    // Determine color based on stock level
    Color stockLevelColor = Colors.green;
    if (tonKhoItem.soLuongHienTai == null || tonKhoItem.soLuongHienTai == 0) {
      stockLevelColor = Colors.red;
    } else if (tonKhoItem.soLuongHienTai! < (tonKhoItem.soLuongDuTru ?? 5)) {
      stockLevelColor = Colors.orange;
    }
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        title: Text(
          productInfo?.tenSanPham ?? 'Sản phẩm không xác định',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('Mã hàng: ${tonKhoItem.maHangID ?? 'N/A'}'),
            SizedBox(height: 2),
            Text('Kho: ${tonKhoItem.khoHangID ?? 'Không xác định'}'),
          ],
        ),
        trailing: Container(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SL: ${tonKhoItem.soLuongHienTai?.toString() ?? '0'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: stockLevelColor,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Dự trữ: ${tonKhoItem.soLuongDuTru?.toString() ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
                            Text(
                 'ĐVT: ${productInfo?.donVi ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        onTap: () => _showTonKhoDetails(tonKhoItem, productInfo),
      ),
    );
  }
List<GiaoDichKhoModel> _transactionHistory = [];
bool _isLoadingTransactions = true;

  Future<void> _showTonKhoDetails(TonKhoModel tonKhoItem, DSHangModel? productInfo) async {
  setState(() {
    _isLoadingTonKho = true;
  });
  
  try {
    // Fetch batches for this product in this warehouse
    final batches = await _dbHelper.getLoHangForProduct(tonKhoItem.maHangID!, tonKhoItem.khoHangID!);
    
    // Sort batches by current quantity (lowest first)
    batches.sort((a, b) => (a.soLuongHienTai ?? 0).compareTo(b.soLuongHienTai ?? 0));
    
    // Get batch IDs for transaction history
    final batchIds = batches
        .where((batch) => batch.loHangID != null)
        .map((batch) => batch.loHangID!)
        .toList();
    
    // Fetch transaction history
    final transactions = await _dbHelper.getTransactionsByBatchIds(batchIds);
    
    setState(() {
      _isLoadingTonKho = false;
      _transactionHistory = transactions;
      _isLoadingTransactions = false;
    });
    
    _showTonKhoDetailsBottomSheet(tonKhoItem, productInfo, batches);
  } catch (e) {
    print('Error loading batch data: $e');
    setState(() {
      _isLoadingTonKho = false;
      _isLoadingTransactions = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi tải dữ liệu lô hàng: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  
  void _showTonKhoDetailsBottomSheet(TonKhoModel tonKhoItem, DSHangModel? productInfo, List<LoHangModel> batches) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DefaultTabController(
        length: 2,
        child: DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: EdgeInsets.only(top: 8, bottom: 16),
                  ),
                ),
                
                // Product header (static)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      if (productInfo != null && productInfo.hinhAnh != null && productInfo.hinhAnh!.isNotEmpty)
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                productInfo.hinhAnh!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(Icons.image_not_supported, size: 32, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      Text(
                        productInfo?.tenSanPham ?? 'Sản phẩm không xác định',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      SizedBox(height: 4),
                      
                      Text(
                        'Mã: ${productInfo?.uid ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Tab bar
                Container(
                  color: Colors.grey[100],
                  child: TabBar(
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: Colors.blue,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2, size: 16),
                            SizedBox(width: 4),
                            Text('Chi tiết lô'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 16),
                            SizedBox(width: 4),
                            Text('Lịch sử XN'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Batch details
                      _buildBatchDetailsTab(tonKhoItem, batches, scrollController),
                      
                      // Tab 2: Transaction history
                      _buildTransactionHistoryTab(scrollController),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
Widget _buildBatchDetailsTab(TonKhoModel tonKhoItem, List<LoHangModel> batches, ScrollController scrollController) {
  return SingleChildScrollView(
    controller: scrollController,
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inventory summary
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kho hàng:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    tonKhoItem.khoHangID ?? 'Không xác định',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Số lượng hiện tại:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${tonKhoItem.soLuongHienTai?.toString() ?? '0'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _getStockLevelColor(tonKhoItem),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dự trữ tối thiểu:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${tonKhoItem.soLuongDuTru?.toString() ?? 'N/A'}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (tonKhoItem.soLuongCanXuat != null) ...[
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cần xuất:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${tonKhoItem.soLuongCanXuat}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        SizedBox(height: 24),
        
        // Batches section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chi tiết lô hàng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${batches.length} lô',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        // No batches message
        if (batches.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Không có lô hàng nào',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        
        // Batch list
        ...batches.map((batch) => _buildBatchItem(batch)),
        
        SizedBox(height: 32),
      ],
    ),
  );
}

// Create the transaction history tab content
Widget _buildTransactionHistoryTab(ScrollController scrollController) {
  return SingleChildScrollView(
    controller: scrollController,
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lịch sử xuất nhập',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_transactionHistory.length} giao dịch',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Loading indicator
        if (_isLoadingTransactions)
          Center(child: CircularProgressIndicator()),
        
        // No transactions message
        if (!_isLoadingTransactions && _transactionHistory.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Không có giao dịch nào',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        
        // Transaction list
        ..._transactionHistory.map((transaction) => _buildTransactionItem(transaction)),
        
        SizedBox(height: 32),
      ],
    ),
  );
}

// Build individual transaction item
Widget _buildTransactionItem(GiaoDichKhoModel transaction) {
  // Format date and time
  String formattedDate = 'N/A';
  String formattedTime = 'N/A';
  
  if (transaction.ngay != null) {
    try {
      final date = DateTime.parse(transaction.ngay!);
      formattedDate = DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      formattedDate = transaction.ngay!;
    }
  }
  
  if (transaction.gio != null) {
    formattedTime = transaction.gio!;
  }
  
  // Determine transaction type color and icon
  Color transactionColor = Colors.grey;
  IconData transactionIcon = Icons.swap_horiz;
  
  if (transaction.loaiGiaoDich != null) {
    final type = transaction.loaiGiaoDich!.toLowerCase();
    if (type.contains('nhập') || type.contains('import')) {
      transactionColor = Colors.green;
      transactionIcon = Icons.arrow_downward;
    } else if (type.contains('xuất') || type.contains('export')) {
      transactionColor = Colors.red;
      transactionIcon = Icons.arrow_upward;
    }
  }
  
  return Card(
    margin: EdgeInsets.symmetric(vertical: 6),
    elevation: 1,
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: transactionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  transactionIcon,
                  color: transactionColor,
                  size: 16,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  transaction.loaiGiaoDich ?? 'Không xác định',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: transactionColor,
                  ),
                ),
              ),
              Text(
                '$formattedDate $formattedTime',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Transaction details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (transaction.maGiaoDich != null)
                      Text(
                        'Mã GD: ${transaction.maGiaoDich}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (transaction.loHangID != null)
                      Text(
                        'Lô: ${transaction.loHangID}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SL: ${transaction.soLuong?.toString() ?? 'N/A'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: transactionColor,
                    ),
                  ),
                  if (transaction.thucTe != null && transaction.thucTe != transaction.soLuong)
                    Text(
                      'Thực tế: ${transaction.thucTe}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // User and status
          if (transaction.nguoiDung != null || transaction.trangThai != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                if (transaction.nguoiDung != null)
                  Expanded(
                    child: Text(
                      'Người dùng: ${transaction.nguoiDung}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                if (transaction.trangThai != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getTransactionStatusColor(transaction.trangThai),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transaction.trangThai!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          
          // Notes
          if (transaction.ghiChu != null && transaction.ghiChu!.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                'Ghi chú: ${transaction.ghiChu}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

// Helper method to get transaction status color
Color _getTransactionStatusColor(String? status) {
  if (status == null) return Colors.grey;
  
  switch (status.toLowerCase()) {
    case 'hoàn thành':
    case 'completed':
    case 'success':
      return Colors.green;
    case 'đang xử lý':
    case 'processing':
    case 'pending':
      return Colors.orange;
    case 'hủy':
    case 'cancelled':
    case 'failed':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
 
 Color _getStockLevelColor(TonKhoModel tonKhoItem) {
   if (tonKhoItem.soLuongHienTai == null || tonKhoItem.soLuongHienTai == 0) {
     return Colors.red;
   } else if (tonKhoItem.soLuongHienTai! < (tonKhoItem.soLuongDuTru ?? 5)) {
     return Colors.orange;
   }
   return Colors.green;
 }
 
 Widget _buildBatchItem(LoHangModel batch) {
   // Format the dates
   final dateFormat = DateFormat('dd/MM/yyyy');
   final importDate = batch.ngayNhap != null 
       ? dateFormat.format(DateTime.parse(batch.ngayNhap!))
       : 'N/A';
   
   final updateDate = batch.ngayCapNhat != null 
       ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(batch.ngayCapNhat!))
       : 'N/A';
   
   // Determine if batch is expired or close to expiry
   Color expiryColor = Colors.black;
   bool isExpired = false;
   bool isCloseToExpiry = false;
   
   if (batch.hanSuDung != null) {
     final expiryDate = DateTime.parse(batch.ngayNhap!).add(Duration(days: batch.hanSuDung!));
     final now = DateTime.now();
     final daysToExpiry = expiryDate.difference(now).inDays;
     
     if (daysToExpiry < 0) {
       isExpired = true;
       expiryColor = Colors.red;
     } else if (daysToExpiry < 30) {
       isCloseToExpiry = true;
       expiryColor = Colors.orange;
     }
   }
   
   return Card(
     margin: EdgeInsets.symmetric(vertical: 6),
     elevation: 1,
     child: Padding(
       padding: EdgeInsets.all(12),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 'Lô: ${batch.loHangID ?? 'N/A'}',
                 style: TextStyle(
                   fontWeight: FontWeight.bold,
                 ),
               ),
               Container(
                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                 decoration: BoxDecoration(
                   color: _getBatchStatusColor(batch.trangThai),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   batch.trangThai ?? 'Không xác định',
                   style: TextStyle(
                     color: Colors.white,
                     fontSize: 12,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ),
             ],
           ),
           SizedBox(height: 8),
           Row(
             children: [
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('SL ban đầu: ${batch.soLuongBanDau ?? 'N/A'}'),
                     SizedBox(height: 4),
                     Text(
                       'SL hiện tại: ${batch.soLuongHienTai ?? '0'}',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         color: batch.soLuongHienTai == 0 ? Colors.red : Colors.black,
                       ),
                     ),
                   ],
                 ),
               ),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('Ngày nhập: $importDate'),
                     SizedBox(height: 4),
                     if (batch.hanSuDung != null)
                       Text(
                         'Hạn SD: ${batch.hanSuDung} ngày',
                         style: TextStyle(color: expiryColor),
                       ),
                   ],
                 ),
               ),
             ],
           ),
           if (isExpired || isCloseToExpiry) ...[
             SizedBox(height: 8),
             Container(
               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: isExpired ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(4),
                 border: Border.all(
                   color: isExpired ? Colors.red : Colors.orange,
                   width: 1,
                 ),
               ),
               child: Text(
                 isExpired ? 'Đã hết hạn' : 'Sắp hết hạn',
                 style: TextStyle(
                   color: isExpired ? Colors.red : Colors.orange,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ),
           ],
           SizedBox(height: 8),
           Text(
             'Cập nhật: $updateDate',
             style: TextStyle(
               fontSize: 11,
               color: Colors.grey[600],
               fontStyle: FontStyle.italic,
             ),
           ),
           if (batch.khuVucKhoID != null) ...[
             SizedBox(height: 4),
             Text(
               'Khu vực: ${batch.khuVucKhoID}',
               style: TextStyle(
                 fontSize: 11,
                 color: Colors.grey[600],
               ),
             ),
           ],
         ],
       ),
     ),
   );
 }
 
 Color _getBatchStatusColor(String? status) {
   if (status == null) return Colors.grey;
   
   switch (status.toLowerCase()) {
     case 'hoạt động':
     case 'active':
       return Colors.green;
     case 'đã xuất':
     case 'exported':
       return Colors.blue;
     case 'hết hàng':
     case 'out of stock':
       return Colors.red;
     case 'hết hạn':
     case 'expired':
       return Colors.purple;
     case 'chờ xuất':
     case 'pending':
       return Colors.orange;
     default:
       return Colors.grey;
   }
 }

 void _showItemDetails(DSHangModel item) {
   showModalBottomSheet(
     context: context,
     isScrollControlled: true,
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
     ),
     builder: (context) {
       return DraggableScrollableSheet(
         initialChildSize: 0.8,
         maxChildSize: 0.95,
         minChildSize: 0.5,
         expand: false,
         builder: (_, scrollController) {
           return SingleChildScrollView(
             controller: scrollController,
             padding: EdgeInsets.all(16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Center(
                   child: Container(
                     width: 40,
                     height: 5,
                     decoration: BoxDecoration(
                       color: Colors.grey.shade300,
                       borderRadius: BorderRadius.circular(8),
                     ),
                     margin: EdgeInsets.only(bottom: 16),
                   ),
                 ),
                 
                 // Header with image if available
                 if (item.hinhAnh != null && item.hinhAnh!.isNotEmpty)
                   Center(
                     child: Container(
                       width: 200,
                       height: 200,
                       margin: EdgeInsets.only(bottom: 16),
                       decoration: BoxDecoration(
                         border: Border.all(color: Colors.grey.shade300),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: Image.network(
                           item.hinhAnh!,
                           fit: BoxFit.cover,
                           errorBuilder: (_, __, ___) => Center(
                             child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                           ),
                         ),
                       ),
                     ),
                   ),
                 
                 // Product name
                 Text(
                   item.tenSanPham ?? 'Không có tên',
                   style: TextStyle(
                     fontSize: 22,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 
                 SizedBox(height: 16),
                 
                 // Basic info section
                 _buildInfoRow('Mã sản phẩm', item.uid),
                 _buildInfoRow('SKU', item.sku),
                 _buildInfoRow('Phân loại', item.phanLoai1),
                 _buildInfoRow('Màu sắc', item.mauSac),
                 _buildInfoRow('Chất liệu', item.chatLieu),
                 _buildInfoRow('Xuất xứ', item.xuatXu),
                 _buildInfoRow('Thương hiệu', item.thuongHieu),
                 
                 SizedBox(height: 16),
                 
                 // Specifications section
                 Text(
                   'Thông số kỹ thuật',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 SizedBox(height: 8),
                 _buildInfoRow('Kích thước', item.kichThuoc),
                 _buildInfoRow('Dung tích', item.dungTich),
                 _buildInfoRow('Khối lượng', item.khoiLuong),
                 _buildInfoRow('Quy cách đóng gói', item.quyCachDongGoi),
                 _buildInfoRow('Số lượng đóng gói', item.soLuongDongGoi),
                 _buildInfoRow('Kích thước đóng gói', item.kichThuocDongGoi),
                 _buildInfoRow('Đơn vị', item.donVi),
                 
                 SizedBox(height: 16),
                 
                 // Additional details section
                 Text(
                   'Thông tin bổ sung',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 SizedBox(height: 8),
                 _buildInfoRow('Công dụng', item.congDung),
                 _buildInfoRow('Nhà cung cấp', item.nhaCungCap),
                 _buildInfoRow('Hàng tiêu hao', item.hangTieuHao == 1 ? 'Có' : 'Không'),
                 _buildInfoRow('Có thời hạn', item.coThoiHan == 1 ? 'Có' : 'Không'),
                 _buildInfoRow('Thời hạn sử dụng', item.thoiHanSuDung),
                 
                 // Description if available
                 if (item.moTa != null && item.moTa!.isNotEmpty) ...[
                   SizedBox(height: 16),
                   Text(
                     'Mô tả',
                     style: TextStyle(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   SizedBox(height: 8),
                   Text(item.moTa!),
                 ],
                 
                 SizedBox(height: 32),
               ],
             ),
           );
         },
       );
     },
   );
 }

 Widget _buildInfoRow(String label, dynamic value) {
   // Skip if value is null or empty
   if (value == null || (value is String && value.isEmpty)) return SizedBox.shrink();
   
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 4),
     child: Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         SizedBox(
           width: 140,
           child: Text(
             '$label:',
             style: TextStyle(
               color: Colors.grey.shade700,
               fontWeight: FontWeight.w500,
             ),
           ),
         ),
         Expanded(
           child: Text(
             value.toString(),
             style: TextStyle(
               fontWeight: FontWeight.w500,
             ),
           ),
         ),
       ],
     ),
   );
 }
}