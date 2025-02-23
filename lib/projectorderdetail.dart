import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'http_client.dart';

class ProjectOrderDetail extends StatefulWidget {
  final String orderId;
  final String boPhan;

  const ProjectOrderDetail({
    Key? key,
    required this.orderId,
    required this.boPhan,
  }) : super(key: key);

  @override
  _ProjectOrderDetailState createState() => _ProjectOrderDetailState();
}

class _ProjectOrderDetailState extends State<ProjectOrderDetail> {
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
 final List<OrderChiTietModel> newItems = [];
 final selectedItems = Map<String, Map<String, dynamic>>();
 final Map<String, bool> hasQuantity = {};
 final Map<String, TextEditingController> soLuongControllers = {};
 final Map<String, TextEditingController> ghiChuControllers = {};
 final Map<String, bool> khachTraValues = {};

 for (var item in _availableItems) {
   final existing = _orderItems.firstWhere(
     (oi) => oi.itemId == item.itemId,
     orElse: () => OrderChiTietModel(uid: ''),
   );
   soLuongControllers[item.itemId] = TextEditingController(text: existing.soLuong?.toString() ?? '');
   ghiChuControllers[item.itemId] = TextEditingController(text: existing.ghiChu ?? '');
   khachTraValues[item.itemId] = existing.khachTra ?? false;
 }

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

    // Log initial state
    print('Current controllers state:');
    soLuongControllers.forEach((key, controller) {
      print('ItemID: $key, Quantity: ${controller.text}');
    });

    // Collect all items that have quantity
    for (var item in _availableItems) {
      final soLuong = double.tryParse(soLuongControllers[item.itemId]?.text ?? '') ?? 0;
      
      print('Processing item ${item.itemId}: quantity = $soLuong');
      
      if (soLuong > 0) {
        final khachTra = khachTraValues[item.itemId] ?? false;
        final ghiChu = ghiChuControllers[item.itemId]?.text ?? '';
        final thanhTien = khachTra ? 0 : (soLuong * (item.donGia ?? 0)).round();

        final existingItem = _orderItems.firstWhere(
          (oi) => oi.itemId == item.itemId,
          orElse: () => OrderChiTietModel(uid: ''),
        );

        final uid = existingItem.uid.isNotEmpty ? existingItem.uid : Uuid().v4();

        print('Creating/Updating item: ID=${item.itemId}, UID=$uid, Quantity=$soLuong, CustomerReturn=$khachTra');

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

    print('Items to save: ${itemsToSave.length}');
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
         builder: (context, setState) => SingleChildScrollView(
           scrollDirection: Axis.horizontal,
           child: SingleChildScrollView(
             child: DataTable(
               columnSpacing: 20,
               columns: [
                 DataColumn(label: Container(width: 150, child: Text('Tên vật tư'))),
                 DataColumn(label: Container(width: 60, child: Text('ĐVT'))),
                 DataColumn(label: Container(width: 100, child: Text('Số lượng'))),
                 DataColumn(label: Container(width: 80, child: Text('Khách trả'))),
                 DataColumn(label: Container(width: 120, child: Text('Ghi chú'))),
               ],
               rows: _availableItems.map((item) {
                 return DataRow(
                   color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                     return hasQuantity[item.itemId] == true ? Colors.green.withOpacity(0.1) : null;
                   }),
                   cells: [
                     DataCell(Container(
                       width: 150,
                       child: Text(item.ten ?? '', softWrap: true, maxLines: 3, overflow: TextOverflow.ellipsis),
                     )),
                     DataCell(Text(item.donVi ?? '')),
                     DataCell(TextField(
                       controller: soLuongControllers[item.itemId],
                       keyboardType: TextInputType.number,
                       decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                       onChanged: (value) {
                         setState(() {
                           hasQuantity[item.itemId] = double.tryParse(value) != null && double.tryParse(value)! > 0;
                           selectedItems[item.itemId] = {
                             'soLuong': value,
                             'khachTra': khachTraValues[item.itemId],
                             'ghiChu': ghiChuControllers[item.itemId]?.text,
                             'item': item,
                           };
                         });
                       },
                     )),
                     DataCell(Checkbox(
                       value: khachTraValues[item.itemId],
                       onChanged: (bool? value) {
                         setState(() {
                           khachTraValues[item.itemId] = value ?? false;
                           selectedItems[item.itemId] = {
                             'soLuong': soLuongControllers[item.itemId]?.text,
                             'khachTra': value,
                             'ghiChu': ghiChuControllers[item.itemId]?.text,
                             'item': item,
                           };
                         });
                       },
                     )),
                     DataCell(TextField(
                       controller: ghiChuControllers[item.itemId],
                       decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                       onChanged: (value) {
                         selectedItems[item.itemId] = {
                           'soLuong': soLuongControllers[item.itemId]?.text,
                           'khachTra': khachTraValues[item.itemId],
                           'ghiChu': value,
                           'item': item,
                         };
                       },
                     )),
                   ],
                 );
               }).toList(),
             ),
           ),
         ),
       ),
     ),
   ),
 );
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
                      if (_orderDetails!.trangThai == 'Nháp')
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