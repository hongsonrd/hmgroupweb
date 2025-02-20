import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'http_client.dart';

class DongPhucManager extends StatefulWidget {
  @override
  _DongPhucManagerState createState() => _DongPhucManagerState();
}

class _DongPhucManagerState extends State<DongPhucManager> {
  final dbHelper = DBHelper();
  Map<String, List<DongPhucModel>> groupedOrders = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
  setState(() => isLoading = true);
  try {
    final orders = await dbHelper.getAllDongPhuc();
    print('Loaded ${orders.length} orders');
    
    // Group orders by month
    final grouped = <String, List<DongPhucModel>>{};
    for (var order in orders) {
      final month = order.thang != null 
          ? '${order.thang!.year}-${order.thang!.month.toString().padLeft(2, '0')}'
          : 'Không có ngày';
      print('Processing order: ${order.toMap()} for month: $month');
      grouped.putIfAbsent(month, () => []).add(order);
    }
    
    print('Grouped orders by month: ${grouped.keys.length} months');
    for (var month in grouped.keys) {
      print('Month $month has ${grouped[month]?.length} orders');
    }
    
    setState(() {
      groupedOrders = grouped;
      isLoading = false;
    });
  } catch (e, stackTrace) {
    print('Error loading orders: $e');
    print('Stack trace: $stackTrace');
    setState(() => isLoading = false);
  }
}

  Widget _buildStatusGroup(List<DongPhucModel> orders, String status) {
  if (status == 'Nháp') return SizedBox();
  
  final filteredOrders = orders.where((o) => o.trangThai == status).toList();
  if (filteredOrders.isEmpty) return SizedBox();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          '$status (${filteredOrders.length})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      ...filteredOrders.map((order) => _buildOrderCard(order)),
    ],
  );
}
  Widget _buildOrderCard(DongPhucModel order) {
  Color statusColor;
  switch (order.trangThai) {
    case 'Gửi':
      statusColor = Colors.blue;
      break;
    case 'Duyệt':
      statusColor = Colors.green;
      break;
    case 'Từ chối':
      statusColor = Colors.red;
      break;
    default:
      statusColor = Colors.grey;
  }

  return Card(
    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: statusColor, width: 2),
    ),
    child: ListTile(
      title: Text(
        '${order.boPhan} - ${order.phanLoai}',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Người dùng: ${order.nguoiDung}'),
          Text(
            'Trạng thái: ${order.trangThai}',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
          ),
          if (order.xuLy != null) Text('Xử lý: ${order.xuLy}'),
        ],
      ),
      trailing: Icon(Icons.chevron_right),
      onTap: () => _showOrderDetails(order),
    ),
  );
}
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

  Future<void> _updateOrderStatus(DongPhucModel order, String newStatus) async {
  try {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final response = await AuthenticatedHttpClient.post(
      Uri.parse('$baseUrl/dongphuccapnhat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'UID': order.uid,
        'TrangThai': newStatus,
        'NguoiDung': userCredentials.username,
      }),
    );

    if (response.statusCode == 200) {
      // Update local database
      final updatedOrder = DongPhucModel(
        uid: order.uid,
        nguoiDung: userCredentials.username,
        boPhan: order.boPhan,
        phanLoai: order.phanLoai,
        thoiGianNhan: order.thoiGianNhan,
        trangThai: newStatus,
        thang: order.thang,
        xuLy: order.xuLy,
      );
      await dbHelper.insertDongPhuc(updatedOrder);
      _loadOrders(); // Reload the list
    } else {
      throw Exception('Failed to update order');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error updating order: $e')),
    );
  }
}

void _showOrderDetails(DongPhucModel order) async {
  try {
    print('Fetching items for order: ${order.uid}');
    
    // Update this line to properly get the items
    final List<ChiTietDPModel> items = await dbHelper.getChiTietDPByOrderUID(order.uid);
    
    print('Found ${items.length} items for order ${order.uid}');
    
    // Debug each item
    items.forEach((item) {
      print('Item: ${item.toMap()}');
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết đơn hàng'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bộ phận: ${order.boPhan}'),
              Text('Phân loại: ${order.phanLoai}'),
              Text('Người dùng: ${order.nguoiDung}'),
              Text('Trạng thái: ${order.trangThai ?? ""}'),
              Text('Xử lý: ${order.xuLy ?? ""}'),
              if (order.thoiGianNhan != null)
                Text('Thời gian nhận: ${DateFormat('dd/MM/yyyy').format(order.thoiGianNhan!)}'),
              Divider(),
              Text('Danh sách hàng:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (items.isEmpty)
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Không có chi tiết đơn hàng'),
                )
              else
                Container(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    children: items.map((item) => Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.ten ?? ""}',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text('Mã NV: ${item.maCN ?? ""}'),
                              ],
                            ),
                            SizedBox(height: 4),
                            if (item.loaiAo != null) _buildItemDetail('Áo', '${item.loaiAo} - Size ${item.sizeAo}'),
                            if (item.loaiQuan != null) _buildItemDetail('Quần', '${item.loaiQuan} - Size ${item.sizeQuan}'),
                            if (item.loaiGiay != null) _buildItemDetail('Giày', '${item.loaiGiay} - Size ${item.sizeGiay}'),
                            if (item.loaiKhac != null) _buildItemDetail('Khác', '${item.loaiKhac} - Size ${item.sizeKhac}'),
                            if (item.ghiChu != null && item.ghiChu!.isNotEmpty) 
                              _buildItemDetail('Ghi chú', item.ghiChu!),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (order.trangThai != 'Duyệt' && order.trangThai != 'Từ chối') ...[
            TextButton(
              onPressed: () {
                _updateOrderStatus(order, 'Duyệt');
                Navigator.pop(context);
              },
              child: Text('Duyệt'),
            ),
            TextButton(
              onPressed: () {
                _updateOrderStatus(order, 'Từ chối');
                Navigator.pop(context);
              },
              child: Text('Từ chối'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  } catch (e, stackTrace) {
    print('Error showing order details: $e');
    print('Stack trace: $stackTrace');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading order details: $e')),
    );
  }
}
Widget _buildItemDetail(String label, String value) {
  return Padding(
    padding: EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text('Quản lý đơn đồng phục'),
  backgroundColor: Color.fromARGB(255, 114, 255, 217),
  actions: [
    IconButton(
      icon: Icon(Icons.refresh),
      onPressed: _loadOrders,
    ),
    IconButton(
      icon: Icon(Icons.bug_report),
      onPressed: () async {
        final orders = await dbHelper.getAllDongPhuc();
        print('Total orders: ${orders.length}');
        for (var order in orders) {
          print('Order: ${order.toMap()}');
        }
      },
    ),
  ],
),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: groupedOrders.length,
              itemBuilder: (context, index) {
                final month = groupedOrders.keys.elementAt(index);
                final orders = groupedOrders[month]!;
                
                return ExpansionTile(
  title: Text('Tháng $month'),
  children: [
    _buildStatusGroup(orders, 'Gửi'),
    _buildStatusGroup(orders, 'Duyệt'),
    _buildStatusGroup(orders, 'Từ chối'),
  ],
);
              },
            ),
    );
  }
}