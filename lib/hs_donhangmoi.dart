import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HSDonHangMoiScreen extends StatefulWidget {
  final bool editMode;
  final String? soPhieu;
  
  const HSDonHangMoiScreen({
    Key? key,
    this.editMode = false,
    this.soPhieu,
  }) : super(key: key);

  @override
  _HSDonHangMoiScreenState createState() => _HSDonHangMoiScreenState();
}

class _HSDonHangMoiScreenState extends State<HSDonHangMoiScreen> {
  final DBHelper _dbHelper = DBHelper();
  final currencyFormat = NumberFormat('#,###', 'vi_VN');
  bool get isEditMode => widget.editMode;
  DonHangModel? _existingOrder;
  // Screen state
  int _currentStep = 0; // 0: Customer selection, 1: Order details, 2: Product selection
  
  // Customer selection variables
  List<KhachHangModel> _khachHangList = [];
  List<KhachHangModel> _filteredList = [];
  KhachHangModel? _selectedCustomer;
  List<KhachHangContactModel> _customerContacts = [];
  String _searchText = '';
  TextEditingController _searchController = TextEditingController();
  
  // Order form controllers
  TextEditingController _diaChiController = TextEditingController();
  TextEditingController _sdtKhachHangController = TextEditingController();
  TextEditingController _poController = TextEditingController();
  TextEditingController _giayToCanKhiGiaoHangController = TextEditingController();
  TextEditingController _thoiGianVietHoaDonController = TextEditingController(text: 'Hoá đơn viết ngay khi giao hàng');
  TextEditingController _thongTinVietHoaDonController = TextEditingController();
  TextEditingController _diaChiGiaoHangController = TextEditingController();
  TextEditingController _hoTenNguoiNhanHoaHongController = TextEditingController();
  TextEditingController _sdtNguoiNhanHoaHongController = TextEditingController();
  TextEditingController _hinhThucChuyenHoaHongController = TextEditingController();
  TextEditingController _thongTinNhanHoaHongController = TextEditingController();
  TextEditingController _phuongTienGiaoHangController = TextEditingController();
  TextEditingController _hoTenNguoiGiaoHangController = TextEditingController();
  TextEditingController _ghiChuController = TextEditingController();
  TextEditingController _giaNetController = TextEditingController();
  TextEditingController _tenKhachHang2Controller = TextEditingController();
  TextEditingController _tenNguoiGiaoDichController = TextEditingController();
  TextEditingController _boPhanGiaoDichController = TextEditingController();
  TextEditingController _sdtNguoiGiaoDichController = TextEditingController();
  TextEditingController _tenNguoiNhanHangController = TextEditingController();
TextEditingController _sdtNguoiNhanHangController = TextEditingController();
  // Order form values
  String _tapKH = 'KH Truyền thống';
  String _phuongThucThanhToan = 'Chuyển khoản';
  int _thanhToanSauNhanHangXNgay = 40;
  int _datCocSauXNgay = 0;
  DateTime _ngayYeuCauGiao = DateTime.now().add(Duration(days: 7)); // Default to 1 week from now
  
  // Product selection variables
  List<DSHangModel> _dshangList = [];
  List<DSHangModel> _filteredDSHangList = [];
  List<ChiTietDonModel> _chiTietDonList = [];
  String _productSearchText = '';
  TextEditingController _productSearchController = TextEditingController();
  
  // For editing fields in order summary
  TextEditingController _hoaHong10Controller = TextEditingController(text: '0');
  TextEditingController _tienGui10Controller = TextEditingController(text: '0');
  TextEditingController _thueTNDNController = TextEditingController(text: '0');
  TextEditingController _vanChuyenController = TextEditingController(text: '0');
  
  // Order data
  DonHangModel? _newOrder;
  
  // Calculated totals
  int _tongTien = 0;
  int _vat10 = 0;
  int _tongCong = 0;
  int _thucThu = 0;
  
  bool _isLoading = true;
  
  // Color scheme to match main app
  final Color appBarTop = Color(0xFF024965);
  final Color appBarBottom = Color(0xFF03a6cf);
  final Color buttonColor = Color(0xFF33a7ce);
  
@override
void initState() {
  super.initState();
  if (isEditMode && widget.soPhieu != null) {
    _loadExistingOrder();
  } else {
    _loadKhachHangData();
  }
}

  @override
  void dispose() {
    // Dispose all controllers
    _searchController.dispose();
    _productSearchController.dispose();
    _diaChiController.dispose();
    _sdtKhachHangController.dispose();
    _poController.dispose();
    _giayToCanKhiGiaoHangController.dispose();
    _thoiGianVietHoaDonController.dispose();
    _thongTinVietHoaDonController.dispose();
    _diaChiGiaoHangController.dispose();
    _hoTenNguoiNhanHoaHongController.dispose();
    _sdtNguoiNhanHoaHongController.dispose();
    _hinhThucChuyenHoaHongController.dispose();
    _thongTinNhanHoaHongController.dispose();
    _phuongTienGiaoHangController.dispose();
    _hoTenNguoiGiaoHangController.dispose();
    _ghiChuController.dispose();
    _giaNetController.dispose();
    _tenKhachHang2Controller.dispose();
    _tenNguoiGiaoDichController.dispose();
    _boPhanGiaoDichController.dispose();
    _sdtNguoiGiaoDichController.dispose();
    _hoaHong10Controller.dispose();
    _tienGui10Controller.dispose();
    _thueTNDNController.dispose();
    _vanChuyenController.dispose();
      _tenNguoiNhanHangController.dispose();
  _sdtNguoiNhanHangController.dispose();
    super.dispose();
  }
  Future<void> _loadExistingOrder() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Load the existing order
    _existingOrder = await _dbHelper.getDonHangBySoPhieu(widget.soPhieu!);
    
    if (_existingOrder == null) {
      throw Exception('Không tìm thấy đơn hàng');
    }
    
    // Load customer data first
    await _loadKhachHangData();
    
    // Find and select the customer
    final customer = _khachHangList.firstWhere(
      (c) => c.tenDuAn == _existingOrder!.tenKhachHang,
      orElse: () => _khachHangList.first,
    );
    
    // Pre-populate form fields with existing order data
    await _populateFormWithExistingData(customer);
    
    // Load existing order items
    await _loadExistingOrderItems();
    
    setState(() {
      _isLoading = false;
      _currentStep = 1; // Start at order details step
    });
    
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi tải đơn hàng: $e'),
        backgroundColor: Colors.red,
      ),
    );
    
    Navigator.pop(context);
  }
}

Future<void> _populateFormWithExistingData(KhachHangModel customer) async {
  _selectedCustomer = customer;
  
  // Load customer contacts
  await _loadCustomerContacts(customer.uid ?? '');
  
  // Populate all form fields with existing order data
  _diaChiController.text = _existingOrder!.diaChi ?? '';
  _sdtKhachHangController.text = _existingOrder!.sdtKhachHang ?? '';
  _poController.text = _existingOrder!.soPO ?? '';
  _giayToCanKhiGiaoHangController.text = _existingOrder!.giayToCanKhiGiaoHang ?? '';
  _thoiGianVietHoaDonController.text = _existingOrder!.thoiGianVietHoaDon ?? 'Hoá đơn viết ngay khi giao hàng';
  _thongTinVietHoaDonController.text = _existingOrder!.thongTinVietHoaDon ?? '';
  _diaChiGiaoHangController.text = _existingOrder!.diaChiGiaoHang ?? '';
  _hoTenNguoiNhanHoaHongController.text = _existingOrder!.hoTenNguoiNhanHoaHong ?? '';
  _sdtNguoiNhanHoaHongController.text = _existingOrder!.sdtNguoiNhanHoaHong ?? '';
  _hinhThucChuyenHoaHongController.text = _existingOrder!.hinhThucChuyenHoaHong ?? '';
  _thongTinNhanHoaHongController.text = _existingOrder!.thongTinNhanHoaHong ?? '';
  _phuongTienGiaoHangController.text = _existingOrder!.phuongTienGiaoHang ?? '';
  _hoTenNguoiGiaoHangController.text = _existingOrder!.hoTenNguoiGiaoHang ?? '';
  _ghiChuController.text = _existingOrder!.ghiChu ?? '';
  _giaNetController.text = _existingOrder!.giaNet?.toString() ?? '';
  _tenKhachHang2Controller.text = _existingOrder!.tenKhachHang2 ?? '';
  _tenNguoiGiaoDichController.text = _existingOrder!.tenNguoiGiaoDich ?? '';
  _boPhanGiaoDichController.text = _existingOrder!.boPhanGiaoDich ?? '';
  _sdtNguoiGiaoDichController.text = _existingOrder!.sdtNguoiGiaoDich ?? '';
  _tenNguoiNhanHangController.text = _existingOrder!.nguoiNhanHang ?? '';
  _sdtNguoiNhanHangController.text = _existingOrder!.sdtNguoiNhanHang ?? '';
  
  // Set dropdown values
  _tapKH = _existingOrder!.tapKH ?? 'KH Truyền thống';
  _phuongThucThanhToan = _existingOrder!.phuongThucThanhToan ?? 'Chuyển khoản';
  _thanhToanSauNhanHangXNgay = _existingOrder!.thanhToanSauNhanHangXNgay ?? 40;
  _datCocSauXNgay = _existingOrder!.datCocSauXNgay ?? 0;
  
  // Set date
  if (_existingOrder!.ngayYeuCauGiao != null) {
    try {
      _ngayYeuCauGiao = DateTime.parse(_existingOrder!.ngayYeuCauGiao!);
    } catch (e) {
      _ngayYeuCauGiao = DateTime.now().add(Duration(days: 7));
    }
  }
  
  // Set total fields
  _hoaHong10Controller.text = _existingOrder!.hoaHong10?.toString() ?? '0';
  _tienGui10Controller.text = _existingOrder!.tienGui10?.toString() ?? '0';
  _thueTNDNController.text = _existingOrder!.thueTNDN?.toString() ?? '0';
  _vanChuyenController.text = _existingOrder!.vanChuyen?.toString() ?? '0';
}

Future<void> _loadExistingOrderItems() async {
  try {
    final items = await _dbHelper.getChiTietDonBySoPhieu(widget.soPhieu!);
    
    _chiTietDonList = items;
    _updateTotals();
    
  } catch (e) {
    print('Error loading existing order items: $e');
  }
}
void _selectRecipientContact(KhachHangContactModel contact) {
  setState(() {
    _tenNguoiNhanHangController.text = contact.hoTen ?? '';
    _sdtNguoiNhanHangController.text = contact.soDienThoai ?? '';
  });
  Navigator.of(context).pop();
}
void _showRecipientContactSelectionDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Chọn người nhận hàng'),
        content: Container(
          width: double.maxFinite,
          child: _customerContacts.isEmpty
              ? Center(child: Text('Không có người liên hệ cho khách hàng này'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _customerContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _customerContacts[index];
                    return ListTile(
                      title: Text(contact.hoTen ?? 'Không có tên'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (contact.chucDanh != null && contact.chucDanh!.isNotEmpty)
                            Text(contact.chucDanh!),
                          if (contact.soDienThoai != null && contact.soDienThoai!.isNotEmpty)
                            Text('ĐT: ${contact.soDienThoai}'),
                        ],
                      ),
                      onTap: () => _selectRecipientContact(contact),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            child: Text('Tự nhập'),
            onPressed: () {
              // Clear fields for manual entry
              _tenNguoiNhanHangController.text = '';
              _sdtNguoiNhanHangController.text = '';
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Đóng'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
  // ===== CUSTOMER SELECTION METHODS =====
  
  Future<void> _loadKhachHangData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final List<KhachHangModel> khachHangData = await _dbHelper.getAllKhachHang();
      setState(() {
        _khachHangList = khachHangData;
        _applySearch();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading customer data: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu khách hàng: $e'))
      );
    }
  }

  void _applySearch() {
    if (_searchText.isEmpty) {
      _filteredList = List.from(_khachHangList);
    } else {
      _filteredList = _khachHangList.where((customer) {
        final search = _searchText.toLowerCase();
        return (customer.tenDuAn?.toLowerCase().contains(search) ?? false) ||
               (customer.soDienThoai?.toLowerCase().contains(search) ?? false) ||
               (customer.diaChi?.toLowerCase().contains(search) ?? false);
      }).toList();
    }
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchText = query;
      _applySearch();
    });
  }

  String _generateSoPhieu() {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username;
    String userPrefix = '';
    
    // Determine user prefix based on username
    if (username.contains('hm.tranly')) {
      userPrefix = '13162';
    } else if (username.contains('hm.dinhmai')) { userPrefix = '1317';
} else if (username.contains('hm.hoangthao')) { userPrefix = '13111';
} else if (username.contains('hm.lehoa')) { userPrefix = 'Kho';
} else if (username.contains('hm.lemanh')) { userPrefix = '13118';
} else if (username.contains('hm.nguyentoan')) { userPrefix = 'Kho';
} else if (username.contains('hm.nguyendung')) { userPrefix = '1312';
} else if (username.contains('hm.nguyennga')) { userPrefix = '13114';
} else if (username.contains('hm.baoha')) { userPrefix = '13181';
} else if (username.contains('hm.trantien')) { userPrefix = '13181';
} else if (username.contains('hm.myha')) { userPrefix = '1312';
} else if (username.contains('hm.phiminh')) { userPrefix = 'Kho';
} else if (username.contains('hm.thanhhao')) { userPrefix = 'SG';
} else if (username.contains('hm.luongtrang')) { userPrefix = 'Kho';
} else if (username.contains('hm.damlinh')) { userPrefix = 'SG2';
} else if (username.contains('hm.thanhthao')) { userPrefix = 'SG3';
} else if (username.contains('hm.damchinh')) { userPrefix = 'SG4';
} else if (username.contains('hm.quocchien')) { userPrefix = 'SG5';
} else if (username.contains('hm.thuyvan')) { userPrefix = '1312';
} else if (username.contains('hotel.danang')) { userPrefix = '13181';
} else if (username.contains('hotel.nhatrang')) { userPrefix = '1312';
} else if (username.contains('hm.doanly')) { userPrefix = 'Kho';
    } else {
      userPrefix = '9999';
    }
    
    // Format: userPrefix-DDMMYY-randomNumber
    final now = DateTime.now();
    final dateStr = DateFormat('ddMMyy').format(now);
    final randomNum = Random().nextInt(90) + 10; // Random number between 10-99
    
    return '$userPrefix-$dateStr-$randomNum';
  }
  
  String _getThoiGianDatHang() {
    // Set based on username
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username;
    
    if (username.contains('hm.tranly')) {
      return 'HN';
    } else if (username.contains('hm.dinhmai')) { return 'HN';
} else if (username.contains('hm.hoangthao')) { return 'HN';
} else if (username.contains('hm.lehoa')) { return 'HN';
} else if (username.contains('hm.lemanh')) { return 'HN';
} else if (username.contains('hm.nguyentoan')) { return 'HN';
} else if (username.contains('hm.nguyendung')) { return 'NT';
} else if (username.contains('hm.nguyennga')) { return 'HN';
} else if (username.contains('hm.baoha')) { return 'DN';
} else if (username.contains('hm.trantien')) { return 'DN';
} else if (username.contains('hm.myha')) { return 'NT';
} else if (username.contains('hm.phiminh')) { return 'HN';
} else if (username.contains('hm.thanhhao')) { return 'SG';
} else if (username.contains('hm.luongtrang')) { return 'DN';
} else if (username.contains('hm.damlinh')) { return 'SG';
} else if (username.contains('hm.thanhthao')) { return 'SG';
} else if (username.contains('hm.damchinh')) { return 'SG';
} else if (username.contains('hm.quocchien')) { return 'SG';
} else if (username.contains('hm.thuyvan')) { return 'NT';
} else if (username.contains('hotel.danang')) { return 'DN';
} else if (username.contains('hotel.nhatrang')) { return 'NT';
} else if (username.contains('hm.doanly')) { return 'HN';
    } else {
      return 'HN'; // Default value
    }
  }
  
  void _selectCustomer(KhachHangModel customer, {String orderType = 'Tạo đơn'}) async {
  setState(() {
    _isLoading = true;
    _selectedCustomer = customer;
    _orderType = orderType; // Change _isBaoGia to _orderType
  });
  
  // Load customer contacts
  await _loadCustomerContacts(customer.uid ?? '');
  
  // Set default values
  _diaChiController.text = customer.diaChi ?? '';
  _sdtKhachHangController.text = customer.sdtDuAn ?? '';
  _diaChiGiaoHangController.text = customer.diaChi ?? '';
  _tenKhachHang2Controller.text = customer.tenDuAn ?? '';
  
  setState(() {
    _isLoading = false;
    _currentStep = 1; // Move to order details step
  });
}
  
  Future<void> _loadCustomerContacts(String customerUid) async {
    try {
      final db = await _dbHelper.database;
      
      // Query to get contacts where boPhan matches the customer's uid
      final List<Map<String, dynamic>> maps = await db.query(
        'KhachHangContact',
        where: 'boPhan = ?',
        whereArgs: [customerUid],
      );
      
      // Convert query results to KhachHangContactModel objects
      _customerContacts = List.generate(maps.length, (i) {
        return KhachHangContactModel.fromMap(maps[i]);
      });
    } catch (e) {
      print('Error loading customer contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu liên hệ khách hàng: $e'))
      );
      _customerContacts = [];
    }
  }
  
  void _selectContact(KhachHangContactModel contact) {
    setState(() {
      _tenNguoiGiaoDichController.text = contact.hoTen ?? '';
      _boPhanGiaoDichController.text = contact.chucDanh ?? '';
      _sdtNguoiGiaoDichController.text = contact.soDienThoai ?? '';
    });
    Navigator.of(context).pop();
  }
  
  void _showContactSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Chọn người liên hệ'),
          content: Container(
            width: double.maxFinite,
            child: _customerContacts.isEmpty
                ? Center(child: Text('Không có người liên hệ cho khách hàng này'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _customerContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _customerContacts[index];
                      return ListTile(
                        title: Text(contact.hoTen ?? 'Không có tên'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (contact.chucDanh != null && contact.chucDanh!.isNotEmpty)
                              Text(contact.chucDanh!),
                            if (contact.soDienThoai != null && contact.soDienThoai!.isNotEmpty)
                              Text('ĐT: ${contact.soDienThoai}'),
                          ],
                        ),
                        onTap: () => _selectContact(contact),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              child: Text('Tự nhập'),
              onPressed: () {
                // Clear fields for manual entry
                _tenNguoiGiaoDichController.text = '';
                _boPhanGiaoDichController.text = '';
                _sdtNguoiGiaoDichController.text = '';
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Đóng'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showCalendarDialog() {
    showDialog(
      context: context,
      builder: (context) {
        DateTime selectedDate = _ngayYeuCauGiao;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Chọn ngày yêu cầu giao'),
              content: Container(
                width: double.maxFinite,
                child: TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(Duration(days: 365)),
                  focusedDay: selectedDate,
                  selectedDayPredicate: (day) {
                    return isSameDay(selectedDate, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      selectedDate = selectedDay;
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Hủy'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Chọn'),
                  onPressed: () {
                    this.setState(() {
                      _ngayYeuCauGiao = selectedDate;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }
  bool _isBaoGia = false;
  String _orderType = 'Tạo đơn'; 
  void _createOrder() {
  if (_selectedCustomer == null) return;
  
  final now = DateTime.now();
  final formattedDate = DateFormat('yyyy-MM-dd').format(now);
  final currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  final userCredentials = Provider.of<UserCredentials>(context, listen: false);
  
  String soPhieu;
  String thoiGianDatHang;
  String trangThai;
  
  if (isEditMode && _existingOrder != null) {
    // Use existing order data for edit mode
    soPhieu = _existingOrder!.soPhieu!;
    thoiGianDatHang = _existingOrder!.thoiGianDatHang ?? _getThoiGianDatHang();
    trangThai = _existingOrder!.trangThai ?? 'Chưa xong';
  } else {
    // Generate new data for create mode
    soPhieu = _generateSoPhieu();
    thoiGianDatHang = _getThoiGianDatHang();
    
    // Determine trangThai based on _orderType and customer name
    if (_orderType == 'Báo giá') {
      trangThai = 'Báo giá';
    } else if (_orderType == 'Dự trù') {
      trangThai = 'Dự trù';
    } else {
      final bool isNoiBo = (_selectedCustomer!.tenDuAn ?? '').toLowerCase().contains('nội bộ');
      trangThai = isNoiBo ? 'Xuất Nội bộ' : 'Chưa xong';
    }
  }
  
  // Create the order (rest of the method remains the same)
    _newOrder = DonHangModel(
    soPhieu: soPhieu,
    nguoiTao: isEditMode ? _existingOrder!.nguoiTao : userCredentials.username,
    ngay: isEditMode ? _existingOrder!.ngay : formattedDate,
    tenKhachHang: _selectedCustomer!.tenDuAn,
    sdtKhachHang: _sdtKhachHangController.text.isNotEmpty ? _sdtKhachHangController.text : null,
    soPO: _poController.text.isNotEmpty ? _poController.text : null,
    diaChi: _diaChiController.text.isNotEmpty ? _diaChiController.text : null,
    mst: _selectedCustomer!.maSoThue,
    tapKH: _tapKH,
    tenNguoiGiaoDich: _tenNguoiGiaoDichController.text.isNotEmpty ? _tenNguoiGiaoDichController.text : null,
    boPhanGiaoDich: _boPhanGiaoDichController.text.isNotEmpty ? _boPhanGiaoDichController.text : null,
    sdtNguoiGiaoDich: _sdtNguoiGiaoDichController.text.isNotEmpty ? _sdtNguoiGiaoDichController.text : null,
    nguoiNhanHang: _tenNguoiNhanHangController.text.isNotEmpty ? _tenNguoiNhanHangController.text : null,
    sdtNguoiNhanHang: _sdtNguoiNhanHangController.text.isNotEmpty ? _sdtNguoiNhanHangController.text : null,
    thoiGianDatHang: thoiGianDatHang,
    ngayYeuCauGiao: DateFormat('yyyy-MM-dd').format(_ngayYeuCauGiao),
    thoiGianCapNhatTrangThai: currentDateTime,
    phuongThucThanhToan: _phuongThucThanhToan,
    thanhToanSauNhanHangXNgay: _thanhToanSauNhanHangXNgay,
    datCocSauXNgay: _datCocSauXNgay,
    giayToCanKhiGiaoHang: _giayToCanKhiGiaoHangController.text.isNotEmpty ? _giayToCanKhiGiaoHangController.text : null,
    thoiGianVietHoaDon: _thoiGianVietHoaDonController.text.isNotEmpty ? _thoiGianVietHoaDonController.text : null,
    thongTinVietHoaDon: _thongTinVietHoaDonController.text.isNotEmpty ? _thongTinVietHoaDonController.text : null,
    diaChiGiaoHang: _diaChiGiaoHangController.text.isNotEmpty ? _diaChiGiaoHangController.text : null,
    hoTenNguoiNhanHoaHong: _hoTenNguoiNhanHoaHongController.text.isNotEmpty ? _hoTenNguoiNhanHoaHongController.text : null,
    sdtNguoiNhanHoaHong: _sdtNguoiNhanHoaHongController.text.isNotEmpty ? _sdtNguoiNhanHoaHongController.text : null,
    hinhThucChuyenHoaHong: _hinhThucChuyenHoaHongController.text.isNotEmpty ? _hinhThucChuyenHoaHongController.text : null,
    thongTinNhanHoaHong: _thongTinNhanHoaHongController.text.isNotEmpty ? _thongTinNhanHoaHongController.text : null,
  ngaySeGiao: _newOrder?.ngaySeGiao,
    thoiGianCapNhatMoiNhat: currentDateTime,
  phuongThucGiaoHang: _newOrder?.phuongThucGiaoHang,
    phuongTienGiaoHang: _phuongTienGiaoHangController.text.isNotEmpty ? _phuongTienGiaoHangController.text : null,
    hoTenNguoiGiaoHang: _hoTenNguoiGiaoHangController.text.isNotEmpty ? _hoTenNguoiGiaoHangController.text : null,
    ghiChu: _ghiChuController.text.isNotEmpty ? _ghiChuController.text : null,
    giaNet: _giaNetController.text.isNotEmpty ? int.tryParse(_giaNetController.text) : null,
    trangThai: trangThai,
    tenKhachHang2: _tenKhachHang2Controller.text.isNotEmpty ? _tenKhachHang2Controller.text : null,
      tongTien: _tongTien,
  vat10: _vat10,
  tongCong: _tongCong,
  hoaHong10: hoaHong10,
  tienGui10: tienGui10,
  thueTNDN: thueTNDN,
  vanChuyen: vanChuyen,
  thucThu: thucThu
  );
  
  // Load product data and move to step 2
  _loadProductData();
  
  setState(() {
    _currentStep = 2;
  });
}
  // ===== PRODUCT SELECTION METHODS =====
  
  Future<void> _loadProductData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final dsHangData = await _dbHelper.getAllDSHang();
      
      setState(() {
        _dshangList = dsHangData;
        _filteredDSHangList = List.from(dsHangData);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading product data: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu sản phẩm: $e'))
      );
    }
  }
  
  void _updateProductSearch(String query) {
    setState(() {
      _productSearchText = query;
      if (query.isEmpty) {
        _filteredDSHangList = List.from(_dshangList);
      } else {
        _filteredDSHangList = _dshangList.where((product) {
          final search = query.toLowerCase();
          return (product.tenSanPham?.toLowerCase().contains(search) ?? false) ||
                 (product.maNhapKho?.toLowerCase().contains(search) ?? false) ||
                 (product.sku?.toLowerCase().contains(search) ?? false);
        }).toList();
      }
    });
  }
  
  void _updateTotals() {
    int tongTien = 0;
    int vat10 = 0;
    
    for (var item in _chiTietDonList) {
      tongTien += item.thanhTien ?? 0;
      vat10 += item.vat ?? 0;
    }
    
    int tongCong = tongTien + vat10;
    int hoaHong10 = int.tryParse(_hoaHong10Controller.text) ?? 0;
    int tienGui10 = int.tryParse(_tienGui10Controller.text) ?? 0;
    int thueTNDN = int.tryParse(_thueTNDNController.text) ?? 0;
    int vanChuyen = int.tryParse(_vanChuyenController.text) ?? 0;
    int thucThu = tongCong - hoaHong10 - tienGui10 - thueTNDN - vanChuyen;
    
    setState(() {
      _tongTien = tongTien;
      _vat10 = vat10;
      _tongCong = tongCong;
      _thucThu = thucThu;
    });
  }
  
  void _showAddProductDialog([DSHangModel? product]) {
    final bool isSpecialProduct = product == null || product.uid == 'KHAC';
    
    TextEditingController tenHangController = TextEditingController(
        text: isSpecialProduct ? '' : product!.tenSanPham ?? '');
    TextEditingController maHangController = TextEditingController(
        text: isSpecialProduct ? '' : product!.maNhapKho ?? '');
    TextEditingController donViTinhController = TextEditingController(
        text: isSpecialProduct ? '' : product!.donVi ?? '');
    TextEditingController xuatXuHangKhacController = TextEditingController();
    TextEditingController soLuongYeuCauController = TextEditingController(text: '1');
    TextEditingController donGiaController = TextEditingController(text: '0');
    TextEditingController ghiChuController = TextEditingController();
    
    int phanTramVAT = 0;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate thanhTien and VAT
            double soLuongYeuCau = double.tryParse(soLuongYeuCauController.text) ?? 0;
            int donGia = int.tryParse(donGiaController.text) ?? 0;
            int thanhTien = (soLuongYeuCau * donGia).toInt();
            int vat = (thanhTien * phanTramVAT / 100).toInt();
            
            return AlertDialog(
              title: Text('Thêm sản phẩm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product info section
                    if (!isSpecialProduct)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product image
                          if (product!.hinhAnh != null && product.hinhAnh!.isNotEmpty)
                            Center(
                              child: Container(
                                height: 120,
                                width: 120,
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Image.network(
                                  product.hinhAnh!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(child: Icon(Icons.image_not_supported));
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    
                    // Fields that are editable if KHAC, otherwise read-only
                    TextField(
                      controller: tenHangController,
                      decoration: InputDecoration(
                        labelText: 'Tên hàng *',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: !isSpecialProduct,
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: maHangController,
                      decoration: InputDecoration(
                        labelText: 'Mã hàng',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: !isSpecialProduct,
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: donViTinhController,
                      decoration: InputDecoration(
                        labelText: 'Đơn vị tính',
                        border: OutlineInputBorder(),
                      ),
                      //readOnly: !isSpecialProduct,
                    ),
                    
                    // Only show XuatXuHangKhac if KHAC
                    if (isSpecialProduct)
                      Column(
                        children: [
                          SizedBox(height: 16),
                          TextField(
                            controller: xuatXuHangKhacController,
                            decoration: InputDecoration(
                              labelText: 'Xuất xứ hàng khác',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    
                    SizedBox(height: 16),
                    
                    // Fields that are always editable
                    TextField(
                      controller: soLuongYeuCauController,
                      decoration: InputDecoration(
                        labelText: 'Số lượng yêu cầu *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          // Recalculate will happen on rebuild
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: donGiaController,
                      decoration: InputDecoration(
                        labelText: 'Đơn giá *',
                        border: OutlineInputBorder(),
                        suffixText: 'VNĐ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          // Recalculate will happen on rebuild
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Calculated fields (non-editable)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Thành tiền',
                        border: OutlineInputBorder(),
                      ),
                      child: Text('${currencyFormat.format(thanhTien)} VNĐ'),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // VAT percentage dropdown
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Phần trăm VAT *',
                        border: OutlineInputBorder(),
                      ),
                      value: phanTramVAT,
                      items: [0, 8, 10]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value%'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          phanTramVAT = value!;
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'VAT',
                        border: OutlineInputBorder(),
                      ),
                      child: Text('${currencyFormat.format(vat)} VNĐ'),
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: ghiChuController,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Hủy'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Xác nhận'),
                  onPressed: () {
                    // Validate required fields
                    if (tenHangController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tên hàng không được để trống'))
                      );
                      return;
                    }
                    
                    if (soLuongYeuCauController.text.isEmpty || 
                        double.tryParse(soLuongYeuCauController.text) == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Số lượng yêu cầu phải lớn hơn 0'))
                      );
                      return;
                    }
                    
                    if (donGiaController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đơn giá phải không được trống'))
                      );
                      return;
                    }
                    String itemTrangThai;
if (_orderType == 'Báo giá') {
  itemTrangThai = 'Báo giá';
} else if (_orderType == 'Dự trù') {
  itemTrangThai = 'Dự trù';
} else {
  itemTrangThai = 'Nháp';
}
                    // Create a new ChiTietDonModel
                    final newChiTiet = ChiTietDonModel(
                     uid: 'TEMP-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}',
                      soPhieu: _newOrder?.soPhieu,
                      trangThai: itemTrangThai,
                      tenHang: tenHangController.text,
                      maHang: maHangController.text,
                      donViTinh: donViTinhController.text,
                      soLuongYeuCau: double.tryParse(soLuongYeuCauController.text) ?? 0,
                      donGia: int.tryParse(donGiaController.text) ?? 0,
                      thanhTien: thanhTien,
                      soLuongThucGiao: 0,
                      chiNhanh: _newOrder?.thoiGianDatHang,
                      idHang: isSpecialProduct ? 'KHAC' : product!.uid,
                      soLuongKhachNhan: 0,
                      duyet: 'Chưa xong',
                      xuatXuHangKhac: isSpecialProduct ? xuatXuHangKhacController.text : '',
                      baoGia: '',
                      hinhAnh: isSpecialProduct ? '' : product!.hinhAnh,
                      ghiChu: ghiChuController.text,
                      phanTramVAT: phanTramVAT,
                      vat: vat,
                      tenKhachHang: _newOrder?.tenKhachHang,
                      updateTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                    );
                    
                    // Add to the list
                    setState(() {
                      _chiTietDonList.add(newChiTiet);
                    });
                    
                    // Update totals
                    _updateTotals();
                    
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  void _showEditProductDialog(ChiTietDonModel chiTietDon, int index) {
    final bool isSpecialProduct = chiTietDon.idHang == 'KHAC';
    
    TextEditingController tenHangController = TextEditingController(text: chiTietDon.tenHang ?? '');
    TextEditingController maHangController = TextEditingController(text: chiTietDon.maHang ?? '');
    TextEditingController donViTinhController = TextEditingController(text: chiTietDon.donViTinh ?? '');
    TextEditingController xuatXuHangKhacController = TextEditingController(text: chiTietDon.xuatXuHangKhac ?? '');
    TextEditingController soLuongYeuCauController = TextEditingController(
        text: chiTietDon.soLuongYeuCau?.toString() ?? '1');
    TextEditingController donGiaController = TextEditingController(
        text: chiTietDon.donGia?.toString() ?? '0');
    TextEditingController ghiChuController = TextEditingController(text: chiTietDon.ghiChu ?? '');
    
    int phanTramVAT = chiTietDon.phanTramVAT ?? 0;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate thanhTien and VAT
            double soLuongYeuCau = double.tryParse(soLuongYeuCauController.text) ?? 0;
            int donGia = int.tryParse(donGiaController.text) ?? 0;
            int thanhTien = (soLuongYeuCau * donGia).toInt();
            int vat = (thanhTien * phanTramVAT / 100).toInt();
            
            return AlertDialog(
              title: Text('Sửa sản phẩm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image
                    if (chiTietDon.hinhAnh != null && chiTietDon.hinhAnh!.isNotEmpty)
                      Center(
                        child: Container(
                          height: 120,
                          width: 120,
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Image.network(
                            chiTietDon.hinhAnh!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(child: Icon(Icons.image_not_supported));
                            },
                          ),
                        ),
                      ),
                    
                    // Fields that are editable if KHAC, otherwise read-only
                    TextField(
                      controller: tenHangController,
                      decoration: InputDecoration(
                        labelText: 'Tên hàng *',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: !isSpecialProduct,
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: maHangController,
                      decoration: InputDecoration(
                        labelText: 'Mã hàng',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: !isSpecialProduct,
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: donViTinhController,
                      decoration: InputDecoration(
                        labelText: 'Đơn vị tính',
                        border: OutlineInputBorder(),
                      ),
                      //readOnly: !isSpecialProduct,
                    ),
                    
                    // Only show XuatXuHangKhac if KHAC
                    if (isSpecialProduct)
                      Column(
                        children: [
                          SizedBox(height: 16),
                          TextField(
                            controller: xuatXuHangKhacController,
                            decoration: InputDecoration(
                              labelText: 'Xuất xứ hàng khác',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    
                    SizedBox(height: 16),
                    
                    // Fields that are always editable
                    TextField(
                      controller: soLuongYeuCauController,
                      decoration: InputDecoration(
                        labelText: 'Số lượng yêu cầu *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          // Recalculate will happen on rebuild
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: donGiaController,
                      decoration: InputDecoration(
                        labelText: 'Đơn giá *',
                        border: OutlineInputBorder(),
                        suffixText: 'VNĐ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          // Recalculate will happen on rebuild
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Calculated fields (non-editable)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Thành tiền',
                        border: OutlineInputBorder(),
                      ),
                      child: Text('${currencyFormat.format(thanhTien)} VNĐ'),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // VAT percentage dropdown
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Phần trăm VAT *',
                        border: OutlineInputBorder(),
                      ),
                      value: phanTramVAT,
                      items: [0, 8, 10]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value%'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          phanTramVAT = value!;
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'VAT',
                        border: OutlineInputBorder(),
                      ),
                      child: Text('${currencyFormat.format(vat)} VNĐ'),
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: ghiChuController,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Hủy'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: Text('Xóa'),
                  onPressed: () {
                    // Remove the item
                    this.setState(() {
                      _chiTietDonList.removeAt(index);
                    });
                    
                    // Update totals
                    _updateTotals();
                    
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Lưu'),
                  onPressed: () {
                    // Validate required fields
                    if (tenHangController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tên hàng không được để trống'))
                      );
                      return;
                    }
                    
                    if (soLuongYeuCauController.text.isEmpty || 
                        double.tryParse(soLuongYeuCauController.text) == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Số lượng yêu cầu phải lớn hơn 0'))
                      );
                      return;
                    }
                    
                    if (donGiaController.text.isEmpty || 
                        int.tryParse(donGiaController.text) == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đơn giá phải lớn hơn 0'))
                      );
                      return;
                    }
                    String itemTrangThai;
if (_orderType == 'Báo giá') {
  itemTrangThai = 'Báo giá';
} else if (_orderType == 'Dự trù') {
  itemTrangThai = 'Dự trù';
} else {
  itemTrangThai = chiTietDon.trangThai ?? 'Nháp';
}
                    // Update the ChiTietDonModel
                    final updatedChiTiet = ChiTietDonModel(
                      uid: chiTietDon.uid,
                      soPhieu: chiTietDon.soPhieu,
                      trangThai: itemTrangThai,
                      tenHang: tenHangController.text,
                      maHang: maHangController.text,
                      donViTinh: donViTinhController.text,
                      soLuongYeuCau: double.tryParse(soLuongYeuCauController.text) ?? 0,
                      donGia: int.tryParse(donGiaController.text) ?? 0,
                      thanhTien: thanhTien,
                      soLuongThucGiao: chiTietDon.soLuongThucGiao,
                      chiNhanh: chiTietDon.chiNhanh,
                      idHang: chiTietDon.idHang,
                      soLuongKhachNhan: chiTietDon.soLuongKhachNhan,
                      duyet: chiTietDon.duyet,
                      xuatXuHangKhac: isSpecialProduct ? xuatXuHangKhacController.text : chiTietDon.xuatXuHangKhac,
                      baoGia: chiTietDon.baoGia,
                      hinhAnh: chiTietDon.hinhAnh,
                      ghiChu: ghiChuController.text,
                      phanTramVAT: phanTramVAT,
                      vat: vat,
                      tenKhachHang: chiTietDon.tenKhachHang,
                      updateTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                    );
                    
                    // Update the list
                    this.setState(() {
                      _chiTietDonList[index] = updatedChiTiet;
                    });
                    
                    // Update totals
                    _updateTotals();
                    
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  void _showAddSpecialProductDialog() {
    // Create a custom "KHAC" product
    DSHangModel specialProduct = DSHangModel(
      uid: 'KHAC',
      tenSanPham: '',
      maNhapKho: '',
      donVi: '',
    );
    
    _showAddProductDialog(specialProduct);
  }
  
  void _showProductSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Chọn sản phẩm'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search bar
                    TextField(
                      controller: _productSearchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm sản phẩm',
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: _productSearchText.isNotEmpty 
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _productSearchController.clear();
                                setState(() {
                                  _productSearchText = '';
                                  _filteredDSHangList = List.from(_dshangList);
                                });
                              },
                            )
                          : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _productSearchText = value;
                          if (value.isEmpty) {
                            _filteredDSHangList = List.from(_dshangList);
                          } else {
                            _filteredDSHangList = _dshangList.where((product) {
                              final search = value.toLowerCase();
                              return (product.tenSanPham?.toLowerCase().contains(search) ?? false) ||
                                     (product.maNhapKho?.toLowerCase().contains(search) ?? false) ||
                                     (product.sku?.toLowerCase().contains(search) ?? false);
                            }).toList();
                          }
                        });
                      },
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Thêm hàng khác button
                    ElevatedButton.icon(
                      icon: Icon(Icons.add_circle),
                      label: Text('Thêm hàng khác'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showAddSpecialProductDialog();
                      },
                    ),
                    
                    SizedBox(height: 8),
                    
                    Divider(),
                    
                    // Product list
                    Expanded(
                      child: _filteredDSHangList.isEmpty
                          ? Center(child: Text('Không tìm thấy sản phẩm'))
                          : ListView.builder(
                              itemCount: _filteredDSHangList.length,
                              itemBuilder: (context, index) {
                                final product = _filteredDSHangList[index];
                                return ListTile(
                                  leading: product.hinhAnh != null && product.hinhAnh!.isNotEmpty
                                      ? Container(
                                          width: 50,
                                          height: 50,
                                          child: Image.network(
                                            product.hinhAnh!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Center(child: Icon(Icons.image_not_supported));
                                            },
                                          ),
                                        )
                                      : Icon(Icons.inventory),
                                  title: Text(product.tenSanPham ?? 'Không có tên'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Mã: ${product.maNhapKho ?? 'N/A'}'),
                                      if (product.donVi != null && product.donVi!.isNotEmpty)
                                        Text('Đơn vị: ${product.donVi}'),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _showAddProductDialog(product);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Đóng'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }
Future<void> _submitOrder() async {
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(isEditMode ? 'Đang cập nhật đơn hàng' : 'Đang gửi đơn hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Vui lòng đợi trong giây lát...'),
          ],
        ),
      );
    },
  );

  try {
    // Get updated values for totals
    int hoaHong10 = int.tryParse(_hoaHong10Controller.text) ?? 0;
    int tienGui10 = int.tryParse(_tienGui10Controller.text) ?? 0;
    int thueTNDN = int.tryParse(_thueTNDNController.text) ?? 0;
    int vanChuyen = int.tryParse(_vanChuyenController.text) ?? 0;
    int thucThu = _tongCong - hoaHong10 - tienGui10 - thueTNDN - vanChuyen;
    
    // Create the order data matching the exact field names from the database schema
    final orderData = {
      'SoPhieu': _newOrder?.soPhieu,
      'NguoiTao': _newOrder?.nguoiTao,
      'Ngay': _newOrder?.ngay,
      'TenKhachHang': _newOrder?.tenKhachHang,
      'SdtKhachHang': _newOrder?.sdtKhachHang,
      'SoPO': _newOrder?.soPO,
      'DiaChi': _newOrder?.diaChi,
      'MST': _newOrder?.mst,
      'TapKH': _newOrder?.tapKH,
      'TenNguoiGiaoDich': _newOrder?.tenNguoiGiaoDich,
      'BoPhanGiaoDich': _newOrder?.boPhanGiaoDich,
      'SDTNguoiGiaoDich': _newOrder?.sdtNguoiGiaoDich,
        'NguoiNhanHang': _newOrder?.nguoiNhanHang,
  'SDTNguoiNhanHang': _newOrder?.sdtNguoiNhanHang,
      'ThoiGianDatHang': _newOrder?.thoiGianDatHang,
      'NgayYeuCauGiao': _newOrder?.ngayYeuCauGiao,
      'ThoiGianCapNhatTrangThai': _newOrder?.thoiGianCapNhatTrangThai,
      'PhuongThucThanhToan': _newOrder?.phuongThucThanhToan,
      'ThanhToanSauNhanHangXNgay': _newOrder?.thanhToanSauNhanHangXNgay,
      'DatCocSauXNgay': _newOrder?.datCocSauXNgay,
      'GiayToCanKhiGiaoHang': _newOrder?.giayToCanKhiGiaoHang,
      'ThoiGianVietHoaDon': _newOrder?.thoiGianVietHoaDon,
      'ThongTinVietHoaDon': _newOrder?.thongTinVietHoaDon,
      'DiaChiGiaoHang': _newOrder?.diaChiGiaoHang,
      'HoTenNguoiNhanHoaHong': _newOrder?.hoTenNguoiNhanHoaHong,
      'SDTNguoiNhanHoaHong': _newOrder?.sdtNguoiNhanHoaHong,
      'HinhThucChuyenHoaHong': _newOrder?.hinhThucChuyenHoaHong,
      'ThongTinNhanHoaHong': _newOrder?.thongTinNhanHoaHong,
      'NgaySeGiao': _newOrder?.ngaySeGiao,
      'ThoiGianCapNhatMoiNhat': _newOrder?.thoiGianCapNhatMoiNhat,
      'PhuongThucGiaoHang': _newOrder?.phuongThucGiaoHang,
      'PhuongTienGiaoHang': _newOrder?.phuongTienGiaoHang,
      'HoTenNguoiGiaoHang': _newOrder?.hoTenNguoiGiaoHang,
      'GhiChu': _newOrder?.ghiChu,
      'GiaNet': _newOrder?.giaNet,
      'TongTien': _tongTien,
      'VAT10': _vat10,
      'TongCong': _tongCong,
      'HoaHong10': hoaHong10,
      'TienGui10': tienGui10,
      'ThueTNDN': thueTNDN,
      'VanChuyen': vanChuyen,
      'ThucThu': thucThu,
      'PhieuXuatKho': '', // Empty for now
      'TrangThai': _newOrder?.trangThai,
      'TenKhachHang2': _newOrder?.tenKhachHang2
    };
    
    // Log the request body for debugging
    print('Submitting order: ${jsonEncode(orderData)}');
    
    // 1. Submit DonHang
    final orderResponse = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hoteldonhangmoi'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(orderData),
    );
    
    // Log the response for debugging
    print('Order submission response: ${orderResponse.statusCode} - ${orderResponse.body}');
    
    if (orderResponse.statusCode != 200) {
      throw Exception('Failed to submit order: ${orderResponse.statusCode} ${orderResponse.body}');
    }
    
    // Update dialog to show progress of submitting order items
    Navigator.pop(context); // Close current dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Đang gửi chi tiết đơn hàng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: 0),
              SizedBox(height: 16),
              Text('Đang gửi sản phẩm 0/${_chiTietDonList.length}...'),
            ],
          ),
        );
      },
    );
    
    // 2. Submit each ChiTietDon
    for (int i = 0; i < _chiTietDonList.length; i++) {
      final item = _chiTietDonList[i];
      
      // Update progress dialog
      Navigator.pop(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Đang gửi chi tiết đơn hàng'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: (i + 1) / _chiTietDonList.length),
                SizedBox(height: 16),
                Text('Đang gửi sản phẩm ${i + 1}/${_chiTietDonList.length}...'),
              ],
            ),
          );
        },
      );
      
      // Create the order item data with exact field names matching the database schema
      final itemData = {
        'UID': item.uid,
        'SoPhieu': item.soPhieu,
        'TrangThai': item.trangThai,
        'TenHang': item.tenHang,
        'MaHang': item.maHang,
        'DonViTinh': item.donViTinh,
        'SoLuongYeuCau': item.soLuongYeuCau,
        'DonGia': item.donGia,
        'ThanhTien': item.thanhTien,
        'SoLuongThucGiao': item.soLuongThucGiao,
        'ChiNhanh': item.chiNhanh,
        'IdHang': item.idHang,
        'SoLuongKhachNhan': item.soLuongKhachNhan,
        'Duyet': item.duyet,
        'XuatXuHangKhac': item.xuatXuHangKhac,
        'BaoGia': item.baoGia,
        'HinhAnh': item.hinhAnh,
        'GhiChu': item.ghiChu,
        'PhanTramVAT': item.phanTramVAT,
        'VAT': item.vat,
        'TenKhachHang': item.tenKhachHang,
        'UpdateTime': item.updateTime ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
      };
      
      // Log the request body for debugging
      print('Submitting order item ${i + 1}/${_chiTietDonList.length}: ${jsonEncode(itemData)}');
      
      final itemResponse = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelchitietdonmoi'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(itemData),
      );
      
      // Log the response for debugging
      print('Order item submission response: ${itemResponse.statusCode} - ${itemResponse.body}');
      
      if (itemResponse.statusCode != 200) {
        throw Exception('Failed to submit order item: ${itemResponse.statusCode} ${itemResponse.body}');
      }
    }
    
    // Close progress dialog
    Navigator.pop(context);
    
    // Show success dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Thành công'),
          content: Text(isEditMode 
            ? 'Đơn hàng đã được cập nhật thành công.' 
            : 'Đơn hàng đã được tạo thành công.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, {
                  'status': 'success',
                  'soPhieu': _newOrder?.soPhieu
                }); // Return to previous screen
              },
            ),
          ],
        );
      },
    );
  } catch (e) {
    // Close progress dialog
    Navigator.pop(context);
    
    // Show error dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Lỗi'),
          content: Text('Đã xảy ra lỗi khi gửi đơn hàng: $e'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
    
    print('Error submitting order: $e');
  }
}
  void _showFinalizeOrderDialog() {
    // Load current values if they exist
    _hoaHong10Controller.text = '0';
    _tienGui10Controller.text = '0';
    _thueTNDNController.text = '0';
    _vanChuyenController.text = '0';
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate thucThu
            int hoaHong10 = int.tryParse(_hoaHong10Controller.text) ?? 0;
            int tienGui10 = int.tryParse(_tienGui10Controller.text) ?? 0;
            int thueTNDN = int.tryParse(_thueTNDNController.text) ?? 0;
            int vanChuyen = int.tryParse(_vanChuyenController.text) ?? 0;
            int thucThu = _tongCong - hoaHong10 - tienGui10 - thueTNDN - vanChuyen;
            
            return AlertDialog(
              title: Text('Hoàn thành đơn hàng'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order summary
                    _buildInfoField('Tổng tiền hàng:', '${currencyFormat.format(_tongTien)} VNĐ'),
                    _buildInfoField('VAT:', '${currencyFormat.format(_vat10)} VNĐ'),
                    _buildInfoField('Tổng cộng:', '${currencyFormat.format(_tongCong)} VNĐ'),
                    
                    Divider(),
                    
                    // Adjustments
                    TextField(
                      controller: _hoaHong10Controller,
                      decoration: InputDecoration(
                        labelText: 'Hoa hồng',
                        border: OutlineInputBorder(),
                        suffixText: 'VNĐ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          // Will recalculate on rebuild
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: _tienGui10Controller,
                      decoration: InputDecoration(
                        labelText: 'Tiền gửi',
                        border: OutlineInputBorder(),
                        suffixText: 'VNĐ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          // Will recalculate on rebuild
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: _thueTNDNController,
                      decoration: InputDecoration(
                        labelText: 'Thuế TNDN',
                        border: OutlineInputBorder(),
                        suffixText: 'VNĐ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          // Will recalculate on rebuild
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    TextField(
                      controller: _vanChuyenController,
                      decoration: InputDecoration(
                        labelText: 'Vận chuyển',
                        border: OutlineInputBorder(),
                        suffixText: 'VNĐ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          // Will recalculate on rebuild
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Calculated thucThu (non-editable)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Thực thu',
                        border: OutlineInputBorder(),
                      ),
                      child: Text('${currencyFormat.format(thucThu)} VNĐ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: thucThu < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Hủy'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: buttonColor,
    foregroundColor: Colors.white,
  ),
  child: Text('Hoàn thành'),
  onPressed: () {
    // Get the values from controllers
    int hoaHong10 = int.tryParse(_hoaHong10Controller.text) ?? 0;
    int tienGui10 = int.tryParse(_tienGui10Controller.text) ?? 0;
    int thueTNDN = int.tryParse(_thueTNDNController.text) ?? 0;
    int vanChuyen = int.tryParse(_vanChuyenController.text) ?? 0;
    int thucThu = _tongCong - hoaHong10 - tienGui10 - thueTNDN - vanChuyen;
    
    _newOrder = DonHangModel(
  soPhieu: _newOrder?.soPhieu,
  nguoiTao: _newOrder?.nguoiTao,
  ngay: _newOrder?.ngay,
  tenKhachHang: _newOrder?.tenKhachHang,
  sdtKhachHang: _newOrder?.sdtKhachHang,
  soPO: _newOrder?.soPO,
  diaChi: _newOrder?.diaChi,
  mst: _newOrder?.mst,
  tapKH: _newOrder?.tapKH,
  tenNguoiGiaoDich: _newOrder?.tenNguoiGiaoDich,
  boPhanGiaoDich: _newOrder?.boPhanGiaoDich,
  sdtNguoiGiaoDich: _newOrder?.sdtNguoiGiaoDich,
  // ADD THESE MISSING FIELDS:
  nguoiNhanHang: _newOrder?.nguoiNhanHang,
  sdtNguoiNhanHang: _newOrder?.sdtNguoiNhanHang,
  // Continue with rest of fields...
  thoiGianDatHang: _newOrder?.thoiGianDatHang,
  ngayYeuCauGiao: _newOrder?.ngayYeuCauGiao,
  thoiGianCapNhatTrangThai: _newOrder?.thoiGianCapNhatTrangThai,
  phuongThucThanhToan: _newOrder?.phuongThucThanhToan,
  thanhToanSauNhanHangXNgay: _newOrder?.thanhToanSauNhanHangXNgay,
  datCocSauXNgay: _newOrder?.datCocSauXNgay,
  giayToCanKhiGiaoHang: _newOrder?.giayToCanKhiGiaoHang,
  thoiGianVietHoaDon: _newOrder?.thoiGianVietHoaDon,
  thongTinVietHoaDon: _newOrder?.thongTinVietHoaDon,
  diaChiGiaoHang: _newOrder?.diaChiGiaoHang,
  hoTenNguoiNhanHoaHong: _newOrder?.hoTenNguoiNhanHoaHong,
  sdtNguoiNhanHoaHong: _newOrder?.sdtNguoiNhanHoaHong,
  hinhThucChuyenHoaHong: _newOrder?.hinhThucChuyenHoaHong,
  thongTinNhanHoaHong: _newOrder?.thongTinNhanHoaHong,
  ngaySeGiao: _newOrder?.ngaySeGiao,
  thoiGianCapNhatMoiNhat: _newOrder?.thoiGianCapNhatMoiNhat,
  phuongThucGiaoHang: _newOrder?.phuongThucGiaoHang,
  phuongTienGiaoHang: _newOrder?.phuongTienGiaoHang,
  hoTenNguoiGiaoHang: _newOrder?.hoTenNguoiGiaoHang,
  ghiChu: _newOrder?.ghiChu,
  giaNet: _newOrder?.giaNet,
  trangThai: _newOrder?.trangThai,
  tenKhachHang2: _newOrder?.tenKhachHang2,
  tongTien: _tongTien,
  vat10: _vat10,
  tongCong: _tongCong,
  hoaHong10: hoaHong10,
  tienGui10: tienGui10,
  thueTNDN: thueTNDN,
  vanChuyen: vanChuyen,
  thucThu: thucThu,
);
    
    // Close dialog
    Navigator.of(context).pop();
    
    // Submit the order to the server
    _submitOrder();
  },
),
              ],
            );
          }
        );
      },
    );
  }
  
  Widget _buildInfoField(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
void _showFinalProductReviewDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Kiểm tra sản phẩm'),
        content: Container(
          width: double.maxFinite,
          height: 400, // Fixed height
          child: Column(
            children: [
              Text('Tất cả sản phẩm trong đơn hàng:'),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _chiTietDonList.length,
                  itemBuilder: (context, index) {
                    final item = _chiTietDonList[index];
                    return ListTile(
                      title: Text(item.tenHang ?? 'Không có tên'),
                      subtitle: Text('${item.soLuongYeuCau} ${item.donViTinh} x ${currencyFormat.format(item.donGia)} VNĐ'),
                      trailing: IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showEditProductDialog(item, index);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Đóng'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Tiếp tục'),
            onPressed: () {
              Navigator.of(context).pop();
              _showFinalizeOrderDialog();
            },
          ),
        ],
      );
    },
  );
}
// Add this method to enable batch selection and operations
void _showBatchOperationsDialog() {
  List<int> selectedIndices = [];
  
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Quản lý sản phẩm'),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Chọn các sản phẩm để thực hiện hành động:'),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _chiTietDonList.length,
                      itemBuilder: (context, index) {
                        final item = _chiTietDonList[index];
                        final isSelected = selectedIndices.contains(index);
                        
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(item.tenHang ?? 'Không có tên'),
                          subtitle: Text('${item.soLuongYeuCau} ${item.donViTinh} x ${currencyFormat.format(item.donGia)} VNĐ'),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedIndices.add(index);
                              } else {
                                selectedIndices.remove(index);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Hủy'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: Text('Xóa đã chọn'),
                onPressed: selectedIndices.isEmpty ? null : () {
                  // Sort indices in descending order to avoid index shifting during removal
                  selectedIndices.sort((a, b) => b.compareTo(a));
                  
                  for (var index in selectedIndices) {
                    this.setState(() {
                      _chiTietDonList.removeAt(index);
                    });
                  }
                  
                  _updateTotals();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        }
      );
    },
  );
}
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [appBarTop, appBarBottom],
          ),
        ),
      ),
      title: Text(
        isEditMode 
          ? (_currentStep == 0 ? 'Sửa đơn hàng' :
             _currentStep == 1 ? 'Sửa thông tin đơn hàng' : 'Sửa sản phẩm')
          : (_currentStep == 0 ? 'Chọn khách hàng' :
             _currentStep == 1 ? 'Thông tin đơn hàng' : 'Thêm sản phẩm'),
        style: TextStyle(color: Colors.white)
      ),
        actions: [
  if (_currentStep == 2 && _chiTietDonList.isNotEmpty)
    IconButton(
      icon: Icon(Icons.list, color: Colors.white),
      onPressed: _showFinalProductReviewDialog,
      tooltip: 'Xem lại sản phẩm',
    ),
  if (_currentStep == 2 && _chiTietDonList.isNotEmpty)
    IconButton(
      icon: Icon(Icons.check, color: Colors.white),
      onPressed: _showFinalizeOrderDialog,
      tooltip: 'Hoàn thành đơn hàng',
    ),
],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildCurrentStep(),
      floatingActionButton: _currentStep == 2 ? Column(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    // Manage products button
    if (_chiTietDonList.isNotEmpty)
      FloatingActionButton.small(
        heroTag: 'manage',
        backgroundColor: Colors.orange,
        child: Icon(Icons.edit),
        onPressed: _showBatchOperationsDialog,
        tooltip: 'Quản lý sản phẩm',
      ),
    SizedBox(height: 8),
    // Add products button
    FloatingActionButton(
      heroTag: 'add',
      backgroundColor: buttonColor,
      child: Icon(Icons.add),
      onPressed: _showProductSelectionDialog,
      tooltip: 'Thêm sản phẩm',
    ),
  ],
) : null,
    );
  }
  
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildCustomerSelectionStep();
      case 1:
        return _buildOrderDetailsStep();
      case 2:
        return _buildProductSelectionStep();
      default:
        return Container();
    }
  }
  Widget _buildCustomerSelectionStep() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _buildCustomerList(),
        ),
      ],
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm theo tên, địa chỉ, số điện thoại...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchText.isNotEmpty 
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _updateSearchQuery('');
                },
              )
            : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        onChanged: _updateSearchQuery,
      ),
    );
  }

  Widget _buildCustomerList() {
    if (_filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Không tìm thấy khách hàng',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_searchText.isNotEmpty)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchText = '';
                    _applySearch();
                  });
                },
                child: Text('Xóa bộ lọc'),
              ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _filteredList.length,
      itemBuilder: (context, index) {
        final customer = _filteredList[index];
        return _buildCustomerCard(customer);
      },
    );
  }

  Widget _buildCustomerCard(KhachHangModel customer) {
  return Card(
    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: ListTile(
      title: Text(
        customer.tenDuAn ?? 'Không có tên',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (customer.diaChi != null && customer.diaChi!.isNotEmpty)
            Text(customer.diaChi!, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (customer.sdtDuAn != null && customer.sdtDuAn!.isNotEmpty)
            Text('ĐT: ${customer.sdtDuAn}'),
        ],
      ),
      trailing: Container(
        width: 240, // Adjust width to fit all three buttons
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 8), // Smaller padding
              ),
              child: Text('Dự trù', style: TextStyle(fontSize: 13)), // Smaller text
              onPressed: () => _selectCustomer(customer, orderType: 'Dự trù'),
            ),
            SizedBox(width: 4),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 8), // Smaller padding
              ),
              child: Text('Báo giá', style: TextStyle(fontSize: 13)), // Smaller text
              onPressed: () => _selectCustomer(customer, orderType: 'Báo giá'),
            ),
            SizedBox(width: 4),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 8), // Smaller padding
              ),
              child: Text('Tạo đơn', style: TextStyle(fontSize: 13)), // Smaller text
              onPressed: () => _selectCustomer(customer, orderType: 'Tạo đơn'),
            ),
          ],
        ),
      ),
    ),
  );
}
  
  Widget _buildOrderDetailsStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Non-editable fields
          _buildInfoField('Số phiếu:', _generateSoPhieu()),
          _buildInfoField('Người tạo:', Provider.of<UserCredentials>(context, listen: false).username),
          _buildInfoField('Ngày:', DateFormat('yyyy-MM-dd').format(DateTime.now())),
          _buildInfoField('Tên khách hàng:', _selectedCustomer!.tenDuAn ?? ''),
          _buildInfoField('MST:', _selectedCustomer!.maSoThue ?? ''),
          _buildInfoField('Thời gian đặt hàng:', _getThoiGianDatHang()),
          _buildInfoField('Trạng thái:', (_selectedCustomer!.tenDuAn ?? '').toLowerCase().contains('nội bộ') ? 'Xuất Nội bộ' : 'Chưa xong'),
          
          SizedBox(height: 20),
          
          // Editable fields
          TextField(
            controller: _sdtKhachHangController,
            decoration: InputDecoration(
              labelText: 'SĐT khách hàng',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          
          SizedBox(height: 16),
          
          TextField(
            controller: _diaChiController,
            decoration: InputDecoration(
              labelText: 'Địa chỉ',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          
          SizedBox(height: 16),
          
          // Tap KH dropdown
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Tập KH *',
              border: OutlineInputBorder(),
            ),
            value: _tapKH,
            items: ['KH Truyền thống', 'KH Mở mới', 'KH Lẻ', 'KH Chăm sóc lại']
                .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _tapKH = value!;
              });
            },
          ),
          
          SizedBox(height: 16),
          
          // Người giao dịch section
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.person_search),
                onPressed: _showContactSelectionDialog,
              ),
              Expanded(
                child: TextField(
                  controller: _tenNguoiGiaoDichController,
                  decoration: InputDecoration(
                    labelText: 'Tên người giao dịch',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          TextField(
            controller: _boPhanGiaoDichController,
            decoration: InputDecoration(
              labelText: 'Bộ phận giao dịch',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 16),
          
          TextField(
            controller: _sdtNguoiGiaoDichController,
            decoration: InputDecoration(
              labelText: 'SĐT người giao dịch',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          
          SizedBox(height: 16),
          Row(
  children: [
    IconButton(
      icon: Icon(Icons.person_search),
      onPressed: _showRecipientContactSelectionDialog,
      tooltip: 'Chọn người nhận hàng từ danh sách',
    ),
    Expanded(
      child: TextField(
        controller: _tenNguoiNhanHangController,
        decoration: InputDecoration(
          labelText: 'Tên người nhận hàng',
          border: OutlineInputBorder(),
        ),
      ),
    ),
  ],
),

SizedBox(height: 16),

TextField(
  controller: _sdtNguoiNhanHangController,
  decoration: InputDecoration(
    labelText: 'SĐT người nhận hàng',
    border: OutlineInputBorder(),
  ),
  keyboardType: TextInputType.phone,
),

SizedBox(height: 16),
          // Số PO
          TextField(
            controller: _poController,
            decoration: InputDecoration(
              labelText: 'Số PO',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Ngày yêu cầu giao
          InkWell(
            onTap: _showCalendarDialog,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Ngày yêu cầu giao',
                border: OutlineInputBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('dd/MM/yyyy').format(_ngayYeuCauGiao)),
                  Icon(Icons.calendar_today),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Phương thức thanh toán
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Phương thức thanh toán *',
              border: OutlineInputBorder(),
            ),
            value: _phuongThucThanhToan,
            items: ['Chuyển khoản', 'Tiền mặt']
                .map((label) => DropdownMenuItem(
                          value: label,
                          child: Text(label),
                        ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _phuongThucThanhToan = value!;
              });
            },
          ),
          
          SizedBox(height: 16),
          
          // Thanh toán sau X ngày
          TextField(
            decoration: InputDecoration(
              labelText: 'Thanh toán sau nhận hàng X ngày',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                _thanhToanSauNhanHangXNgay = int.tryParse(value) ?? 40;
              });
            },
            controller: TextEditingController(text: _thanhToanSauNhanHangXNgay.toString()),
          ),
          
          SizedBox(height: 16),
          
          // Đặt cọc sau X ngày
          TextField(
            decoration: InputDecoration(
              labelText: 'Đặt cọc sau X ngày',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                _datCocSauXNgay = int.tryParse(value) ?? 0;
              });
            },
            controller: TextEditingController(text: _datCocSauXNgay.toString()),
          ),
          
          SizedBox(height: 16),
          
          // Giấy tờ cần khi giao hàng
          TextField(
            controller: _giayToCanKhiGiaoHangController,
            decoration: InputDecoration(
              labelText: 'Giấy tờ cần khi giao hàng',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          
          SizedBox(height: 16),
          
          // Thời gian viết hóa đơn
          TextField(
            controller: _thoiGianVietHoaDonController,
            decoration: InputDecoration(
              labelText: 'Thời gian viết hóa đơn',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          
          SizedBox(height: 16),
          
          // Thông tin viết hóa đơn
          TextField(
            controller: _thongTinVietHoaDonController,
            decoration: InputDecoration(
              labelText: 'Thông tin viết hóa đơn',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          
          SizedBox(height: 16),
          
          // Địa chỉ giao hàng
          TextField(
            controller: _diaChiGiaoHangController,
            decoration: InputDecoration(
              labelText: 'Địa chỉ giao hàng',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          
          SizedBox(height: 16),
          
          // Thông tin hoa hồng
          TextField(
            controller: _hoTenNguoiNhanHoaHongController,
            decoration: InputDecoration(
              labelText: 'Họ tên người nhận hoa hồng',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 16),
          
          TextField(
            controller: _sdtNguoiNhanHoaHongController,
            decoration: InputDecoration(
              labelText: 'SĐT người nhận hoa hồng',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          
          SizedBox(height: 16),
          
          TextField(
            controller: _hinhThucChuyenHoaHongController,
            decoration: InputDecoration(
              labelText: 'Hình thức chuyển hoa hồng',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 16),
          
          TextField(
            controller: _thongTinNhanHoaHongController,
            decoration: InputDecoration(
              labelText: 'Thông tin nhận hoa hồng',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          
          SizedBox(height: 16),
          
          // Thông tin giao hàng
          TextField(
            controller: _phuongTienGiaoHangController,
            decoration: InputDecoration(
              labelText: 'Phương tiện giao hàng',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 16),
          
          TextField(
            controller: _hoTenNguoiGiaoHangController,
            decoration: InputDecoration(
              labelText: 'Họ tên người giao hàng',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Ghi chú
          TextField(
            controller: _ghiChuController,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          
          SizedBox(height: 16),
          
          // Giá Net
          TextField(
            controller: _giaNetController,
            decoration: InputDecoration(
              labelText: 'Giá Net (VNĐ)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          
          SizedBox(height: 16),
          
          // Tên khách hàng 2
          TextField(
            controller: _tenKhachHang2Controller,
            decoration: InputDecoration(
              labelText: 'Tên khách hàng 2',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                child: Text('Quay lại'),
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('Tiếp tục'),
                onPressed: _createOrder,
              ),
            ],
          ),
          
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
 Widget _buildProductSelectionStep() {
  if (_chiTietDonList.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Chưa có sản phẩm nào',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.add_shopping_cart),
            label: Text('Thêm sản phẩm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
            onPressed: _showProductSelectionDialog,
          ),
        ],
      ),
    );
  }
  
  return Column(
    children: [
      // Order header info
      Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đơn hàng: ${_newOrder?.soPhieu}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text('Khách hàng: ${_newOrder?.tenKhachHang}'),
              Text('Ngày: ${_newOrder?.ngay}'),
              Text('Số PO: ${_newOrder?.soPO}'),
            ],
          ),
        ),
      ),
      
      // Order summary
      Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng: ${currencyFormat.format(_tongTien)} VNĐ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'VAT: ${currencyFormat.format(_vat10)} VNĐ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Thành tiền: ${currencyFormat.format(_tongCong)} VNĐ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      
      // Product list
      Expanded(
        child: ListView.builder(
          itemCount: _chiTietDonList.length,
          itemBuilder: (context, index) {
            final item = _chiTietDonList[index];
            return GestureDetector(
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Sửa sản phẩm'),
                            onTap: () {
                              Navigator.pop(context);
                              _showEditProductDialog(item, index);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Xóa sản phẩm', style: TextStyle(color: Colors.red)),
                            onTap: () {
                              Navigator.pop(context);
                              // Show confirmation dialog
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text('Xác nhận xóa'),
                                    content: Text('Bạn có chắc chắn muốn xóa sản phẩm này?'),
                                    actions: [
                                      TextButton(
                                        child: Text('Hủy'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: Text('Xóa'),
                                        onPressed: () {
                                          setState(() {
                                            _chiTietDonList.removeAt(index);
                                          });
                                          _updateTotals();
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: item.hinhAnh != null && item.hinhAnh!.isNotEmpty
                      ? Container(
                          width: 50,
                          height: 50,
                          child: Image.network(
                            item.hinhAnh!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(child: Icon(Icons.image_not_supported));
                            },
                          ),
                        )
                      : Icon(Icons.inventory),
                  title: Text(item.tenHang ?? 'Không có tên'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mã: ${item.maHang ?? 'N/A'} | ${item.soLuongYeuCau} ${item.donViTinh}'),
                      Text('Đơn giá: ${currencyFormat.format(item.donGia)} VNĐ'),
                      Text('Thành tiền: ${currencyFormat.format(item.thanhTien)} VNĐ + VAT ${item.phanTramVAT}%'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit, color: buttonColor),
                    onPressed: () => _showEditProductDialog(item, index),
                  ),
                  isThreeLine: true,
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}}
// Extension method for DBHelper to get products
extension DonHangQueries on DBHelper {
  Future<List<DSHangModel>> getAllDSHang() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query('dshang');
    
    return List.generate(maps.length, (i) {
      return DSHangModel.fromMap(maps[i]);
    });
  }
}
  