// lib/hs_xuhuongkpi.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'hs_xuhuongkpiorder.dart';
class HSXuHuongKPIScreen extends StatefulWidget {
  @override
  _HSXuHuongKPIScreenState createState() => _HSXuHuongKPIScreenState();
}

class _HSXuHuongKPIScreenState extends State<HSXuHuongKPIScreen>
    with SingleTickerProviderStateMixin {
  final DBHelper _dbHelper = DBHelper();
  
  late TabController _tabController;
  
  // Period selection
  String _selectedPeriodType = 'Tháng';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _selectedQuarter = 1;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  
  // Staff filter
  String? _selectedStaff;
  List<String> _staffList = ['Tất cả'];
  
  // Customer KPI data
  List<StaffCustomerKPI> _staffKPIList = [];
  List<CustomerDetail> _customerDetails = [];
  
  // Transaction KPI data
  List<StaffTransactionKPI> _staffTransactionKPIList = [];
  List<TransactionDetail> _transactionDetails = [];
  
  bool _isLoading = false;

  // Period options
  final List<String> _periodTypes = ['Tháng', 'Quý', 'Năm'];
  final List<String> _monthNames = [
    'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
    'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
  ];
  final List<String> _quarterNames = ['Quý 1', 'Quý 2', 'Quý 3', 'Quý 4'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedQuarter = ((DateTime.now().month - 1) ~/ 3) + 1;
    _calculateDateRange();
    _loadStaffList();
    _loadKPIData();
  }

  void _calculateDateRange() {
    switch (_selectedPeriodType) {
      case 'Tháng':
        _startDate = DateTime(_selectedYear, _selectedMonth, 1);
        _endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59, 999);
        break;
      case 'Quý':
        int startMonth = (_selectedQuarter - 1) * 3 + 1;
        _startDate = DateTime(_selectedYear, startMonth, 1);
        _endDate = DateTime(_selectedYear, startMonth + 3, 0, 23, 59, 59, 999);
        break;
      case 'Năm':
        _startDate = DateTime(_selectedYear, 1, 1);
        _endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59, 999);
        break;
    }
  }

  // Helper method to parse thoiGianCapNhatTrangThai string to DateTime
  DateTime? _parseDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return null;
    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      print('Error parsing DateTime: $dateTimeString - $e');
      return null;
    }
  }

  List<int> _getYearOptions() {
    int currentYear = DateTime.now().year;
    List<int> years = [];
    for (int i = currentYear; i >= currentYear - 10; i--) {
      years.add(i);
    }
    return years;
  }

  Future<void> _loadStaffList() async {
    try {
      final allOrders = await _dbHelper.getAllDonHang();
      final allCustomers = await _dbHelper.getAllKhachHang();
      final staffSet = <String>{};
      
      // Get staff from orders
      for (var order in allOrders) {
        if (order.nguoiTao != null && order.nguoiTao!.isNotEmpty) {
          staffSet.add(order.nguoiTao!);
        }
      }
      
      // Get staff from customers
      for (var customer in allCustomers) {
        if (customer.nguoiDung != null && customer.nguoiDung!.isNotEmpty) {
          staffSet.add(customer.nguoiDung!);
        }
      }
      
      setState(() {
        _staffList = ['Tất cả', ...staffSet.toList()..sort()];
        _selectedStaff = 'Tất cả';
      });
    } catch (e) {
      print('Error loading staff list: $e');
    }
  }

  Future<void> _loadKPIData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadCustomerKPI();
      await _loadTransactionKPI();
    } catch (e) {
      print('Error loading KPI data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
Future<void> _loadCustomerKPI() async {
  try {
    // Get all customers created up to end date
    final allCustomers = await _dbHelper.getAllKhachHang();
    final eligibleCustomers = allCustomers.where((customer) {
      if (customer.ngayKhoiTao == null) return false;
      return customer.ngayKhoiTao!.isBefore(_endDate.add(Duration(days: 1)));
    }).toList();

    // Get all COMPLETED orders up to end date using thoiGianCapNhatTrangThai
    final allOrders = await _dbHelper.getAllDonHang();
    final allCompletedOrders = allOrders.where((order) {
      if (order.trangThai != 'Hoàn thành') return false;
      final parsedDate = _parseDateTime(order.thoiGianCapNhatTrangThai);
      if (parsedDate == null) return false;
      return parsedDate.isBefore(_endDate.add(Duration(days: 1)));
    }).toList();

    // Get all customer contacts for D2 calculation
    final allCustomerContacts = await _dbHelper.getAllKhachHangContact();

    // Calculate C1: Count unique customers with first completed order in selected period
    final uniqueC1Customers = <String, String>{}; // customerName -> staff
    
    // Group completed orders by customer to find first order
    final completedOrdersByCustomer = <String, List<dynamic>>{};
    
    for (var order in allCompletedOrders) {
      final customerName = order.tenKhachHang ?? order.tenKhachHang2 ?? '';
      if (customerName.isEmpty) continue;
      
      if (!completedOrdersByCustomer.containsKey(customerName)) {
        completedOrdersByCustomer[customerName] = [];
      }
      completedOrdersByCustomer[customerName]!.add(order);
    }

    // For each customer, find their first completed order and check if it's in the selected period
    for (var customerName in completedOrdersByCustomer.keys) {
      final customerOrders = completedOrdersByCustomer[customerName]!;
      
      // Sort orders by thoiGianCapNhatTrangThai to find the first one
      customerOrders.sort((a, b) {
        final dateA = _parseDateTime(a.thoiGianCapNhatTrangThai);
        final dateB = _parseDateTime(b.thoiGianCapNhatTrangThai);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });
      
      // Check if the first completed order is within the selected period
      final firstOrder = customerOrders.first;
      final firstOrderDate = _parseDateTime(firstOrder.thoiGianCapNhatTrangThai);
      if (firstOrderDate != null) {
        // Check if first order is within selected period
        bool isFirstOrderInPeriod = firstOrderDate.isAfter(_startDate.subtract(Duration(milliseconds: 1))) &&
                                   firstOrderDate.isBefore(_endDate.add(Duration(milliseconds: 1)));
        
        if (isFirstOrderInPeriod && firstOrder.nguoiTao != null && firstOrder.nguoiTao!.isNotEmpty) {
          uniqueC1Customers[customerName] = firstOrder.nguoiTao!;
        }
      }
    }

    // Calculate C2, D1, D2 - counting unique customers only
    final uniqueC2Customers = <String, String>{}; // customerName -> staff
    final uniqueD1Customers = <String, String>{}; // customerName -> staff
    final uniqueD2Customers = <String, String>{}; // customerName -> staff

    final customerDetailsMap = <String, CustomerDetail>{};

    for (var customer in eligibleCustomers) {
      final customerName = customer.tenDuAn ?? '';
      final staff = customer.nguoiDung ?? 'Unknown';

      if (customerName.isEmpty) continue;

      // Calculate C2 (customers with >= 3 completed orders)
      final matchingOrders = allCompletedOrders.where((order) {
        return (order.tenKhachHang != null && order.tenKhachHang!.contains(customerName)) ||
               (order.tenKhachHang2 != null && order.tenKhachHang2!.contains(customerName));
      }).toList();

      String displayStaff = staff;
      DateTime? latestOrderDate;
      
      if (matchingOrders.isNotEmpty) {
        matchingOrders.sort((a, b) {
          final dateA = _parseDateTime(a.thoiGianCapNhatTrangThai);
          final dateB = _parseDateTime(b.thoiGianCapNhatTrangThai);
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
        
        final orderCount = matchingOrders.length;
        final latestOrder = matchingOrders.first;
        final orderStaff = latestOrder.nguoiTao ?? staff;
        latestOrderDate = _parseDateTime(latestOrder.thoiGianCapNhatTrangThai);

        // Count unique C2 customers
        if (orderCount >= 3) {
          uniqueC2Customers[customerName] = orderStaff;
        }

        // Update display staff based on order history
        displayStaff = orderStaff;
      }

      // Override display staff if this customer is a C1 customer
      if (uniqueC1Customers.containsKey(customerName)) {
        displayStaff = uniqueC1Customers[customerName]!;
      }

      // Calculate D1: customer with non-blank kenhTiepCan
      bool isD1 = customer.kenhTiepCan != null && customer.kenhTiepCan!.trim().isNotEmpty;
      
      // Calculate D2: D1 + filled out info + contact record
      bool isD2 = false;
      if (isD1) {
        // Check if basic info is filled
        bool hasBasicInfo = (customer.tenDuAn != null && customer.tenDuAn!.trim().isNotEmpty) &&
                           (customer.soDienThoai != null && customer.soDienThoai!.trim().isNotEmpty) &&
                           (customer.phanLoai != null && customer.phanLoai!.trim().isNotEmpty);
        
        if (hasBasicInfo) {
          // Check if there's at least one contact record with matching boPhan
          bool hasContactRecord = allCustomerContacts.any((contact) => 
            contact.boPhan != null && 
            customer.uid != null && 
            contact.boPhan == customer.uid
          );
          
          isD2 = hasContactRecord;
        }
      }

      // Count unique D1 and D2 customers
      if (isD1) {
        uniqueD1Customers[customerName] = displayStaff;
      }
      if (isD2) {
        uniqueD2Customers[customerName] = displayStaff;
      }

      // Create customer detail
      customerDetailsMap[customerName] = CustomerDetail(
        customerName: customerName,
        customerType: customer.phanLoai ?? '',
        orderCount: matchingOrders.length,
        lastOrderDate: latestOrderDate,
        assignedStaff: displayStaff,
        isC1: uniqueC1Customers.containsKey(customerName),
        isC2: uniqueC2Customers.containsKey(customerName),
        isD1: uniqueD1Customers.containsKey(customerName),
        isD2: uniqueD2Customers.containsKey(customerName),
        phone: customer.soDienThoai ?? '',
        contactChannel: customer.kenhTiepCan ?? '',
      );
    }

    // Apply staff filter to customer details first
    List<CustomerDetail> filteredCustomerDetails = customerDetailsMap.values.toList();

    if (_selectedStaff != null && _selectedStaff != 'Tất cả') {
      filteredCustomerDetails = filteredCustomerDetails.where((detail) => detail.assignedStaff == _selectedStaff).toList();
    }

    // Calculate staff KPI from filtered customer details
    final staffKPIMap = <String, StaffCustomerKPI>{};

    // Group filtered customers by staff
    final customersByStaff = <String, List<CustomerDetail>>{};
    for (var customer in filteredCustomerDetails) {
      if (!customersByStaff.containsKey(customer.assignedStaff)) {
        customersByStaff[customer.assignedStaff] = [];
      }
      customersByStaff[customer.assignedStaff]!.add(customer);
    }

    // Calculate KPI for each staff from their filtered customers
    for (var entry in customersByStaff.entries) {
      final staff = entry.key;
      final customers = entry.value;
      
      staffKPIMap[staff] = StaffCustomerKPI(
        staffName: staff,
        c1Count: customers.where((c) => c.isC1).length,
        c2Count: customers.where((c) => c.isC2).length,
        d1Count: customers.where((c) => c.isD1).length,
        d2Count: customers.where((c) => c.isD2).length,
        doanhThuTruocThue: 0.0,
        doanhThuHoaDon: 0.0,
      );
    }

    // Calculate revenue for each staff from completed orders within selected period
    final completedOrdersInPeriod = allOrders.where((order) {
      if (order.trangThai != 'Hoàn thành') return false;
      if (order.nguoiTao == null || order.nguoiTao!.isEmpty) return false;
      final parsedDate = _parseDateTime(order.thoiGianCapNhatTrangThai);
      if (parsedDate == null) return false;
      return parsedDate.isAfter(_startDate.subtract(Duration(milliseconds: 1))) &&
             parsedDate.isBefore(_endDate.add(Duration(milliseconds: 1)));
    }).toList();

    // Apply staff filter to revenue calculation
    List<dynamic> filteredOrdersInPeriod = completedOrdersInPeriod;
    if (_selectedStaff != null && _selectedStaff != 'Tất cả') {
      filteredOrdersInPeriod = completedOrdersInPeriod.where((order) => order.nguoiTao == _selectedStaff).toList();
    }

    // Calculate revenue by staff from filtered orders
    for (var order in filteredOrdersInPeriod) {
      final staff = order.nguoiTao!;
      if (staffKPIMap.containsKey(staff)) {
        // Add tongTien to doanhThuTruocThue
        if (order.tongTien != null) {
          try {
            double tongTien = double.parse(order.tongTien.toString());
            staffKPIMap[staff]!.doanhThuTruocThue += tongTien;
          } catch (e) {
            print('Error parsing tongTien: ${order.tongTien}');
          }
        }
        
        // Add tongCong to doanhThuHoaDon
        if (order.tongCong != null) {
          try {
            double tongCong = double.parse(order.tongCong.toString());
            staffKPIMap[staff]!.doanhThuHoaDon += tongCong;
          } catch (e) {
            print('Error parsing tongCong: ${order.tongCong}');
          }
        }
      }
    }

    // Get final filtered lists
    List<StaffCustomerKPI> filteredStaffKPI = staffKPIMap.values.toList();

    // Sort by total KPI descending
    filteredStaffKPI.sort((a, b) => (b.getTotalKPI()).compareTo(a.getTotalKPI()));
    
    // Sort customer details by order count descending
    filteredCustomerDetails.sort((a, b) => b.orderCount.compareTo(a.orderCount));

    setState(() {
      _staffKPIList = filteredStaffKPI;
      _customerDetails = filteredCustomerDetails;
    });

  } catch (e) {
    print('Error loading customer KPI: $e');
  }
}

  Future<void> _loadTransactionKPI() async {
    try {
      // Get all customers created up to end date for L1/L2 (D1/D2)
      final allCustomers = await _dbHelper.getAllKhachHang();
      final eligibleCustomers = allCustomers.where((customer) {
        if (customer.ngayKhoiTao == null) return false;
        return customer.ngayKhoiTao!.isBefore(_endDate.add(Duration(days: 1)));
      }).toList();

      // Get all customer contacts for D2/L2 calculation
      final allCustomerContacts = await _dbHelper.getAllKhachHangContact();

      // Get ALL orders for checking quote history using thoiGianCapNhatTrangThai
      final allOrders = await _dbHelper.getAllDonHang();
      
      // Get orders within selected period for L3, L4, L5 calculation
      final periodOrders = allOrders.where((order) {
        final parsedDate = _parseDateTime(order.thoiGianCapNhatTrangThai);
        if (parsedDate == null) return false;
        return parsedDate.isAfter(_startDate.subtract(Duration(milliseconds: 1))) &&
               parsedDate.isBefore(_endDate.add(Duration(milliseconds: 1)));
      }).toList();

      // Calculate transaction KPI for each staff
      final staffTransactionKPIMap = <String, StaffTransactionKPI>{};
      final transactionDetailsMap = <String, TransactionDetail>{};

      // Initialize staff KPI from both customers and orders
      final allStaff = <String>{};
      for (var customer in eligibleCustomers) {
        if (customer.nguoiDung != null && customer.nguoiDung!.isNotEmpty) {
          allStaff.add(customer.nguoiDung!);
        }
      }
      for (var order in periodOrders) {
        if (order.nguoiTao != null && order.nguoiTao!.isNotEmpty) {
          allStaff.add(order.nguoiTao!);
        }
      }

      for (var staff in allStaff) {
        staffTransactionKPIMap[staff] = StaffTransactionKPI(
          staffName: staff,
          l1Count: 0,
          l2Count: 0,
          l3Count: 0,
          l4Count: 0,
          l5Count: 0,
        );
      }

      // Calculate L1 and L2 (same as D1 and D2) - counting unique customers
      final uniqueL1Customers = <String, String>{}; // customerName -> staff
      final uniqueL2Customers = <String, String>{}; // customerName -> staff

      for (var customer in eligibleCustomers) {
        final customerName = customer.tenDuAn ?? '';
        final staff = customer.nguoiDung ?? 'Unknown';

        // Calculate L1 (D1): customer with non-blank kenhTiepCan
        bool isL1 = customer.kenhTiepCan != null && customer.kenhTiepCan!.trim().isNotEmpty;
        
        // Calculate L2 (D2): L1 + filled out info + contact record
        bool isL2 = false;
        if (isL1) {
          // Check if basic info is filled
          bool hasBasicInfo = (customer.tenDuAn != null && customer.tenDuAn!.trim().isNotEmpty) &&
                             (customer.soDienThoai != null && customer.soDienThoai!.trim().isNotEmpty) &&
                             (customer.phanLoai != null && customer.phanLoai!.trim().isNotEmpty);
          
          if (hasBasicInfo) {
            // Check if there's at least one contact record with matching boPhan
            bool hasContactRecord = allCustomerContacts.any((contact) => 
              contact.boPhan != null && 
              customer.uid != null && 
              contact.boPhan == customer.uid
            );
            
            isL2 = hasContactRecord;
          }
        }

        // Count unique L1 and L2 customers
        if (isL1 && customerName.isNotEmpty) {
          uniqueL1Customers[customerName] = staff;
        }
        if (isL2 && customerName.isNotEmpty) {
          uniqueL2Customers[customerName] = staff;
        }
      }

      // Count unique customers per staff for L1 and L2
      for (var staff in uniqueL1Customers.values) {
        if (staffTransactionKPIMap.containsKey(staff)) {
          staffTransactionKPIMap[staff]!.l1Count++;
        }
      }
      
      for (var staff in uniqueL2Customers.values) {
        if (staffTransactionKPIMap.containsKey(staff)) {
          staffTransactionKPIMap[staff]!.l2Count++;
        }
      }

      // NEW L3 CALCULATION: Count unique customers with first-time quote within selected period
      final uniqueL3Customers = <String, String>{}; // customerName -> staff
      
      // Group all quote orders by customer name to track quote history
      final quoteOrdersByCustomer = <String, List<dynamic>>{};
      
      for (var order in allOrders) {
        if (order.trangThai != 'Báo giá') continue;
        final parsedDate = _parseDateTime(order.thoiGianCapNhatTrangThai);
        if (parsedDate == null) continue;
        
        final customerName = order.tenKhachHang ?? order.tenKhachHang2 ?? '';
        if (customerName.isEmpty) continue;
        
        if (!quoteOrdersByCustomer.containsKey(customerName)) {
          quoteOrdersByCustomer[customerName] = [];
        }
        quoteOrdersByCustomer[customerName]!.add(order);
      }

      // For each customer, find their first quote and check if it's in the selected period
      for (var customerName in quoteOrdersByCustomer.keys) {
        final customerQuotes = quoteOrdersByCustomer[customerName]!;
        
        // Sort quotes by thoiGianCapNhatTrangThai to find the first one
        customerQuotes.sort((a, b) {
          final dateA = _parseDateTime(a.thoiGianCapNhatTrangThai);
          final dateB = _parseDateTime(b.thoiGianCapNhatTrangThai);
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateA.compareTo(dateB);
        });
        
        // Check if the first quote is within the selected period
        final firstQuote = customerQuotes.first;
        final firstQuoteDate = _parseDateTime(firstQuote.thoiGianCapNhatTrangThai);
        if (firstQuoteDate != null) {
          // Check if first quote is within selected period
          bool isFirstQuoteInPeriod = firstQuoteDate.isAfter(_startDate.subtract(Duration(milliseconds: 1))) &&
                                     firstQuoteDate.isBefore(_endDate.add(Duration(milliseconds: 1)));
          
          if (isFirstQuoteInPeriod && firstQuote.nguoiTao != null && firstQuote.nguoiTao!.isNotEmpty) {
            uniqueL3Customers[customerName] = firstQuote.nguoiTao!;

            // Create L3 transaction detail
            String l3TransactionKey = 'L3_${firstQuote.soPhieu}_${firstQuote.thoiGianCapNhatTrangThai}';
            transactionDetailsMap[l3TransactionKey] = TransactionDetail(
              orderId: firstQuote.soPhieu ?? '',
              customerName: customerName,
              orderDate: firstQuoteDate,
              deliveryDate: null, // No delivery date for L3
              daysDifference: null, // No days difference for L3
              assignedStaff: firstQuote.nguoiTao!,
              status: firstQuote.trangThai ?? '',
              isL3: true,
              isL4: false,
              isL5: false,
            );
          }
        }
      }

      // Count unique L3 customers per staff
      for (var staff in uniqueL3Customers.values) {
        if (staffTransactionKPIMap.containsKey(staff)) {
          staffTransactionKPIMap[staff]!.l3Count++;
        }
      }

      // Calculate L4 and L5 from quote orders within selected period
      final quoteOrdersInPeriod = periodOrders.where((order) => order.trangThai == 'Báo giá').toList();
      
      for (var order in quoteOrdersInPeriod) {
        if (order.nguoiTao == null || order.nguoiTao!.isEmpty) continue;

        final staff = order.nguoiTao!;

        // L4 and L5: Based on delivery date difference
        if (order.ngayYeuCauGiao != null && order.ngayYeuCauGiao!.isNotEmpty) {
          try {
            final orderDateTime = _parseDateTime(order.thoiGianCapNhatTrangThai);
            final deliveryDate = DateTime.parse(order.ngayYeuCauGiao!);
            
            if (orderDateTime != null) {
              int daysDifference = deliveryDate.difference(orderDateTime).inDays;

              if (staffTransactionKPIMap.containsKey(staff)) {
                if (daysDifference > 40) {
                  staffTransactionKPIMap[staff]!.l4Count++;
                } else {
                  staffTransactionKPIMap[staff]!.l5Count++;
                }
              }

              // Create L4/L5 transaction detail
              String transactionKey = '${order.soPhieu}_${order.thoiGianCapNhatTrangThai}';
              transactionDetailsMap[transactionKey] = TransactionDetail(
                orderId: order.soPhieu ?? '',
                customerName: order.tenKhachHang ?? order.tenKhachHang2 ?? '',
                orderDate: orderDateTime,
                deliveryDate: deliveryDate,
                daysDifference: daysDifference,
                assignedStaff: staff,
                status: order.trangThai ?? '',
                isL3: false,
                isL4: daysDifference > 40,
                isL5: daysDifference <= 40,
              );
            }
          } catch (e) {
            print('Error parsing dates for order ${order.soPhieu}: $e');
          }
        }
      }

      // Apply staff filter
      List<StaffTransactionKPI> filteredStaffTransactionKPI = staffTransactionKPIMap.values.toList();
      List<TransactionDetail> filteredTransactionDetails = transactionDetailsMap.values.toList();

      if (_selectedStaff != null && _selectedStaff != 'Tất cả') {
        filteredStaffTransactionKPI = filteredStaffTransactionKPI.where((kpi) => kpi.staffName == _selectedStaff).toList();
        filteredTransactionDetails = filteredTransactionDetails.where((detail) => detail.assignedStaff == _selectedStaff).toList();
      }

      // Sort by total KPI descending
      filteredStaffTransactionKPI.sort((a, b) => (b.getTotalKPI()).compareTo(a.getTotalKPI()));
      
      // Sort transaction details by order date descending
      filteredTransactionDetails.sort((a, b) => b.orderDate.compareTo(a.orderDate));

      _staffTransactionKPIList = filteredStaffTransactionKPI;
      _transactionDetails = filteredTransactionDetails;

    } catch (e) {
     print('Error loading transaction KPI: $e');
   }
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: Text('Theo dõi KPI'),
       backgroundColor: Colors.blue[800],
       foregroundColor: Colors.white,
       bottom: TabBar(
         controller: _tabController,
         indicatorColor: Colors.white,
         labelColor: Colors.white,
         unselectedLabelColor: Colors.white70,
         tabs: [
           Tab(text: '1️⃣ Khách hàng'),
           Tab(text: '2️⃣ Giao dịch'),
         ],
       ),
     ),
     body: Column(
       children: [
         _buildControls(),
         Expanded(
           child: TabBarView(
             controller: _tabController,
             children: [
               _buildCustomerTab(),
               _buildTransactionTab(),
             ],
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildControls() {
   return Container(
     padding: EdgeInsets.all(16),
     color: Colors.grey[100],
     child: Column(
       children: [
         Row(
           children: [
             // Period type selection
             Expanded(
               flex: 2,
               child: DropdownButtonFormField<String>(
                 value: _selectedPeriodType,
                 decoration: InputDecoration(
                   labelText: 'Loại thời gian',
                   border: OutlineInputBorder(),
                   contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 ),
                 items: _periodTypes
                     .map((type) => DropdownMenuItem(
                           value: type,
                           child: Text(type),
                         ))
                     .toList(),
                 onChanged: (value) {
                   if (value != null) {
                     setState(() {
                       _selectedPeriodType = value;
                     });
                     _calculateDateRange();
                     _loadKPIData();
                   }
                 },
               ),
             ),
             SizedBox(width: 16),
             // Dynamic period selection based on type
             if (_selectedPeriodType == 'Tháng') ...[
               Expanded(
                 flex: 2,
                 child: DropdownButtonFormField<int>(
                   value: _selectedMonth,
                   decoration: InputDecoration(
                     labelText: 'Tháng',
                     border: OutlineInputBorder(),
                     contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   ),
                   items: List.generate(12, (index) => index + 1)
                       .map((month) => DropdownMenuItem(
                             value: month,
                             child: Text(_monthNames[month - 1]),
                           ))
                       .toList(),
                   onChanged: (value) {
                     if (value != null) {
                       setState(() {
                         _selectedMonth = value;
                       });
                       _calculateDateRange();
                       _loadKPIData();
                     }
                   },
                 ),
               ),
             ] else if (_selectedPeriodType == 'Quý') ...[
               Expanded(
                 flex: 2,
                 child: DropdownButtonFormField<int>(
                   value: _selectedQuarter,
                   decoration: InputDecoration(
                     labelText: 'Quý',
                     border: OutlineInputBorder(),
                     contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   ),
                   items: [1, 2, 3, 4]
                       .map((quarter) => DropdownMenuItem(
                             value: quarter,
                             child: Text(_quarterNames[quarter - 1]),
                           ))
                       .toList(),
                   onChanged: (value) {
                     if (value != null) {
                       setState(() {
                         _selectedQuarter = value;
                       });
                       _calculateDateRange();
                       _loadKPIData();
                     }
                   },
                 ),
               ),
             ] else ...[
               Expanded(flex: 2, child: SizedBox()),
             ],
             SizedBox(width: 16),
             // Year selection
             Expanded(
               flex: 2,
               child: DropdownButtonFormField<int>(
                 value: _selectedYear,
                 decoration: InputDecoration(
                   labelText: 'Năm',
                   border: OutlineInputBorder(),
                   contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 ),
                 items: _getYearOptions()
                     .map((year) => DropdownMenuItem(
                           value: year,
                           child: Text(year.toString()),
                         ))
                     .toList(),
                 onChanged: (value) {
                   if (value != null) {
                     setState(() {
                       _selectedYear = value;
                     });
                     _calculateDateRange();
                     _loadKPIData();
                   }
                 },
               ),
             ),
             SizedBox(width: 16),
             // Staff filter
             Expanded(
               flex: 3,
               child: DropdownButtonFormField<String>(
                 value: _selectedStaff,
                 decoration: InputDecoration(
                   labelText: 'Nhân viên',
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
                   _loadKPIData();
                 },
               ),
             ),
           ],
         ),
         SizedBox(height: 12),
         // Date range display
         Container(
           width: double.infinity,
           padding: EdgeInsets.all(12),
           decoration: BoxDecoration(
             border: Border.all(color: Colors.grey),
             borderRadius: BorderRadius.circular(4),
             color: Colors.white,
           ),
           child: Text(
             'Khoảng thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(_startDate)} - ${DateFormat('dd/MM/yyyy HH:mm').format(_endDate)}',
             style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
             textAlign: TextAlign.center,
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildCustomerTab() {
   if (_isLoading) {
     return Center(child: CircularProgressIndicator());
   }

   return SingleChildScrollView(
     padding: EdgeInsets.all(16),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // Staff KPI Table
         _buildStaffKPITable(),
         SizedBox(height: 24),
         // Customer Details Table
         _buildCustomerDetailsTable(),
       ],
     ),
   );
 }

 Widget _buildTransactionTab() {
   if (_isLoading) {
     return Center(child: CircularProgressIndicator());
   }

   return SingleChildScrollView(
     padding: EdgeInsets.all(16),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // Staff Transaction KPI Table
         _buildStaffTransactionKPITable(),
         SizedBox(height: 24),
         // Transaction Details Table
         _buildTransactionDetailsTable(),
       ],
     ),
   );
 }

 Widget _buildStaffKPITable() {
   return Card(
     child: Padding(
       padding: EdgeInsets.all(16),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'Bảng điểm KPI Khách hàng theo Nhân viên (Đếm khách hàng duy nhất)',
             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
           ),
           SizedBox(height: 16),
           SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             child: Table(
               border: TableBorder.all(color: Colors.grey[300]!),
               columnWidths: {
                 0: FixedColumnWidth(150),
                 1: FixedColumnWidth(80),
                 2: FixedColumnWidth(80),
                 3: FixedColumnWidth(80),
                 4: FixedColumnWidth(80),
                 5: FixedColumnWidth(80),
                 6: FixedColumnWidth(120),
                 7: FixedColumnWidth(120),
               },
               children: [
                 TableRow(
                   decoration: BoxDecoration(color: Colors.blue[50]),
                   children: [
                     _buildTableHeader('Nhân viên'),
                     _buildTableHeader('C1\n(KH có đơn hoàn thành đầu tiên trong kỳ)'),
                     _buildTableHeader('C2\n(KH có ≥3 đơn hoàn thành)'),
                     _buildTableHeader('D1\n(KH có kênh tiếp cận)'),
                     _buildTableHeader('D2\n(KH có thông tin đầy đủ)'),
                     _buildTableHeader('Tổng'),
                     _buildTableHeader('Doanh thu\ntrước thuế'),
                     _buildTableHeader('Doanh thu\nhóa đơn'),
                   ],
                 ),
                 ..._staffKPIList.map((kpi) => TableRow(
                   children: [
                     _buildTableCell(kpi.staffName),
                     _buildTableCell(kpi.c1Count.toString()),
                     _buildTableCell(kpi.c2Count.toString()),
                     _buildTableCell(kpi.d1Count.toString()),
                     _buildTableCell(kpi.d2Count.toString()),
                     _buildTableCell(kpi.getTotalKPI().toString()),
                     _buildTableCell(_formatCurrency(kpi.doanhThuTruocThue)),
                     _buildTableCell(_formatCurrency(kpi.doanhThuHoaDon)),
                   ],
                 )),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }

 String _formatCurrency(double amount) {
   final formatter = NumberFormat('#,###', 'vi_VN');
   return formatter.format(amount);
 }

 Widget _buildStaffTransactionKPITable() {
   return Card(
     child: Padding(
       padding: EdgeInsets.all(16),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'Bảng điểm KPI Giao dịch theo Nhân viên (Đếm khách hàng duy nhất)',
             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
           ),
           SizedBox(height: 16),
           SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             child: Table(
               border: TableBorder.all(color: Colors.grey[300]!),
               columnWidths: {
                 0: FixedColumnWidth(150),
                 1: FixedColumnWidth(80),
                 2: FixedColumnWidth(80),
                 3: FixedColumnWidth(100), 
                 4: FixedColumnWidth(80),
                 5: FixedColumnWidth(80),
                 6: FixedColumnWidth(80),
               },
               children: [
                 TableRow(
                   decoration: BoxDecoration(color: Colors.green[50]),
                   children: [
                     _buildTableHeader('Nhân viên'),
                     _buildTableHeader('L1\n(KH có kênh tiếp cận)'),
                     _buildTableHeader('L2\n(KH có thông tin đầy đủ)'),
                     _buildTableHeader('L3\n(KH có báo giá lần đầu trong kỳ)'),
                     _buildTableHeader('L4\n(Đơn giao >40 ngày)'),
                     _buildTableHeader('L5\n(Đơn giao ≤40 ngày)'),
                     _buildTableHeader('Tổng'),
                   ],
                 ),
                 ..._staffTransactionKPIList.map((kpi) => TableRow(
                   children: [
                     _buildTableCell(kpi.staffName),
                     _buildTableCell(kpi.l1Count.toString()),
                     _buildTableCell(kpi.l2Count.toString()),
                     _buildTableCell(kpi.l3Count.toString()),
                     _buildTableCell(kpi.l4Count.toString()),
                     _buildTableCell(kpi.l5Count.toString()),
                     _buildTableCell(kpi.getTotalKPI().toString()),
                   ],
                 )),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildCustomerDetailsTable() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết Khách hàng',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              border: TableBorder.all(color: Colors.grey[300]!),
              headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
              columnSpacing: 8, 
              dataRowHeight: 70, 
              columns: [
                DataColumn(
                  label: Container(
                    width: 320, 
                    child: const Text('Tên khách hàng', 
                      style: TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const DataColumn(label: Text('Loại KH', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                  label: Container(
                    width: 100,
                    child: const Text('SĐT', 
                      style: TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const DataColumn(label: Text('Kênh tiếp cận', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Số đơn hoàn thành', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Đơn hàng cuối', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Nhân viên', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('C1', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('C2', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('D1', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('D2', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _customerDetails.map((customer) => DataRow(
                cells: [
                  DataCell(
                    Container(
                      width: 220, // Made consistent with header width
                      child: Text(
                        customer.customerName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                  DataCell(Text(customer.customerType)),
                  DataCell(
                    Container(
                      width: 100,
                      child: Text(
                        customer.phone,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(customer.contactChannel)),
                  DataCell(Text(customer.orderCount.toString())),
                  DataCell(Text(customer.lastOrderDate != null 
                      ? DateFormat('dd/MM/yyyy HH:mm').format(customer.lastOrderDate!) 
                      : '')),
                  DataCell(Text(customer.assignedStaff)),
                  DataCell(Icon(
                    customer.isC1 ? Icons.check_circle : Icons.cancel,
                    color: customer.isC1 ? Colors.green : Colors.red,
                    size: 20,
                  )),
                  DataCell(Icon(
                    customer.isC2 ? Icons.check_circle : Icons.cancel,
                    color: customer.isC2 ? Colors.green : Colors.red,
                    size: 20,
                  )),
                  DataCell(Icon(
                    customer.isD1 ? Icons.check_circle : Icons.cancel,
                    color: customer.isD1 ? Colors.green : Colors.red,
                    size: 20,
                  )),
                  DataCell(Icon(
                    customer.isD2 ? Icons.check_circle : Icons.cancel,
                    color: customer.isD2 ? Colors.green : Colors.red,
                    size: 20,
                  )),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildTransactionDetailsTable() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết Giao dịch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              border: TableBorder.all(color: Colors.grey[300]!),
              headingRowColor: WidgetStateProperty.all(Colors.green[50]),
              columnSpacing: 12,
              columns: const [
                DataColumn(label: Text('Mã đơn hàng', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Tên khách hàng', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Thời gian cập nhật', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Ngày yêu cầu giao', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Số ngày chênh lệch', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Nhân viên', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('L3', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('L4', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('L5', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Chi tiết', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _transactionDetails.map((transaction) => DataRow(
                cells: [
                  DataCell(Text(transaction.orderId)),
                  DataCell(Text(transaction.customerName)),
                  DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(transaction.orderDate))),
                  DataCell(Text(transaction.deliveryDate != null 
                      ? DateFormat('dd/MM/yyyy').format(transaction.deliveryDate!) 
                      : 'N/A')),
                  DataCell(Text(transaction.daysDifference != null 
                      ? '${transaction.daysDifference} ngày' 
                      : 'N/A')),
                  DataCell(Text(transaction.assignedStaff)),
                  DataCell(Text(transaction.status)),
                  DataCell(Icon(
                    transaction.isL3 ? Icons.check_circle : Icons.cancel,
                    color: transaction.isL3 ? Colors.blue : Colors.grey,
                    size: 20,
                  )),
                  DataCell(Icon(
                    transaction.isL4 ? Icons.check_circle : Icons.cancel,
                    color: transaction.isL4 ? Colors.orange : Colors.grey,
                    size: 20,
                  )),
                  DataCell(Icon(
                    transaction.isL5 ? Icons.check_circle : Icons.cancel,
                    color: transaction.isL5 ? Colors.green : Colors.grey,
                    size: 20,
                  )),
                  DataCell(
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderDetailsScreen(
                              orderId: transaction.orderId,
                              customerName: transaction.customerName,
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('Xem'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    ),
  );
}
 Color _getTransactionStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'báo giá':
      return Colors.orange;
    case 'đã duyệt':
    case 'duyệt':
      return Colors.green;
    case 'hoàn thành':
      return Colors.blue;
    case 'đã huỷ':
      return Colors.red;
    case 'chưa xong':
      return Colors.purple;
    case 'gửi':
    case 'chờ duyệt':
      return Colors.amber[700]!;
    default:
      return Colors.grey;
  }
}
 Widget _buildTableHeader(String text) {
   return Padding(
     padding: EdgeInsets.all(8),
     child: Text(
       text,
       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
       textAlign: TextAlign.center,
     ),
   );
 }

 Widget _buildTableCell(String text) {
   return Padding(
     padding: EdgeInsets.all(8),
     child: Text(
       text,
       textAlign: TextAlign.center,
       style: TextStyle(fontSize: 12),
     ),
   );
 }

 @override
 void dispose() {
   _tabController.dispose();
   super.dispose();
 }
}

// Data models for KPI (unchanged)
class StaffCustomerKPI {
 final String staffName;
 int c1Count;
 int c2Count;
 int d1Count;
 int d2Count;
 double doanhThuTruocThue; 
 double doanhThuHoaDon;

 StaffCustomerKPI({
   required this.staffName,
   required this.c1Count,
   required this.c2Count,
   required this.d1Count,
   required this.d2Count,
   this.doanhThuTruocThue = 0.0,
   this.doanhThuHoaDon = 0.0,
 });

 int getTotalKPI() {
   return c1Count + c2Count + d1Count + d2Count;
 }
}

class StaffTransactionKPI {
 final String staffName;
 int l1Count;
 int l2Count;
 int l3Count;
 int l4Count;
 int l5Count;

 StaffTransactionKPI({
   required this.staffName,
   required this.l1Count,
   required this.l2Count,
   required this.l3Count,
   required this.l4Count,
   required this.l5Count,
 });

 int getTotalKPI() {
   return l1Count + l2Count + l3Count + l4Count + l5Count;
 }
}

class CustomerDetail {
 final String customerName;
 final String customerType;
 final String phone;
 final String contactChannel;
 final int orderCount;
 final DateTime? lastOrderDate;
 final String assignedStaff;
 final bool isC1;
 final bool isC2;
 final bool isD1;
 final bool isD2;

 CustomerDetail({
   required this.customerName,
   required this.customerType,
   required this.phone,
   required this.contactChannel,
   required this.orderCount,
   this.lastOrderDate,
   required this.assignedStaff,
   required this.isC1,
   required this.isC2,
   required this.isD1,
   required this.isD2,
 });
}

class TransactionDetail {
 final String orderId;
 final String customerName;
 final DateTime orderDate;
 final DateTime? deliveryDate; 
 final int? daysDifference;
 final String assignedStaff;
 final String status;
 final bool isL3;
 final bool isL4;
 final bool isL5;

 TransactionDetail({
   required this.orderId,
   required this.customerName,
   required this.orderDate,
   this.deliveryDate,
   this.daysDifference,
   required this.assignedStaff,
   required this.status,
   this.isL3 = false,
   required this.isL4,
   required this.isL5,
 });
}