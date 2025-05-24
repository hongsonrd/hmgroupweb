//projectorder2.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'projectorderdetails2.dart';
import 'dart:core';
import 'package:collection/collection.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'http_client.dart';

class ProjectOrder2 extends StatefulWidget {
  final String selectedBoPhan;

  const ProjectOrder2({
    Key? key,
    required this.selectedBoPhan,
  }) : super(key: key);

  @override
  _ProjectOrderState createState() => _ProjectOrderState();
}

class _ProjectOrderState extends State<ProjectOrder2> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _orderList = [];
  List<Map<String, dynamic>> _filteredOrderList = [];
  late String _username;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi_VN', null).then((_) {
      _username = Provider.of<UserCredentials>(context, listen: false).username;
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final DBHelper dbHelper = DBHelper();
      final allOrders = await dbHelper.query(DatabaseTables.orderTable);
      
      setState(() {
        // Convert and filter out 'Nháp' orders
        _orderList = allOrders
            .map((order) => OrderModel.fromMap(order).toMap())
            .where((order) => order['TrangThai'] != 'Nháp')
            .toList();
        _filteredOrderList = List.from(_orderList);
        _isLoading = false;
      });

      print('Loaded ${_orderList.length} non-draft orders');
      if (_orderList.isNotEmpty) {
        print('Sample order: ${_orderList.first}');
      }

    } catch (e) {
      print('Error loading orders: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải danh sách đặt hàng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterOrders(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOrderList = List.from(_orderList);
      } else {
        _filteredOrderList = _orderList.where((order) {
          final orderName = order['TenDon'].toString().toLowerCase();
          final status = order['TrangThai'].toString().toLowerCase();
          final boPhan = order['BoPhan'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          
          return orderName.contains(searchLower) ||
                 status.contains(searchLower) ||
                 boPhan.contains(searchLower);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredOrderList = List.from(_orderList);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _filteredOrderList.sort((a, b) {
      DateTime dateA = DateTime.parse(a['Ngay']);
      DateTime dateB = DateTime.parse(b['Ngay']);
      return dateB.compareTo(dateA);
    });

    final ordersByMonth = groupBy(_filteredOrderList, 
      (Map<String, dynamic> order) => DateFormat('MM/yyyy')
        .format(DateTime.parse(order['Ngay'])));

    final sortedMonths = ordersByMonth.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MM/yyyy').parse(a);
        final dateB = DateFormat('MM/yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm đơn hàng...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.red),
              ),
              style: TextStyle(color: Colors.white),
              onChanged: _filterOrders,
            )
          : Text('Đặt vật tư ${widget.selectedBoPhan}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadOrders,
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (_isSearching && _searchController.text.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(8.0),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Tìm thấy ${_filteredOrderList.length} kết quả',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ordersByMonth.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isNotEmpty 
                              ? Icons.search_off 
                              : Icons.inbox,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty 
                              ? 'Không tìm thấy đơn hàng phù hợp'
                              : 'Không có đơn hàng',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: sortedMonths.length,
                      itemBuilder: (context, index) {
                        final month = sortedMonths[index];
                        final orders = ordersByMonth[month]!;
                        
                        // Sort orders by TrangThai with "Gửi" first, then by BoPhan
                        orders.sort((a, b) {
                          // First priority: "Gửi" status comes first
                          if (a['TrangThai'] == 'Gửi' && b['TrangThai'] != 'Gửi') {
                            return -1;
                          } else if (a['TrangThai'] != 'Gửi' && b['TrangThai'] == 'Gửi') {
                            return 1;
                          }
                          
                          // Second priority: other TrangThai values
                          if (a['TrangThai'] != b['TrangThai']) {
                            return a['TrangThai'].compareTo(b['TrangThai']);
                          }
                          
                          // Third priority: sort by BoPhan
                          return a['BoPhan'].compareTo(b['BoPhan']);
                        });
                        
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Trạng thái: ${order['TrangThai']}'),
                                    Text('Tổng tiền: ${order['TongTien']} đ'),
                                  ],
                                ),
                                trailing: Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProjectOrderDetail2( 
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