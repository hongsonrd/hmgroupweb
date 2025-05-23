import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'db_helper.dart';
import 'table_models.dart';

// Custom data model to combine information for XNK items
class XNKItemData {
  final String soPhieu;
  final String orderTenKhachHang;
  final String itemUid; // ChiTietDon UID
  final String saleAgent; // ChiTietDon.baoGia
  final String productName; // DSHang.TenSanPham
  final String? brand; // DSHang.ThuongHieu
  final DateTime importerFulfillmentDate; // ChiTietDon.ghiChu parsed as date
  final double importerFulfillmentAmount; // ChiTietDon.soLuongYeuCau

  // Agent fulfillment amounts (based on 'Hoàn thành' orders)
  double agentFulfilledCurrentMonth; // Sum of soLuongYeuCau by this agent for this product in current selected month
  double agentFulfilledNextMonth; // Sum of soLuongYeuCau by this agent for this product in next month
  double agentFulfilledMonth3; // New: Sum for month + 2

  XNKItemData({
    required this.soPhieu,
    required this.orderTenKhachHang,
    required this.itemUid,
    required this.saleAgent,
    required this.productName,
    this.brand,
    required this.importerFulfillmentDate,
    required this.importerFulfillmentAmount,
    this.agentFulfilledCurrentMonth = 0.0,
    this.agentFulfilledNextMonth = 0.0,
    this.agentFulfilledMonth3 = 0.0, // Initialize new field
  });

  double get fulfillmentPercentage {
    if (agentFulfilledCurrentMonth == 0) return 0.0;
    return (importerFulfillmentAmount / agentFulfilledCurrentMonth) * 100;
  }
}

class HSXuHuongXNKScreen extends StatefulWidget {
  const HSXuHuongXNKScreen({Key? key}) : super(key: key);

  @override
  _HSXuHuongXNKScreenState createState() => _HSXuHuongXNKScreenState();
}

class _HSXuHuongXNKScreenState extends State<HSXuHuongXNKScreen> {
  final DBHelper _dbHelper = DBHelper();
  bool _isLoading = true;
  String _selectedPeriodValue = DateFormat('yyyy-MM').format(DateTime.now()); // Default to current month
  List<String> _availableMonths = [];

  String? _selectedSaleAgentFilter; // For filtering by ChiTietDon.baoGia
  List<String> _availableSaleAgents = ['Tất cả']; // List of unique baoGia

  // Overall Statistics
  int _totalXNKOrders = 0;
  double _totalImporterFulfilledAmount = 0.0; // Sum of soLuongYeuCau from XNK items
  double _totalAgentFulfilledAmountOverall = 0.0; // Sum of all 'Hoàn thành' orders for the selected month
  double _overallFulfillmentPercentage = 0.0;

  // Data for item list display
  List<XNKItemData> _xnkItems = [];

  // New: Data for Daily Importer Fulfillment Chart
  Map<String, double> _dailyImporterFulfillmentAmounts = {};

  // Cached DSHang for efficient lookup
  List<DSHangModel> _allDSHangItems = [];

  @override
  void initState() {
    super.initState();
    _generateAvailableMonths();
    _loadInitialData();
  }

  void _generateAvailableMonths() {
    final now = DateTime.now();
    _availableMonths.clear();
    // Generate months for the past year and next 6 months for flexibility
    // This will generate 12 (past) + 1 (current) + 6 (future) = 19 months
    for (int i = -12; i <= 6; i++) {
      _availableMonths.add(DateFormat('yyyy-MM').format(DateTime(now.year, now.month + i, 1)));
    }
    _availableMonths.sort((a, b) => b.compareTo(a)); // Newest first
    // Ensure selected month is in the list
    if (!_availableMonths.contains(_selectedPeriodValue)) {
      _selectedPeriodValue = DateFormat('yyyy-MM').format(now);
    }
  }

  Future<void> _loadInitialData() async {
    await _loadAvailableSaleAgents();
    _calculateXNKStats(); // Initial calculation
  }

  Future<void> _loadAvailableSaleAgents() async {
    try {
      // Get all ChiTietDon to find unique baoGia values
      final allChiTietDon = await _dbHelper.getAllChiTietDon();
      final agents = allChiTietDon
          .where((item) => item.baoGia != null && item.baoGia!.isNotEmpty)
          .map((item) => item.baoGia!)
          .toSet()
          .toList();
      agents.sort();

      setState(() {
        _availableSaleAgents = ['Tất cả', ...agents];
        _selectedSaleAgentFilter = 'Tất cả'; // Default to all agents
      });
    } catch (e) {
      print('Error loading sales agents for XNK: $e');
    }
  }

  Future<void> _calculateXNKStats() async {
    setState(() {
      _isLoading = true;
      _totalXNKOrders = 0;
      _totalImporterFulfilledAmount = 0.0;
      _totalAgentFulfilledAmountOverall = 0.0;
      _overallFulfillmentPercentage = 0.0;
      _xnkItems = [];
      _dailyImporterFulfillmentAmounts = {}; // Reset daily chart data
      _allDSHangItems = []; // Reset cached DSHang items
    });

    try {
      // 1. Fetch necessary data
      _allDSHangItems = await _dbHelper.getAllDSHang(); // Cache all products
      final allDonHang = await _dbHelper.getAllDonHang();
      final allChiTietDon = await _dbHelper.getAllChiTietDon(); // Fetch all details for overall calcs

      // Parse selected period for filtering
      final selectedYear = int.parse(_selectedPeriodValue.split('-')[0]);
      final selectedMonth = int.parse(_selectedPeriodValue.split('-')[1]);
      final currentPeriodStartDate = DateTime(selectedYear, selectedMonth, 1);
      final currentPeriodEndDate = DateTime(selectedYear, selectedMonth + 1, 0, 23, 59, 59);

      // Define next month's and month+2's periods
      final nextMonthStartDate = DateTime(selectedYear, selectedMonth + 1, 1);
      final nextMonthEndDate = DateTime(selectedYear, selectedMonth + 2, 0, 23, 59, 59);

      final month3StartDate = DateTime(selectedYear, selectedMonth + 2, 1);
      final month3EndDate = DateTime(selectedYear, selectedMonth + 3, 0, 23, 59, 59);


      // --- AGENT FULFILLMENT CALCULATION (from 'Hoàn thành' orders) ---
      // Map to store agent fulfillment by product for current, next, and month+2
      // Key: "${agentName}|${productId}"
      Map<String, double> agentProductFulfillmentCurrentMonth = {};
      Map<String, double> agentProductFulfillmentNextMonth = {};
      Map<String, double> agentProductFulfillmentMonth3 = {}; // New map for month+2

      // Filter DonHang for 'Hoàn thành' status only
      final completedOrders = allDonHang.where((order) =>
          order.trangThai?.toLowerCase() == 'hoàn thành').toList();

      for (var order in completedOrders) {
        if (order.soPhieu != null && order.nguoiTao != null && order.thoiGianCapNhatTrangThai != null) {
          final orderCompletionDate = DateTime.tryParse(order.thoiGianCapNhatTrangThai!);
          if (orderCompletionDate == null) continue;

          // Check if order completion date falls into current, next, or month+2
          final isCurrentMonth = orderCompletionDate.year == currentPeriodStartDate.year &&
              orderCompletionDate.month == currentPeriodStartDate.month;
          final isNextMonth = orderCompletionDate.year == nextMonthStartDate.year &&
              orderCompletionDate.month == nextMonthStartDate.month;
          final isMonth3 = orderCompletionDate.year == month3StartDate.year &&
              orderCompletionDate.month == month3StartDate.month;

          if (isCurrentMonth || isNextMonth || isMonth3) {
            final itemsInOrder = await _dbHelper.getChiTietDonBySoPhieu(order.soPhieu!);
            for (var item in itemsInOrder) {
              if (item.idHang != null && item.soLuongYeuCau != null) {
                final key = "${order.nguoiTao!.toLowerCase()}|${item.idHang!}";
                if (isCurrentMonth) {
                  agentProductFulfillmentCurrentMonth[key] =
                      (agentProductFulfillmentCurrentMonth[key] ?? 0.0) + item.soLuongYeuCau!;
                } else if (isNextMonth) {
                  agentProductFulfillmentNextMonth[key] =
                      (agentProductFulfillmentNextMonth[key] ?? 0.0) + item.soLuongYeuCau!;
                } else if (isMonth3) { // New: Add for month+2
                  agentProductFulfillmentMonth3[key] =
                      (agentProductFulfillmentMonth3[key] ?? 0.0) + item.soLuongYeuCau!;
                }
              }
            }
          }
        }
      }

      // --- XNK ITEMS PROCESSING ---
      List<XNKItemData> tempXNKItems = [];
      double currentImporterFulfillmentTotal = 0.0;
      double currentAgentFulfillmentTotal = 0.0;

      // Filter DonHang for 'XNK Đặt hàng đã duyệt' status within the selected month
      final xnkApprovedOrdersInPeriod = allDonHang.where((order) {
        final orderStatus = order.trangThai?.toLowerCase();
        if (orderStatus != 'xnk đặt hàng đã duyệt') {
          return false;
        }
        // Filter by order creation date (or update date if 'XNK Đặt hàng đã duyệt' applies to the order itself in that month)
        // Let's assume the relevant date for the order status is the 'ngay' of the order
        final orderDate = DateTime.tryParse(order.ngay ?? ''); // Assuming 'ngay' is the creation date
        if (orderDate == null) return false;

        return orderDate.isAfter(currentPeriodStartDate.subtract(const Duration(milliseconds: 1))) &&
               orderDate.isBefore(currentPeriodEndDate.add(const Duration(milliseconds: 1)));
      }).toList();

      _totalXNKOrders = xnkApprovedOrdersInPeriod.length;

      for (var order in xnkApprovedOrdersInPeriod) {
        if (order.soPhieu != null) {
          final itemsInOrder = allChiTietDon.where((item) => item.soPhieu == order.soPhieu).toList();

          for (var item in itemsInOrder) {
            // Check item-specific conditions
            final isBaoGiaValid = item.baoGia != null && item.baoGia!.isNotEmpty;
            final isGhiChuDateValid = item.ghiChu != null && item.ghiChu!.isNotEmpty;
            DateTime? importerFulfillmentDate;

            if (isGhiChuDateValid) {
              try {
                // Assuming ghiChu format is YYYY-MM-DD
                importerFulfillmentDate = DateFormat('yyyy-MM-dd').parse(item.ghiChu!);
              } catch (e) {
                // print('Warning: Could not parse ghiChu date "${item.ghiChu}" for item ${item.uid}: $e');
                importerFulfillmentDate = null; // Mark as invalid date
              }
            }

            if (isBaoGiaValid && importerFulfillmentDate != null && item.soLuongYeuCau != null) {
              // Apply screen-level agent filter if selected
              if (_selectedSaleAgentFilter != 'Tất cả' && item.baoGia != _selectedSaleAgentFilter) {
                continue; // Skip if agent filter doesn't match
              }

              final dsHangItem = _allDSHangItems.firstWhere(
                (dsItem) => dsItem.uid == item.idHang,
                orElse: () => DSHangModel(),
              );

              final agentFulfillKey = "${item.baoGia!.toLowerCase()}|${item.idHang!}";

              final xnkItem = XNKItemData(
                soPhieu: order.soPhieu!,
                orderTenKhachHang: order.tenKhachHang ?? 'N/A',
                itemUid: item.uid!,
                saleAgent: item.baoGia!,
                productName: dsHangItem.tenSanPham ?? 'Không rõ sản phẩm',
                brand: dsHangItem.thuongHieu,
                importerFulfillmentDate: importerFulfillmentDate,
                importerFulfillmentAmount: item.soLuongYeuCau!,
                agentFulfilledCurrentMonth: agentProductFulfillmentCurrentMonth[agentFulfillKey] ?? 0.0,
                agentFulfilledNextMonth: agentProductFulfillmentNextMonth[agentFulfillKey] ?? 0.0,
                agentFulfilledMonth3: agentProductFulfillmentMonth3[agentFulfillKey] ?? 0.0, // New: Assign month+2 data
              );
              tempXNKItems.add(xnkItem);

              currentImporterFulfillmentTotal += xnkItem.importerFulfillmentAmount;
              currentAgentFulfillmentTotal += xnkItem.agentFulfilledCurrentMonth; // For overall percentage, use current month's agent fulfillment

              // Populate Daily Importer Fulfillment Amounts for the chart
              final dayKey = DateFormat('yyyy-MM-dd').format(importerFulfillmentDate);
              _dailyImporterFulfillmentAmounts[dayKey] =
                  (_dailyImporterFulfillmentAmounts[dayKey] ?? 0.0) + item.soLuongYeuCau!;
            }
          }
        }
      }

      _overallFulfillmentPercentage = (currentAgentFulfillmentTotal > 0)
          ? (currentImporterFulfillmentTotal / currentAgentFulfillmentTotal) * 100
          : 0.0;

      // Sort items by importer fulfillment date
      tempXNKItems.sort((a, b) => a.importerFulfillmentDate.compareTo(b.importerFulfillmentDate));

      setState(() {
        _xnkItems = tempXNKItems;
        _totalImporterFulfilledAmount = currentImporterFulfillmentTotal;
        _totalAgentFulfilledAmountOverall = currentAgentFulfillmentTotal;
        // _overallFulfillmentPercentage is already calculated above
      });

    } catch (e) {
      print('Error calculating XNK stats: $e');
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

  // Currency formatter
  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Helper to get formatted month string for column headers
  String _getFormattedMonth(String basePeriodValue, int offsetMonths) {
    try {
      final baseDate = DateFormat('yyyy-MM').parse(basePeriodValue);
      final targetDate = DateTime(baseDate.year, baseDate.month + offsetMonths, 1);
      return DateFormat('MM/yyyy').format(targetDate);
    } catch (e) {
      return 'Tháng +$offsetMonths';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarTop = const Color(0xFF534b0d);
    final Color appBarBottom = const Color(0xFFb2a41f);
    final Color cardBgColor = const Color(0xFFFAFAFA);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xu hướng XNK', style: TextStyle(fontSize: 18, color: Colors.yellow)),
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
            onPressed: _isLoading ? null : _calculateXNKStats,
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
                          DropdownButtonFormField<String>(
                            value: _selectedPeriodValue,
                            decoration: const InputDecoration(
                              labelText: 'Chọn kỳ (Tháng của đơn XNK)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: _availableMonths.map((month) {
                              return DropdownMenuItem(value: month, child: Text(_getFormattedMonth(month, 0)));
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedPeriodValue = value;
                                });
                                _calculateXNKStats();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedSaleAgentFilter,
                            decoration: const InputDecoration(
                              labelText: 'Lọc theo Người bán hàng (BaoGia)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: _availableSaleAgents.map((agent) {
                              return DropdownMenuItem(value: agent, child: Text(agent));
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedSaleAgentFilter = value;
                                });
                                _calculateXNKStats();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Thống kê tổng quan XNK'),
                  Card(
                    elevation: 2,
                    color: cardBgColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildSummaryItem(
                            title: 'Tổng đơn XNK đã duyệt',
                            value: _totalXNKOrders.toString(),
                            icon: Icons.check_circle_outline,
                            color: Colors.blue,
                          ),
                          const Divider(),
                          _buildSummaryItem(
                            title: 'Tổng lượng nhập cam kết (Tháng này)',
                            value: '${_totalImporterFulfilledAmount.toInt()} SP',
                            icon: Icons.download,
                            color: Colors.green,
                          ),
                          const Divider(),
                          _buildSummaryItem(
                            title: 'Tổng lượng bán thực tế (Tháng này)',
                            value: '${_totalAgentFulfilledAmountOverall.toInt()} SP',
                            icon: Icons.upload,
                            color: Colors.orange,
                          ),
                          const Divider(),
                          _buildSummaryItem(
                            title: 'Tỷ lệ thực hiện XNK (Tháng này)',
                            value: '${_overallFulfillmentPercentage.toStringAsFixed(1)}%',
                            icon: Icons.percent,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Biểu đồ lượng nhập cam kết theo ngày'),
                  _dailyImporterFulfillmentAmounts.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Không có dữ liệu cam kết nhập khẩu theo ngày để hiển thị biểu đồ.'),
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
                                  barGroups: _dailyImporterFulfillmentAmounts.entries.map((entry) {
                                    final index = _dailyImporterFulfillmentAmounts.keys.toList().indexOf(entry.key);
                                    return BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: entry.value,
                                          color: Colors.teal.shade300,
                                          width: 10,
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
                                          if (index >= 0 && index < _dailyImporterFulfillmentAmounts.keys.length) {
                                            String labelKey = _dailyImporterFulfillmentAmounts.keys.toList()[index];
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(DateFormat('dd').format(DateTime.parse(labelKey))), // Just the day
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
                                        getTitlesWidget: (value, meta) => Text('${value.toInt()} SP'),
                                        reservedSize: 40,
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: (_dailyImporterFulfillmentAmounts.values.isNotEmpty ? _dailyImporterFulfillmentAmounts.values.reduce((a, b) => a > b ? a : b) * 1.2 : 1), // Dynamic max Y
                                  minY: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Chi tiết mặt hàng XNK đã duyệt'),
                  _xnkItems.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Không có mặt hàng XNK đã duyệt trong kỳ này theo bộ lọc.'),
                        ))
                      : Card(
                          elevation: 2,
                          color: cardBgColor,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 12, // Reduced spacing
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 80, // Increased row height for multi-line text
                              headingRowColor: MaterialStateProperty.resolveWith((states) => appBarTop.withOpacity(0.1)),
                              columns: [
                                DataColumn(label: Text('Mã Đơn', style: _dataColumnHeaderStyle)),
                                DataColumn(label: Text('Sản phẩm', style: _dataColumnHeaderStyle)),
                                DataColumn(label: Text('Người bán', style: _dataColumnHeaderStyle)),
                                DataColumn(label: Text('Cam kết nhập\n(Ngày)', style: _dataColumnHeaderStyle)),
                                DataColumn(label: Text('Cam kết nhập\n(Lượng)', style: _dataColumnHeaderStyle)),
                                DataColumn(label: Text('Tổng bán\n(${_getFormattedMonth(_selectedPeriodValue, 0)})', style: _dataColumnHeaderStyle)),
                                DataColumn(label: Text('Tổng bán\n(${_getFormattedMonth(_selectedPeriodValue, 1)})', style: _dataColumnHeaderStyle)),
                                DataColumn(label: Text('Tổng bán\n(${_getFormattedMonth(_selectedPeriodValue, 2)})', style: _dataColumnHeaderStyle)), // New Column Header
                                DataColumn(label: Text('Tỷ lệ thực hiện\n(%)', style: _dataColumnHeaderStyle)),
                              ],
                              rows: _xnkItems.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item.soPhieu, style: _dataCellTextStyle)),
                                    DataCell(Text('${item.productName}\n(${item.brand ?? 'N/A'})', style: _dataCellTextStyle)),
                                    DataCell(Text(item.saleAgent, style: _dataCellTextStyle)),
                                    DataCell(Text(_formatDate(item.importerFulfillmentDate), style: _dataCellTextStyle)),
                                    DataCell(Text('${item.importerFulfillmentAmount.toInt()}', style: _dataCellTextStyle)),
                                    DataCell(Text('${item.agentFulfilledCurrentMonth.toInt()}', style: _dataCellTextStyle)),
                                    DataCell(Text('${item.agentFulfilledNextMonth.toInt()}', style: _dataCellTextStyle)),
                                    DataCell(Text('${item.agentFulfilledMonth3.toInt()}', style: _dataCellTextStyle)), // New Data Cell
                                    DataCell(Text('${item.fulfillmentPercentage.toStringAsFixed(1)}%', style: _dataCellTextStyle.copyWith(
                                      color: item.fulfillmentPercentage >= 100 ? Colors.green.shade700 : (item.fulfillmentPercentage > 0 ? Colors.orange.shade700 : Colors.red.shade700),
                                      fontWeight: FontWeight.bold,
                                    ))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  TextStyle get _dataColumnHeaderStyle => const TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
  TextStyle get _dataCellTextStyle => TextStyle(fontSize: 12, color: Colors.grey[800]);

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF837826), // Match accent color
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
}