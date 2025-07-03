// lib/order_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'table_models.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String customerName;

  const OrderDetailsScreen({
    Key? key,
    required this.orderId,
    required this.customerName,
  }) : super(key: key);

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final DBHelper _dbHelper = DBHelper();
  
  // Order information
  DonHangModel? _orderInfo;
  List<ChiTietDonModel> _orderItems = [];
  bool _isLoading = true;
  
  // Summary data
  int _totalAmount = 0;
  int _totalQuantity = 0;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get order information
      await _loadOrderInfo();
      // Get order items 
      await _loadOrderItems();
      _calculateSummary();
    } catch (e) {
      print('Error loading order details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải thông tin đơn hàng: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrderInfo() async {
    try {
      _orderInfo = await _dbHelper.getDonHangBySoPhieu(widget.orderId);
    } catch (e) {
      print('Error loading order info: $e');
    }
  }

  Future<void> _loadOrderItems() async {
    try {
      _orderItems = await _dbHelper.getChiTietDonBySoPhieu(widget.orderId);
    } catch (e) {
      print('Error loading order items: $e');
      _orderItems = [];
    }
  }

  void _calculateSummary() {
  _totalAmount = 0;
  _totalQuantity = 0;
  
  for (var item in _orderItems) {
    // Fix: Convert to int explicitly
    _totalAmount += item.thanhTien ?? 0;
    _totalQuantity += (item.soLuongYeuCau ?? 0).toInt(); // Convert num to int
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : DraggableScrollableSheet(
              initialChildSize: 1.0,
              minChildSize: 0.5,
              maxChildSize: 1.0,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  // Header with order summary (matching your existing style)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF534b0d),
                    ),
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Chi tiết đơn hàng',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Số phiếu: ${widget.orderId}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              Spacer(),
                              if (_orderInfo != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(_orderInfo!.trangThai).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _getStatusColor(_orderInfo!.trangThai),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _getStatusDisplayName(_orderInfo!.trangThai ?? 'N/A'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Order Details Section
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (_orderInfo != null) ...[
                          // Customer Information
                          Container(
                            color: Colors.grey[100],
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '┇ Thông tin khách hàng ┇',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                ),
                                SizedBox(height: 10),
                                _buildDetailItem('Tên khách hàng', _orderInfo!.tenKhachHang2),
                                _buildDetailItem('Số điện thoại', _orderInfo!.sdtKhachHang),
                                _buildDetailItem('Địa chỉ', _orderInfo!.diaChi),
                                _buildDetailItem('Mã số thuế', _orderInfo!.mst),
                                _buildDetailItem('Số PO', _orderInfo!.soPO),
                                _buildDetailItem('Tên người giao dịch', _orderInfo!.tenNguoiGiaoDich),
                                _buildDetailItem('SĐT người GD', _orderInfo!.sdtNguoiGiaoDich),
                                _buildDetailItem('Bộ phận GD', _orderInfo!.boPhanGiaoDich),
                                _buildDetailItem('Địa chỉ giao hàng', _orderInfo!.diaChiGiaoHang),
                                _buildDetailItem('Người nhận hàng', _orderInfo!.nguoiNhanHang),
                                _buildDetailItem('SĐT người nhận', _orderInfo!.sdtNguoiNhanHang),
                              ],
                            ),
                          ),

                          // Order Information
                          Container(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thông tin đơn hàng',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailItem(
                                        'Ngày tạo',
                                        _orderInfo!.ngay != null
                                            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_orderInfo!.ngay!))
                                            : 'N/A'
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailItem('Số PO', _orderInfo!.soPO),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailItem('Người tạo', _orderInfo!.nguoiTao),
                                    ),
                                    Expanded(
                                      child: _buildDetailItem('Thanh toán', _orderInfo!.phuongThucThanhToan),
                                    ),
                                  ],
                                ),
                                _buildDetailItem('Phương thức giao hàng', _orderInfo!.phuongThucGiaoHang),
                                _buildDetailItem('Ghi chú', _orderInfo!.ghiChu ?? 'Không có'),
                              ],
                            ),
                          ),
                        ],

                        // Order Items Section
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.grey[100],
                          child: Row(
                            children: [
                              Text(
                                'Danh sách sản phẩm (${_orderItems.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Spacer(),
                              Text(
                                _formatCurrency(_totalAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // List of items (matching your existing style)
                        if (_orderItems.isEmpty)
                          Container(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                                SizedBox(height: 16),
                                Text(
                                  'Không có sản phẩm nào trong đơn hàng này',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._orderItems.map((item) => Card(
                            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.idHang != null
                                              ? item.idHang!.contains(" - ")
                                                  ? item.idHang!.split(" - ")[1]
                                                  : item.idHang!
                                              : 'N/A',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        _formatCurrency(item.thanhTien),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Mã hàng: ',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        item.maHang ?? 'N/A',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              'SL: ',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${item.soLuongYeuCau ?? 0} ${item.donViTinh ?? ''}',
                                              style: TextStyle(fontSize: 14, color: Colors.green),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              'Thực giao: ',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${item.soLuongThucGiao ?? 0}',
                                              style: TextStyle(fontSize: 14, color: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'Đơn giá: ',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(item.donGia),
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (item.ghiChu != null && item.ghiChu!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Ghi chú: ',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              item.ghiChu!,
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )).toList(),

                        // Footer with totals (matching your existing style)
                        if (_orderInfo != null)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              border: Border(
                                top: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tổng tiền:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(_orderInfo!.tongTien),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('VAT:'),
                                    Text(_formatCurrency(_orderInfo!.vat10)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tổng cộng:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(_orderInfo!.tongCong),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // Additional financial details
                                if (_orderInfo!.hoaHong10 != null && _orderInfo!.hoaHong10! > 0)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Hoa hồng 10%:'),
                                      Text(_formatCurrency(_orderInfo!.hoaHong10)),
                                    ],
                                  ),
                                if (_orderInfo!.tienGui10 != null && _orderInfo!.tienGui10! > 0) ...[
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Tiền gửi 10%:'),
                                      Text(_formatCurrency(_orderInfo!.tienGui10)),
                                    ],
                                  ),
                                ],
                                if (_orderInfo!.vanChuyen != null && _orderInfo!.vanChuyen! > 0) ...[
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Vận chuyển:'),
                                      Text(_formatCurrency(_orderInfo!.vanChuyen)),
                                    ],
                                  ),
                                ],
                                if (_orderInfo!.thucThu != null && _orderInfo!.thucThu! > 0) ...[
                                  SizedBox(height: 8),
                                  Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Thực thu:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(_orderInfo!.thucThu),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    switch (status.toLowerCase()) {
      case 'gửi':
      case 'gửi xuất nội bộ':
      case 'dự trù':
      case 'chờ duyệt':
        return Colors.orange;
      case 'đã duyệt':
      case 'duyệt':
        return Colors.green;
      case 'đã giao':
        return Colors.blue;
      case 'đã huỷ':
        return Colors.red;
      case 'chưa xong':
        return Colors.purple;
      case 'xuất nội bộ':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'gửi':
        return 'Chờ duyệt';
      case 'gửi xuất nội bộ':
        return 'Chờ duyệt (Nội bộ)';
      case 'dự trù':
        return 'Chờ duyệt (Dự trù)';
      case 'chờ duyệt':
        return 'Đang xử lý';
      case 'đã duyệt':
      case 'duyệt':
        return 'Đã duyệt';
      case 'đã giao':
        return 'Đã giao hàng';
      case 'đã huỷ':
        return 'Đã huỷ';
      case 'chưa xong':
        return 'Chưa hoàn thành';
      case 'xuất nội bộ':
        return 'Xuất nội bộ';
      default:
        return status;
    }
  }

  String _formatCurrency(int? amount) {
    if (amount == null) return '0 đ';

    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    return formatter.format(amount);
  }
}