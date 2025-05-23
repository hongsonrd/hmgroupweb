import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'db_helper.dart'; // Assuming this exists and has methods like getAllDonHang, getChiTietDonBySoPhieu, getAllDSHang
import 'table_models.dart'; // Assuming DonHangModel, ChiTietDonModel, DSHangModel are defined here

class HSXuHuongKDScreen extends StatefulWidget {
  const HSXuHuongKDScreen({Key? key}) : super(key: key);

  @override
  _HSXuHuongKDScreenState createState() => _HSXuHuongKDScreenState();
}

class _HSXuHuongKDScreenState extends State<HSXuHuongKDScreen> {
  final DBHelper _dbHelper = DBHelper();
  bool _isLoading = true;
  String _selectedPeriodType = 'Tháng'; // 'Tháng' or 'Quý'
  String _selectedPeriodValue = ''; // e.g., '2024-05' for May 2024, or '2024-Q2' for Q2 2024
  String? _selectedSaleAgent; // Nullable for 'Tất cả'
  List<String> _availableSaleAgents = ['Tất cả']; // List of NguoiTao

  DateTime? _startDate;
  DateTime? _endDate;

  // Stats variables
  int _totalCompletedOrders = 0;
  double _totalRevenue = 0.0;
  int _uniqueCompletedItems = 0;

  // Data for charts and insights
  // Use a map to preserve order for the chart
  Map<String, double> _chartDataRevenue = {}; // For chart: { '2024-01': 1000.0 } or { '2024-Q1': 5000.0 }
  Map<String, double> _revenueByBrand = {}; // For brand insights: { 'Brand A': 500.0 }
  Map<String, int> _itemsSoldByBrand = {}; // For brand insights: { 'Brand A': 10 }
  List<DonHangModel> _completedOrders = []; // For detailed table
  List<ChiTietDonModel> _completedOrderDetails = []; // For detailed table

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadAvailableSaleAgents();
    _setInitialPeriod(); // This will also trigger _calculateStats
  }

  Future<void> _loadAvailableSaleAgents() async {
    try {
      final allOrders = await _dbHelper.getAllDonHang();
      final agents = allOrders
          .where((order) => order.nguoiTao != null && order.nguoiTao!.isNotEmpty)
          .map((order) => order.nguoiTao!.toLowerCase()) // Convert to lowercase here
          .toSet()
          .toList();
      agents.sort(); // Sort agents alphabetically

      setState(() {
        _availableSaleAgents = ['Tất cả', ...agents];
        _selectedSaleAgent = 'Tất cả'; // Default to all agents
      });
    } catch (e) {
      print('Error loading sales agents: $e');
    }
  }

  void _setInitialPeriod() {
    final now = DateTime.now();
    // Default to current month
    _selectedPeriodType = 'Tháng';
    _selectedPeriodValue = DateFormat('yyyy-MM').format(now);
    _setAndCalculateDateRange(_selectedPeriodType, _selectedPeriodValue);
  }

  Future<void> _setAndCalculateDateRange(String periodType, String periodValue) async {
    DateTime now = DateTime.now();
    DateTime tempStartDate;
    DateTime tempEndDate;

    if (periodType == 'Tháng') {
      int year = int.parse(periodValue.split('-')[0]);
      int month = int.parse(periodValue.split('-')[1]);
      tempStartDate = DateTime(year, month, 1);
      tempEndDate = DateTime(year, month + 1, 0, 23, 59, 59); // Last day of the month
    } else { // Quý
      int year = int.parse(periodValue.split('-')[0]);
      int quarter = int.parse(periodValue.split('-')[1].substring(1)); // 'Q1' -> 1
      int startMonth = (quarter - 1) * 3 + 1;
      tempStartDate = DateTime(year, startMonth, 1);
      tempEndDate = DateTime(year, startMonth + 3, 0, 23, 59, 59); // Last day of the quarter
    }

    setState(() {
      _isLoading = true;
      _selectedPeriodType = periodType;
      _selectedPeriodValue = periodValue;
      _startDate = tempStartDate;
      _endDate = tempEndDate;
    });

    await _calculateStats();
  }

  Future<void> _calculateStats() async {
    setState(() {
      _totalCompletedOrders = 0;
      _totalRevenue = 0.0;
      _uniqueCompletedItems = 0;
      _chartDataRevenue = {}; // Reset chart data
      _revenueByBrand = {};
      _itemsSoldByBrand = {};
      _completedOrders = [];
      _completedOrderDetails = [];
    });

    try {
      final allOrders = await _dbHelper.getAllDonHang();
      final allItems = await _dbHelper.getAllDSHang(); // Fetch all master item data

      final completedOrdersInPeriod = allOrders.where((order) {
        final orderStatus = order.trangThai?.toLowerCase();
        if (orderStatus != 'hoàn thành') {
          return false;
        }

        // Convert nguoiTao to lowercase for comparison
        final orderNguoiTaoLower = order.nguoiTao?.toLowerCase();
        if (_selectedSaleAgent != 'Tất cả' && orderNguoiTaoLower != _selectedSaleAgent) {
          return false; // Filter by selected agent (already lowercase)
        }

        if (order.thoiGianCapNhatTrangThai == null || order.thoiGianCapNhatTrangThai!.isEmpty) {
          return false;
        }
        try {
          final orderDate = DateTime.parse(order.thoiGianCapNhatTrangThai!);
          return _startDate != null && _endDate != null &&
              orderDate.isAfter(_startDate!.subtract(const Duration(milliseconds: 1))) && // Inclusive start
              orderDate.isBefore(_endDate!.add(const Duration(milliseconds: 1))); // Inclusive end
        } catch (e) {
          print('Error parsing date for order ${order.soPhieu} (ThoiGianCapNhatTrangThai): $e');
          return false;
        }
      }).toList();

      _totalCompletedOrders = completedOrdersInPeriod.length;
      _totalRevenue = completedOrdersInPeriod.fold(
          0.0, (sum, order) => sum + (order.tongCong ?? 0).toDouble());

      _completedOrders = completedOrdersInPeriod; // Store for detailed table

      final Set<String> uniqueItemIds = {};
      for (var order in completedOrdersInPeriod) {
        if (order.soPhieu != null) {
          final items = await _dbHelper.getChiTietDonBySoPhieu(order.soPhieu!);
          _completedOrderDetails.addAll(items); // Store details for table

          for (var item in items) {
            if (item.idHang != null) {
              uniqueItemIds.add(item.idHang!);

              // Aggregate revenue and items sold by brand
              final dsHangItem = allItems.firstWhere(
                (dsItem) => dsItem.uid == item.idHang,
                orElse: () => DSHangModel(), // Provide a default empty model if not found
              );
              final brand = dsHangItem.thuongHieu ?? 'Không rõ thương hiệu';
              _revenueByBrand[brand] = (_revenueByBrand[brand] ?? 0.0) + (item.thanhTien ?? 0).toDouble();
              _itemsSoldByBrand[brand] = (_itemsSoldByBrand[brand] ?? 0) + (item.soLuongKhachNhan ?? 0).toInt();
            }
          }
        }
      }
      _uniqueCompletedItems = uniqueItemIds.length;

      // Populate _chartDataRevenue for bar chart
      if (_selectedPeriodType == 'Tháng') {
        // Only one month selected, so represent it directly
        _chartDataRevenue[_selectedPeriodValue] = _totalRevenue;
      } else { // Quý - break down by month
        final startMonth = _startDate!.month;
        final endMonth = _endDate!.month;
        // Ensure months are collected in order for the chart
        List<String> quarterMonths = [];
        for (int m = startMonth; m <= endMonth; m++) {
          final monthDate = DateTime(_startDate!.year, m, 1);
          if (monthDate.isAfter(_endDate!)) break; // Stop if we exceed the quarter boundary
          quarterMonths.add(DateFormat('yyyy-MM').format(monthDate));
        }

        for (var monthKey in quarterMonths) {
          int year = int.parse(monthKey.split('-')[0]);
          int month = int.parse(monthKey.split('-')[1]);

          double monthRevenue = 0.0;
          final ordersInThisMonth = completedOrdersInPeriod.where((order) {
            try {
              final orderDate = DateTime.parse(order.thoiGianCapNhatTrangThai!);
              return orderDate.year == year && orderDate.month == month;
            } catch (e) {
              return false;
            }
          });
          monthRevenue = ordersInThisMonth.fold(0.0, (sum, order) => sum + (order.tongCong ?? 0).toDouble());
          _chartDataRevenue[monthKey] = monthRevenue;
        }
      }

    } catch (e) {
      print('Error calculating stats in HSXuHuongKDScreen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper for generating period values (e.g., '2024-01', '2024-Q1')
  List<String> _generatePeriods(String type) {
    List<String> periods = [];
    final now = DateTime.now();
    if (type == 'Tháng') {
      for (int i = 0; i < 12; i++) { // Last 12 months
        final date = DateTime(now.year, now.month - i, 1);
        periods.add(DateFormat('yyyy-MM').format(date));
      }
    } else { // Quý
      // Generate quarters for current and previous 2 years
      for (int yearOffset = 0; yearOffset <= 2; yearOffset++) {
        int year = now.year - yearOffset;
        for (int q = 1; q <= 4; q++) {
          periods.add('$year-Q$q');
        }
      }
      // Sort descending for most recent first. Using Date objects for accurate quarter sorting
      periods.sort((a, b) {
        int yearA = int.parse(a.split('-')[0]);
        int quarterA = int.parse(a.split('-')[1].substring(1));
        int monthA = (quarterA - 1) * 3 + 1;

        int yearB = int.parse(b.split('-')[0]);
        int quarterB = int.parse(b.split('-')[1].substring(1));
        int monthB = (quarterB - 1) * 3 + 1;

        return DateTime(yearB, monthB).compareTo(DateTime(yearA, monthA));
      });
    }
    return periods;
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarTop = const Color(0xFF534b0d);
    final Color appBarBottom = const Color(0xFFb2a41f);
    final Color cardBgColor = const Color(0xFFFAFAFA);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Xu hướng kinh doanh & bán hàng',
          style: TextStyle(fontSize: 18, color: Colors.yellow),
        ),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _setAndCalculateDateRange(_selectedPeriodType, _selectedPeriodValue),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Lọc dữ liệu'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPeriodType,
                                  decoration: const InputDecoration(
                                    labelText: 'Loại kỳ',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Tháng', child: Text('Theo tháng')),
                                    DropdownMenuItem(value: 'Quý', child: Text('Theo quý')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      _selectedPeriodType = value;
                                      // Reset period value to a default for the new type (most recent)
                                      _setAndCalculateDateRange(value, _generatePeriods(value).first);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPeriodValue,
                                  decoration: const InputDecoration(
                                    labelText: 'Chọn kỳ',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  items: _generatePeriods(_selectedPeriodType).map((period) {
                                    return DropdownMenuItem(value: period, child: Text(period));
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _setAndCalculateDateRange(_selectedPeriodType, value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedSaleAgent,
                            decoration: const InputDecoration(
                              labelText: 'Người tạo đơn',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: _availableSaleAgents.map((agent) {
                              return DropdownMenuItem(value: agent, child: Text(agent));
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedSaleAgent = value;
                                });
                                _calculateStats(); // Recalculate with new agent filter
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Thống kê tổng quan'),
                  Card(
                    elevation: 2,
                    color: cardBgColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildSummaryItem(
                            title: 'Tổng số đơn hoàn thành',
                            value: _totalCompletedOrders.toString(),
                            icon: Icons.assignment_turned_in,
                            color: Colors.blue,
                          ),
                          const Divider(),
                          _buildSummaryItem(
                            title: 'Tổng doanh thu',
                            value: _formatCurrency(_totalRevenue),
                            icon: Icons.payments,
                            color: Colors.green,
                          ),
                          const Divider(),
                          _buildSummaryItem(
                            title: 'Tổng số mặt hàng đã bán',
                            value: _uniqueCompletedItems.toString(),
                            icon: Icons.shopping_basket,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Biểu đồ doanh thu'),
                  _chartDataRevenue.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Không có dữ liệu doanh thu để hiển thị biểu đồ.'),
                        ))
                      : Card(
                          elevation: 2,
                          color: cardBgColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              height: 200,
                              child: BarChart(
                                BarChartData(
                                  barGroups: _chartDataRevenue.entries.map((entry) {
                                    final index = _chartDataRevenue.keys.toList().indexOf(entry.key);
                                    return BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: entry.value / 1000000, // Display in millions for better scale
                                          color: Colors.indigoAccent,
                                          width: _selectedPeriodType == 'Tháng' ? 60 : 20, // Wider bar for single month
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final index = value.toInt();
                                          if (index >= 0 && index < _chartDataRevenue.keys.length) {
                                            String label = _chartDataRevenue.keys.toList()[index];
                                            if (_selectedPeriodType == 'Tháng') {
                                              return SideTitleWidget(
                                                axisSide: meta.axisSide,
                                                child: Text(DateFormat('MM/yyyy').format(DateTime.parse('$label-01'))), // Show full month/year for single month
                                              );
                                            }
                                            // For Quarterly view, break down by month
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(DateFormat('MM/yy').format(DateTime.parse('$label-01'))),
                                            );
                                          }
                                          return const Text('');
                                        },
                                        reservedSize: 30,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) => Text('${value.toInt()} tr'), // Show in millions
                                        reservedSize: 40,
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: (_totalRevenue / 1000000) * 1.2, // Max Y slightly above max revenue
                                  minY: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Doanh thu theo thương hiệu'),
                  _revenueByBrand.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Không có dữ liệu thương hiệu để hiển thị.'),
                        ))
                      : Card(
                          elevation: 2,
                          color: cardBgColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: _revenueByBrand.entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(entry.value),
                                        style: const TextStyle(color: Colors.green),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        '(${_itemsSoldByBrand[entry.key] ?? 0} sp)',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Chi tiết đơn hàng hoàn thành'),
                  _completedOrders.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Không có đơn hàng hoàn thành trong kỳ đã chọn.'),
                        ))
                      : Card(
                          elevation: 2,
                          color: cardBgColor,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 20,
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 60,
                              headingRowColor: MaterialStateProperty.resolveWith((states) => appBarTop.withOpacity(0.1)),
                              columns: const [
                                DataColumn(label: Text('Mã Đơn', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Khách hàng', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Người tạo', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('TG hoàn thành', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Tổng cộng', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Xem chi tiết', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _completedOrders.map((order) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(order.soPhieu ?? 'N/A')),
                                    DataCell(Text(order.tenKhachHang ?? 'N/A')),
                                    DataCell(Text(order.nguoiTao ?? 'N/A')), // Display as is for now in table
                                    DataCell(Text(_formatDate(order.thoiGianCapNhatTrangThai))),
                                    DataCell(Text(_formatCurrency((order.tongCong ?? 0).toDouble()))),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                                        onPressed: () {
                                          _showOrderDetailsDialog(context, order);
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                  const SizedBox(height: 50), // Extra space at bottom
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF837826), // Match button color or other accent
        ),
      ),
    );
  }

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

  void _showOrderDetailsDialog(BuildContext context, DonHangModel order) {
    final orderDetails = _completedOrderDetails.where((detail) => detail.soPhieu == order.soPhieu).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Chi tiết đơn hàng: ${order.soPhieu}', style: const TextStyle(fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Khách hàng:', order.tenKhachHang ?? 'N/A'),
                _buildDetailRow('Người tạo:', order.nguoiTao ?? 'N/A'),
                _buildDetailRow('Thời gian hoàn thành:', _formatDate(order.thoiGianCapNhatTrangThai)),
                _buildDetailRow('Tổng cộng:', _formatCurrency((order.tongCong ?? 0).toDouble())),
                const Divider(),
                const Text('Mặt hàng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (orderDetails.isEmpty)
                  const Text('Không có mặt hàng chi tiết.')
                else
                  ...orderDetails.map((detail) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          '  - ${detail.tenHang ?? 'N/A'} (SL: ${detail.soLuongKhachNhan ?? detail.soLuongThucGiao ?? 'N/A'} ${detail.donViTinh ?? ''}) - ${_formatCurrency((detail.thanhTien ?? 0).toDouble())}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      )).toList(),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Đóng'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}