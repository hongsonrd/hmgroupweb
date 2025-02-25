import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'http_client.dart';

class ProjectOrderDetail2 extends StatefulWidget {
  final String orderId;
  final String boPhan;

  const ProjectOrderDetail2({
    Key? key,
    required this.orderId,
    required this.boPhan,
  }) : super(key: key);

  @override
  _ProjectOrderDetail2State createState() => _ProjectOrderDetail2State();
}

class _ProjectOrderDetail2State extends State<ProjectOrderDetail2> {
  bool _isLoading = true;
  OrderModel? _orderDetails;
  List<OrderChiTietModel> _orderItems = [];
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  List<OrderMatHangModel> _availableItems = [];
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi_VN', null).then((_) {
      _loadOrderDetails();
      _loadAvailableItems();
    });
  }
  Future<void> _loadAvailableItems() async {
    try {
      final DBHelper dbHelper = DBHelper();
      _availableItems = await dbHelper.getAllOrderMatHang();
    } catch (e) {
      print('Error loading available items: $e');
    }
  }
  Future<void> _editOrder() async {
  final formKey = GlobalKey<FormState>();
  String? phanLoai = _orderDetails?.phanLoai;
  String? vanDe = _orderDetails?.vanDe;
  String? ghiChu = _orderDetails?.ghiChu;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Sửa đơn hàng'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tên đơn: ${_orderDetails!.tenDon}'),
              DropdownButtonFormField<String>(
                value: phanLoai,
                decoration: InputDecoration(labelText: 'Phân loại'),
                items: [
                  '1. Đơn định kỳ',
                  '2. Đơn phát sinh',
                  '3. VT ban đầu'
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  phanLoai = value;
                },
              ),
              TextFormField(
                initialValue: vanDe,
                decoration: InputDecoration(labelText: 'Vấn đề'),
                onChanged: (value) {
                  vanDe = value;
                },
              ),
              TextFormField(
                initialValue: ghiChu,
                decoration: InputDecoration(labelText: 'Ghi chú'),
                onChanged: (value) {
                  ghiChu = value;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              try {
                final updates = {
                  'PhanLoai': phanLoai,
                  'VanDe': vanDe,
                  'GhiChu': ghiChu,
                  'NgayCapNhat': DateTime.now().toIso8601String(),
                };

                // Update on server first
                final response = await http.post(
                  Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtsua'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'OrderID': widget.orderId,
                    ...updates,
                  }),
                );

                if (response.statusCode == 200) {
                  // Then update local database
                  final DBHelper dbHelper = DBHelper();
                  await dbHelper.updateOrder(widget.orderId, updates);

                  // Update state
                  setState(() {
                    if (_orderDetails != null) {
                      _orderDetails!.phanLoai = phanLoai;
                      _orderDetails!.vanDe = vanDe;
                      _orderDetails!.ghiChu = ghiChu;
                      _orderDetails!.ngayCapNhat = DateTime.now();
                    }
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã cập nhật đơn hàng')),
                  );
                }
              } catch (e) {
                print('Error updating order: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi khi cập nhật đơn hàng'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: Text('Lưu'),
        ),
      ],
    ),
  );
}
  Future<void> _sendOrder() async {
    try {
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtgui'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'OrderID': widget.orderId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          if (_orderDetails != null) {
            _orderDetails!.trangThai = 'Gửi';
          }
        });

        final DBHelper dbHelper = DBHelper();
        await dbHelper.updateOrder(widget.orderId, {'TrangThai': 'Gửi'});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi đơn hàng thành công')),
        );
      }
    } catch (e) {
      print('Error sending order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi đơn hàng'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _showAddItemDialog() async {
  final selectedItems = Map<String, Map<String, dynamic>>();
  final Map<String, bool> hasQuantity = {};
  final Map<String, TextEditingController> soLuongControllers = {};
  final Map<String, TextEditingController> ghiChuControllers = {};
  final Map<String, bool> khachTraValues = {};
  
  // Add search controller
  final searchController = TextEditingController();
  
  for (var item in _availableItems) {
    final existing = _orderItems.firstWhere(
      (oi) => oi.itemId == item.itemId,
      orElse: () => OrderChiTietModel(uid: ''),
    );
    soLuongControllers[item.itemId] = TextEditingController(text: existing.soLuong?.toString() ?? '');
    ghiChuControllers[item.itemId] = TextEditingController(text: existing.ghiChu ?? '');
    khachTraValues[item.itemId] = existing.khachTra ?? false;
    hasQuantity[item.itemId] = (existing.soLuong ?? 0) > 0;
  }
  
  // Create initial filtered list
  List<OrderMatHangModel> filteredItems = List.from(_availableItems);
  
  showDialog(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Thêm vật tư'),
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                List<OrderChiTietModel> itemsToSave = [];
                List<Map<String, dynamic>> itemsForApi = [];
                
                // Collect all items that have quantity
                for (var item in _availableItems) {
                  final soLuong = double.tryParse(soLuongControllers[item.itemId]?.text ?? '') ?? 0;
                  
                  if (soLuong > 0) {
                    final khachTra = khachTraValues[item.itemId] ?? false;
                    final ghiChu = ghiChuControllers[item.itemId]?.text ?? '';
                    final thanhTien = khachTra ? 0 : (soLuong * (item.donGia ?? 0)).round();
                    
                    final existingItem = _orderItems.firstWhere(
                      (oi) => oi.itemId == item.itemId,
                      orElse: () => OrderChiTietModel(uid: ''),
                    );
                    
                    final uid = existingItem.uid.isNotEmpty ? existingItem.uid : Uuid().v4();
                    
                    final orderChiTiet = OrderChiTietModel(
                      uid: uid,
                      orderId: widget.orderId,
                      itemId: item.itemId,
                      ten: item.ten,
                      phanLoai: item.phanLoai,
                      donVi: item.donVi,
                      soLuong: soLuong,
                      donGia: item.donGia,
                      khachTra: khachTra,
                      thanhTien: thanhTien,
                      ghiChu: ghiChu,
                    );
                    
                    itemsToSave.add(orderChiTiet);
                    itemsForApi.add({
                      ...orderChiTiet.toMap(),
                      'IsUpdate': existingItem.uid.isNotEmpty,
                    });
                  }
                }
                
                if (itemsToSave.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập số lượng cho ít nhất một vật tư'))
                  );
                  return;
                }
                
                try {
                  final apiPayload = itemsForApi.map((item) => {
                    'UID': item['UID'],
                    'OrderID': item['OrderID'],
                    'ItemID': item['ItemID'],
                    'Ten': item['Ten'],
                    'PhanLoai': item['PhanLoai'],
                    'GhiChu': item['GhiChu'],
                    'DonVi': item['DonVi'],
                    'SoLuong': item['SoLuong'],
                    'DonGia': item['DonGia'],
                    'KhachTra': item['KhachTra'],
                    'ThanhTien': item['ThanhTien'],
                    'IsUpdate': item['IsUpdate'],
                  }).toList();
                  
                  final response = await http.post(
                    Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtthemct'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(apiPayload),
                  );
                  
                  if (response.statusCode == 200) {
                    final DBHelper dbHelper = DBHelper();
                    
                    // Update items in local DB
                    for (var item in itemsToSave) {
                      final exists = _orderItems.any((oi) => oi.itemId == item.itemId);
                      if (exists) {
                        await dbHelper.updateOrderChiTiet(item.uid, item.toMap());
                      } else {
                        await dbHelper.insertOrderChiTiet(item);
                      }
                    }
                    
                    // Calculate new total
                    final allItems = await dbHelper.getOrderChiTietByOrderId(widget.orderId);
                    final newTotal = allItems.fold<int>(0, (sum, item) => sum + (item.thanhTien ?? 0));
                    
                    // Update order total on server
                    final updateOrderResponse = await http.post(
                      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtsua'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'OrderID': widget.orderId,
                        'TongTien': newTotal,
                      }),
                    );
                    
                    if (updateOrderResponse.statusCode == 200) {
                      // Update order total in local DB
                      await dbHelper.updateOrder(widget.orderId, {'TongTien': newTotal});
                      
                      // Reload all details
                      await _loadOrderDetails();
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã lưu ${itemsToSave.length} vật tư'))
                      );
                    }
                  }
                } catch (e) {
                  print('Error saving items: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi khi lưu vật tư'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('LƯU', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(width: 16),
          ],
        ),
        body: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              // Search box
              Padding(
                padding: EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm vật tư',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        filteredItems = List.from(_availableItems);
                      } else {
                        filteredItems = _availableItems
                            .where((item) => item.ten?.toLowerCase().contains(value.toLowerCase()) ?? false)
                            .toList();
                      }
                      
                      // Sort items with quantity > 0 to top
                      filteredItems.sort((a, b) {
                        final aQuantity = double.tryParse(soLuongControllers[a.itemId]?.text ?? '0') ?? 0;
                        final bQuantity = double.tryParse(soLuongControllers[b.itemId]?.text ?? '0') ?? 0;
                        return bQuantity.compareTo(aQuantity);
                      });
                    });
                  },
                ),
              ),
              // List of items
              Expanded(
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final soLuong = double.tryParse(soLuongControllers[item.itemId]?.text ?? '') ?? 0;
                    final khachTra = khachTraValues[item.itemId] ?? false;
                    final thanhTien = khachTra ? 0 : (soLuong * (item.donGia ?? 0)).round();
                    
                    return Card(
                      color: hasQuantity[item.itemId] == true 
                          ? Colors.green.withOpacity(0.1) 
                          : null,
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.ten ?? 'No name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Đơn vị: ${item.donVi ?? ''}'),
                                      Text('Đơn giá: ${formatter.format(item.donGia ?? 0)}'),
                                      if (soLuong > 0)
                                        Text('Thành tiền: ${formatter.format(thanhTien)}'),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        Text('Số lượng: '),
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            controller: soLuongControllers[item.itemId],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.all(8),
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                hasQuantity[item.itemId] = double.tryParse(value) != null && double.tryParse(value)! > 0;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text('Khách trả: '),
                                        Checkbox(
                                          value: khachTraValues[item.itemId],
                                          onChanged: (value) {
                                            setState(() {
                                              khachTraValues[item.itemId] = value ?? false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            TextField(
                              controller: ghiChuControllers[item.itemId],
                              decoration: InputDecoration(
                                labelText: 'Ghi chú',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
Future<void> _updateOrderStatus(String status) async {
  try {
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtsua'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'OrderID': widget.orderId,
        'TrangThai': status,
      }),
    );

    if (response.statusCode == 200) {
      final DBHelper dbHelper = DBHelper();
      await dbHelper.updateOrder(widget.orderId, {'TrangThai': status});

      setState(() {
        if (_orderDetails != null) {
          _orderDetails!.trangThai = status;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật trạng thái đơn hàng')),
      );
    }
  } catch (e) {
    print('Error updating order status: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi cập nhật trạng thái'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  Future<void> _loadOrderDetails() async {
    try {
      final DBHelper dbHelper = DBHelper();
      
      // Load order details
      _orderDetails = await dbHelper.getOrderByOrderId(widget.orderId);
      
      // Load order items
      _orderItems = await dbHelper.getOrderChiTietByOrderId(widget.orderId);
      
      setState(() {
        _isLoading = false;
      });
      
      print('Loaded order details: ${_orderDetails?.toMap()}');
      print('Loaded ${_orderItems.length} items');
      
    } catch (e) {
      print('Error loading order details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildItemImage(String? itemId) {
    if (itemId == null) return Container();
    
    // Find the corresponding MatHang item to get the HinhAnh
    final matchingItem = _availableItems.firstWhere(
      (item) => item.itemId == itemId,
      orElse: () => OrderMatHangModel(
        itemId: '', 
        ten: '', 
        donVi: '', // Added required 'donVi' parameter
      ),
    );
    
    final imageSource = matchingItem.hinhAnh ?? '';
    
    if (imageSource.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    if (imageSource.startsWith('http')) {
      // Handle URL images
      return Image.network(
        imageSource,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.error, color: Colors.grey),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(child: CircularProgressIndicator());
        },
      );
    } else if (imageSource.startsWith('assets/')) {
      // Handle asset images
      return Image.asset(
        imageSource,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.error, color: Colors.grey),
          );
        },
      );
    }

    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết đơn hàng'),
      ),
      body: _isLoading
    ? Center(child: CircularProgressIndicator())
    : _orderDetails == null
        ? Center(child: Text('Không tìm thấy đơn hàng'))
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
        Text('Tên đơn: ${_orderDetails!.tenDon ?? ''}'),
        Text('Bộ phận: ${_orderDetails!.boPhan ?? ''}'),
        Text('Người tạo: ${_orderDetails!.nguoiDung ?? ''}'),
        Text('Trạng thái: ${_orderDetails!.trangThai ?? ''}'),
        Text('Ngày tạo: ${_orderDetails!.ngay != null ? DateFormat('dd/MM/yyyy').format(_orderDetails!.ngay!) : ''}'),
        Text('Tổng tiền: ${formatter.format(_orderDetails!.tongTien ?? 0)}'),
        Text(
          'Định mức: ${formatter.format(_orderDetails!.dinhMuc ?? 0)}',
          style: TextStyle(
            color: (_orderDetails!.tongTien ?? 0) > (_orderDetails!.dinhMuc ?? 0)
                ? Colors.red
                : Colors.green,
            fontWeight: (_orderDetails!.tongTien ?? 0) > (_orderDetails!.dinhMuc ?? 0)
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        if (_orderDetails!.phanLoai != null)
          Text('Phân loại: ${_orderDetails!.phanLoai}'),
        if (_orderDetails!.vanDe != null)
          Text('Vấn đề: ${_orderDetails!.vanDe}'),
        if (_orderDetails!.ghiChu != null)
          Text('Ghi chú: ${_orderDetails!.ghiChu}'),
        if (_orderDetails!.trangThai == 'Nháp')
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _editOrder,
                  child: Text('Sửa'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _sendOrder,
                  child: Text('Gửi'),
                ),
              ],
            ),
          ),
        if (_orderDetails!.trangThai == 'Gửi' || _orderDetails!.trangThai == 'Chưa xem')
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _updateOrderStatus('Đồng ý'),
                  child: Text('Đồng ý'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _updateOrderStatus('Từ chối'),
                  child: Text('Từ chối'),
                ),
              ],
            ),
          ),
      ],
    ),
  ),
),
                ),
                Padding(
  padding: const EdgeInsets.all(16.0),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        'Danh sách vật tư',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (_orderDetails!.trangThai == 'Nháp' || 
          _orderDetails!.trangThai == 'Gửi' || 
          _orderDetails!.trangThai == 'Chưa xem')
        ElevatedButton.icon(
          icon: Icon(Icons.add),
          label: Text('Thêm'),
          onPressed: _showAddItemDialog,
        ),
    ],
  ),
),
                ..._orderItems.map((item) => Card(
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: ListTile(
    leading: Container(
      width: 60,
      height: 60,
      child: _buildItemImage(item.itemId),
    ),
    title: Text(item.ten ?? 'Chưa có tên'),
    subtitle: Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       Text('Số lượng: ${item.soLuong ?? 0} ${item.donVi ?? ''}'),
       Text('Đơn giá: ${formatter.format(item.donGia ?? 0)}'),
       if (item.phanLoai != null)
         Text('Phân loại: ${item.phanLoai}'),
       if (item.ghiChu != null)
         Text('Ghi chú: ${item.ghiChu}'),
       if (item.khachTra == true)
         Text('Khách trả: Có'),
     ],
   ),
   trailing: Text(formatter.format(item.thanhTien ?? 0)),
 ),
)).toList(),
             ],
           ),
         ),
   );
 }
}