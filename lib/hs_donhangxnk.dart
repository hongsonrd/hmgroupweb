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

// Extension method for DBHelper to get DonHang and ChiTietDon
extension XNKDonHangQueries on DBHelper {
  Future<List<DonHangModel>> getApprovedDutruOrders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'DonHang',
      where: 'TrangThai = ?',
      whereArgs: ['Dự trù đã duyệt'],
      orderBy: 'Ngay DESC', // Sort by date in descending order
    );
    return List.generate(maps.length, (i) {
      return DonHangModel.fromMap(maps[i]);
    });
  }

  Future<List<ChiTietDonModel>> getChiTietDonBySoPhieu(String soPhieu) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ChiTietDon',
      where: 'SoPhieu = ?',
      whereArgs: [soPhieu],
    );
    return List.generate(maps.length, (i) {
      return ChiTietDonModel.fromMap(maps[i]);
    });
  }

  Future<List<DSHangModel>> getAllDSHang() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query('dshang');

    return List.generate(maps.length, (i) {
      return DSHangModel.fromMap(maps[i]);
    });
  }
}

class HSDonHangXNKScreen extends StatefulWidget {
  final DonHangModel? editOrder; // Add this parameter

  const HSDonHangXNKScreen({Key? key, this.editOrder}) : super(key: key);

  @override
  _HSDonHangXNKScreenState createState() => _HSDonHangXNKScreenState();
}

class _HSDonHangXNKScreenState extends State<HSDonHangXNKScreen> {
  final DBHelper _dbHelper = DBHelper();
  final currencyFormat = NumberFormat('#,###', 'vi_VN');
final List<String> _baoGiaOptions = [
  'hm.tranly',
  'hm.dinhmai', 
  'hm.hoangthao',
  'hm.lehoa',
  'hm.lemanh',
  'hm.nguyentoan',
  'hm.nguyendung',
  'hm.nguyennga',
  'hm.baoha',
  'hm.trantien',
  'hm.myha',
  'hm.phiminh',
  'hm.thanhhao',
  'hm.luongtrang',
  'hm.damlinh',
  'hm.thanhthao',
  'hm.damchinh',
  'hm.quocchien',
  'hm.thuyvan',
  'hotel.danang',
  'hotel.nhatrang',
  'hm.doanly',
  'hm.trangiang', 'hm.tason', 'hm.manhha', 'hongson@officity.vn', ''
];

// Add currency options for XuatXuHangKhac
final List<String> _currencyOptions = ['',
  'VNĐ',
  'CNY', 
  'USD',
  'SGD',
  'EUR',
  'GBP',
  'YEN',
  'WON'
];

  // Screen state
  int _currentStep = 0; // 0: DonHang selection, 1: Order details, 2: Product selection

  // DonHang selection variables
  List<DonHangModel> _approvedDutruList = [];
  List<DonHangModel> _selectedDutruOrders = [];
  String _searchText = '';
  TextEditingController _searchController = TextEditingController();

  // Order form controllers (retained)
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

  // Order form values (retained)
  String _tapKH = 'KH Truyền thống';
  String _phuongThucThanhToan = 'Chuyển khoản';
  int _thanhToanSauNhanHangXNgay = 40;
  int _datCocSauXNgay = 0;
  DateTime _ngayYeuCauGiao = DateTime.now().add(Duration(days: 7)); // Default to 1 week from now

  // Product selection variables (retained, but only for editing/adding custom items)
  List<DSHangModel> _dshangList = []; // Still needed if you want to add new products later
  List<DSHangModel> _filteredDSHangList = [];
  List<ChiTietDonModel> _chiTietDonList = [];
  String _productSearchText = '';
  TextEditingController _productSearchController = TextEditingController();

  // For editing fields in order summary (retained)
  TextEditingController _hoaHong10Controller = TextEditingController(text: '0');
  TextEditingController _tienGui10Controller = TextEditingController(text: '0');
  TextEditingController _thueTNDNController = TextEditingController(text: '0');
  TextEditingController _vanChuyenController = TextEditingController(text: '0');

  // Order data
  DonHangModel? _newOrder;

  // Calculated totals (retained)
  int _tongTien = 0;
  int _vat10 = 0;
  int _tongCong = 0;
  int _thucThu = 0;

  bool _isLoading = true;

  // Color scheme to match main app (retained)
  final Color appBarTop = Color(0xFF024965);
  final Color appBarBottom = Color(0xFF03a6cf);
  final Color buttonColor = Color(0xFF33a7ce);

@override
void initState() {
  super.initState();
  if (widget.editOrder != null) {
        _tenKhachHang2Controller.text = widget.editOrder!.tenKhachHang2 ?? '';
    _loadExistingOrderForEdit();
  } else {
    _loadApprovedDutruOrders();
  }
}

  @override
  void dispose() {
    // Dispose all controllers (retained)
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
    super.dispose();
  }

  // ===== DONHANG SELECTION METHODS (MODIFIED) =====
Future<void> _loadExistingOrderForEdit() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // Set the order data
    _newOrder = widget.editOrder!;
    
    // Load the existing items
    _chiTietDonList = await _dbHelper.getChiTietDonBySoPhieu(widget.editOrder!.soPhieu!);
    
    // Calculate totals
    _updateTotals();
    
    // Load product data for adding new items during edit
    await _loadProductData();  // Add this line
    
    // Skip to step 2 (product selection/editing)
    _currentStep = 2;
    
    setState(() {
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi tải đơn hàng: $e')),
    );
  }
}

  Future<void> _loadApprovedDutruOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<DonHangModel> donHangData = await _dbHelper.getApprovedDutruOrders();
      setState(() {
        _approvedDutruList = donHangData;
        _applySearch(); // Apply search to this new list
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading approved dutru orders: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu đơn dự trù đã duyệt: $e')),
      );
    }
  }

  void _applySearch() {
    if (_searchText.isEmpty) {
      _approvedDutruList = List.from(_approvedDutruList); // Re-assign to trigger UI update
    } else {
      _approvedDutruList = _approvedDutruList.where((order) {
        final search = _searchText.toLowerCase();
        return (order.soPhieu?.toLowerCase().contains(search) ?? false) ||
            (order.tenKhachHang?.toLowerCase().contains(search) ?? false) ||
            (order.nguoiTao?.toLowerCase().contains(search) ?? false);
      }).toList();
    }
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchText = query;
      _loadApprovedDutruOrders(); // Reload to apply search
    });
  }

  void _toggleSelectOrder(DonHangModel order) {
    setState(() {
      if (_selectedDutruOrders.contains(order)) {
        _selectedDutruOrders.remove(order);
      } else {
        _selectedDutruOrders.add(order);
      }
    });
  }

  String _generateSoPhieu() {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username;
    String userPrefix = '';

    // Determine user prefix based on username
    if (username.contains('hm.tranly')) {
      userPrefix = '13162';
    } else if (username.contains('hm.dinhmai')) {
      userPrefix = '1317';
    } else if (username.contains('hm.hoangthao')) {
      userPrefix = '13111';
    } else if (username.contains('hm.lehoa')) {
      userPrefix = 'Kho';
    } else if (username.contains('hm.lemanh')) {
      userPrefix = '13118';
    } else if (username.contains('hm.nguyentoan')) {
      userPrefix = 'Kho';
    } else if (username.contains('hm.nguyendung')) {
      userPrefix = '1312';
    } else if (username.contains('hm.nguyennga')) {
      userPrefix = '13114';
    } else if (username.contains('hm.baoha')) {
      userPrefix = '13181';
    } else if (username.contains('hm.trantien')) {
      userPrefix = '13181';
    } else if (username.contains('hm.myha')) {
      userPrefix = '1312';
    } else if (username.contains('hm.phiminh')) {
      userPrefix = 'Kho';
    } else if (username.contains('hm.thanhhao')) {
      userPrefix = 'SG';
    } else if (username.contains('hm.luongtrang')) {
      userPrefix = 'DN'; // Corrected from Kho based on previous pattern
    } else if (username.contains('hm.damlinh')) {
      userPrefix = 'SG2';
    } else if (username.contains('hm.thanhthao')) {
      userPrefix = 'SG3';
    } else if (username.contains('hm.damchinh')) {
      userPrefix = 'SG4';
    } else if (username.contains('hm.quocchien')) {
      userPrefix = 'SG5';
    } else if (username.contains('hm.thuyvan')) {
      userPrefix = '1312';
    } else if (username.contains('hotel.danang')) {
      userPrefix = '13181';
    } else if (username.contains('hotel.nhatrang')) {
      userPrefix = '1312';
    } else if (username.contains('hm.doanly')) {
      userPrefix = 'Kho';
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
    } else if (username.contains('hm.dinhmai')) {
      return 'HN';
    } else if (username.contains('hm.hoangthao')) {
      return 'HN';
    } else if (username.contains('hm.lehoa')) {
      return 'HN';
    } else if (username.contains('hm.lemanh')) {
      return 'HN';
    } else if (username.contains('hm.nguyentoan')) {
      return 'HN';
    } else if (username.contains('hm.nguyendung')) {
      return 'NT';
    } else if (username.contains('hm.nguyennga')) {
      return 'HN';
    } else if (username.contains('hm.baoha')) {
      return 'DN';
    } else if (username.contains('hm.trantien')) {
      return 'DN';
    } else if (username.contains('hm.myha')) {
      return 'NT';
    } else if (username.contains('hm.phiminh')) {
      return 'HN';
    } else if (username.contains('hm.thanhhao')) {
      return 'SG';
    } else if (username.contains('hm.luongtrang')) {
      return 'DN';
    } else if (username.contains('hm.damlinh')) {
      return 'SG';
    } else if (username.contains('hm.thanhthao')) {
      return 'SG';
    } else if (username.contains('hm.damchinh')) {
      return 'SG';
    } else if (username.contains('hm.quocchien')) {
      return 'SG';
    } else if (username.contains('hm.thuyvan')) {
      return 'NT';
    } else if (username.contains('hotel.danang')) {
      return 'DN';
    } else if (username.contains('hotel.nhatrang')) {
      return 'NT';
    } else if (username.contains('hm.doanly')) {
      return 'HN';
    } else {
      return 'HN'; // Default value
    }
  }

  // This method will be triggered when the "Tạo" button is pressed
  Future<void> _createXNKOrder() async {
    if (_selectedDutruOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn ít nhất một đơn dự trù để tạo đơn XNK.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final soPhieu = _generateSoPhieu();
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final thoiGianDatHang = _getThoiGianDatHang();
    final currentMonth = DateFormat('MM/yyyy').format(now);

_newOrder = DonHangModel(
  soPhieu: soPhieu,
  nguoiTao: userCredentials.username,
  ngay: formattedDate,
  tenKhachHang: 'XNK Đặt hàng tháng $currentMonth',
  sdtKhachHang: '',  
  soPO: '',  
  diaChi: '',  
  mst: '',  
  tapKH: 'KH Truyền thống', // Default
  tenNguoiGiaoDich: '',  
  boPhanGiaoDich: '',  
  sdtNguoiGiaoDich: '',  
  thoiGianDatHang: thoiGianDatHang,
  ngayYeuCauGiao: DateFormat('yyyy-MM-dd').format(_ngayYeuCauGiao),
  thoiGianCapNhatTrangThai: currentDateTime,
  phuongThucThanhToan: 'Chuyển khoản', // Default
  thanhToanSauNhanHangXNgay: 40, // Default
  datCocSauXNgay: 0,  
  giayToCanKhiGiaoHang: '',  
  thoiGianVietHoaDon: 'Hoá đơn viết ngay khi giao hàng', // Default
  thongTinVietHoaDon: '',  
  diaChiGiaoHang: '',  
  hoTenNguoiNhanHoaHong: '',  
  sdtNguoiNhanHoaHong: '',  
  hinhThucChuyenHoaHong: '',  
  thongTinNhanHoaHong: '',  
  ngaySeGiao: '',  
  thoiGianCapNhatMoiNhat: currentDateTime,
  phuongThucGiaoHang: 'HMGROUP', // Retained
  phuongTienGiaoHang: '',  
  hoTenNguoiGiaoHang: '',  
  ghiChu: 'Tạo từ đơn dự trù đã duyệt: ' + _selectedDutruOrders.map((e) => e.soPhieu).join(', '),
  giaNet: null, // Set to null as it will be calculated from items
  trangThai: 'XNK Đặt hàng', // Specific status for XNK
  tenKhachHang2: 'XNK Đặt hàng tháng $currentMonth',
);

// ✅ THEN set the controller text AFTER creating the order
_tenKhachHang2Controller.text = _newOrder!.tenKhachHang2 ?? 'XNK Đặt hàng tháng $currentMonth';

    // Generate ChiTietDon records
    _chiTietDonList.clear();
    for (DonHangModel selectedOrder in _selectedDutruOrders) {
      final List<ChiTietDonModel> originalItems = await _dbHelper.getChiTietDonBySoPhieu(selectedOrder.soPhieu ?? '');
      for (ChiTietDonModel originalItem in originalItems) {
        final newChiTiet = ChiTietDonModel(
          uid: 'TEMP-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}', // New UID
          soPhieu: soPhieu, // New SoPhieu
          trangThai: 'Nháp', // Default status for new items in XNK
          tenHang: originalItem.tenHang,
          maHang: originalItem.maHang,
          donViTinh: originalItem.donViTinh,
          soLuongYeuCau: originalItem.soLuongYeuCau,
          donGia: 0, // Set to 0 as requested
          thanhTien: ((originalItem.soLuongKhachNhan ?? 0) * (originalItem.soLuongYeuCau ?? 0)).toInt(), // Calculate using SoLuongKhachNhan
          soLuongThucGiao: originalItem.soLuongThucGiao,
          chiNhanh: thoiGianDatHang, // New ChiNhanh based on current user
          idHang: originalItem.idHang,
          soLuongKhachNhan: originalItem.soLuongKhachNhan, // Keep original foreign price
          duyet: 'Chưa xong',
          xuatXuHangKhac: originalItem.xuatXuHangKhac ?? 'VNĐ', // Default to VNĐ if empty
          baoGia: selectedOrder.nguoiTao, // BaoGia = original order's NguoiTao
          hinhAnh: originalItem.hinhAnh,
          ghiChu: originalItem.ghiChu,
          phanTramVAT: originalItem.phanTramVAT,
          vat: (((originalItem.soLuongKhachNhan ?? 0) * (originalItem.soLuongYeuCau ?? 0)) * (originalItem.phanTramVAT ?? 0) / 100).toInt(), // Calculate VAT using SoLuongKhachNhan
          tenKhachHang: _newOrder?.tenKhachHang, // New TenKhachHang
          updateTime: currentDateTime,
        );
        _chiTietDonList.add(newChiTiet);
      }
    }

    _updateTotals(); // Calculate totals based on the new items
    _loadProductData(); // Load product data just in case new items need to be added or edited later

    setState(() {
      _isLoading = false;
      _currentStep = 2; // Move directly to product selection/review step
    });
  }

  // Removed _selectCustomer method and related _isBaoGia and _orderType

  // ===== PRODUCT SELECTION METHODS (RETAINED, with minor adjustments) =====

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
        SnackBar(content: Text('Không thể tải dữ liệu sản phẩm: $e')),
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
  TextEditingController soLuongYeuCauController = TextEditingController(text: '1');
  TextEditingController giaNegoaiTeController = TextEditingController(text: '0'); // Changed from donGiaController
  TextEditingController ghiChuController = TextEditingController();
  TextEditingController customBaoGiaController = TextEditingController(); // For custom BaoGia input

  int phanTramVAT = 0;
  String? selectedBaoGia; // Selected BaoGia value
  String selectedCurrency = 'VNĐ'; // Selected currency for XuatXuHangKhac
  bool isCustomBaoGia = false; // Track if "Khác" is selected

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          // Calculate thanhTien and VAT using giaNegoaiTe (SoLuongKhachNhan)
          double soLuongYeuCau = double.tryParse(soLuongYeuCauController.text) ?? 0;
          double giaNegoaiTe = double.tryParse(giaNegoaiTeController.text) ?? 0.0;
int thanhTien = (soLuongYeuCau * giaNegoaiTe).toInt();
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

                 // BaoGia dropdown selection
                 DropdownButtonFormField<String>(
                   decoration: InputDecoration(
                     labelText: 'Báo giá *',
                     border: OutlineInputBorder(),
                   ),
                   value: selectedBaoGia,
                   items: _baoGiaOptions.map((String value) {
                     return DropdownMenuItem<String>(
                       value: value,
                       child: Text(value),
                     );
                   }).toList(),
                   onChanged: (String? newValue) {
                     setState(() {
                       selectedBaoGia = newValue;
                       isCustomBaoGia = newValue == 'Khác';
                       if (!isCustomBaoGia) {
                         customBaoGiaController.clear();
                       }
                     });
                   },
                 ),

                 SizedBox(height: 16),

                 // Custom BaoGia input (only show if "Khác" is selected)
                 if (isCustomBaoGia)
                   Column(
                     children: [
                       TextField(
                         controller: customBaoGiaController,
                         decoration: InputDecoration(
                           labelText: 'Nhập báo giá tùy chỉnh *',
                           border: OutlineInputBorder(),
                         ),
                       ),
                       SizedBox(height: 16),
                     ],
                   ),

                 // Currency dropdown for XuatXuHangKhac
                 DropdownButtonFormField<String>(
                   decoration: InputDecoration(
                     labelText: 'Loại tiền tệ *',
                     border: OutlineInputBorder(),
                   ),
                   value: selectedCurrency,
                   items: _currencyOptions.map((String value) {
                     return DropdownMenuItem<String>(
                       value: value,
                       child: Text(value),
                     );
                   }).toList(),
                   onChanged: (String? newValue) {
                     setState(() {
                       selectedCurrency = newValue ?? 'VNĐ';
                     });
                   },
                 ),

                 SizedBox(height: 16),

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
                   readOnly: !isSpecialProduct,
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

                 // Changed from "Đơn giá" to "Giá ngoại tệ"
                 TextField(
                   controller: giaNegoaiTeController,
                   decoration: InputDecoration(
                     labelText: 'Giá ngoại tệ *',
                     border: OutlineInputBorder(),
                     suffixText: selectedCurrency,
                   ),
                   keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                     SnackBar(content: Text('Tên hàng không được để trống')),
                   );
                   return;
                 }

                 if (selectedBaoGia == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Vui lòng chọn báo giá')),
                   );
                   return;
                 }

                 if (isCustomBaoGia && customBaoGiaController.text.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Vui lòng nhập báo giá tùy chỉnh')),
                   );
                   return;
                 }

                 if (soLuongYeuCauController.text.isEmpty ||
                     double.tryParse(soLuongYeuCauController.text) == 0) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Số lượng yêu cầu phải lớn hơn 0')),
                   );
                   return;
                 }

                 if (giaNegoaiTeController.text.isEmpty ||
    (double.tryParse(giaNegoaiTeController.text) ?? 0.0) == 0.0) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Giá ngoại tệ phải lớn hơn 0')),
                   );
                   return;
                 }

                 String itemTrangThai = 'Nháp'; // New items start as Nháp
                 
                 // Get the final BaoGia value
                 String finalBaoGia = isCustomBaoGia ? customBaoGiaController.text : selectedBaoGia!;

                 // Create a new ChiTietDonModel
                 final newChiTiet = ChiTietDonModel(
                   uid: 'TEMP-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}',
                   soPhieu: _newOrder?.soPhieu,
                   trangThai: itemTrangThai,
                   tenHang: tenHangController.text,
                   maHang: maHangController.text,
                   donViTinh: donViTinhController.text,
                   soLuongYeuCau: double.tryParse(soLuongYeuCauController.text) ?? 0,
                   donGia: 0, // Set to 0 as requested
                   thanhTien: thanhTien,
                   soLuongThucGiao: 0,
                   chiNhanh: _newOrder?.thoiGianDatHang,
                   idHang: isSpecialProduct ? 'KHAC' : product!.uid,
                   soLuongKhachNhan: double.tryParse(giaNegoaiTeController.text) ?? 0.0, // Store foreign price here
                   duyet: 'Chưa xong',
                   xuatXuHangKhac: selectedCurrency, // Store selected currency
                   baoGia: finalBaoGia, // Use the selected/custom BaoGia value
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
       },
     );
   },
 );
}

 void _showEditProductDialog(ChiTietDonModel chiTietDon, int index) {
   final bool isSpecialProduct = chiTietDon.idHang == 'KHAC';

   TextEditingController tenHangController = TextEditingController(text: chiTietDon.tenHang ?? '');
   TextEditingController maHangController = TextEditingController(text: chiTietDon.maHang ?? '');
   TextEditingController donViTinhController = TextEditingController(text: chiTietDon.donViTinh ?? '');
   TextEditingController soLuongYeuCauController = TextEditingController(
       text: chiTietDon.soLuongYeuCau?.toString() ?? '1');
   TextEditingController giaNegoaiTeController = TextEditingController(
       text: chiTietDon.soLuongKhachNhan?.toString() ?? '0'); // Changed from donGiaController
   TextEditingController ghiChuController = TextEditingController(text: chiTietDon.ghiChu ?? '');

   int phanTramVAT = chiTietDon.phanTramVAT ?? 0;
   String selectedCurrency = chiTietDon.xuatXuHangKhac ?? 'VNĐ'; // Get current currency

   showDialog(
     context: context,
     builder: (context) {
       return StatefulBuilder(
         builder: (context, setState) {
           // Calculate thanhTien and VAT using giaNegoaiTe (SoLuongKhachNhan)
           double soLuongYeuCau = double.tryParse(soLuongYeuCauController.text) ?? 0;
           double giaNegoaiTe = double.tryParse(giaNegoaiTeController.text) ?? 0.0;
int thanhTien = (soLuongYeuCau * giaNegoaiTe).toInt();
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

                   // Currency dropdown for XuatXuHangKhac
                   DropdownButtonFormField<String>(
                     decoration: InputDecoration(
                       labelText: 'Loại tiền tệ *',
                       border: OutlineInputBorder(),
                     ),
                     value: selectedCurrency,
                     items: _currencyOptions.map((String value) {
                       return DropdownMenuItem<String>(
                         value: value,
                         child: Text(value),
                       );
                     }).toList(),
                     onChanged: (String? newValue) {
                       setState(() {
                         selectedCurrency = newValue ?? 'VNĐ';
                       });
                     },
                   ),

                   SizedBox(height: 16),

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
                     readOnly: !isSpecialProduct,
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

                   // Changed from "Đơn giá" to "Giá ngoại tệ"
                   TextField(
                     controller: giaNegoaiTeController,
                     decoration: InputDecoration(
                       labelText: 'Giá ngoại tệ *',
                       border: OutlineInputBorder(),
                       suffixText: selectedCurrency,
                     ),
                     keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                       SnackBar(content: Text('Tên hàng không được để trống')),
                     );
                     return;
                   }

                   if (soLuongYeuCauController.text.isEmpty ||
                       double.tryParse(soLuongYeuCauController.text) == 0) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Số lượng yêu cầu phải lớn hơn 0')),
                     );
                     return;
                   }

                   if (giaNegoaiTeController.text.isEmpty ||
    (double.tryParse(giaNegoaiTeController.text) ?? 0.0) == 0.0) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Giá ngoại tệ phải lớn hơn 0')),
                     );
                     return;
                   }
                   String itemTrangThai = chiTietDon.trangThai ?? 'Nháp';
                   // Update the ChiTietDonModel
                   final updatedChiTiet = ChiTietDonModel(
                     uid: chiTietDon.uid,
                     soPhieu: chiTietDon.soPhieu,
                     trangThai: itemTrangThai,
                     tenHang: tenHangController.text,
                     maHang: maHangController.text,
                     donViTinh: donViTinhController.text,
                     soLuongYeuCau: double.tryParse(soLuongYeuCauController.text) ?? 0,
                     donGia: 0, // Set to 0 as requested
                     thanhTien: thanhTien,
                     soLuongThucGiao: chiTietDon.soLuongThucGiao,
                     chiNhanh: chiTietDon.chiNhanh,
                     idHang: chiTietDon.idHang,
                     soLuongKhachNhan: double.tryParse(giaNegoaiTeController.text) ?? 0.0, // Store foreign price here
                     duyet: chiTietDon.duyet,
                     xuatXuHangKhac: selectedCurrency, // Store selected currency
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
         },
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
         },
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
         title: Text('Đang gửi đơn hàng'),
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

     // Update the newOrder object with final values
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
       tongTien: _tongTien,
       vat10: _vat10,
       tongCong: _tongCong,
       hoaHong10: hoaHong10,
       tienGui10: tienGui10,
       thueTNDN: thueTNDN,
       vanChuyen: vanChuyen,
       thucThu: thucThu,
       nguoiNhanHang: '', 
       sdtNguoiNhanHang: '', 
       phieuXuatKho: '',
       trangThai: _newOrder?.trangThai,
       tenKhachHang2 : _tenKhachHang2Controller.text,
     );

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
       'NguoiNhanHang': '', // Empty for now
       'SDTNguoiNhanHang': '', // Empty for now
       'PhieuXuatKho': '', // Empty for now
       'TrangThai': _newOrder?.trangThai,
       'TenKhachHang2': _newOrder?.tenKhachHang2,
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
         'DonGia': 0, // Set to 0 as requested
         'ThanhTien': item.thanhTien,
         'SoLuongThucGiao': item.soLuongThucGiao,
         'ChiNhanh': item.chiNhanh,
         'IdHang': item.idHang,
         'SoLuongKhachNhan': item.soLuongKhachNhan, // This now contains the foreign price
         'Duyet': item.duyet,
         'XuatXuHangKhac': item.xuatXuHangKhac, // This now contains the currency
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
           content: Text('Đơn hàng đã được tạo thành công.'),
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

                   // Update the newOrder object with final values
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
         },
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
                       subtitle: Text('${item.baoGia != null && item.baoGia!.isNotEmpty ? '[${item.baoGia}] ' : ''}${item.soLuongYeuCau} ${item.donViTinh} x ${currencyFormat.format(item.soLuongKhachNhan)} ${item.xuatXuHangKhac ?? 'VNĐ'}'), // Changed to show foreign price and currency
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
                           subtitle: Text('${item.baoGia != null && item.baoGia!.isNotEmpty ? '[${item.baoGia}] ' : ''}${item.soLuongYeuCau} ${item.donViTinh} x ${currencyFormat.format(item.soLuongKhachNhan)} ${item.xuatXuHangKhac ?? 'VNĐ'}'), // Changed to show foreign price and currency
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
         },
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
 widget.editOrder != null ? 'Sửa đơn hàng XNK' :
 (_currentStep == 0 ? 'Chọn đơn dự trù đã duyệt' :
  _currentStep == 1 ? 'Thông tin đơn hàng (Tự động)' : 'Thêm sản phẩm XNK'),
 style: TextStyle(color: Colors.white),
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
     floatingActionButton: _currentStep == 2
         ? Column(
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
           )
         : null,
   );
 }

 Widget _buildCurrentStep() {
   switch (_currentStep) {
     case 0:
       return _buildDutruSelectionStep();
     case 1:
       // This step is now effectively skipped/automated
       return Center(child: Text('Đang tự động tạo đơn hàng...'));
     case 2:
       return _buildProductSelectionStep();
     default:
       return Container();
   }
 }

 Widget _buildDutruSelectionStep() {
   return Column(
     children: [
       _buildSearchBar(),
       Expanded(
         child: _buildDutruOrderList(),
       ),
       if (_selectedDutruOrders.isNotEmpty)
         Padding(
           padding: const EdgeInsets.all(8.0),
           child: ElevatedButton.icon(
             icon: Icon(Icons.create_new_folder),
             label: Text('Tạo đơn XNK từ (${_selectedDutruOrders.length}) đơn đã chọn'),
             style: ElevatedButton.styleFrom(
               backgroundColor: buttonColor,
               foregroundColor: Colors.white,
               minimumSize: Size.fromHeight(50), // Make button full width
             ),
             onPressed: _createXNKOrder,
           ),
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
         hintText: 'Tìm kiếm theo số phiếu, tên khách hàng, người tạo...',
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

 Widget _buildDutruOrderList() {
   if (_approvedDutruList.isEmpty) {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.assignment, size: 64, color: Colors.grey),
           SizedBox(height: 16),
           Text(
             'Không tìm thấy đơn dự trù đã duyệt',
             style: TextStyle(fontSize: 18, color: Colors.grey),
           ),
           if (_searchText.isNotEmpty)
             TextButton(
               onPressed: () {
                 _searchController.clear();
                 setState(() {
                   _searchText = '';
                   _loadApprovedDutruOrders(); // Reload to remove filter
                 });
               },
               child: Text('Xóa bộ lọc'),
             ),
         ],
       ),
     );
   }

   return ListView.builder(
     itemCount: _approvedDutruList.length,
     itemBuilder: (context, index) {
       final order = _approvedDutruList[index];
       final isSelected = _selectedDutruOrders.contains(order);
       return Card(
         margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
         color: isSelected ? Colors.blue.shade50 : null, // Highlight selected
         child: ListTile(
           title: Text(
             '${order.soPhieu ?? 'N/A'} - ${order.tenKhachHang ?? 'Không có tên'}',
             style: TextStyle(fontWeight: FontWeight.bold),
           ),
           subtitle: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Người tạo: ${order.nguoiTao ?? 'N/A'}'),
               Text('Ngày: ${order.ngay ?? 'N/A'}'),
               if (order.soPO != null && order.soPO!.isNotEmpty)
                 Text('Số PO: ${order.soPO}'),
             ],
           ),
           trailing: ElevatedButton(
             style: ElevatedButton.styleFrom(
               backgroundColor: isSelected ? Colors.grey : buttonColor,
               foregroundColor: Colors.white,
             ),
             child: Text(isSelected ? 'Đã chọn' : 'Chọn'),
             onPressed: () => _toggleSelectOrder(order),
           ),
         ),
       );
     },
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
             'Chưa có sản phẩm nào được tự động tạo. Hãy thêm thủ công.',
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
          'Đơn hàng XNK: ${_newOrder?.soPhieu}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        // Make tenKhachHang2 editable
        TextField(
          controller: _tenKhachHang2Controller,
          decoration: InputDecoration(
            labelText: 'Tên khách hàng 2',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // Update the order object when text changes
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
              tenKhachHang2: value, // Update with new value
              tongTien: _newOrder?.tongTien,
              vat10: _newOrder?.vat10,
              tongCong: _newOrder?.tongCong,
              hoaHong10: _newOrder?.hoaHong10,
              tienGui10: _newOrder?.tienGui10,
              thueTNDN: _newOrder?.thueTNDN,
              vanChuyen: _newOrder?.vanChuyen,
              thucThu: _newOrder?.thucThu,
            );
          },
        ),
        SizedBox(height: 8),
        Text('Ngày: ${_newOrder?.ngay}'),
        Text('Trạng thái: ${_newOrder?.trangThai}'),
               // Add more relevant order header info here if needed
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
                       if (item.baoGia != null && item.baoGia!.isNotEmpty) // Show BaoGia here
                         Text('Từ: ${item.baoGia}'),
                       Text('Mã: ${item.maHang ?? 'N/A'} | ${item.soLuongYeuCau} ${item.donViTinh}'),
                       Text('Giá ngoại tệ: ${currencyFormat.format(item.soLuongKhachNhan)} ${item.xuatXuHangKhac ?? 'VNĐ'}'), // Changed to show foreign price and currency
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
 }
}