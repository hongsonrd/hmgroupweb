import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_helper.dart'; 
import 'table_models.dart'; 
import 'hs_xuhuong.dart';
import 'hs_xuhuongxnk.dart';
import 'hs_xuhuongkd.dart';
import 'hs_xuhuongkho.dart';
import 'hs_xuhuongkpi.dart';
import 'hs_xuhuongkhach.dart';
import 'http_client.dart';
import 'dart:convert';
class HSStatScreen extends StatefulWidget {
  const HSStatScreen({Key? key}) : super(key: key);

  @override
  _HSStatScreenState createState() => _HSStatScreenState();
}

class _HSStatScreenState extends State<HSStatScreen> {
  final DBHelper _dbHelper = DBHelper(); 
  String _username = '';
  bool _isLoading = false;
  String _selectedPeriod = 'Tuần này';
  final List<String> _periods = ['Hôm nay', 'Tuần này', 'Tháng này', 'Quý này'];
bool _isSyncing = false; 
  // Variables to hold calculated statistics
  int _totalCompletedOrders = 0;
  double _totalRevenue = 0.0;
  int _uniqueCompletedItems = 0;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadUserInfo().then((_) {
      _setAndCalculateDateRange(_selectedPeriod); // Calculate initial stats after user info loads
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';

      setState(() {
        _username = username;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
Future<void> _syncAllHistoryData() async {
    if (_isSyncing) return; // Prevent multiple simultaneous syncs

    setState(() {
      _isSyncing = true;
    });

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildSyncProgressDialog(),
      );

      // Sync DonHang data (all history)
      await _syncDonHangData();
      
      // Sync ChiTietDon data (all history)
      await _syncChiTietDonData();
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final formattedNow = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      await prefs.setString('last_donhang_sync', formattedNow);
      await prefs.setString('last_chitietdon_sync', formattedNow);
      
      // Close dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Recalculate stats with new data
      await _setAndCalculateDateRange(_selectedPeriod);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đồng bộ lịch sử thành công lúc ${DateFormat('HH:mm').format(now)}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Close dialog on error
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      print('Error syncing history data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi đồng bộ: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
  Widget _buildSyncProgressDialog() {
    return AlertDialog(
      title: Text(
        '📊 Đang đồng bộ lịch sử',
        style: TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          SizedBox(height: 32),
          Text(
            'Đang tải toàn bộ lịch sử đơn hàng và chi tiết...',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  Future<void> _syncDonHangData() async {
    try {
      final encodedUsername = Uri.encodeComponent(_username);
      
      // Get all history by using a very old date
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldonhangall/$encodedUsername?last_sync=2020-01-01%2000:00:00')
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data is List) {
          await _dbHelper.clearDonHangTable();
          print('Local DonHang table cleared for full history sync.');

          if (data.isNotEmpty) {
            final batch = await _dbHelper.startBatch();
            for (var item in data) {
              final donHang = DonHangModel.fromMap(item);
              
              _dbHelper.addToBatch(batch,
                'INSERT INTO donhang (soPhieu, nguoiTao, ngay, tenKhachHang, sdtKhachHang, soPO, diaChi, mst, tapKH, tenNguoiGiaoDich, boPhanGiaoDich, sdtNguoiGiaoDich, thoiGianDatHang, ngayYeuCauGiao, thoiGianCapNhatTrangThai, phuongThucThanhToan, thanhToanSauNhanHangXNgay, datCocSauXNgay, giayToCanKhiGiaoHang, thoiGianVietHoaDon, thongTinVietHoaDon, diaChiGiaoHang, hoTenNguoiNhanHoaHong, sdtNguoiNhanHoaHong, hinhThucChuyenHoaHong, thongTinNhanHoaHong, ngaySeGiao, thoiGianCapNhatMoiNhat, phuongThucGiaoHang, phuongTienGiaoHang, hoTenNguoiGiaoHang, ghiChu, giaNet, tongTien, vat10, tongCong, hoaHong10, tienGui10, thueTNDN, vanChuyen, thucThu, nguoiNhanHang, sdtNguoiNhanHang, phieuXuatKho, trangThai, tenKhachHang2) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [
                  donHang.soPhieu,
                  donHang.nguoiTao,
                  donHang.ngay,
                  donHang.tenKhachHang,
                  donHang.sdtKhachHang,
                  donHang.soPO,
                  donHang.diaChi,
                  donHang.mst,
                  donHang.tapKH,
                  donHang.tenNguoiGiaoDich,
                  donHang.boPhanGiaoDich,
                  donHang.sdtNguoiGiaoDich,
                  donHang.thoiGianDatHang,
                  donHang.ngayYeuCauGiao,
                  donHang.thoiGianCapNhatTrangThai,
                  donHang.phuongThucThanhToan,
                  donHang.thanhToanSauNhanHangXNgay,
                  donHang.datCocSauXNgay,
                  donHang.giayToCanKhiGiaoHang,
                  donHang.thoiGianVietHoaDon,
                  donHang.thongTinVietHoaDon,
                  donHang.diaChiGiaoHang,
                  donHang.hoTenNguoiNhanHoaHong,
                  donHang.sdtNguoiNhanHoaHong,
                  donHang.hinhThucChuyenHoaHong,
                  donHang.thongTinNhanHoaHong,
                  donHang.ngaySeGiao,
                  donHang.thoiGianCapNhatMoiNhat,
                  donHang.phuongThucGiaoHang,
                  donHang.phuongTienGiaoHang,
                  donHang.hoTenNguoiGiaoHang,
                  donHang.ghiChu,
                  donHang.giaNet,
                  donHang.tongTien,
                  donHang.vat10,
                  donHang.tongCong,
                  donHang.hoaHong10,
                  donHang.tienGui10,
                  donHang.thueTNDN,
                  donHang.vanChuyen,
                  donHang.thucThu,
                  donHang.nguoiNhanHang,
                  donHang.sdtNguoiNhanHang,
                  donHang.phieuXuatKho,
                  donHang.trangThai,
                  donHang.tenKhachHang2,
                ]
              );
            }
            await _dbHelper.commitBatch(batch);
            print('Synced ${data.length} DonHang records (full history).');
          }
        }
      } else {
        throw Exception('Failed to sync DonHang history. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing DonHang history: $e');
      throw e;
    }
  }
  Future<void> _syncChiTietDonData() async {
    try {
      final encodedUsername = Uri.encodeComponent(_username);
      
      // Get all history by using a very old date
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelchitietdonall/$encodedUsername?last_sync=2020-01-01%2000:00:00')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          await _dbHelper.clearChiTietDonTable();
          print('Local ChiTietDon table cleared for full history sync.');

          if (data.isNotEmpty) {
            final batch = await _dbHelper.startBatch();
            for (var item in data) {
              final chiTietDon = ChiTietDonModel.fromMap(item);
              _dbHelper.addToBatch(batch,
                'INSERT INTO chitietdon (uid, soPhieu, trangThai, tenHang, maHang, donViTinh, soLuongYeuCau, donGia, thanhTien, soLuongThucGiao, chiNhanh, idHang, soLuongKhachNhan, duyet, xuatXuHangKhac, baoGia, hinhAnh, ghiChu, phanTramVAT, vat, tenKhachHang, updateTime) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [
                  chiTietDon.uid,
                  chiTietDon.soPhieu,
                  chiTietDon.trangThai,
                  chiTietDon.tenHang,
                  chiTietDon.maHang,
                  chiTietDon.donViTinh,
                  chiTietDon.soLuongYeuCau,
                  chiTietDon.donGia,
                  chiTietDon.thanhTien,
                  chiTietDon.soLuongThucGiao,
                  chiTietDon.chiNhanh,
                  chiTietDon.idHang,
                  chiTietDon.soLuongKhachNhan,
                  chiTietDon.duyet,
                  chiTietDon.xuatXuHangKhac,
                  chiTietDon.baoGia,
                  chiTietDon.hinhAnh,
                  chiTietDon.ghiChu,
                  chiTietDon.phanTramVAT,
                  chiTietDon.vat,
                  chiTietDon.tenKhachHang,
                  chiTietDon.updateTime,
                ]
              );
            }
            await _dbHelper.commitBatch(batch);
            print('Synced ${data.length} ChiTietDon records (full history).');
          }
        }
      } else {
        throw Exception('Failed to sync ChiTietDon history. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing ChiTietDon history: $e');
      throw e;
    }
  }
  Future<void> _setAndCalculateDateRange(String period) async { // Added 'async'
  DateTime now = DateTime.now();
  setState(() {
    _selectedPeriod = period;
    if (period == 'Hôm nay') {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (period == 'Tuần này') {
      _startDate = now.subtract(Duration(days: now.weekday - 1)); // Monday of current week
      _startDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      _endDate = _startDate!.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59)); // Sunday end of day
    } else if (period == 'Tháng này') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59); // Last day of current month
    } else if (period == 'Quý này') {
      int currentMonth = now.month;
      int startMonth;
      if (currentMonth >= 1 && currentMonth <= 3) {
        startMonth = 1;
      } else if (currentMonth >= 4 && currentMonth <= 6) {
        startMonth = 4;
      } else if (currentMonth >= 7 && currentMonth <= 9) {
        startMonth = 7;
      } else {
        startMonth = 10;
      }
      _startDate = DateTime(now.year, startMonth, 1);
      _endDate = DateTime(now.year, startMonth + 3, 0, 23, 59, 59); 
    }
  }); // setState ends here

  // Await the asynchronous _calculateStats call
  await _calculateStats(); 
}
    Future<void> _calculateStats() async {
    setState(() {
      _isLoading = true; // Use main _isLoading for data fetching
      _totalCompletedOrders = 0;
      _totalRevenue = 0.0;
      _uniqueCompletedItems = 0;
    });

    try {
      // 1. Fetch all orders
      final allOrders = await _dbHelper.getAllDonHang();

      // 2. Filter orders for 'Hoàn thành' status within the date range
      final completedOrders = allOrders.where((order) {
        final orderStatus = order.trangThai?.toLowerCase();
        if (orderStatus != 'hoàn thành') {
          return false;
        }

        // --- CORRECTED LINE HERE ---
        // Use ThoiGianCapNhatTrangThai for date filtering
        if (order.thoiGianCapNhatTrangThai == null || order.thoiGianCapNhatTrangThai!.isEmpty) {
          return false;
        }
        try {
          // Parse the date string from ThoiGianCapNhatTrangThai
          final orderDate = DateTime.parse(order.thoiGianCapNhatTrangThai!);
          return _startDate != null && _endDate != null &&
              orderDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
              orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
        } catch (e) {
          // Handle cases where order.thoiGianCapNhatTrangThai might not be a valid date string
          print('Error parsing date for order ${order.soPhieu} (ThoiGianCapNhatTrangThai): $e');
          return false;
        }
      }).toList();

      // 3. Calculate Total Orders and Revenue
      _totalCompletedOrders = completedOrders.length;
      _totalRevenue = completedOrders.fold(
          0.0, (sum, order) => sum + (order.tongCong ?? 0).toDouble());

      // 4. Collect unique item IDs from completed orders
      final Set<String> uniqueItemIds = {};
      for (var order in completedOrders) {
        if (order.soPhieu != null) {
          final items = await _dbHelper.getChiTietDonBySoPhieu(order.soPhieu!);
          for (var item in items) {
            if (item.idHang != null) {
              uniqueItemIds.add(item.idHang!);
            }
          }
        }
      }
      _uniqueCompletedItems = uniqueItemIds.length;

    } catch (e) {
      print('Error calculating stats: $e');
      // You might want to display an error message on the UI
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    // Re-calculate stats for the current selected period
    await _setAndCalculateDateRange(_selectedPeriod);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật dữ liệu thành công'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Currency formatter
  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    // Colors with hex values (matching your existing color scheme)
    final Color appBarTop = const Color(0xFF534b0d);
    final Color appBarBottom = const Color(0xFFb2a41f);
    final Color buttonColor = const Color(0xFF837826);
    final Color cardBgColor = const Color(0xFFFAFAFA);

    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉ số hoạt động', style: TextStyle(fontSize: 18, color: Colors.yellow)),
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
  icon: _isSyncing
      ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
          ),
        )
      : const Icon(Icons.cloud_download, color: Colors.yellow),
  label: const Text(
    'Đồng bộ toàn bộ lịch sử',
    style: TextStyle(color: Colors.yellow),
  ),
  onPressed: _isSyncing ? null : _syncAllHistoryData,
),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.yellow),
            onPressed: (_isLoading || _isSyncing) ? null : _refreshData,
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chọn kỳ báo cáo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedPeriod,
                                  items: _periods.map((String period) {
                                    return DropdownMenuItem<String>(
                                      value: period,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: Text(period),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      _setAndCalculateDateRange(newValue); // Update and recalculate
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ngày hiện tại: $formattedDate',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Summary card
                    Card(
                      elevation: 2,
                      color: cardBgColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tổng quan nhanh',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryItem(
                              title: 'Tổng đơn hàng',
                              value: _totalCompletedOrders.toString(),
                              icon: Icons.receipt,
                              color: Colors.blue,
                            ),
                            const Divider(),
                            _buildSummaryItem(
                              title: 'Doanh số',
                              value: _formatCurrency(_totalRevenue),
                              icon: Icons.monetization_on,
                              color: Colors.green,
                            ),
                            const Divider(),
                            _buildSummaryItem(
                              title: 'Số mặt hàng',
                              value: _uniqueCompletedItems.toString(),
                              icon: Icons.category,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                                                            const SizedBox(height: 4),
                    // Main action buttons
                    const Text(
                      'Báo cáo chỉ số',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Button 3
                    _buildActionButton(
                      icon: Icons.insights,
                      title: 'Dự đoán xu hướng hàng',
                      subtitle: 'Phân tích và dự báo xu hướng tiêu thụ hàng hóa',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HSXuHuongScreen()),
                        );
                      },
                      textColor: Colors.orange,
                    ),
                    const SizedBox(height: 16),

                    _buildActionButton(
                      icon: Icons.social_distance,
                      title: 'Tổng hợp đặt hàng XNK',
                      subtitle: 'Theo dõi kết quả đặt hàng và bán hàng',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HSXuHuongXNKScreen()),
                        );
                      },
                      textColor: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      icon: Icons.insert_chart,
                      title: 'Tổng hợp hoạt động kinh doanh, bán hàng',
                      subtitle: 'Dựa theo những đơn đã hoàn thành, và mặt hàng chi tiết',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HSXuHuongKDScreen()),
                        );
                      },
                      textColor: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      icon: Icons.hub,
                      title: 'Tổng hợp kho xuất nhập tồn',
                      subtitle: 'Dựa theo những giao dịch đã hoàn thành, kệ tồn kho',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HSXuHuongKHOScreen()),
                        );
                      },
                      textColor: Colors.purple,
                    ),
const SizedBox(height: 16),
_buildActionButton(
  icon: Icons.trending_up,
  title: 'Theo dõi chỉ số KPI',
  subtitle: 'Theo dõi và phân tích các chỉ số hiệu suất hoạt động',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HSXuHuongKPIScreen()),
    );
  },
  textColor: Colors.red,
),
const SizedBox(height: 16),
_buildActionButton(
  icon: Icons.volunteer_activism,
  title: 'Khách hàng lâu chưa mua',
  subtitle: 'Chú ý: bấm Đồng bộ toàn bộ lịch sử trước khi dùng',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InactiveCustomersScreen()),
    );
  },
  textColor: Colors.teal,
),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper method to build action buttons
  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor, // Added optional textColor parameter
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (textColor ?? const Color(0xFF837826)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: textColor ?? const Color(0xFF837826),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor, // Apply textColor if provided
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build summary items
  Widget _buildSummaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}