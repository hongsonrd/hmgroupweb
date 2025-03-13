import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'projectorderdetail.dart';
import 'dart:core';
import 'package:collection/collection.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'http_client.dart';

class ProjectOrder extends StatefulWidget {
  final String selectedBoPhan;

  const ProjectOrder({
    Key? key,
    required this.selectedBoPhan,
  }) : super(key: key);

  @override
  _ProjectOrderState createState() => _ProjectOrderState();
}

class _ProjectOrderState extends State<ProjectOrder> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _orderList = [];
  List<String> _departments = [];
  String _selectedNewOrderProject = '';
  late String _username;
  
  @override
void initState() {
  super.initState();
  initializeDateFormatting('vi_VN', null).then((_) {
    _username = Provider.of<UserCredentials>(context, listen: false).username;
    _selectedNewOrderProject = widget.selectedBoPhan;
    _loadDepartmentsFromDinhMuc();
    _loadOrders();
  });
}
  Future<void> _loadDepartmentsFromDinhMuc() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    final DBHelper dbHelper = DBHelper();
    
    // Query the orderDinhMucTable to get all records
    final List<Map<String, dynamic>> dinhMucData = 
        await dbHelper.query(DatabaseTables.orderDinhMucTable);
    
    print('Found ${dinhMucData.length} records in orderDinhMucTable');
    
    // Extract unique BoPhan values
    final Set<String> uniqueDepartments = {};
    for (var record in dinhMucData) {
      if (record.containsKey('BoPhan') && record['BoPhan'] != null) {
        uniqueDepartments.add(record['BoPhan'].toString());
      }
    }
    
    setState(() {
      _departments = uniqueDepartments.toList();
      print('Extracted departments: $_departments');
      
      // If the selected department is not in the list, select the first one
      if (!_departments.contains(_selectedNewOrderProject) && _departments.isNotEmpty) {
        _selectedNewOrderProject = _departments.first;
      }
    });
    
  } catch (e) {
    print('Error loading departments from orderDinhMucTable: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải danh sách bộ phận'),
          backgroundColor: Colors.red,
        ),
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
  Future<void> _loadProjects() async {
    try {
      final response = await http.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/projectgs/$_username'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _departments = data.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      print('Error loading projects: $e');
    }
  }

  Future<void> _loadOrders() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final DBHelper dbHelper = DBHelper();
    final List<OrderModel> orders = await dbHelper.getAllOrders();
    
    setState(() {
      _orderList = orders.map((order) => order.toMap()).toList();
      _isLoading = false;
    });
    
    print('Loaded ${_orderList.length} orders from database');
    print('First order: ${_orderList.firstOrNull}');
    
  } catch (e) {
    print('Error loading orders from database: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải danh sách đặt hàng'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }
}

  Future<Map<String, dynamic>> _getDinhMucInfo(String boPhan) async {
    try {
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/dinhmuc/$boPhan'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error getting DinhMuc info: $e');
    }
    return {};
  }

  Future<void> _createNewOrder() async {
  final dinhMucInfo = await _getDinhMucInfo(_selectedNewOrderProject);
  
  final now = DateTime.now();
  final orderMonth = DateFormat.yMMMM('vi_VN').format(now);
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Tạo đơn'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: 'Tháng ${now.month}/${now.year}',
              decoration: InputDecoration(labelText: 'Tên đơn'),
              enabled: false,
            ),
            DropdownButtonFormField<String>(
              value: '1. Đơn định kỳ',
              items: ['1. Đơn định kỳ', '2. Đơn phát sinh', '3. VT ban đầu']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              decoration: InputDecoration(labelText: 'Phân loại'),
              onChanged: (value) {},
            ),
            TextFormField(
              initialValue: 'Không có',
              decoration: InputDecoration(labelText: 'Vấn đề'),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Ghi chú'),
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
  onPressed: () async {
    try {
      final newOrder = {
        'OrderID': Uuid().v4(),
        'TenDon': 'Tháng ${now.month}/${now.year} Định kỳ ${_selectedNewOrderProject}',
        'BoPhan': _selectedNewOrderProject,
        'NguoiDung': _username,
        'TrangThai': 'Nháp',
        'Ngay': now.toIso8601String(),
        'TongTien': 0,
        'DinhMuc': dinhMucInfo['DinhMuc'],
        'NguoiDuyet': dinhMucInfo['NguoiDuyet'],
        'PhanLoai': '1. Đơn định kỳ',
        'VanDe': 'Không có',
        'NgayCapNhat': now.toIso8601String(),
      };

      // First submit to API
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtmoi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newOrder),
      );

      if (response.statusCode == 200) {
        // Then save to local database
        final DBHelper dbHelper = DBHelper();
        final OrderModel orderModel = OrderModel(
          orderId: newOrder['OrderID']!,
          tenDon: newOrder['TenDon'],
          boPhan: newOrder['BoPhan'],
          nguoiDung: newOrder['NguoiDung'],
          trangThai: newOrder['TrangThai'],
          ngay: now,
          tongTien: 0,
          dinhMuc: dinhMucInfo['DinhMuc'],
          nguoiDuyet: dinhMucInfo['NguoiDuyet'],
          phanLoai: newOrder['PhanLoai'],
          vanDe: newOrder['VanDe'],
          ngayCapNhat: now,
        );
        
        await dbHelper.insertOrder(orderModel);
        _loadOrders();
        Navigator.pop(context);
      } else {
        throw Exception('Failed to create order on server');
      }
    } catch (e) {
      print('Error creating order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tạo đơn hàng'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
  child: Text('Lưu'),
),
      ],
    ),
  );
}
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Nháp':
        return Colors.grey.shade200;
      case 'Gửi':
        return Colors.blue.shade100;
      case 'Đồng ý':
        return Colors.green.shade100;
      case 'Từ chối':
        return Colors.red.shade100;
      default:
        return Colors.white;
    }
  }

  @override
Widget build(BuildContext context) {
  // Sort orders by date descending before grouping
  _orderList.sort((a, b) {
    DateTime dateA = DateTime.parse(a['Ngay']);
    DateTime dateB = DateTime.parse(b['Ngay']);
    return dateB.compareTo(dateA); // Descending order
  });

  // Group sorted orders by month
  final ordersByMonth = groupBy(_orderList, 
    (Map<String, dynamic> order) => DateFormat('MM/yyyy')
      .format(DateTime.parse(order['Ngay'])));

  // Sort months in descending order
  final sortedMonths = ordersByMonth.keys.toList()
    ..sort((a, b) {
      final dateA = DateFormat('MM/yyyy').parse(a);
      final dateB = DateFormat('MM/yyyy').parse(b);
      return dateB.compareTo(dateA);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Đặt vật tư ${widget.selectedBoPhan}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButton<String>(
                    value: _selectedNewOrderProject,
                    items: _departments
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedNewOrderProject = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Tạo đơn mới'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 0, 204, 34),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _createNewOrder,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ordersByMonth.isEmpty
                  ? Center(child: Text('Không có đơn hàng'))
                  : ListView.builder(
                      itemCount: sortedMonths.length,
                      itemBuilder: (context, index) {
                        final month = sortedMonths[index];
                        final orders = ordersByMonth[month]!;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                month,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            ...orders.map((order) => Card(
                                color: _getStatusColor(order['TrangThai']),
                                child: ListTile(
                                  title: Text(order['TenDon']),
                                  subtitle: Text('Trạng thái: ${order['TrangThai']}'),
                                  trailing: Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProjectOrderDetail(
                                          orderId: order['OrderID'],
                                          boPhan: order['BoPhan'],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )).toList(),
                          ],
                        );
                      },
                    ),
        ),
      ],
    ),
  );
}
}