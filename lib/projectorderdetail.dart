import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
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
  // Show confirmation dialog first
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Xác nhận gửi đơn hàng'),
      content: Text('Bạn có chắc chắn muốn gửi đơn hàng này? Sau khi gửi, bạn sẽ không thể chỉnh sửa đơn hàng nữa.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text('Xác nhận gửi'),
        ),
      ],
    ),
  );

  // If user cancelled, do nothing
  if (confirm != true) return;

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
List<OrderMatHangModel> getSortedItems(List<OrderMatHangModel> items) {
   return List<OrderMatHangModel>.from(items)..sort((a, b) {
     final aQuantity = double.tryParse(soLuongControllers[a.itemId]?.text ?? '0') ?? 0;
     final bQuantity = double.tryParse(soLuongControllers[b.itemId]?.text ?? '0') ?? 0;
     return bQuantity.compareTo(aQuantity); // Higher quantities first
   });
 }
 List<OrderMatHangModel> filteredItems = getSortedItems(_availableItems);

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
   showDialog(
     context: context,
     barrierDismissible: false,
     builder: (context) => Center(
       child: CircularProgressIndicator(),
     ),
   );

   try {
     List<OrderChiTietModel> itemsToSave = [];
     List<Map<String, dynamic>> itemsForApi = [];

     print('Current controllers state:');
     soLuongControllers.forEach((key, controller) {
       print('ItemID: $key, Quantity: ${controller.text}');
     });

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
       Navigator.pop(context);
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Vui lòng nhập số lượng cho ít nhất một vật tư'))
       );
       return;
     }
     
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
       
       for (var item in itemsToSave) {
         final exists = _orderItems.any((oi) => oi.itemId == item.itemId);
         if (exists) {
           await dbHelper.updateOrderChiTiet(item.uid, item.toMap());
         } else {
           await dbHelper.insertOrderChiTiet(item);
         }
       }

       final allItems = await dbHelper.getOrderChiTietByOrderId(widget.orderId);
       final newTotal = allItems.fold<int>(0, (sum, item) => sum + (item.thanhTien ?? 0));

       final updateOrderResponse = await http.post(
         Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtsua'),
         headers: {'Content-Type': 'application/json'},
         body: json.encode({
           'OrderID': widget.orderId,
           'TongTien': newTotal,
         }),
       );

       if (updateOrderResponse.statusCode == 200) {
         await dbHelper.updateOrder(widget.orderId, {'TongTien': newTotal});
         
         await _loadOrderDetails();
         Navigator.pop(context);
         Navigator.pop(context);
         
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Đã lưu ${itemsToSave.length} vật tư'))
         );
       }
     }
   } catch (e) {
     Navigator.pop(context);
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
                     // Filter items first
                     var filtered = _availableItems
                         .where((item) => item.ten?.toLowerCase().contains(value.toLowerCase()) ?? false)
                         .toList();
                     // Then sort the filtered list
                     filteredItems = getSortedItems(filtered);
                   });
                 },
               ),
             ),
             Expanded(
               child: SingleChildScrollView(
                 scrollDirection: Axis.horizontal,
                 child: SingleChildScrollView(
                   child: Column(
                     children: [
                       // Fixed header
                       Container(
                         color: Theme.of(context).scaffoldBackgroundColor,
                         child: DataTable(
                           columnSpacing: 20,
                           columns: [
                             DataColumn(label: Container(width: 150, child: Text('Tên vật tư'))),
                             DataColumn(label: Container(width: 60, child: Text('ĐVT'))),
                             DataColumn(label: Container(width: 100, child: Text('Số lượng'))),
                             DataColumn(label: Container(width: 100, child: Text('Đơn giá'))),
                             DataColumn(label: Container(width: 100, child: Text('Thành tiền'))),
                             DataColumn(label: Container(width: 80, child: Text('Khách trả'))),
                             DataColumn(label: Container(width: 120, child: Text('Ghi chú'))),
                           ],
                           rows: [],
                         ),
                       ),
                       // Scrollable content
                       DataTable(
                         columnSpacing: 20,
                         columns: [
                           DataColumn(label: Container(width: 150, child: Text(''))),
                           DataColumn(label: Container(width: 60, child: Text(''))),
                           DataColumn(label: Container(width: 100, child: Text(''))),
                           DataColumn(label: Container(width: 100, child: Text(''))),
                           DataColumn(label: Container(width: 100, child: Text(''))),
                           DataColumn(label: Container(width: 80, child: Text(''))),
                           DataColumn(label: Container(width: 120, child: Text(''))),
                         ],
                         rows: filteredItems.map((item) {
                           final soLuong = double.tryParse(soLuongControllers[item.itemId]?.text ?? '') ?? 0;
                           final khachTra = khachTraValues[item.itemId] ?? false;
                           final thanhTien = khachTra ? 0 : (soLuong * (item.donGia ?? 0)).round();
                           
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
                                     // Re-sort the list when quantities change
                                     filteredItems = getSortedItems(filteredItems);
                                   });
                                 },
                               )),
                               DataCell(Text(formatter.format(item.donGia ?? 0))),
                               DataCell(Text(formatter.format(thanhTien))),
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
                     ],
                   ),
                 ),
               ),
             ),
           ],
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
Future<void> _addItemsFromPreviousMonth() async {
  try {
    setState(() {
      _isLoading = true;
    });
    
    final DBHelper dbHelper = DBHelper();
    
    // Get current order details
    final currentOrder = await dbHelper.getOrderByOrderId(widget.orderId);
    if (currentOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy thông tin đơn hàng hiện tại'))
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Get the date from current order
    final currentDate = currentOrder.ngay;
    if (currentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đơn hàng hiện tại không có ngày'))
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Calculate previous month date range
    final previousMonthStart = DateTime(currentDate.year, currentDate.month - 1, 1);
    final previousMonthEnd = DateTime(currentDate.year, currentDate.month, 0);
    
    // Find orders from previous month with same BoPhan and NguoiDung
    final previousOrders = await dbHelper.getOrdersByDateRangeAndDetails(
      previousMonthStart,
      previousMonthEnd,
      boPhan: currentOrder.boPhan,
      nguoiDung: currentOrder.nguoiDung
    );
    
    if (previousOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy đơn hàng tháng trước'))
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Sort by date to find the closest one
    previousOrders.sort((a, b) => b.ngay!.compareTo(a.ngay!));
    final closestPreviousOrder = previousOrders.first;
    
    // Get items from the previous order
    final previousItems = await dbHelper.getOrderChiTietByOrderId(closestPreviousOrder.orderId!);
    
    if (previousItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đơn hàng tháng trước không có vật tư'))
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Get current items to avoid duplicates
    final currentItems = await dbHelper.getOrderChiTietByOrderId(widget.orderId);
    final currentItemIds = currentItems.map((e) => e.itemId).toSet();
    
    // Prepare items to add (exclude duplicates)
    final List<OrderChiTietModel> itemsToAdd = [];
    final List<Map<String, dynamic>> itemsForApi = [];
    
    for (var item in previousItems) {
      // Skip if item already exists in current order
      if (currentItemIds.contains(item.itemId)) continue;
      
      final uid = Uuid().v4();
      final orderChiTiet = OrderChiTietModel(
        uid: uid,
        orderId: widget.orderId,
        itemId: item.itemId,
        ten: item.ten,
        phanLoai: item.phanLoai,
        donVi: item.donVi,
        soLuong: item.soLuong,
        donGia: item.donGia,
        khachTra: item.khachTra,
        thanhTien: item.khachTra == true ? 0 : ((item.soLuong ?? 0) * (item.donGia ?? 0)).round(),
        ghiChu: item.ghiChu,
      );
      
      itemsToAdd.add(orderChiTiet);
      itemsForApi.add({
        ...orderChiTiet.toMap(),
        'IsUpdate': false,
      });
    }
    
    if (itemsToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không có vật tư mới để thêm từ đơn hàng tháng trước'))
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Send to API
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
      // Add items to local database
      for (var item in itemsToAdd) {
        await dbHelper.insertOrderChiTiet(item);
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
        
        // Reload order details
        await _loadOrderDetails();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm ${itemsToAdd.length} vật tư từ đơn hàng tháng trước'))
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thêm vật tư từ đơn hàng tháng trước'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('Error adding items from previous month: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
Future<void> _showDeleteItemsDialog() async {
  // Track which items are selected for deletion
  final Map<String, bool> selectedItems = {};
  
  // Initialize all items as unselected
  for (var item in _orderItems) {
    selectedItems[item.uid] = false;
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Xoá vật tư'),
      content: StatefulBuilder(
        builder: (context, setState) => Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chọn vật tư cần xoá:'),
              SizedBox(height: 8),
              Container(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _orderItems.length,
                  itemBuilder: (context, index) {
                    final item = _orderItems[index];
                    return CheckboxListTile(
                      title: Text(item.ten ?? 'Không có tên'),
                      subtitle: Text('SL: ${item.soLuong} ${item.donVi ?? ''} - ${formatter.format(item.thanhTien ?? 0)}'),
                      value: selectedItems[item.uid],
                      onChanged: (bool? value) {
                        setState(() {
                          selectedItems[item.uid] = value ?? false;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Huỷ'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            // Get selected items for deletion
            final itemsToDelete = selectedItems.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList();
                
            if (itemsToDelete.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Vui lòng chọn ít nhất một vật tư để xoá'))
              );
              return;
            }
            
            try {
              // Delete on server first
              final response = await http.post(
                Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtxoact'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'ItemUIDs': itemsToDelete,
                }),
              );
              
              if (response.statusCode == 200) {
                final DBHelper dbHelper = DBHelper();
                
                // Delete locally
                for (var uid in itemsToDelete) {
                  await dbHelper.deleteOrderChiTiet(uid);
                }
                
                // Calculate new total
                final remainingItems = await dbHelper.getOrderChiTietByOrderId(widget.orderId);
                final newTotal = remainingItems.fold<int>(0, (sum, item) => sum + (item.thanhTien ?? 0));
                
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
                    SnackBar(content: Text('Đã xoá ${itemsToDelete.length} vật tư'))
                  );
                }
              }
            } catch (e) {
              print('Error deleting items: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Lỗi khi xoá vật tư'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Text('Xoá'),
        ),
      ],
    ),
  );
}
Future<void> _deleteOrder() async {
  // Show confirmation dialog first
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Xác nhận xoá đơn hàng'),
      content: Text('Bạn có chắc chắn muốn xoá đơn hàng này? Hành động này không thể hoàn tác và tất cả vật tư trong đơn sẽ bị xoá.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('Xác nhận xoá'),
        ),
      ],
    ),
  );

  // If user cancelled, do nothing
  if (confirm != true) return;

  try {
    // Delete order on server first
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtxoa'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'OrderID': widget.orderId}),
    );

    if (response.statusCode == 200) {
      // Then delete from local database
      final DBHelper dbHelper = DBHelper();
      
      try {
        // Get the actual table name from DatabaseTables
        final db = await dbHelper.database;
        
        // Delete all items first using raw SQL with the correct table name
        await db.rawDelete(
          'DELETE FROM ${DatabaseTables.orderChiTietTable} WHERE OrderID = ?',
          [widget.orderId]
        );
        
        // Then delete the order
        await db.rawDelete(
          'DELETE FROM ${DatabaseTables.orderTable} WHERE OrderID = ?',
          [widget.orderId]
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xoá đơn hàng thành công')),
        );
        
        // Navigate back
        Navigator.pop(context);
      } catch (e) {
        print('Error deleting from local database: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đơn hàng đã xoá từ máy chủ nhưng lỗi khi xoá cơ sở dữ liệu cục bộ'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xoá đơn hàng từ máy chủ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('Error deleting order: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi xoá đơn hàng: $e'),
        backgroundColor: Colors.red,
      ),
    );
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
  'Tổng tiền: ${formatter.format(_orderDetails!.tongTien ?? 0)}',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),
Text(
  'Định mức: ${formatter.format(_orderDetails!.dinhMuc ?? 0)}',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: (_orderDetails!.tongTien ?? 0) > (_orderDetails!.dinhMuc ?? 0)
        ? Colors.red
        : Colors.green,
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
        SizedBox(width: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: _deleteOrder,
          child: Text('Xoá'),
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
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Danh sách VT:',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (_orderDetails!.trangThai == 'Nháp')
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Thêm'),
                onPressed: _showAddItemDialog,
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.history),
                label: Text('Như tháng trước'),
                onPressed: _addItemsFromPreviousMonth,
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.delete),
                label: Text('Xoá'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: _showDeleteItemsDialog,
              ),
            ],
          ),
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
Widget _buildItemImage(String? itemId) {
  if (itemId == null) return Container();
  
  final matchingItem = _availableItems.firstWhere(
    (item) => item.itemId == itemId,
    orElse: () => OrderMatHangModel(
      itemId: '', 
      ten: '', 
      donVi: '',
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
}