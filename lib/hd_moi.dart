// hd_moi.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hd_chiphi.dart';

class HDMoiScreen extends StatefulWidget {
  @override
  _HDMoiScreenState createState() => _HDMoiScreenState();
}

class _HDMoiScreenState extends State<HDMoiScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  
  // Arguments from navigation
  LinkHopDongModel? _editingContract;
  bool _isEdit = false;
  String _username = '';
  String _userRole = '';
  String _currentPeriod = '';
  String _nextPeriod = '';
  String _selectedPeriod = '';
  DateTime? _selectedThoiHanBatDau;
DateTime? _selectedThoiHanKetthuc;
String _selectedThang = '';
bool _isDataLoaded = false;
  // Form controllers - Basic Info
  final TextEditingController _tenHopDongController = TextEditingController();
  final TextEditingController _maKinhDoanhController = TextEditingController();
  final TextEditingController _diaChiController = TextEditingController();
  final TextEditingController _soHopDongController = TextEditingController();
  final TextEditingController _ghiChuHopDongController = TextEditingController();
  
  // Form controllers - Worker Info
  final TextEditingController _congNhanHopDongController = TextEditingController();
  final TextEditingController _congNhanHDTangController = TextEditingController();
  final TextEditingController _congNhanHDGiamController = TextEditingController();
  final TextEditingController _giamSatCoDinhController = TextEditingController();
  
  // Form controllers - Revenue Info
  final TextEditingController _doanhThuCuController = TextEditingController();
  final TextEditingController _comCuController = TextEditingController();
  final TextEditingController _comCu10phantramController = TextEditingController();
  final TextEditingController _comKHThucNhanController = TextEditingController();
  final TextEditingController _comGiamController = TextEditingController();
  final TextEditingController _comTangKhongThueController = TextEditingController();
  final TextEditingController _comTangTinhThueController = TextEditingController();
  final TextEditingController _doanhThuTangCNGiaController = TextEditingController();
  final TextEditingController _doanhThuXuatHoaDonController = TextEditingController();
  
  // Form controllers - Contract Period
  final TextEditingController _thoiHanHopDongController = TextEditingController();
  final TextEditingController _thoiHanBatDauController = TextEditingController();
  final TextEditingController _thoiHanKetthucController = TextEditingController();
  
  // Form controllers - Costs
  final TextEditingController _chiPhiGiamSatController = TextEditingController();
  final TextEditingController _giaNetCNController = TextEditingController();
  
  // Form controllers - Additional Info
  final TextEditingController _daoHanHopDongController = TextEditingController();
  final TextEditingController _congViecCanGiaiQuyetController = TextEditingController();
  final TextEditingController _comTenKhachHangController = TextEditingController();
  
  // Form controllers - Worker Shifts
  final TextEditingController _congNhanCa1Controller = TextEditingController();
  final TextEditingController _congNhanCa2Controller = TextEditingController();
  final TextEditingController _congNhanCa3Controller = TextEditingController();
  final TextEditingController _congNhanCaHCController = TextEditingController();
  final TextEditingController _congNhanCaKhacController = TextEditingController();
  final TextEditingController _congNhanGhiChuBoTriNhanSuController = TextEditingController();
  
  // Dropdown values
  String _selectedVungMien = '';
  String _selectedTrangThai = 'Duy trì';
  String _selectedLoaiHinh = '';
  String _selectedNetVung = '';
  
  // Calculated values
  double _congNhanDuocCo = 0.0;
  int _doanhThuGiamCNGia = 0;
  int _doanhThuDangThucHien = 0;
  int _doanhThuChenhLech = 0;
  int _comMoi = 0;
  int _phanTramThueMoi = 0;
  int _comThucNhan = 0;
  int _giaTriConLai = 0;
  int _netCN = 0;
  int _chenhLechGia = 0;
  int _chenhLechTong = 0;
  
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingMaKinhDoanh = false;
  int _updatedChiPhiVatLieu = 0;
  int _updatedChiPhiCVDinhKy = 0;
  int _updatedChiPhiLeTetTCa = 0;
  int _updatedChiPhiPhuCap = 0;
  int _updatedChiPhiNgoaiGiao = 0;
  int _updatedChiPhiMayMoc = 0;
  int _updatedChiPhiLuong = 0;
@override
void initState() {
  super.initState();
  _initializeUpdatedCosts();
}
void _initializeUpdatedCosts() {
    if (_editingContract != null) {
      _updatedChiPhiVatLieu = _editingContract!.chiPhiVatLieu ?? 0;
      _updatedChiPhiCVDinhKy = _editingContract!.chiPhiCVDinhKy ?? 0;
      _updatedChiPhiLeTetTCa = _editingContract!.chiPhiLeTetTCa ?? 0;
      _updatedChiPhiPhuCap = _editingContract!.chiPhiPhuCap ?? 0;
      _updatedChiPhiNgoaiGiao = _editingContract!.chiPhiNgoaiGiao ?? 0;
      _updatedChiPhiMayMoc = _editingContract!.chiPhiMayMoc ?? 0;
      _updatedChiPhiLuong = _editingContract!.chiPhiLuong ?? 0;
    }
  }
bool get _canEditThang {
  if (_isEdit && _editingContract != null) {
    final contractThang = _editingContract!.thang;
    print('Checking edit permission:');
    print('Contract thang: $contractThang');
    print('Current period: $_currentPeriod');
    print('Next period: $_nextPeriod');
    print('User role: $_userRole');
    // Admin can always edit
    if (_userRole?.toLowerCase() == 'admin') {
      print('Admin role - can edit');
      return true;
    }
    // Other users can only edit current or next period
    if (contractThang != null) {
      final canEdit = contractThang == _currentPeriod || contractThang == _nextPeriod;
      print('Non-admin edit permission: $canEdit');
      return canEdit;
    }
    return false;
  }
  // For new contracts, everyone can edit
  print('New contract - can edit');
  return true;
}
  @override
void didChangeDependencies() {
  super.didChangeDependencies();
  // Only load once to prevent reset issues
  if (!_isDataLoaded) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _editingContract = args['contract'] as LinkHopDongModel?;
      _isEdit = args['isEdit'] as bool? ?? false;
      _username = args['username'] as String? ?? '';
      _userRole = args['userRole'] as String? ?? '';
      _currentPeriod = args['currentPeriod'] as String? ?? '';
      _nextPeriod = args['nextPeriod'] as String? ?? '';
      _selectedPeriod = args['selectedPeriod'] as String? ?? '';
      
      // Set default thang for new contracts (first day of month)
      if (!_isEdit) {
        _selectedThang = _formatToFirstDayOfMonth(_currentPeriod);
        // Automatically fetch MaKinhDoanh for new contracts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchMaKinhDoanh();
        });
      }
      
      print('Route arguments loaded:');
      print('isEdit: $_isEdit');
      print('username: $_username');
      print('userRole: $_userRole');
      print('currentPeriod: $_currentPeriod');
      print('nextPeriod: $_nextPeriod');
      
      // Load contract data if editing
      if (_isEdit && _editingContract != null) {
        _loadContractData();
      }
      _isDataLoaded = true; 
    }
  }
}
String _formatToFirstDayOfMonth(String period) {
    try {
      // If period is like "2024-12", convert to "2024-12-01"
      if (period.length == 7 && period.contains('-')) {
        return '$period-01';
      }
      // If already in full date format, extract year-month and add -01
      if (period.length >= 10) {
        return '${period.substring(0, 7)}-01';
      }
      return period;
    } catch (e) {
      return period;
    }
  }
  @override
  void dispose() {
    // Dispose all controllers
    _tenHopDongController.dispose();
    _maKinhDoanhController.dispose();
    _diaChiController.dispose();
    _soHopDongController.dispose();
    _ghiChuHopDongController.dispose();
    _congNhanHopDongController.dispose();
    _congNhanHDTangController.dispose();
    _congNhanHDGiamController.dispose();
    _giamSatCoDinhController.dispose();
    _doanhThuCuController.dispose();
    _comCuController.dispose();
    _comCu10phantramController.dispose();
    _comKHThucNhanController.dispose();
    _comGiamController.dispose();
    _comTangKhongThueController.dispose();
    _comTangTinhThueController.dispose();
    _doanhThuTangCNGiaController.dispose();
    _doanhThuXuatHoaDonController.dispose();
    _thoiHanHopDongController.dispose();
    _thoiHanBatDauController.dispose();
    _thoiHanKetthucController.dispose();
    _chiPhiGiamSatController.dispose();
    _giaNetCNController.dispose();
    _daoHanHopDongController.dispose();
    _congViecCanGiaiQuyetController.dispose();
    _comTenKhachHangController.dispose();
    _congNhanCa1Controller.dispose();
    _congNhanCa2Controller.dispose();
    _congNhanCa3Controller.dispose();
    _congNhanCaHCController.dispose();
    _congNhanCaKhacController.dispose();
    _congNhanGhiChuBoTriNhanSuController.dispose();
    super.dispose();
  }
Future<void> _fetchMaKinhDoanh() async {
  if (_isEdit) return; // Only fetch for new contracts
  
  setState(() {
    _isLoadingMaKinhDoanh = true;
  });
  
  try {
    final response = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hdsomoi'),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    
    print('MaKinhDoanh API Response Status: ${response.statusCode}');
    print('MaKinhDoanh API Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      try {
        final responseData = json.decode(response.body);
        final soMoi = responseData['soMoi'];
        
        if (soMoi != null) {
          setState(() {
            _maKinhDoanhController.text = soMoi.toString();
          });
          print('MaKinhDoanh set to: $soMoi');
        } else {
          print('soMoi field not found in response');
        }
      } catch (e) {
        print('Error parsing JSON response: $e');
      }
    } else {
      print('Failed to fetch MaKinhDoanh: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching MaKinhDoanh: $e');
  } finally {
    setState(() {
      _isLoadingMaKinhDoanh = false;
    });
  }
}
  void _loadContractData() {
    if (_editingContract != null && !_isDataLoaded) {
      final contract = _editingContract!;
      
      // Load data synchronously to prevent reset issues
      _tenHopDongController.text = contract.tenHopDong ?? '';
      _maKinhDoanhController.text = contract.maKinhDoanh ?? '';
      _soHopDongController.text = contract.soHopDong ?? '';
      _diaChiController.text = contract.diaChi ?? '';
      _ghiChuHopDongController.text = contract.ghiChuHopDong ?? '';
      
      // Set dropdown values
      _selectedVungMien = contract.vungMien ?? '';
      _selectedTrangThai = contract.trangThai ?? 'Duy trì';
      _selectedLoaiHinh = contract.loaiHinh ?? '';
      _selectedNetVung = contract.netVung ?? '';
      _selectedThang = contract.thang ?? _formatToFirstDayOfMonth(_currentPeriod);
      
      // Worker info
      _congNhanHopDongController.text = contract.congNhanHopDong?.toString() ?? '';
      _giamSatCoDinhController.text = contract.giamSatCoDinh?.toString() ?? '';
      _congNhanHDTangController.text = contract.congNhanHDTang?.toString() ?? '';
      _congNhanHDGiamController.text = contract.congNhanHDGiam?.toString() ?? '';
      
      // Revenue fields
      _doanhThuCuController.text = contract.doanhThuCu?.toString() ?? '';
      _doanhThuXuatHoaDonController.text = contract.doanhThuXuatHoaDon?.toString() ?? '';
      _comCuController.text = contract.comCu?.toString() ?? '';
      _comCu10phantramController.text = contract.comCu10phantram?.toString() ?? '';
      _comKHThucNhanController.text = contract.comKHThucNhan?.toString() ?? '';
      _comGiamController.text = contract.comGiam?.toString() ?? '';
      _comTangKhongThueController.text = contract.comTangKhongThue?.toString() ?? '';
      _comTangTinhThueController.text = contract.comTangTinhThue?.toString() ?? '';
      _doanhThuTangCNGiaController.text = contract.doanhThuTangCNGia?.toString() ?? '';
      _comTenKhachHangController.text = contract.comTenKhachHang ?? '';
      
      // Contract period
      _thoiHanHopDongController.text = contract.thoiHanHopDong?.toString() ?? '';
      
      // Parse dates properly
      if (contract.thoiHanBatDau != null && contract.thoiHanBatDau!.isNotEmpty) {
        try {
          _selectedThoiHanBatDau = DateTime.parse(contract.thoiHanBatDau!);
          _thoiHanBatDauController.text = DateFormat('yyyy-MM-dd').format(_selectedThoiHanBatDau!);
        } catch (e) {
          _thoiHanBatDauController.text = contract.thoiHanBatDau ?? '';
        }
      }
      
      if (contract.thoiHanKetthuc != null && contract.thoiHanKetthuc!.isNotEmpty) {
        try {
          _selectedThoiHanKetthuc = DateTime.parse(contract.thoiHanKetthuc!);
          _thoiHanKetthucController.text = DateFormat('yyyy-MM-dd').format(_selectedThoiHanKetthuc!);
        } catch (e) {
          _thoiHanKetthucController.text = contract.thoiHanKetthuc ?? '';
        }
      }
      
      // Cost fields
      _chiPhiGiamSatController.text = contract.chiPhiGiamSat?.toString() ?? '';
      _giaNetCNController.text = contract.giaNetCN?.toString() ?? '';
      
      // Additional info
      _daoHanHopDongController.text = contract.daoHanHopDong ?? '';
      _congViecCanGiaiQuyetController.text = contract.congViecCanGiaiQuyet ?? '';
      
      // Worker shifts
      _congNhanCa1Controller.text = contract.congNhanCa1 ?? '';
      _congNhanCa2Controller.text = contract.congNhanCa2 ?? '';
      _congNhanCa3Controller.text = contract.congNhanCa3 ?? '';
      _congNhanCaHCController.text = contract.congNhanCaHC ?? '';
      _congNhanCaKhacController.text = contract.congNhanCaKhac ?? '';
      _congNhanGhiChuBoTriNhanSuController.text = contract.congNhanGhiChuBoTriNhanSu ?? '';
      
      print('Contract data loaded successfully');
      print('tenHopDong loaded: ${_tenHopDongController.text}');
      _initializeUpdatedCosts();
      // Trigger calculations after loading data
      _calculateDerivedValues();
    }
  }
  Widget _buildThangSelection() {
    if (!_isEdit) {
      return Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedThang.isNotEmpty ? _selectedThang : null,
            decoration: InputDecoration(
              labelText: 'Tháng *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month),
            ),
            items: [
              DropdownMenuItem(
                value: _formatToFirstDayOfMonth(_currentPeriod), 
                child: Text('${_formatToFirstDayOfMonth(_currentPeriod)} (Hiện tại)')
              ),
              DropdownMenuItem(
                value: _formatToFirstDayOfMonth(_nextPeriod), 
                child: Text('${_formatToFirstDayOfMonth(_nextPeriod)} (Tiếp theo)')
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedThang = value ?? _formatToFirstDayOfMonth(_currentPeriod);
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng chọn tháng';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
        ],
      );
    } else {
      return Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Tháng: ${_selectedThang}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
      );
    }
  }
Future<void> _selectStartDate() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedThoiHanBatDau ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
  );
  if (picked != null) {
    setState(() {
      _selectedThoiHanBatDau = picked;
      _thoiHanBatDauController.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }
}

Future<void> _selectEndDate() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedThoiHanKetthuc ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
  );
  if (picked != null) {
    setState(() {
      _selectedThoiHanKetthuc = picked;
      _thoiHanKetthucController.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }
}
  void _calculateDerivedValues() {
    // Parse input values
    double congNhanHopDong = double.tryParse(_congNhanHopDongController.text) ?? 0.0;
    double congNhanHDTang = double.tryParse(_congNhanHDTangController.text) ?? 0.0;
    double congNhanHDGiam = double.tryParse(_congNhanHDGiamController.text) ?? 0.0;
    
    int doanhThuCu = int.tryParse(_doanhThuCuController.text) ?? 0;
    int comCu = int.tryParse(_comCuController.text) ?? 0;
    int comCu10phantram = int.tryParse(_comCu10phantramController.text) ?? 0;
    int comGiam = int.tryParse(_comGiamController.text) ?? 0;
    int comTangKhongThue = int.tryParse(_comTangKhongThueController.text) ?? 0;
    int comTangTinhThue = int.tryParse(_comTangTinhThueController.text) ?? 0;
    int doanhThuTangCNGia = int.tryParse(_doanhThuTangCNGiaController.text) ?? 0;
    int doanhThuXuatHoaDon = int.tryParse(_doanhThuXuatHoaDonController.text) ?? 0;
    int giaNetCN = int.tryParse(_giaNetCNController.text) ?? 0;
    
    // Use updated cost values instead of original contract values
    int chiPhiGiamSat = int.tryParse(_chiPhiGiamSatController.text) ?? 0;
    int chiPhiVatLieu = _updatedChiPhiVatLieu;
    int chiPhiCVDinhKy = _updatedChiPhiCVDinhKy;
    int chiPhiLeTetTCa = _updatedChiPhiLeTetTCa;
    int chiPhiPhuCap = _updatedChiPhiPhuCap;
    int chiPhiNgoaiGiao = _updatedChiPhiNgoaiGiao;
    int chiPhiMayMoc = _updatedChiPhiMayMoc;
    int chiPhiLuong = _updatedChiPhiLuong;
    
    // Calculate derived values
    _congNhanDuocCo = congNhanHopDong + congNhanHDTang - congNhanHDGiam;
    _doanhThuGiamCNGia = (_netCN * congNhanHDGiam).round();
    _doanhThuDangThucHien = doanhThuCu + comTangKhongThue + comTangTinhThue + doanhThuTangCNGia - _doanhThuGiamCNGia;
    _doanhThuChenhLech = _doanhThuDangThucHien - doanhThuXuatHoaDon;
    _comMoi = comCu - comGiam + comTangKhongThue + comTangTinhThue;
    _phanTramThueMoi = (comTangTinhThue * 0.1).round() + comCu10phantram;
    _comThucNhan = _comMoi - _phanTramThueMoi;
    
    _giaTriConLai = _doanhThuDangThucHien - _comMoi - chiPhiGiamSat - chiPhiVatLieu - 
                   chiPhiCVDinhKy - chiPhiLeTetTCa - chiPhiPhuCap - chiPhiNgoaiGiao - 
                   chiPhiMayMoc - chiPhiLuong;
    
    _netCN = _congNhanDuocCo > 0 ? (_giaTriConLai / _congNhanDuocCo).round() : 0;
    _chenhLechGia = _netCN - giaNetCN;
    _chenhLechTong = (_congNhanDuocCo * _chenhLechGia).round();
    
    setState(() {}); // Refresh UI with calculated values
  }

  Future<void> _saveContract() async {
  if (!_formKey.currentState!.validate()) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vui lòng kiểm tra lại thông tin nhập'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() {
    _isSaving = true;
  });

  try {
    // Prepare the data for submission
    final contractData = _prepareContractData();
    
    // Submit to API
    final success = await _submitToAPI(contractData);
    
    if (success) {
      // Show success message
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Thành công'),
              ],
            ),
            content: Text(
              _isEdit 
                ? 'Hợp đồng đã được cập nhật thành công!\n\nVui lòng quay lại menu chính để làm mới dữ liệu.'
                : 'Hợp đồng đã được tạo thành công!\n\nVui lòng quay lại menu chính để làm mới dữ liệu.'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Return to previous screen with success flag
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isSaving = false;
    });
  }
}
Map<String, dynamic> _prepareContractData() {
    final data = <String, dynamic>{
      'tenHopDong': _tenHopDongController.text.trim(),
      'maKinhDoanh': _maKinhDoanhController.text.trim(),
      'soHopDong': _soHopDongController.text.trim(),
      'diaChi': _diaChiController.text.trim(),
      'vungMien': _selectedVungMien,
      'trangThai': _selectedTrangThai,
      'loaiHinh': _selectedLoaiHinh,
      'ghiChuHopDong': _ghiChuHopDongController.text.trim(),
      
      // Worker info - FIX: Send as double, not boolean
      'congNhanHopDong': _parseDouble(_congNhanHopDongController.text),
      'giamSatCoDinh': _parseDouble(_giamSatCoDinhController.text),
      'congNhanHDTang': _parseDouble(_congNhanHDTangController.text),
      'congNhanHDGiam': _parseDouble(_congNhanHDGiamController.text),
      'congNhanDuocCo': _congNhanDuocCo, 
      // Revenue info
      'doanhThuCu': _parseInt(_doanhThuCuController.text),
      'doanhThuXuatHoaDon': _parseInt(_doanhThuXuatHoaDonController.text),
      'comCu': _parseInt(_comCuController.text),
      'comCu10phantram': _parseInt(_comCu10phantramController.text),
      'comKHThucNhan': _parseInt(_comKHThucNhanController.text),
      'comGiam': _parseInt(_comGiamController.text),
      'comTangKhongThue': _parseInt(_comTangKhongThueController.text),
      'comTangTinhThue': _parseInt(_comTangTinhThueController.text),
      'doanhThuTangCNGia': _parseInt(_doanhThuTangCNGiaController.text),
      'comTenKhachHang': _comTenKhachHangController.text.trim(),
      
      // Calculated fields (send as calculated)
      'doanhThuGiamCNGia': _doanhThuGiamCNGia,
      'doanhThuDangThucHien': _doanhThuDangThucHien,
      'doanhThuChenhLech': _doanhThuChenhLech,
      'comMoi': _comMoi,
      'phanTramThueMoi': _phanTramThueMoi,
      'comThucNhan': _comThucNhan,
      
      // Contract period
      'thoiHanHopDong': _parseInt(_thoiHanHopDongController.text),
      'thoiHanBatDau': _selectedThoiHanBatDau != null 
          ? DateFormat('yyyy-MM-dd').format(_selectedThoiHanBatDau!) 
          : (_thoiHanBatDauController.text.trim().isNotEmpty ? _thoiHanBatDauController.text.trim() : null),
      'thoiHanKetthuc': _selectedThoiHanKetthuc != null 
          ? DateFormat('yyyy-MM-dd').format(_selectedThoiHanKetthuc!) 
          : (_thoiHanKetthucController.text.trim().isNotEmpty ? _thoiHanKetthucController.text.trim() : null),
      
      // Costs
      'chiPhiGiamSat': _parseInt(_chiPhiGiamSatController.text),
      'giaNetCN': _parseInt(_giaNetCNController.text),
      'netVung': _selectedNetVung,
            'chiPhiVatLieu': _updatedChiPhiVatLieu,
      'chiPhiCVDinhKy': _updatedChiPhiCVDinhKy,
      'chiPhiLeTetTCa': _updatedChiPhiLeTetTCa,
      'chiPhiPhuCap': _updatedChiPhiPhuCap,
      'chiPhiNgoaiGiao': _updatedChiPhiNgoaiGiao,
      'chiPhiMayMoc': _updatedChiPhiMayMoc,
      'chiPhiLuong': _updatedChiPhiLuong,
      // Calculated costs
      'giaTriConLai': _giaTriConLai,
      'netCN': _netCN,
      'chenhLechGia': _chenhLechGia,
      'chenhLechTong': _chenhLechTong,
      
      // Additional info
      'daoHanHopDong': _daoHanHopDongController.text.trim(),
      'congViecCanGiaiQuyet': _congViecCanGiaiQuyetController.text.trim(),
      
      // Worker shifts
      'congNhanCa1': _congNhanCa1Controller.text.trim(),
      'congNhanCa2': _congNhanCa2Controller.text.trim(),
      'congNhanCa3': _congNhanCa3Controller.text.trim(),
      'congNhanCaHC': _congNhanCaHCController.text.trim(),
      'congNhanCaKhac': _congNhanCaKhacController.text.trim(),
      'congNhanGhiChuBoTriNhanSu': _congNhanGhiChuBoTriNhanSuController.text.trim(),
      
      // System fields - Use proper thang format (first day of month)
      'thang': _isEdit ? _selectedThang : _selectedThang,
      'nguoiTao': _username,
    };
    
    // Add uid only for edits
    if (_isEdit && _editingContract?.uid != null) {
      data['uid'] = _editingContract!.uid;
    }
    
    // Clean up empty string values to null for the database
    data.forEach((key, value) {
      if (value is String && value.trim().isEmpty) {
        data[key] = null;
      }
    });
    
    return data;
  }

Future<bool> _submitToAPI(Map<String, dynamic> contractData) async {
  final url = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/hdupdate';
  
  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(contractData),
    );
    
    print('API Response Status: ${response.statusCode}');
    print('API Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData['success'] == true || response.statusCode == 200;
    } else {
      throw Exception('Server returned ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    print('API submission error: $e');
    throw Exception('Không thể kết nối đến server: $e');
  }
}

double? _parseDouble(String text) {
  if (text.trim().isEmpty) return null;
  return double.tryParse(text.trim());
}

int? _parseInt(String text) {
  if (text.trim().isEmpty) return null;
  return int.tryParse(text.trim());
}
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Chỉnh sửa hợp đồng' : 'Tạo hợp đồng mới'),
        backgroundColor: Color(0xFF024965),
        foregroundColor: Colors.white,
        actions: [
          if (_canEditThang)
            IconButton(
              icon: _isSaving 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.save),
              onPressed: _isSaving ? null : _saveContract,
              tooltip: 'Lưu hợp đồng',
            ),
          if (!_canEditThang)
            Tooltip(
              message: 'Không thể chỉnh sửa (ngoài kỳ hiện tại/tiếp theo)',
              child: Icon(Icons.lock, color: Colors.grey),
            ),
        ],
      ),
      body: _buildForm(),
    );
  }

 Widget _buildForm() {
   return SingleChildScrollView(
     padding: EdgeInsets.all(16.0),
     child: Form(
       key: _formKey,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Permission warning
           if (!_canEditThang && _isEdit) ...[
             Card(
               color: Colors.orange[100],
               child: Padding(
                 padding: EdgeInsets.all(16.0),
                 child: Row(
                   children: [
                     Icon(Icons.warning, color: Colors.orange),
                     SizedBox(width: 8),
                     Expanded(
                       child: Text(
                         'Hợp đồng này chỉ có thể chỉnh sửa trong kỳ hiện tại hoặc kỳ tiếp theo.',
                         style: TextStyle(color: Colors.orange[800]),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             SizedBox(height: 16),
           ],

           // Basic Information Card
           _buildBasicInfoCard(),
           SizedBox(height: 16),

           // Worker Information Card
           _buildWorkerInfoCard(),
           SizedBox(height: 16),

           // Revenue Information Card
           _buildRevenueInfoCard(),
           SizedBox(height: 16),

           // Contract Period Card
           _buildContractPeriodCard(),
           SizedBox(height: 16),

           // Costs and Calculations Card
           _buildCostsCalculationsCard(),
           SizedBox(height: 16),

           // Additional Information Card
           _buildAdditionalInfoCard(),
           SizedBox(height: 16),

           // Worker Shifts Card
           _buildWorkerShiftsCard(),
           SizedBox(height: 24),
         ],
       ),
     ),
   );
 }
List<DropdownMenuItem<String>> _buildSafeDropdownItems(List<String> predefinedItems, String? currentValue) {
  List<String> items = List.from(predefinedItems);
  
  // Add current value if it's not null, not empty, and not already in the list
  if (currentValue != null && 
      currentValue.isNotEmpty && 
      !items.contains(currentValue)) {
    items.add(currentValue);
  }
  
  return items.map((item) {
    return DropdownMenuItem<String>(
      value: item,
      child: Text(item),
    );
  }).toList();
}
 Widget _buildBasicInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin cơ bản',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF024965),
              ),
            ),
            SizedBox(height: 16),
            
            // Add thang selection
            _buildThangSelection(),
            
            TextFormField(
              controller: _tenHopDongController,
              decoration: InputDecoration(
                labelText: 'Tên hợp đồng *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              enabled: _canEditThang,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên hợp đồng';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
           
          Row(
  children: [
    Expanded(
      child: TextFormField(
        controller: _maKinhDoanhController,
        decoration: InputDecoration(
          labelText: 'Mã kinh doanh',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.business),
          suffixIcon: !_isEdit ? IconButton(
            icon: _isLoadingMaKinhDoanh 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  ),
                )
              : Icon(Icons.refresh),
            onPressed: _isLoadingMaKinhDoanh ? null : _fetchMaKinhDoanh,
            tooltip: 'Lấy mã mới',
          ) : null,
          helperText: !_isEdit ? 'Tự động tạo mã mới' : null,
        ),
        enabled: _canEditThang, // Allow editing for both new and edit (if period allows)
      ),
    ),
    SizedBox(width: 16),
    Expanded(
      child: TextFormField(
        controller: _soHopDongController,
        decoration: InputDecoration(
          labelText: 'Số hợp đồng',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.numbers),
        ),
        enabled: _canEditThang,
      ),
    ),
  ],
),
           SizedBox(height: 16),
           
           TextFormField(
             controller: _diaChiController,
             decoration: InputDecoration(
               labelText: 'Địa chỉ',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.location_on),
             ),
             enabled: _canEditThang,
             maxLines: 2,
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: DropdownButtonFormField<String>(
  value: _selectedVungMien.isNotEmpty ? _selectedVungMien : null,
  decoration: InputDecoration(
    labelText: 'Miền *',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.map),
  ),
  items: _buildSafeDropdownItems(['Bắc', 'Trung', 'Nam'], _selectedVungMien),
  onChanged: _canEditThang ? (value) {
    setState(() {
      _selectedVungMien = value ?? '';
    });
  } : null,
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng chọn miền';
    }
    return null;
  },
),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: DropdownButtonFormField<String>(
  value: _selectedTrangThai.isNotEmpty ? _selectedTrangThai : null,
  decoration: InputDecoration(
    labelText: 'Trạng thái *',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.flag),
  ),
  items: _buildSafeDropdownItems(['Duy trì', 'Tăng mới', 'Dừng'], _selectedTrangThai),
  onChanged: _canEditThang ? (value) {
    setState(() {
      _selectedTrangThai = value ?? 'Duy trì';
    });
  } : null,
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng chọn trạng thái';
    }
    return null;
  },
),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           DropdownButtonFormField<String>(
  value: _selectedLoaiHinh.isNotEmpty ? _selectedLoaiHinh : null,
  decoration: InputDecoration(
    labelText: 'Loại hình',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.category),
  ),
  items: _buildSafeDropdownItems([
    'NGÂN HÀNG', 'VP.TN', 'BV.KCN', 'TH.CC', 'SB', 
    'TTTM.ST', 'KĐT', 'Liên kề', 'Khác', 'NM', 'NHÀ RIÊNG'
  ], _selectedLoaiHinh),
  onChanged: _canEditThang ? (value) {
    setState(() {
      _selectedLoaiHinh = value ?? '';
    });
  } : null,
),
           SizedBox(height: 16),
           
           TextFormField(
             controller: _ghiChuHopDongController,
             decoration: InputDecoration(
               labelText: 'Ghi chú hợp đồng',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.note),
             ),
             enabled: _canEditThang,
             maxLines: 3,
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildWorkerInfoCard() {
   return Card(
     elevation: 4,
     child: Padding(
       padding: EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'Thông tin công nhân',
             style: TextStyle(
               fontSize: 18,
               fontWeight: FontWeight.bold,
               color: Color(0xFF024965),
             ),
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: TextFormField(
                   controller: _congNhanHopDongController,
                   decoration: InputDecoration(
                     labelText: 'Công nhân theo HĐ *',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.people),
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.numberWithOptions(decimal: true),
                   onChanged: (value) => _calculateDerivedValues(),
                   validator: (value) {
                     if (value != null && value.trim().isNotEmpty) {
                       final parsed = double.tryParse(value.trim());
                       if (parsed == null || parsed <= 0) {
                         return 'Phải lớn hơn 0';
                       }
                     }
                     return null;
                   },
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _giamSatCoDinhController,
                   decoration: InputDecoration(
                     labelText: 'Giám sát cố định',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.supervisor_account),
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.numberWithOptions(decimal: true),
                 ),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: TextFormField(
                   controller: _congNhanHDTangController,
                   decoration: InputDecoration(
                     labelText: 'Công nhân tăng',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.trending_up),
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.numberWithOptions(decimal: true),
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _congNhanHDGiamController,
                   decoration: InputDecoration(
                     labelText: 'Công nhân giảm',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.trending_down),
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.numberWithOptions(decimal: true),
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           Container(
             padding: EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.blue[50],
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.blue[200]!),
             ),
             child: Row(
               children: [
                 Icon(Icons.calculate, color: Colors.blue),
                 SizedBox(width: 8),
                 Text(
                   'Công nhân được có: ${_congNhanDuocCo.toStringAsFixed(1)}',
                   style: TextStyle(
                     fontWeight: FontWeight.bold,
                     color: Colors.blue[800],
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

 Widget _buildRevenueInfoCard() {
   return Card(
     elevation: 4,
     child: Padding(
       padding: EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'Thông tin doanh thu & Commission',
             style: TextStyle(
               fontSize: 18,
               fontWeight: FontWeight.bold,
               color: Color(0xFF024965),
             ),
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: TextFormField(
                   controller: _doanhThuCuController,
                   decoration: InputDecoration(
                     labelText: 'Doanh thu cũ',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.attach_money),
                     suffixText: 'VND',
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.number,
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _doanhThuXuatHoaDonController,
                   decoration: InputDecoration(
                     labelText: 'Doanh thu xuất hoá đơn',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.receipt),
                     suffixText: 'VND',
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.number,
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: TextFormField(
                   controller: _comCuController,
                   decoration: InputDecoration(
                     labelText: 'Com cũ',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.monetization_on),
                     suffixText: 'VND',
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.number,
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _comCu10phantramController,
                   decoration: InputDecoration(
                     labelText: '10% Com cũ',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.percent),
                     suffixText: 'VND',
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.number,
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: TextFormField(
                   controller: _comKHThucNhanController,
                   decoration: InputDecoration(
                     labelText: 'Com KH thực nhận',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.account_balance),
                     suffixText: 'VND',
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.number,
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _comGiamController,
                   decoration: InputDecoration(
                     labelText: 'Com giảm',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.remove_circle),
                     suffixText: 'VND',
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.number,
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: TextFormField(
                   controller: _comTangKhongThueController,
                   decoration: InputDecoration(
                     labelText: 'Com tăng không thuế',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.add_circle),
                     suffixText: 'VND',
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.number,
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _comTangTinhThueController,
                   decoration: InputDecoration(
                     labelText: 'Com tăng tính thuế',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.add_circle_outline),
                     suffixText: 'VND',
                   ),
                   enabled: _canEditThang,
                   keyboardType: TextInputType.number,
                   onChanged: (value) => _calculateDerivedValues(),
                 ),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           TextFormField(
             controller: _doanhThuTangCNGiaController,
             decoration: InputDecoration(
               labelText: 'Doanh thu tăng từ CN và giá',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.trending_up),
               suffixText: 'VND',
             ),
             enabled: _canEditThang,
             keyboardType: TextInputType.number,
             onChanged: (value) => _calculateDerivedValues(),
           ),
           SizedBox(height: 16),
           
           TextFormField(
             controller: _comTenKhachHangController,
             decoration: InputDecoration(
               labelText: 'Tên KH nhận com',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.person),
             ),
             enabled: _canEditThang,
           ),
           SizedBox(height: 16),
           
           // Calculated values display
           Container(
             padding: EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.green[50],
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.green[200]!),
             ),
             child: Column(
               children: [
                 _buildCalculatedRow('Doanh thu giảm CN & giá', _doanhThuGiamCNGia, 'VND'),
                 _buildCalculatedRow('Doanh thu đang thực hiện', _doanhThuDangThucHien, 'VND'),
                 _buildCalculatedRow('Doanh thu chênh lệch', _doanhThuChenhLech, 'VND'),
                 _buildCalculatedRow('Com mới', _comMoi, 'VND'),
                 _buildCalculatedRow('Phần trăm thuế mới', _phanTramThueMoi, 'VND'),
                 _buildCalculatedRow('Com thực nhận', _comThucNhan, 'VND'),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }
Widget _buildContractPeriodCard() {
  return Card(
    elevation: 4,
    child: Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thông tin thời gian hợp đồng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF024965),
            ),
          ),
          SizedBox(height: 16),
          
          TextFormField(
            controller: _thoiHanHopDongController,
            decoration: InputDecoration(
              labelText: 'Thời hạn hợp đồng (tháng)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.schedule),
              suffixText: 'tháng',
              hintText: '1-60 tháng',
            ),
            enabled: _canEditThang,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed < 1 || parsed > 60) {
                  return 'Từ 1 đến 60 tháng';
                }
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          Row(
  children: [
    Expanded(
      child: TextFormField(
        controller: _thoiHanBatDauController,
        decoration: InputDecoration(
          labelText: 'Thời hạn bắt đầu',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.calendar_today),
          suffixIcon: IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _canEditThang ? _selectStartDate : null,
          ),
        ),
        enabled: _canEditThang, // Changed from false to _canEditThang
        readOnly: true, // Add this to prevent keyboard input
        onTap: _canEditThang ? _selectStartDate : null, // Add this for tap to open date picker
      ),
    ),
    SizedBox(width: 16),
    Expanded(
      child: TextFormField(
        controller: _thoiHanKetthucController,
        decoration: InputDecoration(
          labelText: 'Thời hạn kết thúc',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.event),
          suffixIcon: IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _canEditThang ? _selectEndDate : null,
          ),
        ),
        enabled: _canEditThang, // Changed from false to _canEditThang
        readOnly: true, // Add this to prevent keyboard input
        onTap: _canEditThang ? _selectEndDate : null, // Add this for tap to open date picker
      ),
    ),
  ],
),
        ],
      ),
    ),
  );
}

Widget _buildCostsCalculationsCard() {
  return Card(
    elevation: 4,
    child: Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi phí & Tính toán',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF024965),
            ),
          ),
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _chiPhiGiamSatController,
                  decoration: InputDecoration(
                    labelText: 'Chi phí giám sát',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money_off),
                    suffixText: 'VND',
                  ),
                  enabled: _canEditThang,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _calculateDerivedValues(),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _giaNetCNController,
                  decoration: InputDecoration(
                    labelText: 'Giá Net CN',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.price_check),
                    suffixText: 'VND',
                  ),
                  enabled: _canEditThang,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _calculateDerivedValues(),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedNetVung.isNotEmpty ? _selectedNetVung : null,
            decoration: InputDecoration(
              labelText: 'Net Vùng',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city),
            ),
            items: _buildSafeDropdownItems(['Vùng I', 'Vùng II', 'Vùng III'], _selectedNetVung),
            onChanged: _canEditThang ? (value) {
              setState(() {
                _selectedNetVung = value ?? '';
              });
            } : null,
          ),
          SizedBox(height: 16),
          
          // Cost fields with edit buttons
          Text(
            'Chi phí tự động (từ bảng tham chiếu):',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          
            Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Column(
      children: [
        _buildCostRowWithButton('Chi phí Vật tư', 'VatLieu'),
        _buildCostRowWithButton('Chi phí CV Định kỳ', 'CVDinhKy'),
        _buildCostRowWithButton('Chi phí Lễ tết Tăng ca', 'LeTetTCa'),
        _buildCostRowWithButton('Chi phí Phụ cấp', 'PhuCap'),
        _buildCostRowWithButton('Chi phí Ngoại giao', 'NgoaiGiao'),
        _buildCostRowWithButton('Chi phí Máy móc', 'MayMoc'),
        _buildCostRowWithButton('Chi phí Lương', 'Luong'),
      ],
    ),
  ),
          SizedBox(height: 16),
          
          // Final calculations
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                _buildCalculatedRow('Giá trị còn lại', _giaTriConLai, 'VND'),
                _buildCalculatedRow('Net CN', _netCN, 'VND'),
                _buildCalculatedRow('Chênh lệch giá', _chenhLechGia, 'VND'),
                _buildCalculatedRow('Chênh lệch tổng', _chenhLechTong, 'VND'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
int _getUpdatedCostValue(String costType) {
    switch (costType) {
      case 'VatLieu':
        return _updatedChiPhiVatLieu;
      case 'CVDinhKy':
        return _updatedChiPhiCVDinhKy;
      case 'LeTetTCa':
        return _updatedChiPhiLeTetTCa;
      case 'PhuCap':
        return _updatedChiPhiPhuCap;
      case 'NgoaiGiao':
        return _updatedChiPhiNgoaiGiao;
      case 'MayMoc':
        return _updatedChiPhiMayMoc;
      case 'Luong':
        return _updatedChiPhiLuong;
      default:
        return 0;
    }
  }
 Widget _buildCostRowWithButton(String label, String costType) {
    int value = _getUpdatedCostValue(costType);
    String displayValue = NumberFormat('#,##0', 'vi_VN').format(value);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$displayValue VND',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(width: 8),
          if (_canEditThang)
            SizedBox(
              width: 60,
              height: 28,
              child: ElevatedButton(
                onPressed: () => _editCostType(costType),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF024965),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  textStyle: TextStyle(fontSize: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text('Sửa'),
              ),
            ),
        ],
      ),
    );
  }

// Method to handle cost editing - will call methods from hd_chiphi.dart
void _editCostType(String costType) {
  // Prepare context data for the cost editing
  final costEditContext = HDChiPhiContext(
    costType: costType,
    username: _username,
    userRole: _userRole,
    hopDongUid: _editingContract?.uid,
    hopDongThang: _selectedThang,
    hopDongTen: _tenHopDongController.text.trim(),
    hopDongMaKinhDoanh: _maKinhDoanhController.text.trim(),
    currentPeriod: _currentPeriod,
    nextPeriod: _nextPeriod,
    currentCostValue: _getCurrentCostValue(costType),
    onCostUpdated: _onCostUpdated, // Callback when cost is updated
  );

  // Call the cost editing method from hd_chiphi.dart
  HDChiPhi.editCost(
    context: context,
    costContext: costEditContext,
  );
}

int _getCurrentCostValue(String costType) {
    return _getUpdatedCostValue(costType); 
  }

// Callback method when cost is updated from hd_chiphi.dart
void _onCostUpdated(String costType, int newValue) {
    setState(() {
      // Update the local cost variables
      switch (costType) {
        case 'VatLieu':
          _updatedChiPhiVatLieu = newValue;
          break;
        case 'CVDinhKy':
          _updatedChiPhiCVDinhKy = newValue;
          break;
        case 'LeTetTCa':
          _updatedChiPhiLeTetTCa = newValue;
          break;
        case 'PhuCap':
          _updatedChiPhiPhuCap = newValue;
          break;
        case 'NgoaiGiao':
          _updatedChiPhiNgoaiGiao = newValue;
          break;
        case 'MayMoc':
          _updatedChiPhiMayMoc = newValue;
          break;
        case 'Luong':
          _updatedChiPhiLuong = newValue;
          break;
      }
      
      // Recalculate derived values with new cost
      _calculateDerivedValues();
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chi phí $costType đã được cập nhật: ${NumberFormat('#,##0', 'vi_VN').format(newValue)} VND'),
        backgroundColor: Colors.green,
      ),
    );
  }

 Widget _buildAdditionalInfoCard() {
   return Card(
     elevation: 4,
     child: Padding(
       padding: EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'Thông tin bổ sung',
             style: TextStyle(
               fontSize: 18,
               fontWeight: FontWeight.bold,
               color: Color(0xFF024965),
             ),
           ),
           SizedBox(height: 16),
           
           TextFormField(
             controller: _daoHanHopDongController,
             decoration: InputDecoration(
               labelText: 'Đáo hạn hợp đồng',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.schedule),
               hintText: 'Thầu online, Báo giá cạnh tranh',
             ),
             enabled: _canEditThang,
           ),
           SizedBox(height: 16),
           
           TextFormField(
             controller: _congViecCanGiaiQuyetController,
             decoration: InputDecoration(
               labelText: 'Công việc cần giải quyết',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.work),
             ),
             enabled: _canEditThang,
             maxLines: 3,
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildWorkerShiftsCard() {
   return Card(
     elevation: 4,
     child: Padding(
       padding: EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'Thông tin ca làm việc',
             style: TextStyle(
               fontSize: 18,
               fontWeight: FontWeight.bold,
               color: Color(0xFF024965),
             ),
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: TextFormField(
                   controller: _congNhanCa1Controller,
                   decoration: InputDecoration(
                     labelText: 'Công nhân ca 1',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.schedule),
                   ),
                   enabled: _canEditThang,
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _congNhanCa2Controller,
                   decoration: InputDecoration(
                     labelText: 'Công nhân ca 2',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.schedule),
                   ),
                   enabled: _canEditThang,
                 ),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           Row(
             children: [
               Expanded(
                 child: TextFormField(
                   controller: _congNhanCa3Controller,
                   decoration: InputDecoration(
                     labelText: 'Công nhân ca 3',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.schedule),
                   ),
                   enabled: _canEditThang,
                 ),
               ),
               SizedBox(width: 16),
               Expanded(
                 child: TextFormField(
                   controller: _congNhanCaHCController,
                   decoration: InputDecoration(
                     labelText: 'Công nhân ca HC',
                     border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.schedule),
                   ),
                   enabled: _canEditThang,
                 ),
               ),
             ],
           ),
           SizedBox(height: 16),
           
           TextFormField(
             controller: _congNhanCaKhacController,
             decoration: InputDecoration(
               labelText: 'Công nhân ca khác',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.schedule),
             ),
             enabled: _canEditThang,
           ),
           SizedBox(height: 16),
           
           TextFormField(
             controller: _congNhanGhiChuBoTriNhanSuController,
             decoration: InputDecoration(
               labelText: 'Ghi chú công nhân HĐ',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.note),
             ),
             enabled: _canEditThang,
             maxLines: 3,
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildCalculatedRow(String label, dynamic value, String unit) {
   String displayValue;
   if (value is int) {
     displayValue = NumberFormat('#,##0', 'vi_VN').format(value);
   } else if (value is double) {
     displayValue = NumberFormat('#,##0.0', 'vi_VN').format(value);
   } else {
     displayValue = value.toString();
   }

   return Padding(
     padding: EdgeInsets.symmetric(vertical: 4),
     child: Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Text(
           label,
           style: TextStyle(fontWeight: FontWeight.w500),
         ),
         Text(
           '$displayValue $unit',
           style: TextStyle(
             fontWeight: FontWeight.bold,
             color: Color(0xFF024965),
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildReadOnlyCostRow(String label, int? value) {
   String displayValue = NumberFormat('#,##0', 'vi_VN').format(value ?? 0);
   
   return Padding(
     padding: EdgeInsets.symmetric(vertical: 2),
     child: Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Text(
           label,
           style: TextStyle(
             fontSize: 12,
             color: Colors.grey[600],
           ),
         ),
         Text(
           '$displayValue VND',
           style: TextStyle(
             fontSize: 12,
             color: Colors.grey[800],
           ),
         ),
       ],
     ),
   );
 }
}