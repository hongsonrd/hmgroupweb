// lib/inactive_customers_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:flutter/services.dart';
class InactiveCustomersScreen extends StatefulWidget {
  @override
  _InactiveCustomersScreenState createState() => _InactiveCustomersScreenState();
}

class _InactiveCustomersScreenState extends State<InactiveCustomersScreen> {
  final DBHelper _dbHelper = DBHelper();
  
  // Filter options
  String? _selectedStaff;
  List<String> _staffList = ['Tất cả'];
  int _selectedDuration = 30; // Default to 30 days
  final List<int> _durationOptions = [30, 90, 180, 360];
  
  // Data
  List<InactiveCustomer> _inactiveCustomers = [];
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadStaffList();
    _loadInactiveCustomers();
  }

  Future<void> _loadStaffList() async {
    try {
      // Get all orders to extract unique staff members from nguoiTao field
      final allOrders = await _dbHelper.getAllDonHang();
      final staffSet = <String>{};
      
      for (var order in allOrders) {
        if (order.nguoiTao != null && order.nguoiTao!.trim().isNotEmpty) {
          staffSet.add(order.nguoiTao!.trim());
        }
      }
      
      setState(() {
        _staffList = ['Tất cả', ...staffSet.toList()..sort()];
        _selectedStaff = 'Tất cả';
      });
      
      print('Staff list loaded: ${_staffList.length} members');
    } catch (e) {
      print('Error loading staff list: $e');
    }
  }

  DateTime? _parseDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return null;
    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      print('Error parsing DateTime: $dateTimeString - $e');
      return null;
    }
  }

  // Safe conversion of int? to double for calculations
  double _safeToDouble(int? value) {
    return value?.toDouble() ?? 0.0;
  }

  Future<void> _loadInactiveCustomers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all completed orders
      final allOrders = await _dbHelper.getAllDonHang();
      print('Total orders: ${allOrders.length}');
      
      final completedOrders = allOrders.where((order) => 
        order.trangThai == 'Hoàn thành' && 
        order.tenKhachHang != null && 
        order.tenKhachHang!.trim().isNotEmpty
      ).toList();
      
      print('Completed orders: ${completedOrders.length}');

      if (completedOrders.isEmpty) {
        setState(() {
          _inactiveCustomers = [];
        });
        return;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: _selectedDuration));
      print('Cutoff date: $cutoffDate');
      
      // Group orders by customer name
      Map<String, List<DonHangModel>> customerOrders = {};
      
      for (var order in completedOrders) {
        final customerName = order.tenKhachHang!.trim();
        if (customerName.isNotEmpty) {
          if (!customerOrders.containsKey(customerName)) {
            customerOrders[customerName] = [];
          }
          customerOrders[customerName]!.add(order);
        }
      }

      print('Unique customers: ${customerOrders.length}');

      List<InactiveCustomer> inactiveList = [];

      // Process each customer
      for (var entry in customerOrders.entries) {
        final customerName = entry.key;
        final orders = entry.value;
        
        // Sort orders by completion date (most recent first)
        orders.sort((a, b) {
          final dateA = _parseDateTime(a.thoiGianCapNhatTrangThai);
          final dateB = _parseDateTime(b.thoiGianCapNhatTrangThai);
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

        final lastOrder = orders.first;
        final lastOrderDate = _parseDateTime(lastOrder.thoiGianCapNhatTrangThai);
        
        // Apply staff filter - check if any order from this customer was created by selected staff
        bool matchesStaffFilter = true;
        if (_selectedStaff != null && _selectedStaff != 'Tất cả') {
          matchesStaffFilter = orders.any((order) => order.nguoiTao == _selectedStaff);
        }
        
        // Check if customer is inactive and matches staff filter
        if (matchesStaffFilter && lastOrderDate != null && lastOrderDate.isBefore(cutoffDate)) {
          final daysSinceLastOrder = DateTime.now().difference(lastOrderDate).inDays;
          
          // Find the staff member who created the most recent order
          final lastOrderStaff = lastOrder.nguoiTao ?? 'Unknown';
          
          inactiveList.add(InactiveCustomer(
            customerName: customerName,
            lastOrderDate: lastOrderDate,
            daysSinceLastOrder: daysSinceLastOrder,
            totalOrders: orders.length,
            lastOrderId: lastOrder.soPhieu ?? '', // soPhieu is String
            lastOrderValue: _safeToDouble(lastOrder.tongTien), // Safe conversion
            lastOrderStaff: lastOrderStaff, // Add staff info
          ));
        }
      }

      print('Inactive customers found: ${inactiveList.length}');

      // Sort by days since last order (ascending - lowest first)
      inactiveList.sort((a, b) => (a.daysSinceLastOrder ?? 0).compareTo(b.daysSinceLastOrder ?? 0));

      setState(() {
        _inactiveCustomers = inactiveList;
      });
    } catch (e) {
      print('Error loading inactive customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToPDF() async {
  setState(() {
    _isExporting = true;
  });

  try {
    final pdf = pw.Document();
    
    // Load Vietnamese-compatible font
    final fontData = await rootBundle.load("assets/fonts/RobotoCondensed-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    
    // Split customers into chunks to avoid too many pages error
    const int customersPerPage = 25; // Reduced to ensure it fits on page
    final chunks = <List<InactiveCustomer>>[];
    
    for (int i = 0; i < _inactiveCustomers.length; i += customersPerPage) {
      chunks.add(_inactiveCustomers.skip(i).take(customersPerPage).toList());
    }

    // Add header page with summary
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                alignment: pw.Alignment.center,
                margin: const pw.EdgeInsets.only(bottom: 30),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'BÁO CÁO KHÁCH HÀNG KHÔNG HOẠT ĐỘNG',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(font: ttf, fontSize: 14),
                    ),
                    pw.Text(
                      'Bộ lọc: Không mua hàng trong $_selectedDuration ngày qua',
                      style: pw.TextStyle(font: ttf, fontSize: 14),
                    ),
                    pw.Text(
                      'Nhân viên: ${_selectedStaff ?? 'Tất cả'}',
                      style: pw.TextStyle(font: ttf, fontSize: 14),
                    ),
                    pw.Text(
                      'Tổng số khách hàng: ${_inactiveCustomers.length}',
                      style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              
              // Summary statistics
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 30),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'THỐNG KÊ TỔNG QUAN',
                      style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPDFSummaryItem('Hơn 30 ngày', _inactiveCustomers.where((c) => (c.daysSinceLastOrder ?? 0) > 30).length.toString(), ttf),
                        _buildPDFSummaryItem('Hơn 90 ngày', _inactiveCustomers.where((c) => (c.daysSinceLastOrder ?? 0) > 90).length.toString(), ttf),
                        _buildPDFSummaryItem('Hơn 180 ngày', _inactiveCustomers.where((c) => (c.daysSinceLastOrder ?? 0) > 180).length.toString(), ttf),
                        _buildPDFSummaryItem('Hơn 1 năm', _inactiveCustomers.where((c) => (c.daysSinceLastOrder ?? 0) > 360).length.toString(), ttf),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Add data pages using MultiPage for better table handling
    if (chunks.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(15),
          header: (context) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Text(
              'DANH SÁCH KHÁCH HÀNG KHÔNG HOẠT ĐỘNG - Trang ${context.pageNumber}',
              style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          build: (pw.Context context) {
            return [
              // Create one big table with all data
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Customer name
                  1: const pw.FlexColumnWidth(2), // Last order date
                  2: const pw.FlexColumnWidth(1.5), // Days since
                  3: const pw.FlexColumnWidth(1.5), // Total orders
                  4: const pw.FlexColumnWidth(2), // Last order value
                  5: const pw.FlexColumnWidth(2), // Last order staff
                  6: const pw.FlexColumnWidth(2), // Last order ID
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildPDFTableCell('Tên khách hàng', ttf, isHeader: true),
                      _buildPDFTableCell('Đơn hàng cuối', ttf, isHeader: true),
                      _buildPDFTableCell('Số ngày', ttf, isHeader: true),
                      _buildPDFTableCell('Tổng đơn', ttf, isHeader: true),
                      _buildPDFTableCell('Giá trị cuối', ttf, isHeader: true),
                      _buildPDFTableCell('NV đơn cuối', ttf, isHeader: true),
                      _buildPDFTableCell('Số phiếu cuối', ttf, isHeader: true),
                    ],
                  ),
                  // All data rows
                  ..._inactiveCustomers.map((customer) => pw.TableRow(
                    children: [
                      _buildPDFTableCell(customer.customerName, ttf),
                      _buildPDFTableCell(customer.lastOrderDate != null 
                        ? DateFormat('dd/MM/yyyy').format(customer.lastOrderDate!) 
                        : '', ttf),
                      _buildPDFTableCell('${customer.daysSinceLastOrder ?? 0}', ttf),
                      _buildPDFTableCell(customer.totalOrders.toString(), ttf),
                      _buildPDFTableCell(customer.lastOrderValue != null 
                        ? NumberFormat('#,###').format(customer.lastOrderValue!.toInt()) 
                        : '0', ttf),
                      _buildPDFTableCell(customer.lastOrderStaff, ttf),
                      _buildPDFTableCell(customer.lastOrderId, ttf),
                    ],
                  )).toList(),
                ],
              ),
            ];
          },
        ),
      );
    }

    // Save and share PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/khach_hang_khong_hoat_dong_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Báo cáo khách hàng không hoạt động',
      text: 'Báo cáo khách hàng không hoạt động ngày ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
    );

  } catch (e) {
    print('Error exporting PDF: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi xuất PDF: $e')),
    );
  } finally {
    setState(() {
      _isExporting = false;
    });
  }
}

pw.Widget _buildPDFSummaryItem(String label, String value, pw.Font font) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          value, 
          style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold)
        ),
        pw.Text(
          label, 
          style: pw.TextStyle(font: font, fontSize: 10)
        ),
      ],
    ),
  );
}

pw.Widget _buildPDFTableCell(String text, pw.Font font, {bool isHeader = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: isHeader ? 10 : 9,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      textAlign: pw.TextAlign.center,
      maxLines: isHeader ? 2 : 1,
      overflow: pw.TextOverflow.clip,
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khách hàng không hoạt động'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        actions: [
          if (_inactiveCustomers.isNotEmpty)
            IconButton(
              onPressed: _isExporting ? null : _exportToPDF,
              icon: _isExporting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.share),
              tooltip: 'Xuất PDF và chia sẻ',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildControls(),
          _buildSummaryCard(),
          Expanded(child: _buildCustomersList()),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          // First row: Duration and Staff filters
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: _selectedDuration,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian không mua hàng',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _durationOptions
                      .map((duration) => DropdownMenuItem(
                            value: duration,
                            child: Text('Hơn $duration ngày'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedDuration = value;
                      });
                      _loadInactiveCustomers();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedStaff,
                  decoration: const InputDecoration(
                    labelText: 'Nhân viên (Người tạo đơn)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _staffList
                      .map((staff) => DropdownMenuItem(
                            value: staff,
                            child: Text(staff),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStaff = value;
                    });
                    _loadInactiveCustomers();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row: Refresh button
          Row(
            children: [
              Expanded(child: Container()), // Spacer
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadInactiveCustomers,
                icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
                label: const Text('Làm mới'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final over30Days = _inactiveCustomers.where((c) => (c.daysSinceLastOrder ?? 0) > 30).length;
    final over90Days = _inactiveCustomers.where((c) => (c.daysSinceLastOrder ?? 0) > 90).length;
    final over180Days = _inactiveCustomers.where((c) => (c.daysSinceLastOrder ?? 0) > 180).length;
    final over360Days = _inactiveCustomers.where((c) => (c.daysSinceLastOrder ?? 0) > 360).length;
    final totalInactive = _inactiveCustomers.length;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng quan khách hàng không hoạt động${_selectedStaff != 'Tất cả' ? ' - NV: $_selectedStaff' : ''} (sắp xếp từ ít ngày nhất)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSummaryItem('Tổng số KH', totalInactive.toString(), Colors.red[800]!),
                    const SizedBox(width: 16),
                    _buildSummaryItem('Hơn 30 ngày', over30Days.toString(), Colors.orange[600]!),
                    const SizedBox(width: 16),
                    _buildSummaryItem('Hơn 90 ngày', over90Days.toString(), Colors.orange[700]!),
                    const SizedBox(width: 16),
                    _buildSummaryItem('Hơn 180 ngày', over180Days.toString(), Colors.red[600]!),
                    const SizedBox(width: 16),
                    _buildSummaryItem('Hơn 1 năm', over360Days.toString(), Colors.red[800]!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCustomersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inactiveCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_very_satisfied, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Không có khách hàng không hoạt động!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Tất cả khách hàng${_selectedStaff != 'Tất cả' ? ' của $_selectedStaff' : ''} đều đã mua hàng trong $_selectedDuration ngày qua.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Danh sách khách hàng không hoạt động (${_inactiveCustomers.length} khách hàng)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                border: TableBorder.all(color: Colors.grey[300]!),
                headingRowColor: WidgetStateProperty.all(Colors.red[50]),
                columnSpacing: 12,
                columns: const [
                  DataColumn(label: Text('Tên khách hàng', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Đơn hàng cuối', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Số ngày không mua', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Tổng đơn hoàn thành', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Giá trị đơn cuối', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('NV đơn cuối', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Số phiếu cuối', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _inactiveCustomers.map((customer) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 250,
                        child: Text(
                          customer.customerName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(Text(
                      customer.lastOrderDate != null 
                        ? DateFormat('dd/MM/yyyy').format(customer.lastOrderDate!) 
                        : ''
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDaysBadgeColor(customer.daysSinceLastOrder ?? 0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${customer.daysSinceLastOrder} ngày',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(customer.totalOrders.toString())),
                    DataCell(Text(
                      customer.lastOrderValue != null 
                        ? NumberFormat('#,###').format(customer.lastOrderValue!.toInt())
                        : '0'
                    )),
                    DataCell(Text(customer.lastOrderStaff)),
                    DataCell(Text(customer.lastOrderId)),
                  ],
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDaysBadgeColor(int days) {
    if (days >= 360) return Colors.red[800]!;
    if (days >= 180) return Colors.red[600]!;
    if (days >= 90) return Colors.orange[700]!;
    return Colors.orange[600]!;
  }
}

// Updated data model to include staff information
class InactiveCustomer {
  final String customerName;
  final DateTime? lastOrderDate;
  final int? daysSinceLastOrder;
  final int totalOrders;
  final String lastOrderId; // soPhieu is String
  final double? lastOrderValue;
  final String lastOrderStaff; // Added staff info

  InactiveCustomer({
    required this.customerName,
    this.lastOrderDate,
    this.daysSinceLastOrder,
    required this.totalOrders,
    required this.lastOrderId,
    this.lastOrderValue,
    required this.lastOrderStaff,
  });
}