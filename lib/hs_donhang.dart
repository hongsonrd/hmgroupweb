
// hs_donhang.dart with enhanced features
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'user_credentials.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:excel/excel.dart' as xl;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pdfx;
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'hs_pxkform.dart';
import 'hs_pycform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hs_donhangmoi.dart';

class HSDonHangScreen extends StatefulWidget {
  final String? username;
  
  const HSDonHangScreen({Key? key, this.username}) : super(key: key);

  @override
  _HSDonHangScreenState createState() => _HSDonHangScreenState();
}

class _HSDonHangScreenState extends State<HSDonHangScreen> {
  final DBHelper _dbHelper = DBHelper();
  late String _username = '';
  List<DonHangModel> _orders = [];
  List<DonHangModel> _filteredOrders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showPendingOnly = false;
  TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAgent;
  String? _selectedStatus;
  Map<String, bool> _collapsedSections = {};
  Map<String, String> _processingOrders = {};
  Timer? _cleanupTimer;
  Set<String> _processingApprovals = {};
  bool _isTableMode = false; // New state for table view

  // List of admin users who can see all orders and approve
  final List<String> adminUsers = [
    'hm.tason',
    'hm.luukinh',
    'hm.trangiang',
    'hm.damlinh',
    'nvthunghiem',
    'hm.manhha',
  ];

  // List of statuses that need approval
  final List<String> pendingStatuses = ['gửi', 'gửi xuất nội bộ', 'dự trù'];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(Duration(days: 30));
    _endDate = DateTime.now();
    _loadUserAndOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cleanupTimer?.cancel();
    super.dispose();
  }
Future<void> _deleteOrder(String soPhieu) async {
  // Show confirmation dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Xác nhận xoá đơn'),
      content: Text('Bạn có chắc chắn muốn xoá đơn hàng $soPhieu?\n\nHành động này không thể hoàn tác.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Xoá', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
        ),
      ],
    ),
  ) ?? false;

  if (!confirm) return;

  setState(() {
    _processingOrders[soPhieu] = 'processing';
  });

  try {
    final url = Uri.parse(
      'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldonhangxoa/$soPhieu'
    );
    
    print('Sending delete request to: ${url.toString()}');

    final response = await http.get(url);
    
    print('Delete response status code: ${response.statusCode}');
    print('Delete response body: ${response.body}');

    if (response.statusCode == 200) {
      setState(() {
        _processingOrders[soPhieu] = 'success';
      });

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Thành công'),
          content: Text('Đơn hàng $soPhieu đã được xoá thành công.\n\nVui lòng nhấn đồng bộ ở trên để cập nhật danh sách.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadOrders(); // Refresh the orders list
              },
              child: Text('Đã xong', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF534b0d),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _processingOrders[soPhieu] = 'error';
      });
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Lỗi'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Không thể xoá đơn hàng. Vui lòng thử lại sau.'),
                SizedBox(height: 8),
                Text('URL: ${url.toString()}', style: TextStyle(fontSize: 12)),
                Text('Mã lỗi: ${response.statusCode}', style: TextStyle(fontSize: 12)),
                Text('Phản hồi: ${response.body}', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    print('Exception deleting order: $e');
    setState(() {
      _processingOrders[soPhieu] = 'error';
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lỗi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không thể xoá đơn hàng.'),
              SizedBox(height: 8),
              Text('Chi tiết lỗi: $e', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

bool _canDeleteOrder(DonHangModel order) {
  final isOrderCreator = (order.nguoiTao?.toLowerCase() ?? '') == _username.toLowerCase();
  final lowerStatus = (order.trangThai ?? '').toLowerCase();
  
  final deletableStatuses = [
    'chưa xong',
    'gửi', 
    'duyệt',
    'xuất nội bộ',
    'gửi xuất nội bộ',
    'dự trù'
  ];
  
  return isOrderCreator && deletableStatuses.contains(lowerStatus);
}
  Future<void> _exportToExcel() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Create a new Excel document with two sheets - note the xl. prefix
      final excel = xl.Excel.createExcel();

      // Remove the default sheet
      excel.delete('Sheet1');

      // Create DonHang sheet
      final donHangSheet = excel['DonHang'];

      // Add header row for DonHang
      final donHangHeaders = [
        'Số phiếu',
        'Ngày',
        'Khách hàng',
        'SĐT',
        'Mã số thuế',
        'Địa chỉ',
        'Tổng tiền',
        'VAT',
        'Tổng cộng',
        'Trạng thái',
        'Người tạo',
        'Thời gian cập nhật'
      ];
      donHangSheet.appendRow(donHangHeaders);

      // Add data rows for filtered orders
      for (var order in _filteredOrders) {
        donHangSheet.appendRow([
          order.soPhieu ?? '',
          order.ngay ?? '',
          order.tenKhachHang ?? '',
          order.sdtKhachHang ?? '',
          order.mst ?? '',
          order.diaChi ?? '',
          order.tongTien ?? 0,
          order.vat10 ?? 0,
          order.tongCong ?? 0,
          order.trangThai ?? '',
          order.nguoiTao ?? '',
          order.thoiGianCapNhatMoiNhat ?? '',
        ]);
      }

      // Create ChiTietDon sheet
      final chiTietSheet = excel['ChiTietDonHang'];

      // Add header row for ChiTietDon
      final chiTietHeaders = [
        'Số phiếu',
        'Mã hàng',
        'Tên hàng',
        'Số lượng',
        'Đơn vị tính',
        'Đơn giá',
        'Thành tiền'
      ];
      chiTietSheet.appendRow(chiTietHeaders);

      // Fetch chi tiết đơn hàng for all filtered orders
      List<ChiTietDonModel> allItems = [];
      for (var order in _filteredOrders) {
        if (order.soPhieu != null) {
          List<ChiTietDonModel> items =
              await _dbHelper.getChiTietDonBySoPhieu(order.soPhieu!);
          allItems.addAll(items);
        }
      }

      // Add data rows for chi tiết đơn hàng
      for (var item in allItems) {
        chiTietSheet.appendRow([
          item.soPhieu ?? '',
          item.maHang ?? '',
          item.tenHang ?? '',
          item.soLuongYeuCau ?? 0,
          item.donViTinh ?? '',
          item.donGia ?? 0,
          item.thanhTien ?? 0,
        ]);
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      String fileName =
          'don_hang_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      // Save the excel file
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // Share the file
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Danh sách đơn hàng',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: Không thể xuất Excel. ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error exporting to Excel: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserAndOrders() async {
    try {
      final userCredentials =
          Provider.of<UserCredentials>(context, listen: false);
      _username = userCredentials.username.toLowerCase();

      await _loadOrders();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi tải dữ liệu: ${e.toString()}';
      });
      print('Error loading data: $e');
    }
  }

  Future<void> _loadOrders() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    // Get all orders from database
    final allOrders = await _dbHelper.getAllDonHang();

    // Filter based on username
    if (adminUsers.contains(_username)) {
      // Admin users see all orders
      _orders = allOrders;
    } else {
      // Regular users only see their own orders
      _orders = allOrders
          .where(
              (order) => (order.nguoiTao?.toLowerCase() ?? '') == _username)
          .toList();
    }

    // Sort by update time first, then by status
    _sortOrders();

    // **ADD THIS SECTION: Initialize all sections as collapsed**
    // Get unique statuses from the orders
    final uniqueStatuses = _orders
        .map((order) => order.trangThai?.toLowerCase() ?? '')
        .where((status) => status.isNotEmpty)
        .toSet();
    
    // Initialize all sections as collapsed (true = collapsed)
    for (String status in uniqueStatuses) {
      _collapsedSections[status] = true;
    }

    // First set filtered orders to all orders
    setState(() {
      _filteredOrders = List.from(_orders);
      _isLoading = false;
      _processingApprovals.clear(); // Clear processing approvals after reload
    });

    // Then apply any filters
    _applyFilters();
  } catch (e) {
    setState(() {
      _isLoading = false;
      _errorMessage = 'Lỗi tải dữ liệu: ${e.toString()}';
    });
    print('Error loading orders: $e');
  }
}

  void _sortOrders() {
    // First sort by update time (newest first)
    _orders.sort((a, b) {
      final aTime = a.thoiGianCapNhatMoiNhat ?? '';
      final bTime = b.thoiGianCapNhatMoiNhat ?? '';
      return bTime.compareTo(aTime);
    });

    // Then group by status by using a stable sort
    // This preserves the time sorting within each status group
    final Map<String, int> statusPriority = {
      'gửi': 0,
      'gửi xuất nội bộ': 1,
      'dự trù': 2,
      'chờ duyệt': 3,
      'đã duyệt': 4,
      'đã giao': 5,
      'đã huỷ': 6,
    };

    _orders.sort((a, b) {
      final aStatus = (a.trangThai ?? '').toLowerCase();
      final bStatus = (b.trangThai ?? '').toLowerCase();
      final aPriority = statusPriority[aStatus] ?? 999;
      final bPriority = statusPriority[bStatus] ?? 999;
      return aPriority.compareTo(bPriority);
    });
  }

  void _filterOrders() {
    _applyFilters();
  }

  void _applyFilters() {
    List<DonHangModel> result = List.from(_orders);

    // Apply date range filter if set
    if (_startDate != null && _endDate != null) {
      result = result.where((order) {
        if (order.ngay == null) return false;
        try {
          final orderDate = DateTime.parse(order.ngay!);
          return orderDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
              orderDate.isBefore(_endDate!.add(Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Apply agent filter if set
    if (_selectedAgent != null) {
      result = result
          .where((order) =>
              (order.nguoiTao?.toLowerCase() ?? '') == _selectedAgent!.toLowerCase())
          .toList();
    }

    // Apply status filter if set
    if (_selectedStatus != null) {
      result = result
          .where((order) =>
              (order.trangThai?.toLowerCase() ?? '') == _selectedStatus!.toLowerCase())
          .toList();
    }

    // Apply pending status filter if enabled
    if (_showPendingOnly) {
      result = result
          .where((order) =>
              pendingStatuses.contains((order.trangThai ?? '').toLowerCase()))
          .toList();
    }

    // Apply search text filter if any
    final searchText = _searchController.text.toLowerCase();
    if (searchText.isNotEmpty) {
      result = result
          .where((order) =>
              (order.soPhieu?.toLowerCase() ?? '').contains(searchText) ||
              (order.tenKhachHang?.toLowerCase() ?? '').contains(searchText) ||
              (order.tenKhachHang2?.toLowerCase() ?? '').contains(searchText))
          .toList();
    }

    setState(() {
      _filteredOrders = result;
    });
  }

  Future<void> _showDateRangePicker() async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
      end: _endDate ?? DateTime.now(),
    );

    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFFb2a41f),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
      });
      _applyFilters();
    }
  }

  void _showAgentFilterDialog() {
    // Get unique agents from orders
    final agents = _orders
        .map((order) => order.nguoiTao?.toLowerCase() ?? '')
        .where((agent) => agent.isNotEmpty)
        .toSet()
        .toList();
    agents.sort();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn người tạo đơn'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final agent = agents[index];
              return RadioListTile<String>(
                title: Text(agent),
                value: agent,
                groupValue: _selectedAgent,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _selectedAgent = value;
                  });
                  _applyFilters();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedAgent = null;
              });
              _applyFilters();
            },
            child: Text('Xoá lọc'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showStatusFilterDialog() {
    // Get unique statuses from orders
    final statuses = _orders
        .map((order) => order.trangThai?.toLowerCase() ?? '')
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList();

    // Sort statuses by priority
    final Map<String, int> statusPriority = {
      'gửi': 0,
      'gửi xuất nội bộ': 1,
      'dự trù': 2,
      'chờ duyệt': 3,
      'đã duyệt': 4,
      'đã giao': 5,
      'đã huỷ': 6,
    };

    statuses.sort((a, b) {
      final aPriority = statusPriority[a] ?? 999;
      final bPriority = statusPriority[b] ?? 999;
      return aPriority.compareTo(bPriority);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn trạng thái'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: statuses.length,
            itemBuilder: (context, index) {
              final status = statuses[index];
              return RadioListTile<String>(
                title: Text(_getStatusDisplayName(status)),
                value: status,
                groupValue: _selectedStatus,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _selectedStatus = value;
                  });
                  _applyFilters();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedStatus = null;
              });
              _applyFilters();
            },
            child: Text('Xoá lọc'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _togglePendingFilter() {
    setState(() {
      _showPendingOnly = !_showPendingOnly;
    });
    _applyFilters();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _showPendingOnly = false;
      _selectedAgent = null;
      _selectedStatus = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  Future<bool> _approveOrder(String soPhieu) async {
  // Find the current order to get its current status
  DonHangModel? currentOrder;
  for (var order in _orders) {
    if (order.soPhieu == soPhieu) {
      currentOrder = order;
      break;
    }
  }
  
  if (currentOrder == null) {
    print('Order not found: $soPhieu');
    return false;
  }

  // Mark this order as being processed
  setState(() {
    _processingApprovals.add(soPhieu);
    _processingOrders[soPhieu] = 'processing';
  });

  // Start cleanup timer if not active
  _cleanupTimer ??= Timer.periodic(Duration(seconds: 10), (timer) {
    // Remove successful or error statuses after 10 seconds
    setState(() {
      _processingOrders.removeWhere((key, value) => value != 'processing');
      if (_processingOrders.isEmpty) {
        _cleanupTimer?.cancel();
        _cleanupTimer = null;
      }
    });
  });

  try {
    // API call code remains the same
    final url = Uri.parse(
        'https://www.appsheet.com/api/v2/apps/HMPro-6083480/tables/DonHang/Action');

    final Map<String, dynamic> requestBody = {
      "Action": "Edit",
      "Properties": {
        "Locale": "en-US",
        "Location": "47.623098, -122.330184",
        "Timezone": "SE Asia Standard Time",
        "UserSettings": {
          "Người dùng": "hm.trangiang",
          "Mật khẩu": "100011"
        }
      },
      "Rows": [
        {
          "Số phiếu": soPhieu,
          "Phương thức giao hàng": soPhieu
        }
      ]
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'applicationAccessKey': 'V2-HcSe8-jFGNM-Oyw1x-IN5xg-SybvY-i04pC-zcz8P-yzDzd',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      // Success - update local database
      final currentStatus = currentOrder.trangThai ?? '';
      final newStatus = _getNextStatus(currentStatus, 'Duyệt đơn');
      
      if (newStatus != currentStatus) {
        await _updateOrderStatusLocally(soPhieu, newStatus);
      }
      
      setState(() {
        _processingOrders[soPhieu] = 'success';
        // Don't remove from _processingApprovals until reload completes
      });
      return true;
    } else {
      // Error
      print('Error approving order: ${response.statusCode}, ${response.body}');
      setState(() {
        _processingOrders[soPhieu] = 'error';
        _processingApprovals.remove(soPhieu);
      });
      return false;
    }
  } catch (e) {
    print('Exception approving order: $e');
    setState(() {
      _processingOrders[soPhieu] = 'error';
      _processingApprovals.remove(soPhieu);
    });
    return false;
  }
}

  Widget _buildProcessingQueue() {
    if (_processingOrders.isEmpty) return SizedBox.shrink();

    return Container(
      color: Colors.grey[100],
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        children: _processingOrders.entries.map((entry) {
          final soPhieu = entry.key;
          final status = entry.value;

          IconData icon;
          Color color;
          String statusText;

          switch (status) {
            case 'processing':
              icon = Icons.pending_outlined;
              color = Colors.orange;
              statusText = 'Đang xử lý...';
              break;
            case 'success':
              icon = Icons.check_circle;
              color = Colors.green;
              statusText = 'Đã duyệt';
              break;
            case 'error':
              icon = Icons.error;
              color = Colors.red;
              statusText = 'Lỗi';
              break;
            default:
              icon = Icons.info;
              color = Colors.grey;
              statusText = 'Không xác định';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đơn $soPhieu: $statusText',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                if (status == 'processing')
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                if (status != 'processing')
                  IconButton(
                    icon: Icon(Icons.close, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _processingOrders.remove(soPhieu);
                      });
                    },
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _toggleSectionCollapse(String status) {
    setState(() {
      _collapsedSections[status] = !(_collapsedSections[status] ?? false);
    });
  }

  void _toggleViewMode() {
    setState(() {
      _isTableMode = !_isTableMode;
    });
  }
  // Check if a button should be disabled due to processing
bool _isOrderBeingProcessed(String soPhieu) {
  return _processingApprovals.contains(soPhieu) || 
         _processingOrders.containsKey(soPhieu);
}

// Get consistent button text
String _getApprovalButtonText(String soPhieu, bool isHmGroup) {
  if (_processingApprovals.contains(soPhieu)) {
    return 'Đang xử lý...';
  }
  return isHmGroup ? 'Duyệt nhanh' : 'Duyệt đơn';
}

// Unified approval handler
Future<void> _handleApproval(DonHangModel order, bool isHmGroup) async {
  if (isHmGroup) {
    _quickApproveHMGroupOrder(order.soPhieu!);
  } else {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận duyệt đơn'),
        content: Text('Xác nhận duyệt đơn hàng ${order.soPhieu}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Duyệt', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && order.soPhieu != null) {
      final success = await _approveOrder(order.soPhieu!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã duyệt đơn hàng ${order.soPhieu}'),
            backgroundColor: Colors.green,
          ),
        );
        Future.delayed(Duration(seconds: 3), () => _loadOrders());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi duyệt đơn hàng ${order.soPhieu}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

  @override
Widget build(BuildContext context) {
  // Colors matching the HSPage style
  final Color appBarTop = Color(0xFFb8cc32);
  final Color appBarBottom = Color(0xFFe1ff72);

  // Check if we're on a large screen
  final bool isLargeScreen = MediaQuery.of(context).size.width > 600;

  return Scaffold(
    appBar: AppBar(
      title: Text('Đơn hàng của tôi'),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [appBarTop, appBarBottom],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
  icon: Icon(Icons.filter_list, color: Colors.black),
  label: Text("Lọc", style: TextStyle(color: Colors.black)),
  onPressed: () {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildFilterOptions(),
    );
  },
),

TextButton.icon(
  icon: Icon(Icons.add, color: Colors.black, size: 18),
  label: Text("Đơn mới", style: TextStyle(color: Colors.black)),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HSDonHangMoiScreen(),
      ),
    );
  },
),

      ],
    ),
    body: Column(
      children: [
        // Processing queue
        _buildProcessingQueue(),

        // Search and export section
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: isLargeScreen
              ? Row(
                  children: [
                    // Search bar
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm đơn hàng',
                          prefixIcon: Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Date range picker
                    ElevatedButton.icon(
                      onPressed: _showDateRangePicker,
                      icon: Icon(Icons.date_range, size: 18),
                      label: Text(
                        _startDate != null && _endDate != null
                            ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                            : "Chọn ngày",
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF837826),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Status filter
                    ElevatedButton.icon(
                      onPressed: _showStatusFilterDialog,
                      icon: Icon(Icons.filter_alt, size: 18),
                      label: Text(
                        _selectedStatus != null
                            ? _getStatusDisplayName(_selectedStatus!)
                            : "Lọc trạng thái",
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF837826),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Excel export button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _exportToExcel,
                      icon: Icon(Icons.file_download, size: 18),
                      label: Text("Excel", style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF534b0d),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Smaller search bar
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm đơn hàng',
                          prefixIcon: Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    // Excel export button
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _exportToExcel,
                        icon: Icon(Icons.file_download, size: 18),
                        label: Text("Excel", style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF534b0d),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // Filter chips (only show on mobile or if filters are active on desktop)
        if (!isLargeScreen ||
            _startDate != null ||
            _endDate != null ||
            _showPendingOnly ||
            _selectedAgent != null ||
            _selectedStatus != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (!isLargeScreen && _startDate != null && _endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                          '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'),
                      onSelected: (_) => _showDateRangePicker(),
                      selected: true,
                      selectedColor: appBarBottom.withOpacity(0.2),
                      checkmarkColor: appBarBottom,
                    ),
                  ),
                if (_selectedAgent != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('Người tạo: $_selectedAgent'),
                      onSelected: (_) => _showAgentFilterDialog(),
                      selected: true,
                      selectedColor: Colors.blue.withOpacity(0.2),
                      checkmarkColor: Colors.blue,
                    ),
                  ),
                if (!isLargeScreen && _selectedStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                          'Trạng thái: ${_getStatusDisplayName(_selectedStatus!)}'),
                      onSelected: (_) => _showStatusFilterDialog(),
                      selected: true,
                      selectedColor: Colors.purple.withOpacity(0.2),
                      checkmarkColor: Colors.purple,
                    ),
                  ),
                if (_showPendingOnly)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('Chờ duyệt'),
                      onSelected: (_) => _togglePendingFilter(),
                      selected: true,
                      selectedColor: Colors.orange.withOpacity(0.2),
                      checkmarkColor: Colors.orange,
                    ),
                  ),
                if (_startDate != null ||
                    _endDate != null ||
                    _showPendingOnly ||
                    _selectedAgent != null ||
                    _selectedStatus != null)
                  ActionChip(
                    label: Text('Xoá bộ lọc'),
                    onPressed: _clearFilters,
                    avatar: Icon(Icons.clear, size: 16),
                  ),
              ],
            ),
          ),

        // Username and summary row
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[100],
          child: Row(
            children: [
              Icon(Icons.person, size: 20, color: Colors.grey[700]),
              SizedBox(width: 8),
              Text(
                'Người dùng: $_username',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: _toggleViewMode,
                child: Text(
                  _isTableMode ? 'Xem bình thường' : 'Xem dạng bảng',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF534b0d),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Số đơn hàng: ${_filteredOrders.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
        ),

        // Main content
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text(_errorMessage, textAlign: TextAlign.center),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadOrders,
                            child: Text('Thử lại'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appBarBottom,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'Không tìm thấy đơn hàng nào',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadOrders,
                          child: _isTableMode
                              ? _buildTableOrderList() // Table view
                              : _buildGroupedOrderList(), // Grouped list view
                        ),
        ),
      ],
    ),
  );
}

  Widget _buildGroupedOrderList() {
    // Group orders by status
    Map<String, List<DonHangModel>> groupedOrders = {};

    for (var order in _filteredOrders) {
      final status = order.trangThai?.toLowerCase() ?? 'không xác định';
      if (!groupedOrders.containsKey(status)) {
        groupedOrders[status] = [];
      }
      groupedOrders[status]!.add(order);
    }

    // Sort status keys by priority
    final List<String> sortedStatuses = groupedOrders.keys.toList();
    final Map<String, int> statusPriority = {
      'gửi': 0,
      'gửi xuất nội bộ': 1,
      'dự trù': 2,
      'chờ duyệt': 3,
      'đã duyệt': 4,
      'đã giao': 5,
      'đã huỷ': 6,
    };

    sortedStatuses.sort((a, b) {
      final aPriority = statusPriority[a] ?? 999;
      final bPriority = statusPriority[b] ?? 999;
      return aPriority.compareTo(bPriority);
    });

    // Get screen width to determine number of columns
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;
    final bool isExtraLargeScreen = screenWidth > 1000;

    // Determine grid column count based on screen width
    final int columnCount = isExtraLargeScreen ? 3 : (isLargeScreen ? 2 : 1);

    return ListView.builder(
      itemCount: sortedStatuses.length,
      itemBuilder: (context, index) {
        final status = sortedStatuses[index];
        final orders = groupedOrders[status]!;
        final isCollapsed = _collapsedSections[status] ?? false;

        return Column(
          children: [
            // Status header with count and toggle
            InkWell(
              onTap: () => _toggleSectionCollapse(status),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: _getStatusColor(status).withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      isCollapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                      color: _getStatusColor(status),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _getStatusDisplayName(status),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${orders.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Spacer(),
                    Icon(
                      isCollapsed ? Icons.star : Icons.star,
                      color: Colors.orange[600],
                    ),
                  ],
                ),
              ),
            ),

            // Order items (visible only if section not collapsed)
            if (!isCollapsed)
              isLargeScreen
                  // Grid layout for large screens with dynamic column count
                  ? GridView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        mainAxisExtent:
                            180, // Increased height to accommodate approval button
                      ),
                      itemCount: orders.length,
                      padding: EdgeInsets.all(8),
                      itemBuilder: (context, idx) =>
                          _buildOrderItem(orders[idx], columnCount),
                    )
                  // List layout for small screens
                  : Column(
                      children:
                          orders.map((order) => _buildOrderItem(order, 1)).toList(),
                    ),
          ],
        );
      },
    );
  }
Future<void> _editOrder(String soPhieu) async {
  try {
    // Navigate to the order creation screen in edit mode
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HSDonHangMoiScreen(
          editMode: true,
          soPhieu: soPhieu,
        ),
      ),
    );
    
    // If the edit was successful, refresh the orders list
    if (result != null && result['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đơn hàng đã được cập nhật thành công'),
          backgroundColor: Colors.green,
        ),
      );
      _loadOrders(); // Refresh the orders list
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi mở form sửa đơn: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  Widget _buildTableOrderList() {
    // Sort orders by date for table view, or keep the default sort
    final orders = List.from(_filteredOrders);
    orders.sort((a, b) {
      final aDate = a.ngay != null ? DateTime.tryParse(a.ngay!) : null;
      final bDate = b.ngay != null ? DateTime.tryParse(b.ngay!) : null;
      if (aDate == null || bDate == null) return 0; // Keep original order if dates are invalid
      return bDate.compareTo(aDate); // Newest first
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        dataRowHeight: 50,
        columns: [
          DataColumn(label: Text('Số phiếu')),
          DataColumn(label: Text('Ngày')),
          DataColumn(label: Text('Khách hàng')),
          DataColumn(label: Text('Tổng cộng')),
          DataColumn(label: Text('Trạng thái')),
          DataColumn(label: Text('Người tạo')),
          DataColumn(label: Text('Thao tác')), // Actions column
        ],
        
        rows: orders.map((order) {
    final formattedDate = order.ngay != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(order.ngay!))
        : 'N/A';
    final statusColor = _getStatusColor(order.trangThai);
    final lowerStatus = (order.trangThai ?? '').toLowerCase();
    final canApprove = adminUsers.contains(_username) &&
        pendingStatuses.contains(lowerStatus);
    final isOrderCreator = (order.nguoiTao?.toLowerCase() ?? '') == _username.toLowerCase();
    final isHmGroup = (order.phuongThucGiaoHang?.toUpperCase() ?? '') == 'HMGROUP';
    
    // Use consistent state checking methods
    final isBeingProcessed = _isOrderBeingProcessed(order.soPhieu ?? '');
    final buttonText = _getApprovalButtonText(order.soPhieu ?? '', isHmGroup);
    
    return DataRow(
      cells: [
              DataCell(Text(order.soPhieu ?? 'N/A')),
              DataCell(Text(formattedDate)),
              DataCell(Text(order.tenKhachHang2 ?? 'N/A')),
              DataCell(Text(_formatCurrency(order.tongCong))),
              DataCell(
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    _getStatusDisplayName(order.trangThai ?? 'N/A'),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(Text(order.nguoiTao ?? 'N/A')),
              DataCell(
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Edit button with consistent state
      if (isOrderCreator && (lowerStatus == 'chưa xong' || lowerStatus == 'xuất nội bộ' || lowerStatus == 'nháp'))
        IconButton(
          icon: Icon(Icons.edit, size: 18, color: Colors.blue),
          tooltip: 'Sửa đơn',
          onPressed: _isOrderBeingProcessed(order.soPhieu ?? '') ? null : () => _editOrder(order.soPhieu!),
        ),
      if (_canDeleteOrder(order))
        IconButton(
          icon: Icon(Icons.delete, size: 18, color: Colors.red),
          tooltip: 'Xoá đơn',
          onPressed: _isOrderBeingProcessed(order.soPhieu ?? '') ? null : () => _deleteOrder(order.soPhieu!),
        ),
      // Send button with consistent state
      if (isOrderCreator && isHmGroup && 
          (lowerStatus == 'chưa xong' || lowerStatus == 'xuất nội bộ'))
        IconButton(
          icon: Icon(Icons.send, size: 18, color: Colors.blue),
          tooltip: 'Gửi đơn',
          onPressed: _isOrderBeingProcessed(order.soPhieu ?? '') ? null : () => _sendHMGroupOrder(order.soPhieu!),
        ),
      
      // PXK button
      if (order.soPhieu != null && lowerStatus != 'nháp')
        IconButton(
          icon: Icon(Icons.receipt_long, size: 18, color: Color(0xFF534b0d)),
          tooltip: 'Xuất PXK',
          onPressed: () => _generatePXK(order),
        ),
        
      // PYC button
      if (order.soPhieu != null && lowerStatus != 'nháp')
        IconButton(
          icon: Icon(Icons.receipt_long, size: 18, color: Color(0xFF564b0d)),
          tooltip: 'Xuất PYC',
          onPressed: () => _generatePYC(order),
        ),
        
      // QR button
      if (order.soPhieu != null && lowerStatus != 'nháp')
        IconButton(
          icon: Icon(Icons.qr_code, size: 18, color: Color(0xFF534b0d)),
          tooltip: 'Hiện mã QR',
          onPressed: () => _showQrCode(order.soPhieu!, order.tenKhachHang2 ?? ''),
        ),
        
      // Approval button with consistent state
      if (canApprove)
        IconButton(
          icon: _isOrderBeingProcessed(order.soPhieu ?? '')
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(isHmGroup ? Colors.orange : Colors.green),
                  ),
                )
              : Icon(
                  Icons.check, 
                  size: 18, 
                  color: isHmGroup ? Colors.orange : Colors.green
                ),
          tooltip: _isOrderBeingProcessed(order.soPhieu ?? '') 
              ? 'Đang xử lý...' 
              : _getApprovalButtonText(order.soPhieu ?? '', isHmGroup),
          onPressed: _isOrderBeingProcessed(order.soPhieu ?? '') 
              ? null 
              : () => _handleApproval(order, isHmGroup),
        ),
        
      // Detail button
      IconButton(
        icon: Icon(Icons.info_outline, size: 18, color: Colors.blue),
        tooltip: 'Xem chi tiết',
        onPressed: () {
          if (order.soPhieu != null) {
            _loadOrderItems(order.soPhieu!);
          }
        },
      ),
    ],
  ),
),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lọc đơn hàng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.date_range),
            title: Text('Chọn khoảng thời gian'),
            subtitle: _startDate != null && _endDate != null
                ? Text(
                    '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}')
                : Text('Tất cả ngày'),
            onTap: () {
              Navigator.pop(context);
              _showDateRangePicker();
            },
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Lọc theo người tạo'),
            subtitle: _selectedAgent != null ? Text(_selectedAgent!) : Text('Tất cả'),
            onTap: () {
              Navigator.pop(context);
              _showAgentFilterDialog();
            },
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Lọc theo trạng thái'),
            subtitle: _selectedStatus != null
                ? Text(_getStatusDisplayName(_selectedStatus!))
                : Text('Tất cả'),
            onTap: () {
              Navigator.pop(context);
              _showStatusFilterDialog();
            },
          ),
          ListTile(
            leading: Icon(Icons.filter_list),
            title: Text('Chỉ hiện đơn chờ duyệt'),
            trailing: Switch(
              value: _showPendingOnly,
              onChanged: (value) {
                Navigator.pop(context);
                setState(() {
                  _showPendingOnly = value;
                });
                _applyFilters();
              },
              activeColor: Color(0xFFb2a41f),
            ),
          ),
          ListTile(
            leading: Icon(Icons.clear_all),
            title: Text('Xoá tất cả bộ lọc'),
            onTap: () {
              Navigator.pop(context);
              _clearFilters();
            },
          ),
        ],
      ),
    );
  }

  void _generatePXK(DonHangModel order) async {
    if (order.soPhieu == null) {
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
    }
  }

  void _generatePYC(DonHangModel order) async {
    if (order.soPhieu == null) {
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

      // Get warehouse info (if needed for this form)
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

      // Generate and show the delivery request form
      await DeliveryRequestFormGenerator.generateDeliveryRequestForm(
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

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tạo phiếu yêu cầu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildOrderItem(DonHangModel order, int columnCount) {
  final isProcessingApproval = order.soPhieu != null &&
      _processingApprovals.contains(order.soPhieu!);
  final formattedDate = order.ngay != null
      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(order.ngay!))
      : 'N/A';

  final statusColor = _getStatusColor(order.trangThai);
  final lowerStatus = (order.trangThai ?? '').toLowerCase();
  
  // Check if user is the creator of the order
  final isOrderCreator = (order.nguoiTao?.toLowerCase() ?? '') == _username.toLowerCase();
  
  // Check if order is for HMGROUP and needs "Gửi" button
  final isHmGroup = (order.phuongThucGiaoHang?.toUpperCase() ?? '') == 'HMGROUP';
  final needsGuiButton = isOrderCreator && isHmGroup && 
      (lowerStatus == 'chưa xong' || lowerStatus == 'xuất nội bộ');
  
  // Check if admin should see "Duyệt nhanh" instead of "Duyệt đơn"
  final canApprove = adminUsers.contains(_username) && pendingStatuses.contains(lowerStatus);
  final shouldShowQuickApprove = canApprove && isHmGroup;
  
  final showQrButton =
      order.soPhieu != null && (order.trangThai?.toLowerCase() ?? '') != 'nháp';

  // Adjust font sizes based on column count
  final double titleSize = columnCount == 3 ? 13 : (columnCount == 2 ? 14 : 16);
  final double normalSize = columnCount == 3 ? 12 : (columnCount == 2 ? 13 : 14);
  final double smallSize = columnCount == 3 ? 11 : (columnCount == 2 ? 12 : 13);
  final double microSize = columnCount == 3 ? 10 : (columnCount == 2 ? 11 : 12);

  return Card(
    margin:
        EdgeInsets.symmetric(horizontal: columnCount > 1 ? 4 : 8, vertical: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              if (order.soPhieu != null) {
                _loadOrderItems(order.soPhieu!);
              }
            },
            child: Padding(
              padding: EdgeInsets.all(columnCount == 3 ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '✨${order.tenKhachHang2 ?? 'N/A'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: titleSize,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor, width: 1),
                        ),
                        child: Text(
                          _getStatusDisplayName(order.trangThai ?? 'N/A'),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: microSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Số phiếu: ${order.soPhieu ?? 'N/A'}',
                    style: TextStyle(fontSize: normalSize),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ngày: $formattedDate',
                          style: TextStyle(
                            fontSize: smallSize,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Text(
                        _formatCurrency(order.tongCong),
                        style: TextStyle(
                          fontSize: normalSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  Spacer(), // This will push the next row to the bottom
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Người tạo: ${order.nguoiTao ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: smallSize,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: microSize, color: Colors.blue),
                          SizedBox(width: 2),
                          Text(
                            'Chi tiết',
                            style: TextStyle(
                              fontSize: microSize,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom buttons container
        Container(
  width: double.infinity,
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: Colors.grey[100],
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (!_isTableMode && _canDeleteOrder(order))
        ElevatedButton.icon(
          onPressed: _isOrderBeingProcessed(order.soPhieu ?? '') ? null : () {
            _deleteOrder(order.soPhieu!);
          },
          icon: Icon(
            Icons.delete,
            size: columnCount == 3 ? 12 : (columnCount == 2 ? 14 : 16),
            color: Colors.white,
          ),
          label: Text(
            'Xoá',
            style: TextStyle(
              color: Colors.white,
              fontSize: microSize,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isOrderBeingProcessed(order.soPhieu ?? '') ? Colors.grey : Colors.red,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: TextStyle(fontSize: microSize),
            minimumSize: Size(0, 28),
          ),
        ),
      if (!_isTableMode && _canDeleteOrder(order)) SizedBox(width: 8),
      // Add Edit button for order creators
      if (isOrderCreator && (lowerStatus == 'chưa xong' || lowerStatus == 'xuất nội bộ' || lowerStatus == 'nháp'))
        ElevatedButton.icon(
          onPressed: () {
            _editOrder(order.soPhieu!);
          },
          icon: Icon(
            Icons.edit,
            size: columnCount == 3 ? 12 : (columnCount == 2 ? 14 : 16),
            color: Colors.white,
          ),
          label: Text(
            'Sửa',
            style: TextStyle(
              color: Colors.white,
              fontSize: microSize,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: TextStyle(fontSize: microSize),
            minimumSize: Size(0, 28),
          ),
        ),
      if (isOrderCreator && (lowerStatus == 'chưa xong' || lowerStatus == 'xuất nội bộ' || lowerStatus == 'nháp')) 
        SizedBox(width: 8),
      
      // Existing "Gửi" button for HMGROUP orders with specific status
      if (needsGuiButton)
        ElevatedButton.icon(
          onPressed: () {
            _sendHMGroupOrder(order.soPhieu!);
          },
          icon: Icon(
            Icons.send, 
            size: columnCount == 3 ? 12 : (columnCount == 2 ? 14 : 16),
            color: Colors.white,
          ),
          label: Text(
            'Gửi',
            style: TextStyle(
              color: Colors.white,
              fontSize: microSize,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: TextStyle(fontSize: microSize),
            minimumSize: Size(0, 28),
          ),
        ),
      if (needsGuiButton) SizedBox(width: 8),
              
              if (showQrButton)
                ElevatedButton.icon(
                  onPressed: () {
                    // Generate PXK for order
                    _generatePXK(order);
                  },
                  icon: Icon(
                    Icons.receipt_long,
                    size: columnCount == 3 ? 12 : (columnCount == 2 ? 14 : 16),
                    color: Colors.white,
                  ),
                  label: Text(
                    'PXK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: microSize,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF534b0d),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: TextStyle(fontSize: microSize),
                    minimumSize: Size(0, 28),
                  ),
                ),
              SizedBox(width: 8),
              if (showQrButton)
                ElevatedButton.icon(
                  onPressed: () {
                    // Generate PYC for order
                    _generatePYC(order);
                  },
                  icon: Icon(
                    Icons.receipt_long,
                    size: columnCount == 3 ? 12 : (columnCount == 2 ? 14 : 16),
                    color: Colors.white,
                  ),
                  label: Text(
                    'PYC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: microSize,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF564b0d),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: TextStyle(fontSize: microSize),
                    minimumSize: Size(0, 28),
                  ),
                ),
              SizedBox(width: 8),
              if (showQrButton)
                ElevatedButton.icon(
                  icon: Icon(
                    Icons.qr_code,
                    size: columnCount == 3 ? 12 : (columnCount == 2 ? 14 : 16),
                    color: Colors.white,
                  ),
                  label: Text(
                    'QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: microSize,
                    ),
                  ),
                  onPressed: () {
                    _showQrCode(order.soPhieu!, order.tenKhachHang2 ?? '');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF534b0d),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: TextStyle(fontSize: microSize),
                    minimumSize: Size(0, 28),
                  ),
                ),
              if (canApprove) SizedBox(width: 8),
              if (canApprove)
                ElevatedButton.icon(
                  icon: Icon(
                    isProcessingApproval ? Icons.hourglass_top : Icons.check,
                    size: columnCount == 3 ? 12 : (columnCount == 2 ? 14 : 16),
                    color: Colors.white,
                  ),
                  label: Text(
                    isProcessingApproval ? 'Đang xử lý...' : (shouldShowQuickApprove ? 'Duyệt nhanh' : 'Duyệt đơn'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: microSize,
                    ),
                  ),
                  onPressed: isProcessingApproval
                      ? null
                      : () async {
                          if (shouldShowQuickApprove) {
                            // Handle quick approval for HMGROUP
                            _quickApproveHMGroupOrder(order.soPhieu!);
                          } else {
                            // Regular approval process
                            final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Xác nhận duyệt đơn'),
                                    content:
                                        Text('Xác nhận duyệt đơn hàng ${order.soPhieu}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text('Huỷ'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text('Duyệt', style: TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;

                            if (confirm && order.soPhieu != null) {
                              final success = await _approveOrder(order.soPhieu!);

                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã duyệt đơn hàng ${order.soPhieu}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Future.delayed(Duration(seconds: 3), () {
                                  _loadOrders();
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi khi duyệt đơn hàng ${order.soPhieu}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isProcessingApproval ? Colors.grey : (shouldShowQuickApprove ? Colors.orange : Colors.green),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: TextStyle(fontSize: microSize),
                    minimumSize: Size(0, 28),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
Future<void> _updateOrderStatusLocally(String soPhieu, String newStatus) async {
  try {
    // First update the database
    await _dbHelper.updateDonHangStatus(soPhieu, newStatus);
    
    // Then update the local lists
    setState(() {
      // Update the main orders list
      for (int i = 0; i < _orders.length; i++) {
        if (_orders[i].soPhieu == soPhieu) {
          _orders[i] = _orders[i].copyWith(trangThai: newStatus);
          break;
        }
      }
      
      // Update filtered orders as well
      for (int i = 0; i < _filteredOrders.length; i++) {
        if (_filteredOrders[i].soPhieu == soPhieu) {
          _filteredOrders[i] = _filteredOrders[i].copyWith(trangThai: newStatus);
          break;
        }
      }
    });
    
    // Re-apply filters and sorting after the update
    _sortOrders();
    _applyFilters();
    
    print('Successfully updated order $soPhieu status to $newStatus');
  } catch (e) {
    print('Error updating order status locally: $e');
  }
}

String _getNextStatus(String currentStatus, String action) {
  currentStatus = currentStatus.trim();
  
  if (action == 'Gửi') {
    switch (currentStatus) {
      case 'Chưa xong':
        return 'Gửi';
      case 'Xuất Nội bộ':
        return 'Gửi Xuất Nội bộ';
      default:
        return currentStatus; 
    }
  } else if (action == 'Duyệt đơn' || action == 'Duyệt nhanh') {
    switch (currentStatus) {
      case 'Gửi':
        return 'Duyệt';
      case 'Gửi Xuất Nội bộ':
        return 'Xuất Nội bộ xong';
      case 'Dự trù':
        return 'Dự trù đã duyệt';
      case 'XNK Đặt hàng':
        return 'XNK Đặt hàng đã duyệt';
      default:
        return currentStatus; 
    }
  }
  
  return currentStatus; 
}
Future<void> _sendHMGroupOrder(String soPhieu) async {
  // Find the current order to get its current status
  DonHangModel? currentOrder;
  for (var order in _orders) {
    if (order.soPhieu == soPhieu) {
      currentOrder = order;
      break;
    }
  }
  
  if (currentOrder == null) {
    print('Order not found: $soPhieu');
    return;
  }

  setState(() {
    _processingApprovals.add(soPhieu);
    _processingOrders[soPhieu] = 'processing';
  });

  try {
    final url = Uri.parse(
      'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldonhanggui/$soPhieu'
    );
    
    print('Sending request to: ${url.toString()}');

    final response = await http.get(url);
    
    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      // Success - update local database
      final currentStatus = currentOrder.trangThai ?? '';
      final newStatus = _getNextStatus(currentStatus, 'Gửi');
      
      if (newStatus != currentStatus) {
        await _updateOrderStatusLocally(soPhieu, newStatus);
      }
      
      setState(() {
        _processingOrders[soPhieu] = 'success';
      });

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Thành công'),
          content: Text('Đơn hàng đã được gửi thành công và trạng thái đã được cập nhật thành "$newStatus".'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Optional: Still refresh from server to ensure consistency
                _loadOrders();
              },
              child: Text('Làm mới từ server'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF534b0d),
              ),
            ),
          ],
        ),
      );
    } else {
      // Error handling remains the same
      setState(() {
        _processingOrders[soPhieu] = 'error';
        _processingApprovals.remove(soPhieu);
      });
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Lỗi'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Không thể gửi đơn hàng. Vui lòng thử lại sau.'),
                SizedBox(height: 8),
                Text('URL: ${url.toString()}', style: TextStyle(fontSize: 12)),
                Text('Mã lỗi: ${response.statusCode}', style: TextStyle(fontSize: 12)),
                Text('Phản hồi: ${response.body}', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    // Error handling remains the same
    print('Exception sending order: $e');
    setState(() {
      _processingOrders[soPhieu] = 'error';
      _processingApprovals.remove(soPhieu);
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lỗi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không thể gửi đơn hàng.'),
              SizedBox(height: 8),
              Text('Chi tiết lỗi: $e', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
Future<void> _quickApproveHMGroupOrder(String soPhieu) async {
  // Show confirmation dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Duyệt nhanh'),
      content: Text('Xác nhận duyệt nhanh đơn hàng HMGROUP $soPhieu?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Duyệt nhanh', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
        ),
      ],
    ),
  ) ?? false;

  if (!confirm) return;

  // Find the current order to get its current status
  DonHangModel? currentOrder;
  for (var order in _orders) {
    if (order.soPhieu == soPhieu) {
      currentOrder = order;
      break;
    }
  }
  
  if (currentOrder == null) {
    print('Order not found: $soPhieu');
    return;
  }

  setState(() {
    _processingApprovals.add(soPhieu);
    _processingOrders[soPhieu] = 'processing';
  });

  try {
    final url = Uri.parse(
      'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldonhangduyet/$soPhieu'
    );
    
    print('Sending request to: ${url.toString()}');

    final response = await http.get(url);
    
    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      // Success - update local database
      final currentStatus = currentOrder.trangThai ?? '';
      final newStatus = _getNextStatus(currentStatus, 'Duyệt nhanh');
      
      if (newStatus != currentStatus) {
        await _updateOrderStatusLocally(soPhieu, newStatus);
      }
      
      setState(() {
        _processingOrders[soPhieu] = 'success';
      });

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Thành công'),
          content: Text('Đơn hàng đã được duyệt nhanh thành công và trạng thái đã được cập nhật thành "$newStatus".'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadOrders(); // Refresh from server
              },
              child: Text('Làm mới từ server'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF534b0d),
              ),
            ),
          ],
        ),
      );
    } else {
      // Error handling remains the same...
      setState(() {
        _processingOrders[soPhieu] = 'error';
        _processingApprovals.remove(soPhieu);
      });
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Lỗi'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Không thể duyệt nhanh đơn hàng. Vui lòng thử lại sau.'),
                SizedBox(height: 8),
                Text('URL: ${url.toString()}', style: TextStyle(fontSize: 12)),
                Text('Mã lỗi: ${response.statusCode}', style: TextStyle(fontSize: 12)),
                Text('Phản hồi: ${response.body}', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    // Error handling remains the same...
    print('Exception quick approving order: $e');
    setState(() {
      _processingOrders[soPhieu] = 'error';
      _processingApprovals.remove(soPhieu);
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lỗi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không thể duyệt nhanh đơn hàng.'),
              SizedBox(height: 8),
              Text('Chi tiết lỗi: $e', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
  Future<void> _showQrCode(String soPhieu, String khachHang) async {
    // Create a PDF document for printing
    final pdf = pw.Document();

    // Parse the SoPhieu into parts (if needed)
    List<String> parts = soPhieu.split('-');
    String displayText = '';

    // Make sure we display number2-number3 as specified (if it follows that format)
    if (parts.length >= 3) {
      displayText = '${parts[1]}-${parts[2]}';
    } else if (parts.length == 2) {
      displayText = parts.join('-');
    } else {
      displayText = soPhieu;
    }

    // Add QR code to PDF with horizontal 5x3cm layout
    pdf.addPage(
      pw.Page(
        pageFormat: pdfx.PdfPageFormat(50 * pdfx.PdfPageFormat.mm,
            30 * pdfx.PdfPageFormat.mm,
            marginAll: 2 * pdfx.PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // QR Code on the left
              pw.Container(
                width: 26 * pdfx.PdfPageFormat.mm,
                height: 26 * pdfx.PdfPageFormat.mm,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: soPhieu,
                  width: 26 * pdfx.PdfPageFormat.mm,
                  height: 26 * pdfx.PdfPageFormat.mm,
                ),
              ),

              pw.SizedBox(width: 4 * pdfx.PdfPageFormat.mm),

              // Text on the right (normal orientation for simplicity)
              pw.Container(
                width: 16 * pdfx.PdfPageFormat.mm,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Black pill with identifier
                    pw.Container(
                      width: 16 * pdfx.PdfPageFormat.mm,
                      padding: pw.EdgeInsets.symmetric(
                        horizontal: 2 * pdfx.PdfPageFormat.mm,
                        vertical: 2 * pdfx.PdfPageFormat.mm,
                      ),
                      decoration: pw.BoxDecoration(
                        color: pdfx.PdfColors.black,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        displayText,
                        style: pw.TextStyle(
                          color: pdfx.PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),

                    pw.SizedBox(height: 4 * pdfx.PdfPageFormat.mm),

                    // Order number text with wrapping
                    pw.Text(
                      'Đơn: $soPhieu',
                      style: pw.TextStyle(fontSize: 6),
                      textAlign: pw.TextAlign.center,
                      maxLines: 3, // Allow multiple lines
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Show QR code dialog with preview
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mã QR đơn hàng'),
        contentPadding: EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 250,
              height: 250,
              child: QrImageView(
                data: soPhieu,
                version: QrVersions.auto,
                size: 250,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Số phiếu: $soPhieu",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text("Khách hàng: $khachHang"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Đóng'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.save, color: Colors.white),
            label: Text('Lưu', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () async {
              try {
                // Create PDF with QR code using the simplified format
                final savePdf = pw.Document();
                savePdf.addPage(
                  pw.Page(
                    pageFormat: pdfx.PdfPageFormat(50 * pdfx.PdfPageFormat.mm,
                        30 * pdfx.PdfPageFormat.mm,
                        marginAll: 2 * pdfx.PdfPageFormat.mm),
                    build: (pw.Context context) {
                      return pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // QR Code on the left
                          pw.Container(
                            width: 26 * pdfx.PdfPageFormat.mm,
                            height: 26 * pdfx.PdfPageFormat.mm,
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: soPhieu,
                              width: 26 * pdfx.PdfPageFormat.mm,
                              height: 26 * pdfx.PdfPageFormat.mm,
                            ),
                          ),

                          pw.SizedBox(width: 4 * pdfx.PdfPageFormat.mm),

                          // Text on the right (normal orientation for simplicity)
                          pw.Container(
                            width: 16 * pdfx.PdfPageFormat.mm,
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                // Black pill with identifier
                                pw.Container(
                                  width: 16 * pdfx.PdfPageFormat.mm,
                                  padding: pw.EdgeInsets.symmetric(
                                    horizontal: 2 * pdfx.PdfPageFormat.mm,
                                    vertical: 2 * pdfx.PdfPageFormat.mm,
                                  ),
                                  decoration: pw.BoxDecoration(
                                    color: pdfx.PdfColors.black,
                                    borderRadius: pw.BorderRadius.circular(8),
                                  ),
                                  child: pw.Text(
                                    displayText,
                                    style: pw.TextStyle(
                                      color: pdfx.PdfColors.white,
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),

                                pw.SizedBox(height: 4 * pdfx.PdfPageFormat.mm),

                                // Order number text with wrapping
                                pw.Text(
                                  'Đơn: $soPhieu',
                                  style: pw.TextStyle(fontSize: 6),
                                  textAlign: pw.TextAlign.center,
                                  maxLines: 3, // Allow multiple lines
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );

                // Get temporary directory to save PDF
                final directory = await getTemporaryDirectory();
                final fileName =
                    'qr_${soPhieu}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                final filePath = '${directory.path}/$fileName';

                // Save PDF to file
                final file = File(filePath);
                await file.writeAsBytes(await savePdf.save());

                // Share the file
                await Share.shareXFiles(
                  [XFile(filePath)],
                  text: 'Mã QR đơn hàng $soPhieu',
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: Không thể lưu mã QR. $e')));
                print('Error saving QR: $e');
              }
            },
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.print, color: Colors.white),
            label: Text('In', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF534b0d),
            ),
            onPressed: () async {
              try {
                await Printing.layoutPdf(
                  onLayout: (format) => pdf.save(),
                  name: 'QR_$soPhieu',
                  format: pdfx.PdfPageFormat(
                      50 * pdfx.PdfPageFormat.mm, 30 * pdfx.PdfPageFormat.mm),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: Không thể in mã QR')));
                print('Error printing QR: $e');
              }
            },
          ),
        ],
      ),
    );

    // Auto-trigger printing
    Future.delayed(Duration(milliseconds: 500), () async {
      try {
        await Printing.layoutPdf(
          onLayout: (format) => pdf.save(),
          name: 'QR_$soPhieu',
          format: pdfx.PdfPageFormat(
              50 * pdfx.PdfPageFormat.mm, 30 * pdfx.PdfPageFormat.mm),
        );
      } catch (e) {
        print('Error auto-printing QR: $e');
      }
    });
  }

  void _showOrderDetails(DonHangModel order) {
    // For now, show a dialog with basic order details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết đơn hàng'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Số phiếu', order.soPhieu),
              _buildDetailRow('Ngày', order.ngay),
              _buildDetailRow('Khách hàng', order.tenKhachHang),
              _buildDetailRow('Số điện thoại', order.sdtKhachHang),
              _buildDetailRow('Số PO', order.soPO),
              _buildDetailRow('Địa chỉ giao', order.diaChiGiaoHang),
              _buildDetailRow('MST', order.mst),
              _buildDetailRow('Phương thức thanh toán', order.phuongThucThanhToan),
              _buildDetailRow('Trạng thái', order.trangThai),
              _buildDetailRow('Người tạo', order.nguoiTao),
              Divider(),
              _buildDetailRow('Tổng tiền', _formatCurrency(order.tongTien)),
              _buildDetailRow('VAT', _formatCurrency(order.vat10)),
              _buildDetailRow('Tổng cộng', _formatCurrency(order.tongCong),
                  isBold: true),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            child: Text('Xem chi tiết đơn'),
            onPressed: () {
              Navigator.pop(context);
              if (order.soPhieu != null) {
                _loadOrderItems(order.soPhieu!);
              }
            },
          ),
          TextButton(
            child: Text('Đóng'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value, {bool isBold = false}) {
    String displayValue = '';

    if (value == null) {
      displayValue = 'N/A';
    } else if (value is int) {
      displayValue = value.toString();
    } else {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadOrderItems(String soPhieu) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Load order and its items
      final order = await _dbHelper.getDonHangBySoPhieu(soPhieu);
      final items = await _dbHelper.getChiTietDonBySoPhieu(soPhieu);

      // Close loading indicator
      Navigator.pop(context);

      if (order == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tìm thấy thông tin đơn hàng')),
        );
        return;
      }

      // Calculate totals
      int totalAmount = 0;
      for (var item in items) {
        totalAmount += item.thanhTien ?? 0;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              // Header with order summary
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  color: Color(0xFF534b0d),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chi tiết đơn hàng',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Số phiếu: $soPhieu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.trangThai).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _getStatusColor(order.trangThai),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getStatusDisplayName(order.trangThai ?? 'N/A'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Order Details Section
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Customer Information
                    Container(
                      color: Colors.grey[100],
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                    // Order Information
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông tin đơn hàng',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailItem(
                                    'Ngày tạo',
                                    order.ngay != null
                                        ? DateFormat('dd/MM/yyyy')
                                            .format(DateTime.parse(order.ngay!))
                                        : 'N/A'),
                              ),
                              Expanded(
                                child: _buildDetailItem('Số PO', order.soPO),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailItem('Người tạo', order.nguoiTao),
                              ),
                              Expanded(
                                child: _buildDetailItem(
                                    'Thanh toán', order.phuongThucThanhToan),
                              ),
                            ],
                          ),
                          _buildDetailItem('Ghi chú', order.ghiChu ?? 'Không có'),
                        ],
                      ),
                    ),

                    // Order Items Section
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey[100],
                      child: Row(
                        children: [
                          Text(
                            'Danh sách sản phẩm (${items.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey[800],
                            ),
                          ),
                          Spacer(),
                          Text(
                            _formatCurrency(totalAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List of items
                    ...items.map((item) => Card(
                          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.idHang != null
                                            ? item.idHang!.contains(" - ")
                                                ? item.idHang!.split(" - ")[1]
                                                : item.idHang!
                                            : 'N/A',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      _formatCurrency(item.thanhTien),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'Mã hàng: ',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      item.maHang ?? 'N/A',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            'SL: ',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '${item.soLuongYeuCau ?? 0} ${item.donViTinh ?? ''}',
                                            style: TextStyle(fontSize: 14, color: Colors.green),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            'Thực giao: ',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '${item.soLuongThucGiao ?? 0}',
                                            style: TextStyle(fontSize: 14, color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Đơn giá: ',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(item.donGia),
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )).toList(),

                    // Footer with totals
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          top: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tổng tiền:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _formatCurrency(order.tongTien),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('VAT:'),
                              Text(_formatCurrency(order.vat10)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tổng cộng:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                _formatCurrency(order.tongCong),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
Text(
                            '┇ Thông tin khách hàng ┇',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 10),
                          _buildDetailItem('Tên khách hàng', order.tenKhachHang2),
                          _buildDetailItem('Số điện thoại', order.sdtKhachHang),
                          _buildDetailItem('Địa chỉ', order.diaChi),
                          _buildDetailItem('Mã số thuế', order.mst),
                          _buildDetailRow('Số PO', order.soPO),
                          _buildDetailItem('Tên người giao dịch', order.tenNguoiGiaoDich),
                          _buildDetailItem('SĐT người GD', order.sdtNguoiGiaoDich),
                          _buildDetailItem('Bộ phận GD', order.boPhanGiaoDich),
                          _buildDetailItem('Chi nhánh', order.thoiGianDatHang),
                          _buildDetailItem('Giấy tờ cần khi giao', order.giayToCanKhiGiaoHang),
                          _buildDetailItem('Thời gian viết hoá đơn', order.thoiGianVietHoaDon),
                          _buildDetailItem('Thông tin viết hoá đơn', order.thongTinVietHoaDon),
                          _buildDetailItem('Địa chỉ giao hàng', order.diaChiGiaoHang),
                          _buildDetailItem('Người nhận hoa hồng', order.hoTenNguoiNhanHoaHong),
                          _buildDetailItem('SĐT người nhận hoa hồng', order.sdtNguoiNhanHoaHong),
                          _buildDetailItem('Hình thức chuyển HH', order.hinhThucChuyenHoaHong),
                          _buildDetailItem('Thông tin nhận HH', order.thongTinNhanHoaHong),
                          _buildDetailRow('Gía net', order.giaNet),
                          _buildDetailRow('Tổng tiền', order.tongTien),
                          _buildDetailRow('VAT', order.vat10),
                          _buildDetailRow('Tổng cộng', order.tongCong),
                          _buildDetailRow('Hoa hồng 10%', order.hoaHong10),
                          _buildDetailRow('Tiền gửi 10%', order.tienGui10),
                          _buildDetailRow('Thuế TNDN', order.thueTNDN),
                          _buildDetailRow('Vận chuyển', order.vanChuyen),
                          _buildDetailRow('Thực thu', order.thucThu),
                          _buildDetailItem('Phương thức giao hàng', order.phuongThucGiaoHang),
                          _buildDetailItem('Phương tiện giao hàng', order.phuongTienGiaoHang),
                          _buildDetailItem('Người giao hàng', order.hoTenNguoiGiaoHang),
                          _buildDetailItem('Người nhận hàng', order.nguoiNhanHang),
                          _buildDetailItem('SĐT người nhận', order.sdtNguoiNhanHang),
                          _buildDetailItem('Tên khách hàng gốc', order.tenKhachHang),
                        ],
                      ),
                    ),

                          // Only show approval button for admins and pending orders
                          if (adminUsers.contains(_username) &&
                              pendingStatuses.contains(
                                  (order.trangThai ?? '').toLowerCase()))
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: Icon(
                                      _processingApprovals.contains(soPhieu)
                                          ? Icons.hourglass_top
                                          : Icons.check,
                                      color: Colors.white),
                                  label: Text(
                                      _processingApprovals.contains(soPhieu)
                                          ? 'Đang xử lý...'
                                          : 'Duyệt đơn hàng',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _processingApprovals.contains(soPhieu)
                                            ? Colors.grey
                                            : Colors.green,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _processingApprovals.contains(soPhieu)
                                      ? null // Disable button if processing
                                      : () async {
                                          Navigator.pop(context);
                                          final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text('Xác nhận duyệt đơn'),
                                                  content: Text(
                                                      'Xác nhận duyệt đơn hàng ${order.soPhieu}?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(context, false),
                                                      child: Text('Huỷ'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(context, true),
                                                      child: Text('Duyệt'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ) ??
                                              false;

                                          if (confirm) {
                                            final success =
                                                await _approveOrder(soPhieu);
                                            if (success) {
                                              // Reload orders after a slight delay to allow the server to process
                                              Future.delayed(Duration(seconds: 3), () {
                                                _loadOrders();
                                              });
                                            }
                                          }
                                        },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Close loading indicator
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: Không thể tải chi tiết đơn hàng'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error loading order items: $e');
    }
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    switch (status.toLowerCase()) {
      case 'gửi':
      case 'gửi xuất nội bộ':
      case 'dự trù':
      case 'chờ duyệt':
        return Colors.orange;
      case 'đã duyệt':
        return Colors.green;
      case 'đã giao':
        return Colors.blue;
      case 'đã huỷ':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'gửi':
        return 'Chờ duyệt';
      case 'gửi xuất nội bộ':
        return 'Chờ duyệt (Nội bộ)';
      case 'dự trù':
        return 'Chờ duyệt (Dự trù)';
      case 'chờ duyệt':
        return 'Đang xử lý';
      case 'đã duyệt':
        return 'Đã duyệt';
      case 'đã giao':
        return 'Đã giao hàng';
      case 'đã huỷ':
        return 'Đã huỷ';
      default:
        return status;
    }
  }

  String _formatCurrency(int? amount) {
    if (amount == null) return '0 đ';

    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    return formatter.format(amount);
  }
}

class GalleryHandler {
  static Future<String?> saveImage(ui.Image image, String fileName) async {
    try {
      // Convert image to bytes
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temporary file first
      final directory = await getTemporaryDirectory();
      final String tempPath = '${directory.path}/$fileName';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(pngBytes);

      // For simplicity, we're just returning the temporary file path
      // In a production app, you should use platform channels to save to the gallery
      return tempPath;
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }
}