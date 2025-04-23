import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'http_client.dart';
import 'dart:core';

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
    setState(() => _isLoading = true);
    
    final DBHelper dbHelper = DBHelper();
    var items = await dbHelper.getAllOrderMatHang();
    
    // If no items are found, try to sync with server
    if (items.isEmpty) {
      print('No order items found in database, attempting to sync from server');
      
      // Show syncing indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đang đồng bộ danh sách vật tư từ server...'))
        );
      }
      
      try {
        final response = await http.get(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordermathang'),
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> orderMatHangData = json.decode(response.body);
          
          await dbHelper.clearTable(DatabaseTables.orderMatHangTable);
          
          final orderMatHangModels = orderMatHangData.map((data) => 
            OrderMatHangModel.fromMap(data as Map<String, dynamic>)
          ).toList();
          
          await dbHelper.batchInsertOrderMatHang(orderMatHangModels);
          
          // Get the updated list
          items = await dbHelper.getAllOrderMatHang();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã đồng bộ ${items.length} vật tư thành công'))
            );
          }
        } else {
          throw Exception('Server returned status ${response.statusCode}');
        }
      } catch (e) {
        print('Error syncing order items: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi đồng bộ danh sách vật tư: $e'),
              backgroundColor: Colors.red,
            )
          );
        }
      }
    }
    
    setState(() {
      _availableItems = items;
      _isLoading = false;
    });
    
    print('Loaded ${_availableItems.length} available items');
  } catch (e) {
    print('Error loading available items: $e');
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải danh sách vật tư: $e'))
      );
    }
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
  setState(() => _isLoading = true);
  
  // Force reload available items to ensure we have the latest data
  try {
    final DBHelper dbHelper = DBHelper();
    final items = await dbHelper.getAllOrderMatHang();
    _availableItems = items;
    print('Loaded ${_availableItems.length} available items for dialog');
  } catch (e) {
    print('Error reloading items: $e');
  }
  
  setState(() => _isLoading = false);
  
  if (_availableItems.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể tải danh sách vật tư. Vui lòng thử lại sau.'))
    );
    return;
  }
  
  final selectedItems = Map<String, Map<String, dynamic>>();
  final Map<String, bool> hasQuantity = {};
  final Map<String, TextEditingController> soLuongControllers = {};
  final Map<String, TextEditingController> ghiChuControllers = {};
  final Map<String, bool> khachTraValues = {};
  final searchController = TextEditingController();
  
  // Initialize controllers and values for all available items
  for (var item in _availableItems) {
    final existing = _orderItems.firstWhere(
      (oi) => oi.itemId == item.itemId,
      orElse: () => OrderChiTietModel(uid: ''),
    );
    
    soLuongControllers[item.itemId] = TextEditingController(
      text: existing.uid.isNotEmpty ? existing.soLuong?.toString() ?? '' : ''
    );
    
    ghiChuControllers[item.itemId] = TextEditingController(
      text: existing.ghiChu ?? ''
    );
    
    khachTraValues[item.itemId] = existing.khachTra ?? false;
    hasQuantity[item.itemId] = existing.soLuong != null && existing.soLuong! > 0;
  }
  
  // Function to sort items (items with quantity > 0 first)
  List<OrderMatHangModel> getSortedItems(List<OrderMatHangModel> items) {
    return List<OrderMatHangModel>.from(items)..sort((a, b) {
      final aQuantity = double.tryParse(soLuongControllers[a.itemId]?.text ?? '0') ?? 0;
      final bQuantity = double.tryParse(soLuongControllers[b.itemId]?.text ?? '0') ?? 0;
      if (aQuantity > 0 && bQuantity <= 0) return -1;
      if (aQuantity <= 0 && bQuantity > 0) return 1;
      return a.ten?.compareTo(b.ten ?? '') ?? 0;
    });
  }
  
  // Initial sorted and filtered items
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
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(child: CircularProgressIndicator()),
                );
                
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
                  
                  // Close loading indicator
                  Navigator.of(context).pop();
                  
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
                      
                      // Close the dialog
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã lưu ${itemsToSave.length} vật tư'))
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi khi lưu: ${response.statusCode}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  // Close loading indicator if error occurs
                  Navigator.of(context).pop();
                  
                  print('Error saving items: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi khi lưu vật tư: $e'),
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
                        filteredItems = getSortedItems(_availableItems);
                      } else {
                        filteredItems = getSortedItems(_availableItems
                            .where((item) => 
                                (item.ten?.toLowerCase().contains(value.toLowerCase()) ?? false) ||
                                (item.phanLoai?.toLowerCase().contains(value.toLowerCase()) ?? false)
                            )
                            .toList());
                      }
                    });
                  },
                ),
              ),
              
              // Status text
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hiển thị: ${filteredItems.length}/${_availableItems.length} vật tư',
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                    if (filteredItems.isEmpty && _availableItems.isNotEmpty)
                      TextButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Tải lại'),
                        onPressed: () {
                          setState(() {
                            searchController.clear();
                            filteredItems = getSortedItems(_availableItems);
                          });
                        },
                      ),
                  ],
                ),
              ),
              
              // List of items
              Expanded(
                child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            _availableItems.isEmpty 
                              ? 'Không có vật tư nào. Vui lòng thêm vật tư trước.'
                              : 'Không tìm thấy vật tư phù hợp.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Item image (if available)
                                    if (item.hinhAnh != null && item.hinhAnh!.isNotEmpty)
                                      Container(
                                        width: 60,
                                        height: 60,
                                        margin: EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: Image.network(
                                            item.hinhAnh!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(Icons.image_not_supported, color: Colors.grey[400]);
                                            },
                                          ),
                                        ),
                                      ),
                                    
                                    // Item details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.ten ?? 'Không có tên',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          SizedBox(height: 4),
                                          Text('Đơn vị: ${item.donVi ?? ''}'),
                                          Text('Đơn giá: ${formatter.format(item.donGia ?? 0)}'),
                                          if (item.phanLoai != null)
                                            Text('Phân loại: ${item.phanLoai}'),
                                          if (soLuong > 0)
                                            Text(
                                              'Thành tiền: ${formatter.format(thanhTien)}',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    // Quantity field
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: soLuongControllers[item.itemId],
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Số lượng',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            hasQuantity[item.itemId] = double.tryParse(value) != null && double.tryParse(value)! > 0;
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    
                                    // Customer pays checkbox
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: khachTraValues[item.itemId],
                                            onChanged: (value) {
                                              setState(() {
                                                khachTraValues[item.itemId] = value ?? false;
                                              });
                                            },
                                          ),
                                          Text('Khách trả'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                
                                // Notes field
                                TextField(
                                  controller: ghiChuControllers[item.itemId],
                                  decoration: InputDecoration(
                                    labelText: 'Ghi chú',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        Text('Tổng tiền: ${formatter.format(_orderDetails!.tongTien ?? 0)}', style: TextStyle(
            color: (_orderDetails!.tongTien ?? 0) > (_orderDetails!.dinhMuc ?? 0)
                ? Colors.red
                : Colors.green,
            fontWeight: (_orderDetails!.tongTien ?? 0) > (_orderDetails!.dinhMuc ?? 0)
                ? FontWeight.bold
                : FontWeight.normal,
          ),),
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
      Row(
        children: [
          if (_orderDetails!.trangThai == 'Nháp' || 
             _orderDetails!.trangThai == 'Gửi' || 
             _orderDetails!.trangThai == 'Chưa xem')
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Thêm'),
              onPressed: _showAddItemDialog,
            ),
          SizedBox(width: 8),
          if (_orderDetails!.trangThai == 'Nháp' || 
             _orderDetails!.trangThai == 'Gửi' || 
             _orderDetails!.trangThai == 'Chưa xem')
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
 // Add this method to implement item deletion
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
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(child: CircularProgressIndicator()),
              );
              
              // Delete on server first
              final response = await http.post(
  Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/ordervtxoact'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({'ItemUIDs': itemsToDelete}),
);   
              Navigator.pop(context); // Close loading dialog
              
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
                  content: Text('Lỗi khi xoá vật tư: $e'),
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
}