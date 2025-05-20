import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'db_helper.dart';
import 'table_models.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart' as pdfx;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'hs_pxkform.dart';

class HSKhoScreen extends StatefulWidget {
  final String? username;
  
  const HSKhoScreen({Key? key, this.username}) : super(key: key);

  @override
  _HSKhoScreenState createState() => _HSKhoScreenState();
}

class _HSKhoScreenState extends State<HSKhoScreen> with SingleTickerProviderStateMixin {
  List<GiaoDichKhoModel> _inputHistory = [];
  List<GiaoDichKhoModel> _outputHistory = [];
  String _historySearchQuery = '';
  bool _isLoadingHistory = false; 
  final TextEditingController _historySearchController = TextEditingController();
  late TabController _tabController;
  final DBHelper _dbHelper = DBHelper();
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  List<DonHangModel> _pendingOrders = [];
  String _searchQuery = '';
  List<Map<String, dynamic>> _getWarehousePermissions(String warehouseId) {
  // Static mapping of warehouse permissions (as in your original WarehouseDetailsDialog)
  final Map<String, List<Map<String, dynamic>>> warehousePermissions = {
    "HN": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.phiminh', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
      {'name': 'hm.lehoa', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
        "HN2": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.phiminh', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
      {'name': 'hm.lehoa', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "ĐN": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hotel.danang', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "NT": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hotel.nhatrang', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "SG": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.damchinh', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
      {'name': 'hm.quocchien', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "default": [
      {'name': 'hm.tason', 'position': 'Quản trị viên', 'canImport': true, 'canExport': true},
    ]
  };
  return warehousePermissions[warehouseId] ?? warehousePermissions["default"]!;
}
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchPendingOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _historySearchController.dispose(); 
    super.dispose();
  }
void _handleTabChange() {
  if (_tabController.index == 1 && _inputHistory.isEmpty) {
    _fetchInputHistory();
  } else if (_tabController.index == 2 && _outputHistory.isEmpty) {
    _fetchOutputHistory();
  }
}
Future<void> _fetchInputHistory() async {
  setState(() {
    _isLoadingHistory = true;
  });
  
  try {
    // Get all transactions
    final allTransactions = await _dbHelper.getAllGiaoDichKho();
    
    // Filter for input transactions (trangThai = '+')
    final inputTransactions = allTransactions.where((transaction) {
      return transaction.trangThai == "+";
    }).toList();
    
    // Sort by date and time (newest first)
    inputTransactions.sort((a, b) {
      final aDate = a.ngay ?? '';
      final bDate = b.ngay ?? '';
      final aTime = a.gio ?? '';
      final bTime = b.gio ?? '';
      
      // Compare dates first
      final dateComparison = bDate.compareTo(aDate);
      if (dateComparison != 0) return dateComparison;
      
      // If dates are equal, compare times
      return bTime.compareTo(aTime);
    });
    
    setState(() {
      _inputHistory = inputTransactions;
      _isLoadingHistory = false;
    });
  } catch (e) {
    setState(() {
      _isLoadingHistory = false;
    });
    _showErrorSnackBar('Lỗi tải dữ liệu lịch sử nhập kho: ${e.toString()}');
  }
}

// Add method to fetch output history
Future<void> _fetchOutputHistory() async {
  setState(() {
    _isLoadingHistory = true;
  });
  
  try {
    // Get all transactions
    final allTransactions = await _dbHelper.getAllGiaoDichKho();
    
    // Filter for output transactions (trangThai = '-')
    final outputTransactions = allTransactions.where((transaction) {
      return transaction.trangThai == "-";
    }).toList();
    
    // Sort by date and time (newest first)
    outputTransactions.sort((a, b) {
      final aDate = a.ngay ?? '';
      final bDate = b.ngay ?? '';
      final aTime = a.gio ?? '';
      final bTime = b.gio ?? '';
      
      // Compare dates first
      final dateComparison = bDate.compareTo(aDate);
      if (dateComparison != 0) return dateComparison;
      
      // If dates are equal, compare times
      return bTime.compareTo(aTime);
    });
    
    setState(() {
      _outputHistory = outputTransactions;
      _isLoadingHistory = false;
    });
  } catch (e) {
    setState(() {
      _isLoadingHistory = false;
    });
    _showErrorSnackBar('Lỗi tải dữ liệu lịch sử xuất kho: ${e.toString()}');
  }
}

// Add method to search history transactions
void _searchHistory(String query) {
  setState(() {
    _historySearchQuery = query.toLowerCase();
  });
}
List<GiaoDichKhoModel> get _filteredInputHistory {
  if (_historySearchQuery.isEmpty) {
    return _inputHistory;
  }
  
  return _inputHistory.where((transaction) {
    return (transaction.loHangID?.toLowerCase().contains(_historySearchQuery) ?? false) ||
           (transaction.nguoiDung?.toLowerCase().contains(_historySearchQuery) ?? false) ||
           (transaction.ghiChu?.toLowerCase().contains(_historySearchQuery) ?? false);
  }).toList();
}

// Add getter for filtered output history
List<GiaoDichKhoModel> get _filteredOutputHistory {
  if (_historySearchQuery.isEmpty) {
    return _outputHistory;
  }
  
  return _outputHistory.where((transaction) {
    return (transaction.loHangID?.toLowerCase().contains(_historySearchQuery) ?? false) ||
           (transaction.nguoiDung?.toLowerCase().contains(_historySearchQuery) ?? false) ||
           (transaction.ghiChu?.toLowerCase().contains(_historySearchQuery) ?? false);
  }).toList();
}
  Future<void> _fetchPendingOrders() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all orders
      final allOrders = await _dbHelper.getAllDonHang();
      
      // Filter for orders with status "0" (Đang xử lý) or "Cần xuất"
      final pendingOrders = allOrders.where((order) {
        return order.trangThai == "0" || order.trangThai == "Cần xuất";
      }).toList();
      
      setState(() {
        _pendingOrders = pendingOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Lỗi tải dữ liệu đơn hàng: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showScanDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ScanDialogContent(
            onScanComplete: (String orderNumber) {
              Navigator.of(context).pop();
              _showOrderDetails(orderNumber);
            },
          ),
        );
      },
    );
  }

  void _showOrderDetails(String soPhieu) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final order = await _dbHelper.getDonHangBySoPhieu(soPhieu);
      final items = await _dbHelper.getChiTietDonBySoPhieu(soPhieu);
      
      setState(() {
        _isLoading = false;
      });
      
      if (order != null) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => OrderDetailsSheet(
            order: order,
            items: items,
          ),
        );
      } else {
        _showErrorSnackBar('Không tìm thấy đơn hàng với mã: $soPhieu');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Lỗi khi tìm kiếm đơn hàng: ${e.toString()}');
    }
  }

  void _showWarehouseActionDialog(String actionType) {
  if (actionType == 'nhap') {
    _showWarehouseInputDialog();
  } else if (actionType == 'xuat') {
    _showWarehouseOutputDialog();
  } else {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            actionType == 'nhap' ? 'Nhập kho' : 'Xuất kho',
            style: TextStyle(
              color: Color(0xFF534b0d),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Tính năng ${actionType == 'nhap' ? 'nhập kho' : 'xuất kho'} đang được phát triển và sẽ sớm được ra mắt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Đóng',
                style: TextStyle(color: Color(0xFF837826)),
              ),
            ),
          ],
        );
      },
    );
  }
}
void _showWarehouseOutputDialog() async {
  // Get username from widget parameter first, then fall back to shared preferences
  String username = '';
  if (widget.username != null && widget.username!.isNotEmpty) {
    username = widget.username!;
  } else {
    // Fall back to shared preferences
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? '';
  }
  
  if (username.isEmpty) {
    _showErrorSnackBar('Không thể xác định người dùng. Vui lòng đăng nhập lại.');
    return;
  }
  
  // Check if user has permission to any warehouse
  bool hasPermission = false;
  String? defaultWarehouseId;
  
  // Fetch all warehouses
  final warehouses = await _dbHelper.getAllKho();
  
  // Map to store warehouses the user has access to
  Map<String, bool> warehousePermissions = {};
  
  // Check permissions for each warehouse
  for (var warehouse in warehouses) {
    if (warehouse.khoHangID != null) {
      // Get the permissions map for this warehouse
      final permissions = _getWarehousePermissions(warehouse.khoHangID!);
      
      // Check if current user has export permission
      final userPermission = permissions.firstWhere(
        (p) => p['name'] == username && p['canExport'] == true,
        orElse: () => {'name': '', 'canExport': false},
      );
      
      if (userPermission['canExport'] == true) {
        hasPermission = true;
        warehousePermissions[warehouse.khoHangID!] = true;
        
        // Set the first permitted warehouse as default
        if (defaultWarehouseId == null) {
          defaultWarehouseId = warehouse.khoHangID;
        }
      }
    }
  }
  
  if (!hasPermission) {
    _showErrorSnackBar('Bạn không có quyền xuất kho.');
    return;
  }
  
  // Show warehouse output dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WarehouseOutputDialog(
        username: username,
        warehouses: warehouses.where((w) => 
          w.khoHangID != null && warehousePermissions[w.khoHangID!] == true
        ).toList(),
        pendingOrders: _filteredOrders,
        defaultWarehouseId: defaultWarehouseId,
        dbHelper: _dbHelper,
        onSuccess: () {
          // Refresh data after successful output
          _fetchPendingOrders();
          if (_tabController.index == 2) {
            _fetchOutputHistory();
          }
        },
      );
    },
  );
}
void _showWarehouseInputDialog() async {
  // Get username from widget parameter first, then fall back to shared preferences
  String username = '';
  if (widget.username != null && widget.username!.isNotEmpty) {
    username = widget.username!;
  } else {
    // Fall back to shared preferences
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? '';
  }
  
  if (username.isEmpty) {
    _showErrorSnackBar('Không thể xác định người dùng. Vui lòng đăng nhập lại.');
    return;
  }
  
  // Check if user has permission to any warehouse
  bool hasPermission = false;
  String? defaultWarehouseId;
  
  // Fetch all warehouses
  final warehouses = await _dbHelper.getAllKho();
  
  // Map to store warehouses the user has access to
  Map<String, bool> warehousePermissions = {};
  
  // Check permissions for each warehouse
  for (var warehouse in warehouses) {
    if (warehouse.khoHangID != null) {
      // Get the permissions map for this warehouse
      final permissions = _getWarehousePermissions(warehouse.khoHangID!);
      
      // Check if current user has import permission
      final userPermission = permissions.firstWhere(
        (p) => p['name'] == username && p['canImport'] == true,
        orElse: () => {'name': '', 'canImport': false},
      );
      
      if (userPermission['canImport'] == true) {
        hasPermission = true;
        warehousePermissions[warehouse.khoHangID!] = true;
        
        // Set the first permitted warehouse as default
        if (defaultWarehouseId == null) {
          defaultWarehouseId = warehouse.khoHangID;
        }
      }
    }
  }
  
  if (!hasPermission) {
    _showErrorSnackBar('Bạn không có quyền nhập kho.');
    return;
  }
  
  // Show warehouse input dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WarehouseInputDialog(
        username: username,
        warehouses: warehouses.where((w) => 
          w.khoHangID != null && warehousePermissions[w.khoHangID!] == true
        ).toList(),
        defaultWarehouseId: defaultWarehouseId,
        dbHelper: _dbHelper,
        onSuccess: () {
          // Refresh data after successful input
          _fetchPendingOrders();
          if (_tabController.index == 1) {
    _fetchInputHistory();
  }
        },
      );
    },
  );
}
  void _searchOrders(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<DonHangModel> get _filteredOrders {
    if (_searchQuery.isEmpty) {
      return _pendingOrders;
    }
    
    return _pendingOrders.where((order) {
      return (order.soPhieu?.toLowerCase().contains(_searchQuery) ?? false) ||
             (order.tenKhachHang?.toLowerCase().contains(_searchQuery) ?? false) ||
             (order.tenKhachHang2?.toLowerCase().contains(_searchQuery) ?? false) ||
             (order.nguoiTao?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

 @override
  Widget build(BuildContext context) {
    final Color appBarTop = Color(0xFF534b0d);
    final Color appBarBottom = Color(0xFFb2a41f);
    final Color buttonColor = Color(0xFF837826);
    
    return Scaffold(
      appBar: AppBar(
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [appBarTop, appBarBottom],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  ),
        title: Row(
          children: [
            Text('Quản lý kho', style: TextStyle(color: Colors.white)),
            SizedBox(width: 28),
            ElevatedButton(
              onPressed: _showWarehouseDetails,
              child: Text(
                'Chi tiết',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.0),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.orange,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.6),
            tabs: [
              Tab(text: 'Đơn hàng'),
              Tab(text: 'Lịch sử nhập'),
              Tab(text: 'Lịch sử xuất'),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Action buttons
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showScanDialog,
                        icon: Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                        label: Text('Quét mã', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showWarehouseActionDialog('nhap'),
                        icon: Icon(Icons.input, color: Colors.white, size: 18),
                        label: Text('Nhập kho', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    //SizedBox(width: 8),
                    //Expanded(
                    //  child: ElevatedButton.icon(
                    //    onPressed: () => _showWarehouseActionDialog('xuat'),
                    //    icon: Icon(Icons.output, color: Colors.white, size: 18),
                    //    label: Text('Xuất kho', style: TextStyle(color: Colors.white)),
                    //    style: ElevatedButton.styleFrom(
                    //      backgroundColor: buttonColor,
                    //      padding: EdgeInsets.symmetric(vertical: 12),
                    //      shape: RoundedRectangleBorder(
                    //        borderRadius: BorderRadius.circular(8),
                    //      ),
                    //    ),
                    //  ),
                    //),
                  ],
                ),
              ),
              
              // Search bar - only show in the first tab (Pending Orders)
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  return _tabController.index == 0
                    ? Padding(
                        padding: EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _searchOrders,
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm đơn hàng, khách hàng...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      )
                    : SizedBox.shrink();
                },
              ),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Pending Orders Tab
                    _buildPendingOrdersTab(),
                    
                    // Input History Tab
                    _buildInputHistoryTab(),
                    
                    // Output History Tab
                    _buildOutputHistoryTab(),
                  ],
                ),
              ),
            ],
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildOutputHistoryTab() {
  if (_isLoadingHistory) {
    return Center(child: CircularProgressIndicator());
  }
  
  if (_outputHistory.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.outbox,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Không có lịch sử xuất kho',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchOutputHistory,
            child: Text('Làm mới'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF837826),
            ),
          ),
        ],
      ),
    );
  }
  
  return Column(
    children: [
      // Search bar for output history
      Padding(
        padding: EdgeInsets.all(16),
        child: TextField(
          controller: _historySearchController,
          onChanged: _searchHistory,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm lịch sử xuất kho...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ),
      
      // Transactions list
      Expanded(
        child: RefreshIndicator(
          onRefresh: _fetchOutputHistory,
          child: _filteredOutputHistory.isEmpty
              ? Center(
                  child: Text(
                    'Không tìm thấy kết quả',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: _filteredOutputHistory.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final transaction = _filteredOutputHistory[index];
                    return _buildTransactionCard(transaction, isInputHistory: false);
                  },
                ),
        ),
      ),
    ],
  );
}

// Add method to build transaction card
Widget _buildTransactionCard(GiaoDichKhoModel transaction, {required bool isInputHistory}) {
  String formattedDate = 'N/A';
  if (transaction.ngay != null) {
    try {
      final date = DateTime.parse(transaction.ngay!);
      formattedDate = DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      formattedDate = transaction.ngay!;
    }
  }
  
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        // Transaction details
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Mã lô: ${transaction.loHangID ?? "N/A"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isInputHistory ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isInputHistory ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Text(
                  isInputHistory ? 'Nhập kho' : 'Xuất kho',
                  style: TextStyle(
                    color: isInputHistory ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ngày: $formattedDate'),
                  Text('Giờ: ${transaction.gio ?? "N/A"}'),
                ],
              ),
              SizedBox(height: 4),
              Text('Số lượng: ${transaction.soLuong?.toString() ?? "0"}'),
              Text('Người thực hiện: ${transaction.nguoiDung ?? "N/A"}'),
              if (transaction.ghiChu != null && transaction.ghiChu!.isNotEmpty)
                Text('Ghi chú: ${transaction.ghiChu}'),
            ],
          ),
          isThreeLine: true,
        ),
        
        // QR Code button
        if (transaction.loHangID != null && transaction.loHangID!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showTransactionQRCode(transaction),
                  icon: Icon(Icons.qr_code, size: 16, color: Colors.white),
                  label: Text('Xem mã QR', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF534b0d),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

// Add method to show transaction QR code
void _showTransactionQRCode(GiaoDichKhoModel transaction) async {
  final loHangID = transaction.loHangID!;
  
  // Get additional information about the batch
  LoHangModel? loHang;
  DSHangModel? product;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    loHang = await _dbHelper.getLoHangById(loHangID);
    if (loHang?.maHangID != null) {
      product = await _dbHelper.getDSHangByUID(loHang!.maHangID!);
    }
  } catch (e) {
    print('Error loading batch details: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
  
  // Show QR code dialog
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Mã QR lô hàng'),
      contentPadding: EdgeInsets.all(16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 200,
            child: QrImageView(
              data: loHangID,
              version: QrVersions.auto,
              size: 200,
            ),
          ),
          SizedBox(height: 16),
          Text(
            "Mã lô: $loHangID",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            "Sản phẩm: ${product?.tenSanPham ?? 'N/A'}",
            textAlign: TextAlign.center,
          ),
          Text(
            "Mã sản phẩm: ${loHang?.maHangID ?? 'N/A'}",
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          if (loHang != null)
            Text(
              "Số lượng: ${loHang.soLuongHienTai?.toString() ?? '0'}",
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Đóng'),
        ),
        ElevatedButton.icon(
          icon: Icon(Icons.print, color: Colors.white),
          label: Text('In', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF534b0d),
          ),
          onPressed: () async {
            await _printBatchQRCode(loHangID, loHang?.maHangID ?? 'N/A');
          },
        ),
      ],
    ),
  );
}
Future<bool> _isPreviewAvailable() async {
  try {
    final result = await Process.run('which', ['open']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}
Future<void> _printBatchQRCode(String loHangID, String maHangID) async {
  try {
    final pdf = pw.Document();
    
    // Use horizontal page format (5x3cm)
    pdf.addPage(
      pw.Page(
        pageFormat: pdfx.PdfPageFormat(50 * pdfx.PdfPageFormat.mm, 30 * pdfx.PdfPageFormat.mm, marginAll: 2 * pdfx.PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // QR Code on the left
                pw.Container(
                  width: 26 * pdfx.PdfPageFormat.mm,
                  height: 26 * pdfx.PdfPageFormat.mm,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: loHangID,
                    width: 26 * pdfx.PdfPageFormat.mm,
                    height: 26 * pdfx.PdfPageFormat.mm,
                  ),
                ),
                
                pw.SizedBox(width: 4 * pdfx.PdfPageFormat.mm),
                
                // Rotated text information on the right
                pw.Container(
                  width: 16 * pdfx.PdfPageFormat.mm,
                  height: 26 * pdfx.PdfPageFormat.mm,
                  alignment: pw.Alignment.center,
                  child: pw.Transform.rotate(
                    angle: 90 * 3.1415927 / 180, // Rotate 90 degrees (counter-clockwise)
                    child: pw.Container(
                      width: 26 * pdfx.PdfPageFormat.mm, // Height of the original container becomes width
                      height: 16 * pdfx.PdfPageFormat.mm, // Width of the original container becomes height
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Lot ID text
                          pw.Text(
                            'Mã lô: $loHangID',
                            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2 * pdfx.PdfPageFormat.mm),
                          
                          // Product ID text
                          pw.Text(
                            'Mã SP: $maHangID',
                            style: pw.TextStyle(fontSize: 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    // Print the document
    await Printing.layoutPdf(
      onLayout: (pdfx.PdfPageFormat format) async => pdf.save(),
      format: pdfx.PdfPageFormat(50 * pdfx.PdfPageFormat.mm, 30 * pdfx.PdfPageFormat.mm),
      name: 'QR_${loHangID}.pdf',
    );
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi lệnh in mã QR thành công'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi in mã QR: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    print('Error printing QR code: $e');
  }
}
void _generatePXK(DonHangModel order) async {
  if (order.soPhieu == null) {
    _showErrorSnackBar('Không thể tạo phiếu xuất kho: Số phiếu không hợp lệ');
    return;
  }
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Get order items
    final items = await _dbHelper.getChiTietDonBySoPhieu(order.soPhieu!);
    
    // Get current user name
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'User';
    
    // Get warehouse info
    final warehouses = await _dbHelper.getAllKho();
    String? warehouseId;
    String? warehouseName;
    
    if (warehouses.isNotEmpty) {
      warehouseId = warehouses.first.khoHangID;
      warehouseName = warehouses.first.tenKho;
    }
    
    setState(() {
      _isLoading = false;
    });
    
    // Generate and show the export form
    await ExportFormGenerator.generateExportForm(
      context: context,
      order: order,
      items: items,
      createdBy: username,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
    );
    
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    _showErrorSnackBar('Lỗi khi tạo phiếu xuất kho: ${e.toString()}');
  }
}
void _showWarehouseDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch warehouse data
      final warehouses = await _dbHelper.getAllKho();
      
      setState(() {
        _isLoading = false;
      });
      
      if (warehouses.isEmpty) {
        _showErrorSnackBar('Không có kho hàng nào trong hệ thống');
        return;
      }
      
      // Show the warehouse details dialog
      showDialog(
        context: context,
        builder: (context) => WarehouseDetailsDialog(
          warehouses: warehouses,
          dbHelper: _dbHelper,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Lỗi khi tải dữ liệu kho: ${e.toString()}');
    }
  }
  Widget _buildPendingOrdersTab() {
  if (_filteredOrders.isEmpty && !_isLoading) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Không có đơn hàng nào cần xử lý',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  return ListView.separated(
    padding: EdgeInsets.all(16),
    itemCount: _filteredOrders.length,
    separatorBuilder: (context, index) => SizedBox(height: 8),
    itemBuilder: (context, index) {
      final order = _filteredOrders[index];
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                'Đơn hàng #${order.soPhieu}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text('Khách hàng: ${order.tenKhachHang2 ?? order.tenKhachHang ?? "N/A"}'),
                  Text('Ngày: ${order.ngay ?? "N/A"}'),
                  Text('Trạng thái: ${_getStatusText(order.trangThai)}'),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () {
                  if (order.soPhieu != null) {
                    _showOrderDetails(order.soPhieu!);
                  }
                },
              ),
              isThreeLine: true,
              onTap: () {
                if (order.soPhieu != null) {
                  _showOrderDetails(order.soPhieu!);
                }
              },
            ),
            
            // Add output and QR buttons
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
        onPressed: () {
          // Generate PXK for order
          _generatePXK(order);
        },
        icon: Icon(Icons.receipt_long, size: 16, color: Colors.white),
        label: Text('PXK', style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
                        SizedBox(width: 8),
                  // Add QR button
                  ElevatedButton.icon(
                    onPressed: () {
                      // Generate QR for order
                      _showOrderQRCode(order);
                    },
                    icon: Icon(Icons.qr_code, size: 16, color: Colors.white),
                    label: Text('Mã QR', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Export button
                  ElevatedButton.icon(
                    onPressed: () {
                      // Direct export for this order
                      _directOrderExport(order);
                    },
                    icon: Icon(Icons.output, size: 16, color: Colors.white),
                    label: Text('Xuất kho', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF534b0d),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    },
  );
}
void _showOrderQRCode(DonHangModel order) async {
  if (order.soPhieu == null || order.soPhieu!.isEmpty) {
    _showErrorSnackBar('Không thể tạo mã QR: Số phiếu không hợp lệ');
    return;
  }
  
  // Parse the SoPhieu into parts (number1-number2-number3)
  List<String> parts = order.soPhieu!.split('-');
  String displayText = '';
  
  // Make sure we display number2-number3 as specified
  if (parts.length >= 3) {
    displayText = '${parts[1]}-${parts[2]}';
  } else if (parts.length == 2) {
    displayText = parts.join('-');
  } else {
    displayText = order.soPhieu!;
  }
  
  // Show QR code dialog
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Mã QR đơn hàng'),
      contentPadding: EdgeInsets.all(16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 200,
            child: QrImageView(
              data: order.soPhieu!,
              version: QrVersions.auto,
              size: 200,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              displayText,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Đơn hàng: ${order.soPhieu}",
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Đóng'),
        ),
        ElevatedButton.icon(
          icon: Icon(Icons.print, color: Colors.white),
          label: Text('In', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF534b0d),
          ),
          onPressed: () async {
            await _printOrderQRCode(order);
          },
        ),
      ],
    ),
  );
}
Future<void> _printOrderQRCode(DonHangModel order) async {
  try {
    final pdf = pw.Document();
    
    // Parse the SoPhieu into parts
    List<String> parts = order.soPhieu!.split('-');
    
    // Extract the last 2 digits
    String lastTwoDigits = "";
    if (parts.length >= 1) {
      String lastPart = parts.last;
      if (lastPart.length >= 2) {
        lastTwoDigits = lastPart.substring(lastPart.length - 2);
      } else if (lastPart.length == 1) {
        lastTwoDigits = "0" + lastPart; // Pad with 0 if only one digit
      }
    }
    
    // Create a map of digits to keycap emojis that work well on thermal printers
    Map<String, String> digitToEmoji = {
      '0': '0⃣', // Keycap Digit Zero
      '1': '❤️', // Keycap Digit One
      '2': '2⃣', // Keycap Digit Two
      '3': '3⃣', // Keycap Digit Three
      '4': '4⃣', // Keycap Digit Four
      '5': '5⃣', // Keycap Digit Five
      '6': '6⃣', // Keycap Digit Six
      '7': '7⃣', // Keycap Digit Seven
      '8': '8⃣', // Keycap Digit Eight
      '9': '9⃣', // Keycap Digit Nine
    };
    
    // Alternative simpler symbols in case keycap emojis don't print well
    Map<String, String> digitToBackupSymbol = {
      '0': '⓪', // Circled Digit Zero
      '1': '❤️', // Circled Digit One
      '2': '②', // Circled Digit Two
      '3': '③', // Circled Digit Three
      '4': '④', // Circled Digit Four
      '5': '⑤', // Circled Digit Five
      '6': '⑥', // Circled Digit Six
      '7': '⑦', // Circled Digit Seven
      '8': '⑧', // Circled Digit Eight
      '9': '⑨', // Circled Digit Nine
    };
    
    // Create 5x3cm (50mm x 30mm) vertical page
    pdf.addPage(
      pw.Page(
        pageFormat: pdfx.PdfPageFormat(30 * pdfx.PdfPageFormat.mm, 50 * pdfx.PdfPageFormat.mm, marginAll: 2 * pdfx.PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                // QR Code using BarcodeWidget
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: order.soPhieu!,
                  width: 26 * pdfx.PdfPageFormat.mm,
                  height: 26 * pdfx.PdfPageFormat.mm,
                ),
                pw.SizedBox(height: 4 * pdfx.PdfPageFormat.mm),
                
                // Black pill with ONLY the last two digits as large symbols
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(
                    horizontal: 6 * pdfx.PdfPageFormat.mm,
                    vertical: 2 * pdfx.PdfPageFormat.mm,
                  ),
                  decoration: pw.BoxDecoration(
                    color: pdfx.PdfColors.black,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      // First digit symbol
                      pw.Text(
                        lastTwoDigits.isNotEmpty 
                            ? digitToBackupSymbol[lastTwoDigits[0]] ?? lastTwoDigits[0]
                            : "",
                        style: pw.TextStyle(
                          color: pdfx.PdfColors.white,
                          fontSize: 14, // Larger font for better visibility
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: 2 * pdfx.PdfPageFormat.mm),
                      // Second digit symbol
                      pw.Text(
                        lastTwoDigits.length > 1 
                            ? digitToBackupSymbol[lastTwoDigits[1]] ?? lastTwoDigits[1]
                            : "",
                        style: pw.TextStyle(
                          color: pdfx.PdfColors.white,
                          fontSize: 14, // Larger font for better visibility
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 2 * pdfx.PdfPageFormat.mm),
                
                // Order number text at bottom
                pw.Text(
                  'Đơn: ${order.soPhieu}',
                  style: pw.TextStyle(fontSize: 6),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    // Print the document
    await Printing.layoutPdf(
      onLayout: (pdfx.PdfPageFormat format) async => pdf.save(),
      format: pdfx.PdfPageFormat(30 * pdfx.PdfPageFormat.mm, 50 * pdfx.PdfPageFormat.mm),
      name: 'ORDER_QR_${order.soPhieu}.pdf',
    );
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi lệnh in mã QR thành công'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi in mã QR: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    print('Error printing QR code: $e');
  }
}
Future<void> _directOrderExport(DonHangModel order) async {
  // Get username from widget parameter first, then fall back to shared preferences
  String username = '';
  if (widget.username != null && widget.username!.isNotEmpty) {
    username = widget.username!;
  } else {
    // Fall back to shared preferences
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? '';
  }
  
  if (username.isEmpty) {
    _showErrorSnackBar('Không thể xác định người dùng. Vui lòng đăng nhập lại.');
    return;
  }

  // Check for export permissions
  bool hasPermission = false;
  String? defaultWarehouseId;
  
  // Fetch all warehouses
  final warehouses = await _dbHelper.getAllKho();
  
  // Map to store warehouses the user has access to
  Map<String, bool> warehousePermissions = {};
  
  // Check permissions for each warehouse
  for (var warehouse in warehouses) {
    if (warehouse.khoHangID != null) {
      final permissions = _getWarehousePermissions(warehouse.khoHangID!);
      
      final userPermission = permissions.firstWhere(
        (p) => p['name'] == username && p['canExport'] == true,
        orElse: () => {'name': '', 'canExport': false},
      );
      
      if (userPermission['canExport'] == true) {
        hasPermission = true;
        warehousePermissions[warehouse.khoHangID!] = true;
        
        if (defaultWarehouseId == null) {
          defaultWarehouseId = warehouse.khoHangID;
        }
      }
    }
  }
  
  if (!hasPermission) {
    _showErrorSnackBar('Bạn không có quyền xuất kho.');
    return;
  }
  
  // Show warehouse output dialog with pre-selected order
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WarehouseOutputDialog(
        username: username,
        warehouses: warehouses.where((w) => 
          w.khoHangID != null && warehousePermissions[w.khoHangID!] == true
        ).toList(),
        pendingOrders: [order], // Only include this order
        defaultWarehouseId: defaultWarehouseId,
        dbHelper: _dbHelper,
        onSuccess: () {
          // Refresh data after successful output
          _fetchPendingOrders();
          if (_tabController.index == 2) {
            _fetchOutputHistory();
          }
        },
      );
    },
  );
}

  Widget _buildInputHistoryTab() {
  if (_isLoadingHistory) {
    return Center(child: CircularProgressIndicator());
  }
  
  if (_inputHistory.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Không có lịch sử nhập kho',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchInputHistory,
            child: Text('Làm mới'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF837826),
            ),
          ),
        ],
      ),
    );
  }
  
  return Column(
    children: [
      // Search bar for input history
      Padding(
        padding: EdgeInsets.all(16),
        child: TextField(
          controller: _historySearchController,
          onChanged: _searchHistory,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm lịch sử nhập kho...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ),
      
      // Transactions list
      Expanded(
        child: RefreshIndicator(
          onRefresh: _fetchInputHistory,
          child: _filteredInputHistory.isEmpty
              ? Center(
                  child: Text(
                    'Không tìm thấy kết quả',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: _filteredInputHistory.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final transaction = _filteredInputHistory[index];
                    return _buildTransactionCard(transaction, isInputHistory: true);
                  },
                ),
        ),
      ),
    ],
  );
}

  String _getStatusText(String? status) {
    if (status == null) return 'Không xác định';
    
    switch (status) {
      case "0":
        return 'Đang xử lý';
      case "Cần xuất":
        return 'Cần xuất';
      case "1":
        return 'Đã duyệt';
      case "2":
        return 'Đang giao hàng';
      case "3":
        return 'Hoàn thành';
      case "4":
        return 'Đã hủy';
      default:
        return status;
    }
  }
}

class OrderDetailsSheet extends StatelessWidget {
  final DonHangModel order;
  final List<ChiTietDonModel> items;

  const OrderDetailsSheet({
    Key? key,
    required this.order,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 16),
              
              // Title
              Text(
                'CHI TIẾT ĐƠN HÀNG',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF534b0d),
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order details card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'THÔNG TIN ĐƠN HÀNG',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF534b0d),
                                  ),
                                ),
                              ),
                              Divider(thickness: 1),
                              SizedBox(height: 8),
                              _buildInfoRow('Số phiếu:', order.soPhieu ?? 'N/A'),
                              _buildInfoRow('Ngày tạo:', order.ngay ?? 'N/A'),
                              _buildInfoRow('Khách hàng:', order.tenKhachHang2 ?? order.tenKhachHang ?? 'N/A'),
                              _buildInfoRow('Người tạo:', order.nguoiTao ?? 'N/A'),
                              _buildInfoRow('Trạng thái:', _getStatusText(order.trangThai)),
                              _buildInfoRow('Ghi chú:', order.ghiChu ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Order items
                      Text(
                        'CHI TIẾT HÀNG HÓA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF534b0d),
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  'Không có mặt hàng nào trong đơn',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            )
                          : Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.separated(
                                physics: NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: items.length,
                                separatorBuilder: (context, index) => Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return ListTile(
                                    title: Text(
                                      item.tenHang ?? 'Sản phẩm không tên',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 4),
                                        Text('Mã hàng: ${item.maHang ?? 'N/A'}'),
                                        Text('Số lượng: ${item.soLuongYeuCau?.toString() ?? '0'} ${item.donViTinh ?? ''}'),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  );
                                },
                              ),
                            ),
                            
                      SizedBox(height: 24),
                            
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: Icon(Icons.arrow_back, color: Colors.white),
                              label: Text('Quay lại', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF837826),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String? status) {
    if (status == null) return 'Không xác định';
    
    switch (status) {
      case "0":
        return 'Đang xử lý';
      case "Cần xuất":
        return 'Cần xuất';
      case "1":
        return 'Đã duyệt';
      case "2":
        return 'Đang giao hàng';
      case "3":
        return 'Hoàn thành';
      case "4":
        return 'Đã hủy';
      default:
        return status;
    }
  }
}

class ScanDialogContent extends StatefulWidget {
  final Function(String) onScanComplete;

  const ScanDialogContent({
    Key? key,
    required this.onScanComplete,
  }) : super(key: key);

  @override
  _ScanDialogContentState createState() => _ScanDialogContentState();
}

class _ScanDialogContentState extends State<ScanDialogContent> {
  bool _isScanning = true;
  bool _hasError = false;
  String _errorMessage = '';
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

 void _initializeScanner() {
  _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  setState(() {
    _isScanning = true;
    _hasError = false; 
    _errorMessage = '';
  });
}

  Future<void> _onDetect(BarcodeCapture capture) async {
  if (!_isScanning) return;
  
  final List<Barcode> barcodes = capture.barcodes;
  if (barcodes.isEmpty) return;
  
  final String? code = barcodes.first.rawValue;
  if (code == null || code.isEmpty) return;
  
  // Get the barcode format if available
  final BarcodeType? format = barcodes.first.type;
  
  // Only proceed for certain barcode types
  bool isAcceptableFormat = true;
  
  // If we can detect the format, filter out UPC and EAN
  if (format != null) {
  // Check using string representation instead of direct enum comparison
  String formatName = format.toString();
  if (formatName.contains('upc') || 
      formatName.contains('ean8') || 
      formatName.contains('ean13') ||
      formatName.contains('ean_8') || 
      formatName.contains('ean_13')) {
    isAcceptableFormat = false;
  }
}
  
  // Simple validation for obviously invalid barcodes
  if (code.length < 8) {
    isAcceptableFormat = false;
  }
  
  if (!isAcceptableFormat) {
    // Give feedback but don't stop scanning
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mã vạch không hợp lệ. Vui lòng quét loại mã GS1-128 hoặc Code 128.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  
  setState(() {
    _isScanning = false;
  });
  
  // Pass the scanned code back
  widget.onScanComplete(code);
}

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Color(0xFF534b0d),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Text(
                'Quét mã QR đơn hàng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: _hasError
                ? _buildErrorView()
                : _buildScannerView(),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Hủy',
                    style: TextStyle(
                      color: Color(0xFF837826),
                      fontWeight: FontWeight.bold,
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        // Scanner
        _scannerController != null
            ? MobileScanner(
                controller: _scannerController!,
                onDetect: _onDetect,
              )
            : Center(child: CircularProgressIndicator()),
        
        // Scan overlay
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
          ),
          child: Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white.withOpacity(0.8),
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Đang quét...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WarehouseDetailsDialog extends StatefulWidget {
  final List<KhoModel> warehouses;
  final DBHelper dbHelper;
  
  const WarehouseDetailsDialog({
    Key? key,
    required this.warehouses,
    required this.dbHelper,
  }) : super(key: key);
  
  @override
  _WarehouseDetailsDialogState createState() => _WarehouseDetailsDialogState();
}

class _WarehouseDetailsDialogState extends State<WarehouseDetailsDialog> {
  int _selectedWarehouseIndex = 0;
  bool _isLoading = false;
  List<KhuVucKhoModel> _areas = [];
  
  // Direct mapping of warehouse IDs to authorized users
  final Map<String, List<Map<String, dynamic>>> _warehousePermissions = {
    "HN": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.phiminh', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
      {'name': 'hm.lehoa', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "HN2": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.phiminh', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
      {'name': 'hm.lehoa', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "ĐN": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hotel.danang', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "NT": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hotel.nhatrang', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "SG": [
      {'name': 'nvthunghiem', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.tason', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.kimdung', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.manhha', 'position': 'TEST', 'canImport': true, 'canExport': true},
      {'name': 'hm.damchinh', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
      {'name': 'hm.quocchien', 'position': 'Quản lý kho', 'canImport': true, 'canExport': true},
    ],
    "default": [
      {'name': 'hm.tason', 'position': 'Quản trị viên', 'canImport': true, 'canExport': true},
    ]
  };
  
  @override
  void initState() {
    super.initState();
    _loadWarehouseAreas();
  }
  
  Future<void> _loadWarehouseAreas() async {
    if (widget.warehouses.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final selectedWarehouse = widget.warehouses[_selectedWarehouseIndex];
      
      // Load areas for this warehouse
      final areas = await widget.dbHelper.getKhuVucKhoByKhoID(selectedWarehouse.khoHangID ?? '');
      
      setState(() {
        _areas = areas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải chi tiết kho: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  List<Map<String, dynamic>> _getStaffForWarehouse(String? warehouseId) {
    if (warehouseId == null) return _warehousePermissions["default"]!;
    return _warehousePermissions[warehouseId] ?? _warehousePermissions["default"]!;
  }
  
  void _selectWarehouse(int index) {
    if (index != _selectedWarehouseIndex) {
      setState(() {
        _selectedWarehouseIndex = index;
      });
      _loadWarehouseAreas();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final selectedWarehouse = widget.warehouses.isNotEmpty 
        ? widget.warehouses[_selectedWarehouseIndex]
        : null;
    
    // Get the appropriate staff list for the selected warehouse
    final warehouseStaff = selectedWarehouse != null 
        ? _getStaffForWarehouse(selectedWarehouse.khoHangID)
        : _warehousePermissions["default"]!;
        
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Color(0xFF534b0d),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Text(
                  'CHI TIẾT KHO HÀNG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            // Warehouse selector
            Container(
              height: 60,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.warehouses.length,
                separatorBuilder: (context, index) => SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final warehouse = widget.warehouses[index];
                  final isSelected = index == _selectedWarehouseIndex;
                  
                  return InkWell(
                    onTap: () => _selectWarehouse(index),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF837826) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : Colors.grey[300]!,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          warehouse.tenKho ?? 'Kho không tên',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Warehouse details
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : selectedWarehouse == null
                      ? Center(child: Text('Không có kho hàng nào'))
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Warehouse info
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'THÔNG TIN KHO',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF534b0d),
                                        ),
                                      ),
                                      Divider(),
                                      _buildInfoRow('Mã kho:', selectedWarehouse.khoHangID ?? 'N/A'),
                                      _buildInfoRow('Tên kho:', selectedWarehouse.tenKho ?? 'N/A'),
                                      _buildInfoRow('Địa chỉ:', selectedWarehouse.diaChi ?? 'N/A'),
                                    ],
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              
                              // Areas section
                              Text(
                                'KHU VỰC KHO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF534b0d),
                                ),
                              ),
                              SizedBox(height: 8),
                              
                              _areas.isEmpty
                                  ? Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: Text(
                                            'Chưa có khu vực nào trong kho này',
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: _areas.length,
                                        separatorBuilder: (context, index) => Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final area = _areas[index];
                                          return ListTile(
                                            title: Text('Khu vực ${area.khuVucKhoID ?? 'N/A'}'),
                                            trailing: Icon(Icons.info_outline),
                                            onTap: () {
                                              // Show area details if needed
                                            },
                                          );
                                        },
                                      ),
                                    ),
                              
                              SizedBox(height: 16),
                              
                              // Staff section - directly defined in this class
                              Text(
                                'NHÂN VIÊN ĐƯỢC PHÂN QUYỀN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF534b0d),
                                ),
                              ),
                              SizedBox(height: 8),
                              
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: warehouseStaff.isEmpty
                                  ? Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: Text(
                                          'Không có nhân viên nào được phân quyền cho kho này',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: warehouseStaff.length,
                                      separatorBuilder: (context, index) => Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final staff = warehouseStaff[index];
                                        return _buildStaffItem(
                                          staff['name'] ?? 'Unknown',
                                          staff['position'] ?? 'No position',
                                          staff['canImport'] ?? false,
                                          staff['canExport'] ?? false,
                                        );
                                      },
                                    ),
                              ),
                            ],
                          ),
                        ),
            ),
            
            // Footer with close button
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Đóng',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF837826),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffItem(String name, String position, bool canImport, bool canExport) {
    return ListTile(
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(position),
          SizedBox(height: 4),
          Row(
            children: [
              _buildPermissionChip('Nhập kho', canImport),
              SizedBox(width: 8),
              _buildPermissionChip('Xuất kho', canExport),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildPermissionChip(String label, bool hasPermission) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasPermission ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPermission ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPermission ? Icons.check_circle : Icons.cancel,
            color: hasPermission ? Colors.green : Colors.red,
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: hasPermission ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
class WarehouseInputDialog extends StatefulWidget {
  final String username;
  final List<KhoModel> warehouses;
  final String? defaultWarehouseId;
  final DBHelper dbHelper;
  final VoidCallback onSuccess;

  const WarehouseInputDialog({
    Key? key,
    required this.username,
    required this.warehouses,
    this.defaultWarehouseId,
    required this.dbHelper,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _WarehouseInputDialogState createState() => _WarehouseInputDialogState();
}

class _WarehouseInputDialogState extends State<WarehouseInputDialog> {
  bool _isLoading = false;
  String? _selectedWarehouseId;
  String? _selectedAreaId;
  DSHangModel? _selectedProduct;
  List<KhuVucKhoModel> _warehouseAreas = [];
  List<DSHangModel> _products = [];
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _shelfLifeController = TextEditingController(text: '0');
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _validateInputs() {
  // Basic validations
  if (_selectedWarehouseId == null) {
    _showError('Vui lòng chọn kho hàng');
    return false;
  }
  if (_selectedAreaId == null) {
    _showError('Vui lòng chọn khu vực kho');
    return false;
  }
  if (_selectedProduct == null) {
    _showError('Vui lòng chọn sản phẩm');
    return false;
  }
  // Validate quantity
  final quantity = double.tryParse(_quantityController.text);
  if (quantity == null || quantity <= 0) {
    _showError('Vui lòng nhập số lượng hợp lệ');
    return false;
  }
  // Validate shelf life
  final shelfLife = int.tryParse(_shelfLifeController.text);
  if (shelfLife == null || shelfLife < 0) {
    _showError('Hạn sử dụng không hợp lệ');
    return false;
  }
  // Special validation for products with shelf life
  if (_selectedProduct!.coThoiHan == 1 && shelfLife == 0) {
    _showError('Sản phẩm này cần có thời hạn sử dụng');
    return false;
  }
  return true;
}
  @override
  void initState() {
    super.initState();
    _selectedWarehouseId = widget.defaultWarehouseId;
    _loadWarehouseAreas();
    _loadProducts();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _shelfLifeController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouseAreas() async {
    if (_selectedWarehouseId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final areas = await widget.dbHelper.getKhuVucKhoByKhoID(_selectedWarehouseId!);
      setState(() {
        _warehouseAreas = areas;
        if (areas.isNotEmpty) {
          _selectedAreaId = areas.first.khuVucKhoID;
        } else {
          _selectedAreaId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Lỗi khi tải khu vực kho: ${e.toString()}');
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final products = await widget.dbHelper.getAllDSHang();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Lỗi khi tải danh sách hàng: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Generate a unique ID for LoHang
  String _generateLoHangID(DSHangModel product) {
  final now = DateTime.now();
  final datePart = '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year.toString().substring(2)}';
  // Extract Counter value correctly
  int counterValue = 0;
  if (product.counter != null) {
    counterValue = product.counter!;
  }
  // Format as 5 digits
  final counterPart = counterValue.toString().padLeft(5, '0');
  // Generate random suffix (1000-9999)
  final randomPart = (1000 + Random().nextInt(9000)).toString(); // Added semicolon here
  return '$datePart-$counterPart-$randomPart';
}

  // Generate transaction ID
  String _generateGiaoDichID() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    final random = Random().nextInt(10000).toString().padLeft(4, '0');
    return 'GDIN-$timestamp-$random';
  }
  Future<void> _submitWarehouseInput([String? preGeneratedLoHangID]) async {
  // Validate all inputs
  if (!_validateInputs()) {
    return;
  }
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Parse input values
    final quantity = double.parse(_quantityController.text);
    final shelfLife = int.parse(_shelfLifeController.text);
    
    // Generate IDs
    final loHangID = preGeneratedLoHangID ?? _generateLoHangID(_selectedProduct!);
    final giaoDichID = _generateGiaoDichID();
    
    // Get current date/time
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final formattedTime = DateFormat('HH:mm:ss').format(now);
    
    // Prepare LoHang data
    final loHang = LoHangModel(
      loHangID: loHangID,
      soLuongBanDau: quantity,
      soLuongHienTai: quantity,
      ngayNhap: formattedDate,
      ngayCapNhat: formattedDateTime,
      hanSuDung: shelfLife,
      trangThai: 'Bình thường',
      maHangID: _selectedProduct!.uid,
      khoHangID: _selectedWarehouseId,
      khuVucKhoID: _selectedAreaId,
    );
    
    // Prepare GiaoDichKho data
    final giaoDich = GiaoDichKhoModel(
      giaoDichID: giaoDichID,
      ngay: formattedDate,
      gio: formattedTime,
      nguoiDung: widget.username,
      trangThai: '+',
      loaiGiaoDich: 'Nhập kho',
      maGiaoDich: '',
      loHangID: loHangID,
      soLuong: quantity,
      ghiChu: _noteController.text,
      thucTe: null,
    );
    
    // Log the data being sent
    print('Sending LoHang data: ${jsonEncode(loHang.toMap())}');
    print('Sending GiaoDichKho data: ${jsonEncode(giaoDich.toMap())}');
    
    // Send to server - first save to local database to ensure data is stored
    await widget.dbHelper.insertLoHang(loHang);
    await widget.dbHelper.insertGiaoDichKho(giaoDich);
    
    // Then send to server
    bool serverSuccess = true;
    String errorMessage = '';
    
    try {
      // 1. Create LoHang on server
      final loHangResponse = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelnewlohang/${loHang.loHangID}'),
        body: jsonEncode(loHang.toMap()),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      print('LoHang server response: ${loHangResponse.statusCode} - ${loHangResponse.body}');
      
      if (loHangResponse.statusCode != 200) {
        serverSuccess = false;
        errorMessage = 'Lỗi khi tạo lô hàng: ${loHangResponse.statusCode}';
      }
      
      // 2. Create GiaoDichKho on server
      final giaoDichResponse = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelnewgiaodich/${giaoDich.giaoDichID}'),
        body: jsonEncode(giaoDich.toMap()),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      print('GiaoDichKho server response: ${giaoDichResponse.statusCode} - ${giaoDichResponse.body}');
      
      if (giaoDichResponse.statusCode != 200) {
        serverSuccess = false;
        errorMessage += '\nLỗi khi tạo giao dịch: ${giaoDichResponse.statusCode}';
      }
    } catch (e) {
      serverSuccess = false;
      errorMessage = 'Lỗi kết nối máy chủ: ${e.toString()}';
      print('Server connection error: $e');
    }
    
    setState(() {
      _isLoading = false;
    });
    
    // Show appropriate message
    if (serverSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nhập kho thành công'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_lohang_sync', formattedDateTime);
      await prefs.setString('last_giaodichkho_sync', formattedDateTime);
      
      // Close dialog and refresh data
      Navigator.of(context).pop();
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dữ liệu đã lưu cục bộ, nhưng chưa đồng bộ lên máy chủ.\n$errorMessage'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      
      // Close dialog but still refresh local data
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    _showError('Lỗi khi nhập kho: ${e.toString()}');
    print('Error in _submitWarehouseInput: $e');
  }
}
// Add this method to the _WarehouseInputDialogState class
void _scanCustomLoHangID() async {
  final result = await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => CustomLoHangIDScanScreen(
        onScanComplete: (String scannedId) {
          Navigator.of(context).pop(scannedId);
        },
      ),
    )
  );
  
  if (result != null && result is String && result.isNotEmpty) {
    // Check if the scanned ID is unique
    _checkLoHangIDUniqueness(result);
  }
}
// Add this method to validate a scanned barcode
bool _isValidBarcodeFormat(String barcode) {
  // Check if it's likely a UPC code (exactly 12 digits)
  if (RegExp(r'^\d{12}$').hasMatch(barcode)) {
    return false; // Don't allow UPC codes
  }
  
  // Check if it's likely a EAN-13 code (exactly 13 digits)
  if (RegExp(r'^\d{13}$').hasMatch(barcode)) {
    return false; // Don't allow EAN-13 codes
  }
  
  // Check if the barcode contains too many normal text characters
  // We'll allow some alphanumeric characters, but not exclusively normal text
  // For example, GS1-128 often contains special characters and numeric sequences
  int specialCharCount = 0;
  int numericCount = 0;
  
  for (int i = 0; i < barcode.length; i++) {
    if (RegExp(r'[0-9]').hasMatch(barcode[i])) {
      numericCount++;
    } else if (RegExp(r'[^a-zA-Z0-9]').hasMatch(barcode[i])) {
      specialCharCount++;
    }
  }
  
  // A barcode should have a substantial number of numbers and/or special characters
  // If it's mostly text, it's probably not a valid barcode
  if (numericCount / barcode.length < 0.4 && specialCharCount == 0) {
    return false; // Likely just normal text
  }
  
  // Check minimum length for safety
  if (barcode.length < 8) {
    return false; // Too short to be a meaningful barcode
  }
  
  return true;
}
// Add this method to check uniqueness
Future<void> _checkLoHangIDUniqueness(String loHangID) async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // First validate the barcode format
    if (!_isValidBarcodeFormat(loHangID)) {
      setState(() {
        _isLoading = false;
      });
      _showError('Mã vạch không hợp lệ. Vui lòng quét mã vạch chuẩn GS1-128 hoặc Code 128.');
      return;
    }
    
    // Check if loHangID already exists in database
    final existingLoHang = await widget.dbHelper.getLoHangById(loHangID);
    
    setState(() {
      _isLoading = false;
    });
    
    if (existingLoHang != null) {
      // ID already exists, show error
      _showError('Mã lô hàng "$loHangID" đã tồn tại trong hệ thống. Vui lòng sử dụng mã khác.');
    } else {
      // ID is unique, show confirmation dialog with the custom ID
      _showConfirmationDialog(loHangID);
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    _showError('Lỗi kiểm tra mã lô hàng: ${e.toString()}');
  }
}
void _showConfirmationDialog([String? customLoHangID]) {
  if (!_validateInputs()) {
    return;
  }
  
  final quantity = double.parse(_quantityController.text);
  final shelfLife = int.parse(_shelfLifeController.text);
  
  // Generate the loHangID in advance to show it in QR code, or use the custom one if provided
  final loHangID = customLoHangID ?? _generateLoHangID(_selectedProduct!);
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Xác nhận nhập kho', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn thực hiện nhập kho với thông tin sau:'),
            SizedBox(height: 12),
            _buildConfirmationRow('Sản phẩm:', _selectedProduct!.tenSanPham ?? 'N/A'),
            _buildConfirmationRow('Kho hàng:', widget.warehouses.firstWhere(
              (w) => w.khoHangID == _selectedWarehouseId,
              orElse: () => KhoModel(khoHangID: '', tenKho: 'N/A'),
            ).tenKho ?? 'N/A'),
            _buildConfirmationRow('Khu vực:', 'Khu vực $_selectedAreaId'),
            _buildConfirmationRow('Số lượng:', '$quantity ${_selectedProduct!.donVi ?? ''}'),
            if (shelfLife > 0)
              _buildConfirmationRow('Hạn sử dụng:', '$shelfLife tháng'),
            if (_noteController.text.isNotEmpty)
              _buildConfirmationRow('Ghi chú:', _noteController.text),
            
            // Add indication of custom loHangID if provided
            if (customLoHangID != null)
              Container(
                margin: EdgeInsets.only(top: 8, bottom: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn đang sử dụng mã lô hàng tùy chỉnh',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            SizedBox(height: 24),
            
            // QR Code section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Mã QR lô hàng:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF534b0d),
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // QR Code
                  Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: loHangID,
                      version: QrVersions.auto,
                      size: 150,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Lot ID text
                  Text(
                    'Mã lô: $loHangID',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Product ID text
                  Text(
                    'Mã sản phẩm: ${_selectedProduct!.uid ?? "N/A"}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Print button
                  ElevatedButton.icon(
                    onPressed: () => _printQRCode(loHangID, _selectedProduct!.uid ?? ""),
                    icon: Icon(Icons.print, size: 18),
                    label: Text('In mã QR (5x5 cm)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _submitWarehouseInput(loHangID); 
          },
          child: Text('Xác nhận', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF837826),
          ),
        ),
      ],
    ),
  );
}
Future<void> _printQRCode(String loHangID, String maHangID) async {
  try {
    final pdf = pw.Document();
    
    // Use horizontal page format (5x3cm)
    pdf.addPage(
      pw.Page(
        pageFormat: pdfx.PdfPageFormat(50 * pdfx.PdfPageFormat.mm, 30 * pdfx.PdfPageFormat.mm, marginAll: 2 * pdfx.PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // QR Code on the left
                pw.Container(
                  width: 26 * pdfx.PdfPageFormat.mm,
                  height: 26 * pdfx.PdfPageFormat.mm,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: loHangID,
                    width: 26 * pdfx.PdfPageFormat.mm,
                    height: 26 * pdfx.PdfPageFormat.mm,
                  ),
                ),
                
                pw.SizedBox(width: 4 * pdfx.PdfPageFormat.mm),
                
                // Rotated text information on the right
                pw.Container(
                  width: 16 * pdfx.PdfPageFormat.mm,
                  height: 26 * pdfx.PdfPageFormat.mm,
                  alignment: pw.Alignment.center,
                  child: pw.Transform.rotate(
                    angle: 90 * 3.1415927 / 180, // Rotate 90 degrees (counter-clockwise)
                    child: pw.Container(
                      width: 26 * pdfx.PdfPageFormat.mm, // Height of the original container becomes width
                      height: 16 * pdfx.PdfPageFormat.mm, // Width of the original container becomes height
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Lot ID text
                          pw.Text(
                            'Mã lô: $loHangID',
                            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2 * pdfx.PdfPageFormat.mm),
                          
                          // Product ID text
                          pw.Text(
                            'Mã SP: $maHangID',
                            style: pw.TextStyle(fontSize: 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    // Print the document
    await Printing.layoutPdf(
      onLayout: (pdfx.PdfPageFormat format) async => pdf.save(),
      format: pdfx.PdfPageFormat(50 * pdfx.PdfPageFormat.mm, 30 * pdfx.PdfPageFormat.mm),
      name: 'QR_${loHangID}.pdf',
    );
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi lệnh in mã QR thành công'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi in mã QR: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    print('Error printing QR code: $e');
  }
}
Widget _buildConfirmationRow(String label, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    ),
  );
}
  void _searchProducts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<DSHangModel> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    
    return _products.where((product) {
      return (product.tenSanPham?.toLowerCase().contains(_searchQuery) ?? false) ||
             (product.sku?.toLowerCase().contains(_searchQuery) ?? false) ||
             (product.uid?.toLowerCase().contains(_searchQuery) ?? false) ||
             (product.maNhapKho?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Color(0xFF534b0d),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'NHẬP KHO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Warehouse section
                        Text(
                          'THÔNG TIN KHO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF534b0d),
                          ),
                        ),
                        SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Warehouse dropdown
                                _buildDropdownField(
                                  label: 'Kho hàng',
                                  hint: 'Chọn kho hàng',
                                  value: _selectedWarehouseId,
                                  items: widget.warehouses.map((warehouse) {
                                    return DropdownMenuItem<String>(
                                      value: warehouse.khoHangID,
                                      child: Text(warehouse.tenKho ?? 'Kho không tên'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedWarehouseId = value as String?;
                                      _selectedAreaId = null;
                                    });
                                    _loadWarehouseAreas();
                                  },
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Warehouse area dropdown
                                _buildDropdownField(
                                  label: 'Khu vực kho',
                                  hint: 'Chọn khu vực kho',
                                  value: _selectedAreaId,
                                  items: _warehouseAreas.map((area) {
                                    return DropdownMenuItem<String>(
                                      value: area.khuVucKhoID,
                                      child: Text('Khu vực ${area.khuVucKhoID}'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAreaId = value as String?;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Product selection section
                        Text(
                          'CHỌN SẢN PHẨM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF534b0d),
                          ),
                        ),
                        SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Search bar
                                TextField(
                                  controller: _searchController,
                                  onChanged: _searchProducts,
                                  decoration: InputDecoration(
                                    hintText: 'Tìm kiếm sản phẩm...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                                  ),
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Product list with radio selection
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _isLoading
                                      ? Center(child: CircularProgressIndicator())
                                      : ListView.builder(
                                          itemCount: _filteredProducts.length,
                                          itemBuilder: (context, index) {
                                            final product = _filteredProducts[index];
                                            return RadioListTile<DSHangModel>(
                                              title: Text(
                                                product.tenSanPham ?? 'Sản phẩm không tên',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                'Mã: ${product.sku ?? 'N/A'} | ID: ${product.uid ?? 'N/A'}',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              value: product,
                                              groupValue: _selectedProduct,
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedProduct = value;
                                                });
                                              },
                                              activeColor: Color(0xFF837826),
                                              dense: true,
                                            );
                                          },
                                        ),
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Selected product info
                                if (_selectedProduct != null) ...[
  Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sản phẩm đã chọn:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text('Tên: ${_selectedProduct!.tenSanPham ?? 'N/A'}'),
        Text('Mã: ${_selectedProduct!.sku ?? 'N/A'}'),
        Text('Đơn vị: ${_selectedProduct!.donVi ?? 'N/A'}'),
        Text('Mã số: ${_selectedProduct!.counter != null ? _selectedProduct!.counter.toString() : 'N/A'}'),
        if (_selectedProduct!.coThoiHan == 1)
          Text(
            'Sản phẩm có thời hạn sử dụng',
            style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
          ),
        
        // Add custom loHangID button
        SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _scanCustomLoHangID,
          icon: Icon(Icons.qr_code_scanner, size: 18),
          label: Text('Quét mã lô hàng tùy chỉnh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFF534b0d),
            side: BorderSide(color: Color(0xFF534b0d)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ),
  ),
],
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Input details section
                        Text(
                          'THÔNG TIN NHẬP KHO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF534b0d),
                          ),
                        ),
                        SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Quantity field
                                _buildTextField(
                                  controller: _quantityController,
                                  label: 'Số lượng',
                                  keyboardType: TextInputType.number,
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Shelf life field
                                _buildTextField(
                                  controller: _shelfLifeController,
                                  label: 'Hạn sử dụng (tháng)',
                                  hint: 'Nhập 0 nếu không có hạn sử dụng',
                                  keyboardType: TextInputType.number,
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Note field
                                _buildTextField(
                                  controller: _noteController,
                                  label: 'Ghi chú',
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer with action buttons
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Hủy',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
  onPressed: _isLoading ? null : _showConfirmationDialog,
  child: Text(
    'Nhập kho',
    style: TextStyle(color: Colors.white),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFF837826),
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            
            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(hint),
              isExpanded: true,
             items: items,
             onChanged: onChanged,
             icon: Icon(Icons.arrow_drop_down, color: Color(0xFF837826)),
           ),
         ),
       ),
     ],
   );
 }
}
class WarehouseOutputDialog extends StatefulWidget {
  final String username;
  final List<KhoModel> warehouses;
  final List<DonHangModel> pendingOrders;
  final String? defaultWarehouseId;
  final DBHelper dbHelper;
  final VoidCallback onSuccess;

  const WarehouseOutputDialog({
    Key? key,
    required this.username,
    required this.warehouses,
    required this.pendingOrders,
    this.defaultWarehouseId,
    required this.dbHelper,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _WarehouseOutputDialogState createState() => _WarehouseOutputDialogState();
}

class _WarehouseOutputDialogState extends State<WarehouseOutputDialog> {
  bool _isLoading = false;
  String? _selectedWarehouseId;
  DonHangModel? _selectedOrder;
  ChiTietDonModel? _selectedOrderItem;
  LoHangModel? _selectedBatch;
  List<ChiTietDonModel> _orderItems = [];
  List<LoHangModel> _availableBatches = [];
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _selectedWarehouseId = widget.defaultWarehouseId;
    
    // Auto-select order if only one is provided
    if (widget.pendingOrders.length == 1) {
      _selectedOrder = widget.pendingOrders.first;
      _loadOrderItems();
    }
  }
  
  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }
  
  bool _validateInputs() {
    // Basic validations
    if (_selectedWarehouseId == null) {
      _showError('Vui lòng chọn kho hàng');
      return false;
    }
    if (_selectedOrder == null) {
      _showError('Vui lòng chọn đơn hàng');
      return false;
    }
    if (_selectedOrderItem == null) {
      _showError('Vui lòng chọn mặt hàng');
      return false;
    }
    if (_selectedBatch == null) {
      _showError('Vui lòng chọn lô hàng');
      return false;
    }
    
    // Validate quantity
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showError('Vui lòng nhập số lượng hợp lệ');
      return false;
    }
    
    // Check if quantity exceeds available amount
    if (quantity > (_selectedBatch!.soLuongHienTai ?? 0)) {
      _showError('Số lượng xuất vượt quá số lượng hiện có trong lô hàng');
      return false;
    }
    
    return true;
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  Future<void> _loadOrderItems() async {
    if (_selectedOrder == null || _selectedOrder!.soPhieu == null) return;
    
    setState(() {
      _isLoading = true;
      _selectedOrderItem = null;
      _selectedBatch = null;
      _availableBatches = [];
    });
    
    try {
      // Load order items
      final items = await widget.dbHelper.getChiTietDonBySoPhieu(_selectedOrder!.soPhieu!);
      
      setState(() {
        _orderItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Lỗi khi tải chi tiết đơn hàng: ${e.toString()}');
    }
  }
  
  Future<void> _loadAvailableBatches() async {
  if (_selectedOrderItem == null || _selectedOrderItem!.idHang == null || _selectedWarehouseId == null) return;
  
  setState(() {
    _isLoading = true;
    _selectedBatch = null;
  });
  
  try {
    // Find batches matching the product ID and warehouse
    final batches = await widget.dbHelper.getLoHangByMaHangAndKho(
      _selectedOrderItem!.idHang!, // Correct field name
      _selectedWarehouseId!
    );
      
      // Filter for batches with available quantity
      final availableBatches = batches.where((batch) => 
        (batch.soLuongHienTai ?? 0) > 0
      ).toList();
      
      // Sort by expiry date (if applicable) and/or date received
      availableBatches.sort((a, b) {
        // If both have expiry dates, sort by that first
        if (a.hanSuDung != null && b.hanSuDung != null && a.hanSuDung! > 0 && b.hanSuDung! > 0) {
          return a.hanSuDung!.compareTo(b.hanSuDung!);
        }
        
        // Otherwise sort by date received (oldest first)
        if (a.ngayNhap != null && b.ngayNhap != null) {
          return a.ngayNhap!.compareTo(b.ngayNhap!);
        }
        
        return 0;
      });
      
      setState(() {
        _availableBatches = availableBatches;
        
        // Auto-select first batch if available and set suggested quantity
        if (availableBatches.isNotEmpty) {
          _selectedBatch = availableBatches.first;
          
          // Set default quantity to either the requested amount or maximum available
          final requestedQty = _selectedOrderItem!.soLuongYeuCau ?? 0;
          final availableQty = _selectedBatch!.soLuongHienTai ?? 0;
          final defaultQty = requestedQty < availableQty ? requestedQty : availableQty;
          
          _quantityController.text = defaultQty.toString();
        } else {
          _quantityController.text = "";
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Lỗi khi tìm kiếm lô hàng: ${e.toString()}');
    }
  }
  
  // Generate transaction ID
  String _generateGiaoDichID() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    final random = Random().nextInt(10000).toString().padLeft(4, '0');
    return 'GDOUT-$timestamp-$random';
  }
  
  Future<void> _submitWarehouseOutput() async {
    // Validate all inputs
    if (!_validateInputs()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Parse input values
      final quantity = double.parse(_quantityController.text);
      
      // Generate transaction ID
      final giaoDichID = _generateGiaoDichID();
      
      // Get current date/time
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd').format(now);
      final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final formattedTime = DateFormat('HH:mm:ss').format(now);
      
      // Update batch quantity
      final updatedBatch = LoHangModel(
        loHangID: _selectedBatch!.loHangID,
        soLuongBanDau: _selectedBatch!.soLuongBanDau,
        soLuongHienTai: (_selectedBatch!.soLuongHienTai ?? 0) - quantity,
        ngayNhap: _selectedBatch!.ngayNhap,
        ngayCapNhat: formattedDateTime,
        hanSuDung: _selectedBatch!.hanSuDung,
        trangThai: (_selectedBatch!.soLuongHienTai ?? 0) - quantity <= 0 ? 'Đã hết' : 'Bình thường',
        maHangID: _selectedBatch!.maHangID,
        khoHangID: _selectedBatch!.khoHangID,
        khuVucKhoID: _selectedBatch!.khuVucKhoID,
      );
      
      // Prepare GiaoDichKho data
      final giaoDich = GiaoDichKhoModel(
        giaoDichID: giaoDichID,
        ngay: formattedDate,
        gio: formattedTime,
        nguoiDung: widget.username,
        trangThai: '-',
        loaiGiaoDich: 'Xuất kho',
        maGiaoDich: _selectedOrder!.soPhieu ?? '',
        loHangID: _selectedBatch!.loHangID ?? '',
        soLuong: quantity,
        ghiChu: _noteController.text,
        thucTe: null,
      );
      
      // Save to local database
      await widget.dbHelper.updateLoHang(updatedBatch);
      await widget.dbHelper.insertGiaoDichKho(giaoDich);
      
      // Send to server
      bool serverSuccess = true;
      String errorMessage = '';
      
      try {
        // 1. Update LoHang on server
        final loHangResponse = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelupdatelohang/${updatedBatch.loHangID}'),
          body: jsonEncode(updatedBatch.toMap()),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 10));
        
        if (loHangResponse.statusCode != 200) {
          serverSuccess = false;
          errorMessage = 'Lỗi khi cập nhật lô hàng: ${loHangResponse.statusCode}';
        }
        
        // 2. Create GiaoDichKho on server
        final giaoDichResponse = await http.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelnewgiaodich/${giaoDich.giaoDichID}'),
          body: jsonEncode(giaoDich.toMap()),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 10));
        
        if (giaoDichResponse.statusCode != 200) {
          serverSuccess = false;
          errorMessage += '\nLỗi khi tạo giao dịch: ${giaoDichResponse.statusCode}';
        }
      } catch (e) {
        serverSuccess = false;
        errorMessage = 'Lỗi kết nối máy chủ: ${e.toString()}';
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // Show appropriate message
      if (serverSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xuất kho thành công'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Update last sync time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_lohang_sync', formattedDateTime);
        await prefs.setString('last_giaodichkho_sync', formattedDateTime);
        
        // Close dialog and refresh data
        Navigator.of(context).pop();
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dữ liệu đã lưu cục bộ, nhưng chưa đồng bộ lên máy chủ.\n$errorMessage'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Close dialog but still refresh local data
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Lỗi khi xuất kho: ${e.toString()}');
    }
  }
  
  Widget build(BuildContext context) {
  return Dialog(
    insetPadding: EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: 1200,
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Color(0xFF534b0d),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Text(
                    'XUẤT KHO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Essential info row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Warehouse dropdown (left side)
                          Expanded(
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: _buildDropdownField<String>(
                                  label: 'Kho hàng',
                                  hint: 'Chọn kho hàng',
                                  value: _selectedWarehouseId,
                                  items: widget.warehouses.map((warehouse) {
                                    return DropdownMenuItem<String>(
                                      value: warehouse.khoHangID,
                                      child: Text(warehouse.tenKho ?? 'Kho không tên'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedWarehouseId = value;
                                      if (_selectedOrderItem != null) {
                                        _loadAvailableBatches();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(width: 12),
                          
                          // Order info (right side)
                          Expanded(
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đơn hàng:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '${_selectedOrder?.soPhieu ?? "N/A"} - ${_selectedOrder?.tenKhachHang2 ?? _selectedOrder?.tenKhachHang ?? "N/A"}',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text('Ngày: ${_selectedOrder?.ngay ?? "N/A"}'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Order items section - made more prominent
                      if (_orderItems.isNotEmpty) ...[
                        Text(
                          'CHỌN MẶT HÀNG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF534b0d),
                          ),
                        ),
                        SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            height: 200, // Fixed height for scrollable list
                            child: ListView.separated(
                              padding: EdgeInsets.all(12),
                              itemCount: _orderItems.length,
                              separatorBuilder: (context, index) => Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _orderItems[index];
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedOrderItem = item;
                                      _selectedBatch = null;
                                      _quantityController.text = "";
                                    });
                                    if (item != null) {
                                      _loadAvailableBatches();
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: _selectedOrderItem == item 
                                          ? Color(0xFFf5f3e0) 
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        // Selection indicator
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _selectedOrderItem == item 
                                                ? Color(0xFF837826) 
                                                : Colors.grey[300],
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        // Item details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.tenHang ?? 'Sản phẩm không tên',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Mã: ${item.idHang ?? "N/A"}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Quantity indicator
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12, 
                                            vertical: 6
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFf0f0f0),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.grey[300]!),
                                          ),
                                          child: Text(
                                            'SL: ${item.soLuongYeuCau ?? "0"} ${item.donViTinh ?? ""}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      
                      if (_availableBatches.isNotEmpty) ...[
                        SizedBox(height: 16),
                        
                        // Batch and quantity section combined in one card
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CHỌN LÔ HÀNG VÀ SỐ LƯỢNG',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF534b0d),
                                  ),
                                ),
                                SizedBox(height: 16),
                                
                                // Batch selection
                                _buildDropdownField<LoHangModel>(
                                  label: 'Lô hàng',
                                  hint: 'Chọn lô hàng',
                                  value: _selectedBatch,
                                  items: _availableBatches.map((batch) {
                                    String expiryInfo = '';
                                    if (batch.hanSuDung != null && batch.hanSuDung! > 0) {
                                      expiryInfo = ' | HSD: ${batch.hanSuDung} tháng';
                                    }
                                    return DropdownMenuItem<LoHangModel>(
                                      value: batch,
                                      child: Text('${batch.loHangID} | SL: ${batch.soLuongHienTai ?? 0}$expiryInfo'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBatch = value;
                                      
                                      if (value != null) {
                                        final requestedQty = _selectedOrderItem!.soLuongYeuCau ?? 0;
                                        final availableQty = value.soLuongHienTai ?? 0;
                                        final defaultQty = requestedQty < availableQty ? requestedQty : availableQty;
                                        
                                        _quantityController.text = defaultQty.toString();
                                      } else {
                                        _quantityController.text = "";
                                      }
                                    });
                                  },
                                ),
                                
                                if (_selectedBatch != null) ...[
                                  SizedBox(height: 16),
                                  
                                  // Batch info and quantity in a row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Batch info
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Thông tin lô hàng:',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              SizedBox(height: 8),
                                              Text('Mã lô: ${_selectedBatch!.loHangID ?? "N/A"}'),
                                              Text('Số lượng có sẵn: ${_selectedBatch!.soLuongHienTai ?? "0"}'),
                                              if (_selectedBatch!.hanSuDung != null && _selectedBatch!.hanSuDung! > 0)
                                                Text('Hạn sử dụng: ${_selectedBatch!.hanSuDung} tháng'),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(width: 16),
                                      
                                      // Quantity field - made more prominent
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Số lượng xuất',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            TextField(
                                              controller: _quantityController,
                                              keyboardType: TextInputType.number,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                    color: Color(0xFF837826),
                                                    width: 2,
                                                  ),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 16,
                                                ),
                                                helperText: 'Tối đa: ${_selectedBatch!.soLuongHienTai}',
                                                suffix: Text(
                                                  _selectedOrderItem?.donViTinh ?? '',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                              onChanged: (value) {
                                                final maxValue = _selectedBatch!.soLuongHienTai ?? 0;
                                                final inputValue = double.tryParse(value);
                                                if (inputValue != null && inputValue > maxValue) {
                                                  _quantityController.text = maxValue.toString();
                                                  _quantityController.selection = TextSelection.fromPosition(
                                                    TextPosition(offset: _quantityController.text.length),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 16),
                                  
                                  // Note field
                                  TextField(
                                    controller: _noteController,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      labelText: 'Ghi chú (không bắt buộc)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Footer with action buttons
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Hủy',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading || _selectedBatch == null ? null : _submitWarehouseOutput,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          'Xuất kho',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF837826),
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
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    double? maxValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            helperText: maxValue != null ? 'Tối đa: $maxValue' : null,
          ),
          onChanged: (value) {
            if (maxValue != null) {
              // Validate input doesn't exceed max value
              final inputValue = double.tryParse(value);
              if (inputValue != null && inputValue > maxValue) {
                controller.text = maxValue.toString();
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(hint),
              isExpanded: true,
              items: items,
              onChanged: onChanged,
              icon: Icon(Icons.arrow_drop_down, color: Color(0xFF837826)),
            ),
          ),
        ),
      ],
    );
  }
}
class CustomLoHangIDScanScreen extends StatefulWidget {
  final Function(String) onScanComplete;
  
  const CustomLoHangIDScanScreen({
    Key? key,
    required this.onScanComplete,
  }) : super(key: key);
  
  @override
  _CustomLoHangIDScanScreenState createState() => _CustomLoHangIDScanScreenState();
}

class _CustomLoHangIDScanScreenState extends State<CustomLoHangIDScanScreen> {
  bool _isScanning = true;
  bool _hasError = false;
  String _errorMessage = '';
  MobileScannerController? _scannerController;
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }
  
  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    setState(() {
      _isScanning = true;
    });
  }
  
  Future<void> _onDetect(BarcodeCapture capture) async {
  if (!_isScanning) return;
  
  final List<Barcode> barcodes = capture.barcodes;
  if (barcodes.isEmpty) return;
  
  final String? code = barcodes.first.rawValue;
  if (code == null || code.isEmpty) return;
  
  // Get the barcode format if available
  final BarcodeType? format = barcodes.first.type;
  
  // Only proceed for certain barcode types
  bool isAcceptableFormat = true;
  
  // If we can detect the format, filter out UPC and EAN
  if (format != null) {
    // Check using string representation instead of direct enum comparison
    String formatName = format.toString();
    if (formatName.contains('upc') || 
        formatName.contains('ean8') || 
        formatName.contains('ean13') ||
        formatName.contains('ean_8') || 
        formatName.contains('ean_13')) {
      isAcceptableFormat = false;
    }
  }
  
  // Check for square brackets in the code
  if (code.contains('[') || code.contains(']')) {
    isAcceptableFormat = false;
  }
  
  // Simple validation for obviously invalid barcodes
  if (code.length < 8) {
    isAcceptableFormat = false;
  }
  
  if (!isAcceptableFormat) {
    // Give feedback but don't stop scanning
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mã vạch không hợp lệ. Vui lòng quét loại mã GS1-128 hoặc Code 128.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  
  setState(() {
    _isScanning = false;
  });
   
  // Pass the scanned code back
  widget.onScanComplete(code);
}
  
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Quét mã lô hàng'),
      backgroundColor: Color(0xFF534b0d),
      foregroundColor: Colors.white,
    ),
    body: Stack(
      children: [
        // Scanner
        _hasError
            ? _buildErrorView()
            : _buildScannerView(),
        
        // Instructions
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 24),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Quét mã lô hàng tùy chỉnh',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Hướng camera vào mã vạch GS1-128 hoặc Code 128.\nLưu ý: Mã UPC, EAN-13 hoặc văn bản thông thường không được chấp nhận.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScannerView() {
    return Stack(
      children: [
        // Scanner
        _scannerController != null
            ? MobileScanner(
                controller: _scannerController!,
                onDetect: _onDetect,
              )
            : Center(child: CircularProgressIndicator()),
        
        // Scan overlay
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
          ),
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white.withOpacity(0.8),
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Đang quét...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}