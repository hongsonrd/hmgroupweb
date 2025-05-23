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

  // New state for product brand filter
  String? _selectedProductBrandFilter;
  List<String> _availableBrandsForProductFilter = ['Tất cả thương hiệu'];

  DateTime? _startDate;
  DateTime? _endDate;

  // Stats variables
  int _totalCompletedOrders = 0;
  double _totalRevenue = 0.0;
  int _uniqueCompletedItems = 0;

  // Data for charts and insights
  Map<String, double> _chartDataRevenue = {}; // For chart: { '2024-05-01': 100.0 } or { '2024-04': 500.0 }
  Map<String, double> _revenueByBrand = {};
  Map<String, double> _totalQuantitySoldByBrand = {}; // To calculate average price
  Map<String, double> _avgPriceByBrand = {}; // Average price for each brand

  Map<String, double> _revenueByProduct = {};
  Map<String, double> _totalQuantitySoldByProduct = {}; // To calculate average price
  Map<String, double> _avgPriceByProduct = {}; // Average price for each product

  // Store all DSHangModels after fetching once per calculation cycle
  List<DSHangModel> _allDSHangItems = [];

  List<DonHangModel> _completedOrders = []; // For detailed table
  List<ChiTietDonModel> _completedOrderDetails = []; // For detailed table

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadAvailableSaleAgents();
    // Set initial product brand filter default here before calculations
    setState(() {
      _selectedProductBrandFilter = 'Tất cả thương hiệu';
    });
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
      _totalQuantitySoldByBrand = {};
      _avgPriceByBrand = {};
      _revenueByProduct = {};
      _totalQuantitySoldByProduct = {};
      _avgPriceByProduct = {};
      _availableBrandsForProductFilter = ['Tất cả thương hiệu']; // Reset for product filter
      _completedOrders = [];
      _completedOrderDetails = [];
      _allDSHangItems = []; // Reset cached DSHang items here before fetching
    });

    try {
      final allOrders = await _dbHelper.getAllDonHang();
      _allDSHangItems = await _dbHelper.getAllDSHang(); // <--- Fetch all DSHangModels here

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
      final Set<String> uniqueBrands = {}; // To populate product filter brands

      for (var order in completedOrdersInPeriod) {
        if (order.soPhieu != null) {
          final items = await _dbHelper.getChiTietDonBySoPhieu(order.soPhieu!);
          _completedOrderDetails.addAll(items); // Store details for table

          for (var item in items) {
            if (item.idHang != null) {
              uniqueItemIds.add(item.idHang!);

              // Find the corresponding DSHangModel from the cached _allDSHangItems list
              final dsHangItem = _allDSHangItems.firstWhere(
                (dsItem) => dsItem.uid == item.idHang,
                orElse: () => DSHangModel(), // Provide a default empty model if not found
              );

              // Get actual quantity and unit price for calculations
              // Use soLuongYeuCau for quantity
              final itemQuantity = item.soLuongYeuCau ?? 0.0;
              // Use thanhTien for total amount, as it's directly available from item
              final itemTotalAmount = (item.thanhTien ?? 0).toDouble();

              // Aggregate revenue and total quantity sold by brand
              final brand = dsHangItem.thuongHieu ?? 'Không rõ thương hiệu';
              uniqueBrands.add(brand); // Add to unique brands list
              _revenueByBrand[brand] = (_revenueByBrand[brand] ?? 0.0) + itemTotalAmount;
              _totalQuantitySoldByBrand[brand] = (_totalQuantitySoldByBrand[brand] ?? 0.0) + itemQuantity;

              // Aggregate revenue and total quantity sold by product
              final productName = dsHangItem.tenSanPham ?? 'Không rõ sản phẩm';
              _revenueByProduct[productName] = (_revenueByProduct[productName] ?? 0.0) + itemTotalAmount;
              _totalQuantitySoldByProduct[productName] = (_totalQuantitySoldByProduct[productName] ?? 0.0) + itemQuantity;
            }
          }
        }
      }
      _uniqueCompletedItems = uniqueItemIds.length;

      // Calculate Average Price for Brands
      _revenueByBrand.forEach((brand, revenue) {
        final totalQty = _totalQuantitySoldByBrand[brand] ?? 0.0;
        // Ensure totalQty is greater than 0 to avoid division by zero
        _avgPriceByBrand[brand] = (totalQty > 0) ? (revenue / totalQty) : 0.0;
      });

      // Calculate Average Price for Products
      _revenueByProduct.forEach((product, revenue) {
        final totalQty = _totalQuantitySoldByProduct[product] ?? 0.0;
        // Ensure totalQty is greater than 0 to avoid division by zero
        _avgPriceByProduct[product] = (totalQty > 0) ? (revenue / totalQty) : 0.0;
      });

      // Sort brands alphabetically for the product filter dropdown
      final sortedBrands = uniqueBrands.toList()..sort();
      _availableBrandsForProductFilter = ['Tất cả thương hiệu', ...sortedBrands];

      // If the previously selected product brand filter is no longer available, reset it
      if (_selectedProductBrandFilter != null && !_availableBrandsForProductFilter.contains(_selectedProductBrandFilter)) {
        _selectedProductBrandFilter = 'Tất cả thương hiệu';
      }


      // Populate _chartDataRevenue for bar chart based on selected period type
      if (_selectedPeriodType == 'Tháng') {
        // Daily breakdown for the selected month
        final int daysInMonth = DateTime(_startDate!.year, _startDate!.month + 1, 0).day;
        for (int i = 1; i <= daysInMonth; i++) {
          final day = DateTime(_startDate!.year, _startDate!.month, i);
          final dayKey = DateFormat('yyyy-MM-dd').format(day);
          double dayRevenue = 0.0;
          final ordersInThisDay = completedOrdersInPeriod.where((order) {
            try {
              final orderDate = DateTime.parse(order.thoiGianCapNhatTrangThai!);
              return orderDate.year == day.year && orderDate.month == day.month && orderDate.day == day.day;
            } catch (e) {
              return false;
            }
          });
          dayRevenue = ordersInThisDay.fold(0.0, (sum, order) => sum + (order.tongCong ?? 0).toDouble());
          _chartDataRevenue[dayKey] = dayRevenue;
        }
      } else { // Quý - Monthly breakdown for the selected quarter
        final startMonth = _startDate!.month;
        final endMonth = _endDate!.month;
        // Ensure months are collected in order for the chart
        List<String> quarterMonths = [];
        for (int m = startMonth; m <= endMonth; m++) {
          final monthDate = DateTime(_startDate!.year, m, 1);
          // Only add months that are actually within the quarter's end date (e.g., Q4 goes into next year for calculation of end date)
          if (monthDate.isAfter(_endDate!)) break;
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

  // Formatter for average price (can have decimals)
  String _formatAveragePrice(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: amount < 1000 ? 2 : 0, // Show decimals for small amounts
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

  // Helper for generating pie chart sections
  List<PieChartSectionData> _getPieChartSections(Map<String, double> dataMap, double totalRevenue, {bool isBrandChart = true}) {
    List<Color> pieColors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.brown, Colors.indigo, Colors.cyan, Colors.deepOrange
    ];

    if (dataMap.isEmpty || totalRevenue == 0) { // Added check for totalRevenue == 0
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 100, // Represent 100% of no data
          title: 'Không có dữ liệu',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          // Removed badgeRadian
        ),
      ];
    }

    // Sort entries by revenue descending
    final sortedEntries = dataMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Show top N slices and group the rest as 'Other'
    const int maxSlices = 5; // Adjust as needed
    double otherRevenue = 0.0;
    List<MapEntry<String, double>> topSlices = [];

    if (sortedEntries.length > maxSlices) {
      topSlices = sortedEntries.sublist(0, maxSlices -1); // leave one slot for 'Other'
      otherRevenue = sortedEntries.sublist(maxSlices -1).fold(0.0, (sum, entry) => sum + entry.value);
    } else {
      topSlices = sortedEntries;
    }


    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    for (var entry in topSlices) {
      final percentage = (entry.value / totalRevenue * 100).toStringAsFixed(1);
      sections.add(
        PieChartSectionData(
          color: pieColors[colorIndex % pieColors.length],
          value: entry.value,
          title: '${entry.key}\n${percentage}%',
          radius: 80,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: null, // No badge for simplicity
          // Removed badgeRadian
        ),
      );
      colorIndex++;
    }

    if (otherRevenue > 0) {
      final otherPercentage = (otherRevenue / totalRevenue * 100).toStringAsFixed(1);
      sections.add(
        PieChartSectionData(
          color: Colors.grey, // Consistent color for 'Other'
          value: otherRevenue,
          title: 'Khác\n${otherPercentage}%',
          radius: 80,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: null,
          // Removed badgeRadian
        ),
      );
    }

    return sections;
  }

@override
Widget build(BuildContext context) {
  final Color appBarTop = const Color(0xFF534b0d);
  final Color appBarBottom = const Color(0xFFb2a41f);
  final Color cardBgColor = const Color(0xFFFAFAFA);

  // Filtered products for display
  final List<MapEntry<String, double>> filteredProducts = _revenueByProduct.entries
      .where((entry) {
        if (_selectedProductBrandFilter == 'Tất cả thương hiệu') {
          return true;
        }
        // Find the brand for the product to filter from the _allDSHangItems list
        // Ensure _allDSHangItems is not empty before trying to find
        if (_allDSHangItems.isEmpty) return false;

        final correspondingItem = _allDSHangItems.firstWhere(
          (dsItem) => dsItem.tenSanPham == entry.key, // Assuming tenSanPham is unique per product
          orElse: () => DSHangModel(), // Return empty model if not found
        );
        return correspondingItem.thuongHieu == _selectedProductBrandFilter;
      })
      .toList();

  // Sort products by revenue descending
  filteredProducts.sort((a, b) => b.value.compareTo(a.value));

  // Calculate total revenue for filtered products to get correct percentages for product pie chart
  final double totalFilteredProductRevenue = filteredProducts.fold(0.0, (sum, entry) => sum + entry.value);

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

                _buildSectionTitle('Biểu đồ doanh thu theo thời gian'),
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
                                        toY: entry.value / 1000000, 
                                        color: Colors.indigoAccent,
                                        width: _selectedPeriodType == 'Tháng' ? 10 : 20, 
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
                                          String labelKey = _chartDataRevenue.keys.toList()[index];
                                          if (_selectedPeriodType == 'Tháng') {
                                            // Daily breakdown for the selected month
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(DateFormat('dd').format(DateTime.parse(labelKey))), // Just the day
                                            );
                                          }
                                          // Monthly breakdown for the selected quarter
                                          return SideTitleWidget(
                                            axisSide: meta.axisSide,
                                            child: Text(DateFormat('MM/yy').format(DateTime.parse('$labelKey-01'))), // Month/Year
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
                                      getTitlesWidget: (value, meta) => Text('${value.toInt()} tr'), 
                                      reservedSize: 40,
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: true, drawVerticalLine: false),
                                alignment: BarChartAlignment.spaceAround,
                                maxY: (_chartDataRevenue.values.isNotEmpty ? (_chartDataRevenue.values.reduce((a, b) => a > b ? a : b) / 1000000) * 1.2 : 1), // Dynamic max Y, min 1 for empty
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
                            children: [
                              // Pie Chart for Revenue by Brand
                              SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: _getPieChartSections(_revenueByBrand, _totalRevenue, isBrandChart: true),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                          // _touchedIndex = -1;
                                          return;
                                        }
                                        // Handle touch events if needed, e.g., show tooltip
                                      });
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._revenueByBrand.entries.map((entry) {
                                final brand = entry.key;
                                final revenue = entry.value;
                                final totalUnits = _totalQuantitySoldByBrand[brand] ?? 0.0;
                                final avgPrice = _avgPriceByBrand[brand] ?? 0.0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              brand,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Doanh thu: ${_formatCurrency(revenue)}',
                                                style: const TextStyle(color: Colors.green),
                                              ),
                                              Text(
                                                'Tổng SP bán: ${totalUnits.toInt()} sp',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                              Text(
                                                'Giá TB: ${_formatAveragePrice(avgPrice)}',
                                                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (_revenueByBrand.keys.last != brand) const Divider(), // Add divider between items
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                const SizedBox(height: 24),

                _buildSectionTitle('Doanh thu theo sản phẩm'),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Brand Filter Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedProductBrandFilter,
                          decoration: const InputDecoration(
                            labelText: 'Lọc theo thương hiệu',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: _availableBrandsForProductFilter.map((brand) {
                            return DropdownMenuItem(value: brand, child: Text(brand));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProductBrandFilter = value;
                              });
                              // No need to recalculate _calculateStats(), just rebuilds with filter
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Pie Chart for Revenue by Product
                        totalFilteredProductRevenue == 0
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Không có dữ liệu sản phẩm để hiển thị biểu đồ.'),
                              ))
                            : SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: _getPieChartSections(
                                      Map.fromIterable(filteredProducts, key: (e) => e.key, value: (e) => e.value),
                                      totalFilteredProductRevenue,
                                      isBrandChart: false,
                                    ),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                          // _touchedIndex = -1;
                                          return;
                                        }
                                        // Handle touch events if needed, e.g., show tooltip
                                      });
                                    }),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 16),
                        filteredProducts.isEmpty
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Không có dữ liệu sản phẩm để hiển thị với bộ lọc này.'),
                              ))
                            : Column(
                                children: filteredProducts.map((entry) {
                                  final productName = entry.key;
                                  final revenue = entry.value;
                                  final totalUnits = _totalQuantitySoldByProduct[productName] ?? 0.0;
                                  final avgPrice = _avgPriceByProduct[productName] ?? 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                productName,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Doanh thu: ${_formatCurrency(revenue)}',
                                                  style: const TextStyle(color: Colors.green),
                                                ),
                                                Text(
                                                  'Tổng SP bán: ${totalUnits.toInt()} sp',
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                ),
                                                Text(
                                                  'Giá TB: ${_formatAveragePrice(avgPrice)}',
                                                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (filteredProducts.last.key != productName) const Divider(), // Add divider between items
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                ), // Closing bracket for Card widget
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
                                  DataCell(Text(order.tenKhachHang2 ?? 'N/A')),
                                  DataCell(Text(order.nguoiTao ?? 'N/A')), 
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
                _buildDetailRow('Khách hàng:', order.tenKhachHang2 ?? 'N/A'),
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
                          // Use soLuongYeuCau for quantity in details display
                          '  - ${detail.tenHang ?? 'N/A'} (SL: ${detail.soLuongYeuCau ?? 'N/A'} ${detail.donViTinh ?? ''}) - ${_formatCurrency((detail.thanhTien ?? 0).toDouble())}',
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