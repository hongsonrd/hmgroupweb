import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'db_helper.dart'; // Assuming this exists and has methods for kho, lohang, giaodichkho, dshang
import 'table_models.dart'; // Assuming GiaoDichKhoModel, LoHangModel, KhoModel, DSHangModel are here

// Helper class for displaying batch information with resolved names and dates
class BatchDataView {
  final LoHangModel batch;
  final String productName;
  final String warehouseName;
  final DateTime? expiryDate;
  final int? daysToExpiry;
  final DateTime? lastOutputDate;

  BatchDataView({
    required this.batch,
    required this.productName,
    required this.warehouseName,
    this.expiryDate,
    this.daysToExpiry,
    this.lastOutputDate,
  });
}

class HSXuHuongKHOScreen extends StatefulWidget {
  const HSXuHuongKHOScreen({Key? key}) : super(key: key);

  @override
  _HSXuHuongKHOScreenState createState() => _HSXuHuongKHOScreenState();
}

class _HSXuHuongKHOScreenState extends State<HSXuHuongKHOScreen> {
  final DBHelper _dbHelper = DBHelper();
  bool _isLoading = true;
  String _selectedPeriodValue = DateFormat('yyyy-MM').format(DateTime.now());
  List<String> _availableMonths = [];

  String? _selectedKhoId; // For KhoModel.khoHangID
  List<KhoModel> _availableWarehouses = [];

  String? _selectedProductId; // For DSHangModel.uid (maHangID)
  List<DSHangModel> _availableProducts = [];

  // Data stores from DB
  List<GiaoDichKhoModel> _allGiaoDichKhoMaster = [];
  List<LoHangModel> _allLoHangMaster = [];
  List<KhoModel> _allKhoMaster = [];
  List<DSHangModel> _allDSHangMaster = [];

  // Processed data for UI
  double _totalInputsQuantity = 0.0;
  double _totalOutputsQuantity = 0.0;
  int _inputTxnCount = 0;
  int _outputTxnCount = 0;
  Map<int, _DailyInOut> _dailyInOutData = {};

  double _totalCurrentStock = 0.0;
  List<BatchDataView> _expiringBatches = [];
  List<BatchDataView> _slowMovingBatches = [];

  final int _expiryWarningDays = 90;
  final int _slowMovingThresholdDays = 90;

  @override
  void initState() {
    super.initState();
    _generateAvailableMonths();
    _loadInitialData();
  }

  void _generateAvailableMonths() {
    final now = DateTime.now();
    _availableMonths.clear();
    for (int i = -12; i <= 3; i++) { // Last 12 months, current, next 3
      _availableMonths.add(DateFormat('yyyy-MM').format(DateTime(now.year, now.month + i, 1)));
    }
    _availableMonths.sort((a, b) => b.compareTo(a));
    if (!_availableMonths.contains(_selectedPeriodValue)) {
      _selectedPeriodValue = _availableMonths.isNotEmpty ? _availableMonths.first : DateFormat('yyyy-MM').format(now);
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch master data needed for filters and lookups
      _allKhoMaster = await _dbHelper.getAllKho();
      _allDSHangMaster = await _dbHelper.getAllDSHang(); // Assuming DSHangModel and method exist

      _availableWarehouses = [KhoModel(khoHangID: null, tenKho: 'Tất cả Kho'), ..._allKhoMaster];
      _availableProducts = [DSHangModel(uid: null, tenSanPham: 'Tất cả Sản phẩm'), ..._allDSHangMaster];
      
      // Fetch transactional data once
      _allGiaoDichKhoMaster = await _dbHelper.getAllGiaoDichKho();
      _allLoHangMaster = await _dbHelper.getAllLoHang();

      await _processWarehouseData();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu ban đầu: $e')),
        );
      }
      print("Error loading initial data for Kho Screen: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processWarehouseData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _totalInputsQuantity = 0.0;
      _totalOutputsQuantity = 0.0;
      _inputTxnCount = 0;
      _outputTxnCount = 0;
      _dailyInOutData = {};
      _totalCurrentStock = 0.0;
      _expiringBatches = [];
      _slowMovingBatches = [];

      final selectedYear = int.parse(_selectedPeriodValue.split('-')[0]);
      final selectedMonth = int.parse(_selectedPeriodValue.split('-')[1]);
      final periodStartDate = DateTime(selectedYear, selectedMonth, 1);
      final periodEndDate = DateTime(selectedYear, selectedMonth + 1, 0, 23, 59, 59);

      List<LoHangModel> filteredLoHangSource = List.from(_allLoHangMaster);
      if (_selectedKhoId != null) {
        filteredLoHangSource = filteredLoHangSource.where((lh) => lh.khoHangID == _selectedKhoId).toList();
      }
      if (_selectedProductId != null) {
        filteredLoHangSource = filteredLoHangSource.where((lh) => lh.maHangID == _selectedProductId).toList();
      }
      final relevantLoHangIDs = filteredLoHangSource.map((lh) => lh.loHangID).toSet();

      List<GiaoDichKhoModel> periodTransactions = _allGiaoDichKhoMaster.where((gd) {
        if (gd.ngay == null) return false;
        try {
          final gdDate = DateFormat('yyyy-MM-dd').parse(gd.ngay!);
          bool isDateInRange = gdDate.isAfter(periodStartDate.subtract(const Duration(milliseconds:1))) &&
                               gdDate.isBefore(periodEndDate.add(const Duration(milliseconds:1)));
          if (!isDateInRange) return false;

          if ((_selectedKhoId != null || _selectedProductId != null)) {
             // If warehouse or product filters are active, transaction must be for a relevant batch
             // For period summary, we might sum all transactions in the period from selected warehouses/products.
             // Let's find the batch for this transaction.
             final transactionBatch = _allLoHangMaster.firstWhere((lh) => lh.loHangID == gd.loHangID, orElse: () => LoHangModel()); // Empty if not found
             bool matchesKho = _selectedKhoId == null || transactionBatch.khoHangID == _selectedKhoId;
             bool matchesProduct = _selectedProductId == null || transactionBatch.maHangID == _selectedProductId;
             return matchesKho && matchesProduct;
          }
          return true; // No warehouse/product filter, or transaction is not for specific item analysis yet
        } catch (e) {
          print("Error parsing GiaoDichKho date ${gd.ngay}: $e");
          return false;
        }
      }).toList();

      for (var gd in periodTransactions) {
        if (gd.soLuong == null) continue;
        final gdDate = DateFormat('yyyy-MM-dd').parse(gd.ngay!);
        final dayOfMonth = gdDate.day;

        _dailyInOutData.putIfAbsent(dayOfMonth, () => _DailyInOut());

        if (gd.trangThai == '+') {
          _totalInputsQuantity += gd.soLuong!;
          _inputTxnCount++;
          _dailyInOutData[dayOfMonth]!.input += gd.soLuong!;
        } else if (gd.trangThai == '-') {
          _totalOutputsQuantity += gd.soLuong!;
          _outputTxnCount++;
          _dailyInOutData[dayOfMonth]!.output += gd.soLuong!;
        }
      }

      // For stock status (total, expiring, slow-moving), use `filteredLoHangSource`
      for (var lh in filteredLoHangSource) {
        if (lh.soLuongHienTai != null) {
          _totalCurrentStock += lh.soLuongHienTai!;
        }

        final product = _allDSHangMaster.firstWhere(
            (ds) => ds.uid == lh.maHangID, 
            orElse: () => DSHangModel(tenSanPham: 'N/A', uid: lh.maHangID)
        );
        final productName = product.tenSanPham ?? 'N/A (${lh.maHangID})';

        final warehouse = _allKhoMaster.firstWhere(
            (k) => k.khoHangID == lh.khoHangID, 
            orElse: () => KhoModel(tenKho: 'N/A', khoHangID: lh.khoHangID)
        );
        final warehouseName = warehouse.tenKho ?? 'N/A (${lh.khoHangID})';

        if (lh.hanSuDung != null && lh.hanSuDung! > 0 && lh.ngayNhap != null && (lh.soLuongHienTai ?? 0) > 0) {
          try {
            DateTime entryDate = DateFormat('yyyy-MM-dd').parse(lh.ngayNhap!);
            DateTime expiryDate = DateTime(entryDate.year, entryDate.month + lh.hanSuDung!, entryDate.day);
            int daysToExpiry = expiryDate.difference(DateTime.now()).inDays;

            if (daysToExpiry <= _expiryWarningDays) {
              _expiringBatches.add(BatchDataView(
                batch: lh,
                productName: productName,
                warehouseName: warehouseName,
                expiryDate: expiryDate,
                daysToExpiry: daysToExpiry,
              ));
            }
          } catch (e) { print("Error parsing expiry for LoHang ${lh.loHangID}: $e");}
        }

        if ((lh.soLuongHienTai ?? 0) > 0) {
          DateTime? lastOutputDate;
          _allGiaoDichKhoMaster
              .where((gd) => gd.loHangID == lh.loHangID && gd.trangThai == '-' && gd.ngay != null)
              .forEach((gd) {
            try {
              DateTime gdDate = DateFormat('yyyy-MM-dd').parse(gd.ngay!);
              if (lastOutputDate == null || gdDate.isAfter(lastOutputDate!)) {
                lastOutputDate = gdDate;
              }
            } catch (e) {/* ignore */}
          });
          
          bool isSlowMoving = false;
          DateTime referenceDateForSlowMoving = DateTime.now();
          if (lh.ngayNhap != null) {
             try {
                referenceDateForSlowMoving = DateFormat('yyyy-MM-dd').parse(lh.ngayNhap!);
             } catch(e) {/* ignore */}
          }

          if (lastOutputDate == null) {
              if (DateTime.now().difference(referenceDateForSlowMoving).inDays > _slowMovingThresholdDays) {
                  isSlowMoving = true;
              }
          } else {
              if (DateTime.now().difference(lastOutputDate!).inDays > _slowMovingThresholdDays) {
                  isSlowMoving = true;
              }
          }

          if (isSlowMoving) {
            _slowMovingBatches.add(BatchDataView(
              batch: lh,
              productName: productName,
              warehouseName: warehouseName,
              lastOutputDate: lastOutputDate,
            ));
          }
        }
      }
      _expiringBatches.sort((a,b) => (a.daysToExpiry ?? _expiryWarningDays + 1).compareTo(b.daysToExpiry ?? _expiryWarningDays + 1));
      _slowMovingBatches.sort((a,b) {
          final aDate = a.lastOutputDate ?? (a.batch.ngayNhap != null ? DateFormat('yyyy-MM-dd').parse(a.batch.ngayNhap!) : DateTime.fromMillisecondsSinceEpoch(0));
          final bDate = b.lastOutputDate ?? (b.batch.ngayNhap != null ? DateFormat('yyyy-MM-dd').parse(b.batch.ngayNhap!) : DateTime.fromMillisecondsSinceEpoch(0));
          return aDate.compareTo(bDate);
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý dữ liệu kho: $e')),
        );
      }
      print("Error processing warehouse data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatQuantity(double? qty) {
      if (qty == null) return "0";
      return NumberFormat("#,##0.##", "vi_VN").format(qty); // Allow decimals
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xu hướng Kho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadInitialData, // Refresh all data
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
                  _buildFilterSection(),
                  const SizedBox(height: 20),
                  _buildPeriodSummarySection(),
                  const SizedBox(height: 20),
                  _buildDailyActivityChartSection(),
                  const SizedBox(height: 20),
                  _buildCurrentStockOverviewSection(),
                  const SizedBox(height: 20),
                  _buildExpiringBatchesSection(),
                  const SizedBox(height: 20),
                  _buildSlowMovingStockSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bộ lọc:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedPeriodValue,
              decoration: const InputDecoration(labelText: 'Chọn Kỳ (Tháng/Năm)', border: OutlineInputBorder()),
              items: _availableMonths.map((month) {
                return DropdownMenuItem(value: month, child: Text(month));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPeriodValue = value;
                  });
                  _processWarehouseData();
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              value: _selectedKhoId,
              decoration: const InputDecoration(labelText: 'Chọn Kho', border: OutlineInputBorder()),
              items: _availableWarehouses.map((kho) {
                return DropdownMenuItem(value: kho.khoHangID, child: Text(kho.tenKho ?? 'N/A'));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedKhoId = value;
                });
                _processWarehouseData();
              },
            ),
            const SizedBox(height: 10),
             DropdownButtonFormField<String?>(
              value: _selectedProductId,
              decoration: const InputDecoration(labelText: 'Chọn Sản phẩm', border: OutlineInputBorder()),
              items: _availableProducts.map((prod) {
                return DropdownMenuItem(value: prod.uid, child: Text(prod.tenSanPham ?? 'N/A'));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                });
                _processWarehouseData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSummarySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tổng quan Kỳ: $_selectedPeriodValue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildSummaryRow('Tổng Lượng Nhập:', '${_formatQuantity(_totalInputsQuantity)} (${_formatQuantity(_inputTxnCount.toDouble())} GD)'),
            _buildSummaryRow('Tổng Lượng Xuất:', '${_formatQuantity(_totalOutputsQuantity)} (${_formatQuantity(_outputTxnCount.toDouble())} GD)'),
            _buildSummaryRow('Thay đổi tồn kho:', _formatQuantity(_totalInputsQuantity - _totalOutputsQuantity), isBold: true),
          ],
        ),
      ),
    );
  }

   Widget _buildDailyActivityChartSection() {
    if (_dailyInOutData.isEmpty) {
      return Card(
        elevation: 2,
        child: Container(
          height: 250,
          padding: const EdgeInsets.all(16.0),
          child: const Center(child: Text('Không có dữ liệu giao dịch cho kỳ này.')),
        ),
      );
    }

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    List<int> sortedDays = _dailyInOutData.keys.toList()..sort();

    for (int day in sortedDays) {
      final data = _dailyInOutData[day]!;
      if (data.input > maxY) maxY = data.input;
      if (data.output > maxY) maxY = data.output;

      barGroups.add(
        BarChartGroupData(
          x: day,
          barRods: [
            BarChartRodData(toY: data.input, color: Colors.green, width: 7, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: data.output, color: Colors.red, width: 7, borderRadius: BorderRadius.circular(2)),
          ],
        ),
      );
    }
    maxY = (maxY * 1.2).roundToDouble(); 
    if (maxY < 10) maxY = 10; // Minimum maxY for better visualization if values are too small

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hoạt động Nhập/Xuất hàng ngày', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 12), Text(" Nhập"), SizedBox(width: 10),
                  Icon(Icons.circle, color: Colors.red, size: 12), Text(" Xuất"),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    barGroups: barGroups,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 0 ? maxY/5 : 1), // Dynamic interval
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                             // Show fewer labels if many days
                            if (sortedDays.length > 15 && value.toInt() % 2 != 0 && value.toInt() != sortedDays.last && value.toInt() != sortedDays.first) return const Text('');
                            return Text(' ${value.toInt()}', style: const TextStyle(fontSize: 10));
                          },
                          reservedSize: 20,
                          interval: 1,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45, // Increased for better label fitting
                            getTitlesWidget: (value, meta) {
                               if (value == 0 && maxY > 0) return const Text('0', style: TextStyle(fontSize: 10)); // Ensure 0 is shown if data exists
                               if (value % (maxY > 0 ? (maxY/5).ceilToDouble() : 1) == 0 || value == maxY) {
                                   return Text(_formatQuantity(value), style: const TextStyle(fontSize: 10));
                                }
                                return const Text('');
                            },
                           interval: maxY > 0 ? (maxY/5).ceilToDouble() : 1, // Dynamic interval
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }


  Widget _buildCurrentStockOverviewSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng quan Tồn Kho Hiện Tại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
             _buildSummaryRow(
              'Tổng lượng tồn hiện tại:',
              _formatQuantity(_totalCurrentStock),
              subText: (_selectedKhoId == null && _selectedProductId == null)
                  ? '(Tất cả kho, tất cả SP)'
                  : (_selectedKhoId != null && _selectedProductId != null)
                      ? '(${_availableWarehouses.firstWhere((k) => k.khoHangID == _selectedKhoId, orElse: () => KhoModel(tenKho: '')).tenKho}, ${_availableProducts.firstWhere((p) => p.uid == _selectedProductId, orElse: () => DSHangModel(tenSanPham: '')).tenSanPham})'
                      : _selectedKhoId != null
                          ? '(${_availableWarehouses.firstWhere((k) => k.khoHangID == _selectedKhoId, orElse: () => KhoModel(tenKho: '')).tenKho}, tất cả SP)'
                          : '(Tất cả kho, ${_availableProducts.firstWhere((p) => p.uid == _selectedProductId, orElse: () => DSHangModel(tenSanPham: '')).tenSanPham})',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringBatchesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lô Sắp Hết Hạn (trong vòng $_expiryWarningDays ngày)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _expiringBatches.isEmpty
                ? const Text('Không có lô nào sắp hết hạn theo bộ lọc.')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 15,
                      columns: const [
                        DataColumn(label: Text('Sản phẩm')),
                        DataColumn(label: Text('Lô ID')),
                        DataColumn(label: Text('Kho')),
                        DataColumn(label: Text('SL Hiện Tại')),
                        DataColumn(label: Text('Ngày Nhập')),
                        DataColumn(label: Text('Ngày Hết Hạn')),
                        DataColumn(label: Text('Còn (ngày)')),
                      ],
                      rows: _expiringBatches.map((b) {
                        return DataRow(cells: [
                          DataCell(Tooltip(message: b.productName, child: Text(_truncateString(b.productName, 20)))),
                          DataCell(Text(b.batch.loHangID ?? 'N/A')),
                          DataCell(Tooltip(message: b.warehouseName, child: Text(_truncateString(b.warehouseName,15)))),
                          DataCell(Text(_formatQuantity(b.batch.soLuongHienTai))),
                          DataCell(Text(_formatDate(b.batch.ngayNhap != null ? DateFormat('yyyy-MM-dd').parse(b.batch.ngayNhap!) : null))),
                          DataCell(Text(_formatDate(b.expiryDate), style: TextStyle(color: (b.daysToExpiry ?? _expiryWarningDays + 1) < 30 ? Colors.red : Colors.orange ))),
                          DataCell(Text('${b.daysToExpiry ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold, color: (b.daysToExpiry ?? _expiryWarningDays+1) < 30 ? Colors.red.shade700 : Colors.orange.shade700))),
                        ]);
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

 Widget _buildSlowMovingStockSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tồn Kho Chậm Luân Chuyển (không xuất > $_slowMovingThresholdDays ngày)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _slowMovingBatches.isEmpty
                ? const Text('Không có tồn kho chậm luân chuyển theo bộ lọc.')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 15,
                      columns: const [
                        DataColumn(label: Text('Sản phẩm')),
                        DataColumn(label: Text('Lô ID')),
                        DataColumn(label: Text('Kho')),
                        DataColumn(label: Text('SL Hiện Tại')),
                        DataColumn(label: Text('Ngày Nhập')),
                        DataColumn(label: Text('Lần Xuất Cuối')),
                      ],
                      rows: _slowMovingBatches.map((b) {
                        return DataRow(cells: [
                          DataCell(Tooltip(message: b.productName, child: Text(_truncateString(b.productName, 20)))),
                          DataCell(Text(b.batch.loHangID ?? 'N/A')),
                          DataCell(Tooltip(message: b.warehouseName, child: Text(_truncateString(b.warehouseName, 15)))),
                          DataCell(Text(_formatQuantity(b.batch.soLuongHienTai))),
                          DataCell(Text(_formatDate(b.batch.ngayNhap != null ? DateFormat('yyyy-MM-dd').parse(b.batch.ngayNhap!) : null))),
                          DataCell(Text(_formatDate(b.lastOutputDate), style: const TextStyle(color: Colors.blueGrey))),
                        ]);
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isBold = false, String? subText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
                Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
                if(subText != null && subText.isNotEmpty)
                    Text(subText, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  String _truncateString(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}

class _DailyInOut {
  double input = 0.0;
  double output = 0.0;
}

// Ensure you have db_helper.dart with at least these methods (or adapt names):
// class DBHelper {
//   Future<List<GiaoDichKhoModel>> getAllGiaoDichKho() async { /* ... */ return []; }
//   Future<List<LoHangModel>> getAllLoHang() async { /* ... */ return []; }
//   Future<List<KhoModel>> getAllKho() async { /* ... */ return []; }
//   Future<List<DSHangModel>> getAllDSHang() async { /* ... */ return []; } // For product names
// }

// Ensure table_models.dart contains GiaoDichKhoModel, LoHangModel, KhoModel, DSHangModel (with at least uid, tenSanPham)