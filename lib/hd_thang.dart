// hd_thang.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'hd_moi.dart';
import 'hd_thangexcel.dart';
import 'package:excel/excel.dart' as xl; 
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart' as flutter;

class HDThangScreen extends StatefulWidget {
  final String period;
  final String username;
  final String userRole;
  final String currentPeriod;
  final String nextPeriod;

  const HDThangScreen({
    Key? key,
    required this.period,
    required this.username,
    required this.userRole,
    required this.currentPeriod,
    required this.nextPeriod,
  }) : super(key: key);

  @override
  _HDThangScreenState createState() => _HDThangScreenState();
}

class _HDThangScreenState extends State<HDThangScreen> {
  final DBHelper _dbHelper = DBHelper();
  bool _isGeneratingExcel = false;

  List<LinkHopDongModel> _contracts = [];
  List<LinkHopDongModel> _filteredContracts = [];
  bool _isLoading = true;
  String _error = '';
  
  // Summary data for the period
  int _totalContracts = 0;
  double _totalRevenue = 0.0;
  double _totalCosts = 0.0;
  double _netProfit = 0.0;

  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();
  String _selectedLoaiHinh = 'Tất cả';
  String _selectedTrangThai = 'Tất cả';
  String _selectedNguoiTao = 'Tất cả';
  String _sortBy = 'Tên hợp đồng';
  bool _sortAscending = true;
  bool _isTableView = false;

  // Lists for filter options
  List<String> _loaiHinhOptions = ['Tất cả'];
  List<String> _trangThaiOptions = ['Tất cả'];
  List<String> _nguoiTaoOptions = ['Tất cả'];
  List<String> _sortOptions = [
    'Tên hợp đồng',
    'Ngày kết thúc',
    'Doanh thu hiện tại'
  ];

  @override
  void initState() {
    super.initState();
    print("HDThang Screen initialized:");
    print("Period: ${widget.period}");
    print("Username: ${widget.username}");
    print("User Role: ${widget.userRole}");
    _loadContractsForPeriod();
    
    // Add listeners
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
Future<void> _generateAndShareExcel() async {
  setState(() {
    _isGeneratingExcel = true;
  });

  try {
    final excelGenerator = HDThangExcelGenerator();
    
    final success = await excelGenerator.generateAndShareExcel(
      contracts: _filteredContracts,
      period: widget.period,
      totalRevenue: _totalRevenue,
      totalCosts: _totalCosts,
      netProfit: _netProfit,
      dbHelper: _dbHelper,
      context: context,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo file Excel thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tạo file Excel'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    
    print('Error generating Excel: $e');
  } finally {
    setState(() {
      _isGeneratingExcel = false;
    });
  }
}
void _navigateToEditContract(LinkHopDongModel contract) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => HDMoiScreen(),
      settings: RouteSettings(
        arguments: {
          'contract': contract,
          'isEdit': true,
          'username': widget.username,
          'userRole': widget.userRole,
          'currentPeriod': widget.currentPeriod,
          'nextPeriod': widget.nextPeriod,
          'selectedPeriod': widget.period,
        },
      ),
    ),
  );

  if (result == true) {
    // Refresh the contract list
    //_loadContracts();
  }
}

void _navigateToNewContract() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => HDMoiScreen(),
      settings: RouteSettings(
        arguments: {
          'contract': null,
          'isEdit': false,
          'username': widget.username,
          'userRole': widget.userRole,
          'currentPeriod': widget.currentPeriod,
          'nextPeriod': widget.nextPeriod,
          'selectedPeriod': widget.period,
        },
      ),
    ),
  ).then((result) {
    if (result == true) {
      // Refresh the contract list if a new contract was added
      _loadContractsForPeriod();
    }
  });
}
Future<Map<String, List<dynamic>>> _loadCostRecords(String contractId) async {
  Map<String, List<dynamic>> costRecords = {};
  
  try {
    // Load all cost records for this contract
    costRecords['VatLieu'] = await _dbHelper.getLinkVatTusByContract(contractId);
    costRecords['DinhKy'] = await _dbHelper.getLinkDinhKysByContract(contractId);
    costRecords['LeTetTC'] = await _dbHelper.getLinkLeTetTCsByContract(contractId);
    costRecords['PhuCap'] = await _dbHelper.getLinkPhuCapsByContract(contractId);
    costRecords['NgoaiGiao'] = await _dbHelper.getLinkNgoaiGiaosByContract(contractId);
    costRecords['MayMoc'] = await _dbHelper.getLinkMayMocsByContract(contractId);
    costRecords['Luong'] = await _dbHelper.getLinkLuongsByContract(contractId);
  } catch (e) {
    print('Error loading cost records: $e');
  }
  
  return costRecords;
}

Widget _buildCostRecordsSection(String contractId) {
  return FutureBuilder<Map<String, List<dynamic>>>(
    future: _loadCostRecords(contractId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      
      if (snapshot.hasError || !snapshot.hasData) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Text('Không thể tải chi tiết chi phí'),
        );
      }
      
      final costRecords = snapshot.data!;
      bool hasRecords = costRecords.values.any((list) => list.isNotEmpty);
      
      if (!hasRecords) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Text(
            'Chưa có bản ghi chi phí chi tiết',
            style: TextStyle(color: Colors.grey[600]),
          ),
        );
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vat lieu records
          if (costRecords['VatLieu']?.isNotEmpty == true)
            _buildCostRecordCard(
              'Chi phí Vật tư (${costRecords['VatLieu']!.length} mục)',
              costRecords['VatLieu']!,
              _buildVatLieuRecord,
              Icons.build,
              Colors.blue,
            ),
          
          // Dinh ky records  
          if (costRecords['DinhKy']?.isNotEmpty == true)
            _buildCostRecordCard(
              'Chi phí CV Định kỳ (${costRecords['DinhKy']!.length} mục)',
              costRecords['DinhKy']!,
              _buildDinhKyRecord,
              Icons.schedule,
              Colors.green,
            ),
          
          // Le tet tang ca records
          if (costRecords['LeTetTC']?.isNotEmpty == true)
            _buildCostRecordCard(
              'Chi phí Lễ tết Tăng ca (${costRecords['LeTetTC']!.length} mục)',
              costRecords['LeTetTC']!,
              _buildLeTetTCRecord,
              Icons.celebration,
              Colors.orange,
            ),
          
          // Phu cap records
          if (costRecords['PhuCap']?.isNotEmpty == true)
            _buildCostRecordCard(
              'Chi phí Phụ cấp (${costRecords['PhuCap']!.length} mục)',
              costRecords['PhuCap']!,
              _buildPhuCapRecord,
              Icons.attach_money,
              Colors.purple,
            ),
          
          // Ngoai giao records
          if (costRecords['NgoaiGiao']?.isNotEmpty == true)
            _buildCostRecordCard(
              'Chi phí Ngoại giao (${costRecords['NgoaiGiao']!.length} mục)',
              costRecords['NgoaiGiao']!,
              _buildNgoaiGiaoRecord,
              Icons.business,
              Colors.indigo,
            ),
          
          // May moc records
          if (costRecords['MayMoc']?.isNotEmpty == true)
            _buildCostRecordCard(
              'Chi phí Máy móc (${costRecords['MayMoc']!.length} mục)',
              costRecords['MayMoc']!,
              _buildMayMocRecord,
              Icons.precision_manufacturing,
              Colors.teal,
            ),
          
          // Luong records
          if (costRecords['Luong']?.isNotEmpty == true)
            _buildCostRecordCard(
              'Chi phí Lương (${costRecords['Luong']!.length} mục)',
              costRecords['Luong']!,
              _buildLuongRecord,
              Icons.people,
              Colors.red,
            ),
        ],
      );
    },
  );
}

Widget _buildCostRecordCard(String title, List<dynamic> records, Widget Function(dynamic) recordBuilder, IconData icon, Color color) {
  return Card(
    elevation: 2,
    margin: EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      subtitle: Text(
        'Tổng: ${_formatCurrency(_calculateCategoryTotal(records))}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Container(
          constraints: BoxConstraints(maxHeight: 300),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: records.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) => recordBuilder(records[index]),
          ),
        ),
      ],
    ),
  );
}

double _calculateCategoryTotal(List<dynamic> records) {
  double total = 0.0;
  for (var record in records) {
    if (record is LinkVatTuModel) {
      total += _safeToDouble(record.thanhTien);
    } else if (record is LinkDinhKyModel) {
      total += _safeToDouble(record.thanhTien);
    } else if (record is LinkLeTetTCModel) {
      total += _safeToDouble(record.thanhTienTrenThang);
    } else if (record is LinkPhuCapModel) {
      total += _safeToDouble(record.thanhTienTrenThang);
    } else if (record is LinkNgoaiGiaoModel) {
      total += _safeToDouble(record.thanhTienTrenThang);
    } else if (record is LinkMayMocModel) {
      total += _safeToDouble(record.thanhTienThang);
    } else if (record is LinkLuongModel) {
      total += _safeToDouble(record.thanhTien);
    }
  }
  return total;
}

// Individual record builders
Widget _buildVatLieuRecord(dynamic record) {
  final vatLieu = record as LinkVatTuModel;
  return ListTile(
    dense: true,
    title: Text(
      vatLieu.danhMucVatTuTieuHao ?? 'N/A',
      style: TextStyle(fontWeight: FontWeight.w500),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vatLieu.nhanHieu?.isNotEmpty == true)
          Text('Nhãn hiệu: ${vatLieu.nhanHieu}'),
        if (vatLieu.quyCach?.isNotEmpty == true)
          Text('Quy cách: ${vatLieu.quyCach}'),
        Text('Số lượng: ${vatLieu.soLuong ?? 0} | Đơn giá: ${_formatCurrency(_safeToDouble(vatLieu.donGiaCapKhachHang))}'),
      ],
    ),
    trailing: Text(
      _formatCurrency(_safeToDouble(vatLieu.thanhTien)),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    ),
  );
}

Widget _buildDinhKyRecord(dynamic record) {
  final dinhKy = record as LinkDinhKyModel;
  return ListTile(
    dense: true,
    title: Text(
      dinhKy.danhMucCongViec ?? 'N/A',
      style: TextStyle(fontWeight: FontWeight.w500),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dinhKy.chiTietCongViec?.isNotEmpty == true)
          Text('Chi tiết: ${dinhKy.chiTietCongViec}'),
        Text('Tần suất: ${dinhKy.tanSuatThucHienTrenThang ?? 0}/tháng | Số lượng: ${dinhKy.soLuong ?? 0}'),
        Text('Đơn giá/tháng: ${_formatCurrency(_safeToDouble(dinhKy.donGiaTrenThang))}'),
      ],
    ),
    trailing: Text(
      _formatCurrency(_safeToDouble(dinhKy.thanhTien)),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    ),
  );
}

Widget _buildLeTetTCRecord(dynamic record) {
  final leTetTC = record as LinkLeTetTCModel;
  return ListTile(
    dense: true,
    title: Text(
      leTetTC.danhMucCongViec ?? 'N/A',
      style: TextStyle(fontWeight: FontWeight.w500),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leTetTC.chiTietCongViec?.isNotEmpty == true)
          Text('Chi tiết: ${leTetTC.chiTietCongViec}'),
        Text('Số NV: ${leTetTC.soLuongNhanVien ?? 0} | Đơn giá: ${_formatCurrency(_safeToDouble(leTetTC.donGia))}'),
        if (leTetTC.phanBoTrenThang != null)
          Text('Phân bổ: ${leTetTC.phanBoTrenThang} tháng'),
      ],
    ),
    trailing: Text(
      _formatCurrency(_safeToDouble(leTetTC.thanhTienTrenThang)),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.orange,
      ),
    ),
  );
}

Widget _buildPhuCapRecord(dynamic record) {
  final phuCap = record as LinkPhuCapModel;
  return ListTile(
    dense: true,
    title: Text(
      phuCap.danhMucCongViec ?? 'N/A',
      style: TextStyle(fontWeight: FontWeight.w500),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (phuCap.chiTietCongViec?.isNotEmpty == true)
          Text('Chi tiết: ${phuCap.chiTietCongViec}'),
        Text('Số NV: ${phuCap.soLuongNhanVien ?? 0} | Đơn giá: ${_formatCurrency(_safeToDouble(phuCap.donGia))}'),
        if (phuCap.phanBoTrenThang != null)
          Text('Phân bổ: ${phuCap.phanBoTrenThang} tháng'),
      ],
    ),
    trailing: Text(
      _formatCurrency(_safeToDouble(phuCap.thanhTienTrenThang)),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.purple,
      ),
    ),
  );
}

Widget _buildNgoaiGiaoRecord(dynamic record) {
  final ngoaiGiao = record as LinkNgoaiGiaoModel;
  return ListTile(
    dense: true,
    title: Text(
      ngoaiGiao.danhMuc ?? 'N/A',
      style: TextStyle(fontWeight: FontWeight.w500),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ngoaiGiao.noiDungChiTiet?.isNotEmpty == true)
          Text('Nội dung: ${ngoaiGiao.noiDungChiTiet}'),
        Text('Số lượng: ${ngoaiGiao.soLuong ?? 0} | Đơn giá: ${_formatCurrency(_safeToDouble(ngoaiGiao.donGia))}'),
        if (ngoaiGiao.phanBoTrenThang != null)
          Text('Phân bổ: ${ngoaiGiao.phanBoTrenThang} tháng'),
      ],
    ),
    trailing: Text(
      _formatCurrency(_safeToDouble(ngoaiGiao.thanhTienTrenThang)),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
      ),
    ),
  );
}

Widget _buildMayMocRecord(dynamic record) {
  final mayMoc = record as LinkMayMocModel;
  final tinhTrangPercent = ((mayMoc.tinhTrangThietBi ?? 0.0) * 100).toStringAsFixed(0);
  
  return ListTile(
    dense: true,
    title: Text(
      '${mayMoc.loaiMay ?? 'N/A'} - ${mayMoc.tenMay ?? ''}',
      style: TextStyle(fontWeight: FontWeight.w500),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mayMoc.hangSanXuat?.isNotEmpty == true)
          Text('Hãng: ${mayMoc.hangSanXuat}'),
        Text('Giá máy: ${_formatCurrency(_safeToDouble(mayMoc.donGiaMay))} | Tình trạng: $tinhTrangPercent%'),
        Text('Khấu hao: ${mayMoc.khauHao ?? 0} | Số lượng: ${mayMoc.soLuongCap ?? 0}'),
      ],
    ),
    trailing: Text(
      _formatCurrency(_safeToDouble(mayMoc.thanhTienThang)),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.teal,
      ),
    ),
  );
}

Widget _buildLuongRecord(dynamic record) {
  final luong = record as LinkLuongModel;
  return ListTile(
    dense: true,
    title: Text(
      luong.hangMuc ?? 'N/A',
      style: TextStyle(fontWeight: FontWeight.w500),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (luong.moTa?.isNotEmpty == true)
          Text('Mô tả: ${luong.moTa}'),
        Text('Số lượng: ${luong.soLuong ?? 0} | Đơn giá: ${_formatCurrency(_safeToDouble(luong.donGia))}'),
      ],
    ),
    trailing: Text(
      _formatCurrency(_safeToDouble(luong.thanhTien)),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
    ),
  );
}
  Future<void> _loadContractsForPeriod() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Get all contracts
      final allContracts = await _dbHelper.getAllLinkHopDongs();
      print("Total contracts loaded: ${allContracts.length}");

      // Filter contracts for the specific period
      List<LinkHopDongModel> periodContracts = [];
      double totalRevenue = 0.0;
      double totalCosts = 0.0;

      // Collect unique values for filter options
      Set<String> loaiHinhSet = Set<String>();
      Set<String> trangThaiSet = Set<String>();
      Set<String> nguoiTaoSet = Set<String>();

      for (var contract in allContracts) {
        String contractPeriod = _extractPeriodFromThang(contract.thang);
        if (contractPeriod == widget.period) {
          periodContracts.add(contract);
          
          // Calculate totals
          double revenue = _safeToDouble(contract.doanhThuDangThucHien);
          double costs = _calculateTotalCosts(contract);
          
          totalRevenue += revenue;
          totalCosts += costs;

          // Collect filter options
          if (contract.loaiHinh != null && contract.loaiHinh!.isNotEmpty) {
            loaiHinhSet.add(contract.loaiHinh!);
          }
          if (contract.trangThai != null && contract.trangThai!.isNotEmpty) {
            trangThaiSet.add(contract.trangThai!);
          }
          if (contract.nguoiTao != null && contract.nguoiTao!.isNotEmpty) {
            nguoiTaoSet.add(contract.nguoiTao!);
          }
        }
      }

      print("Contracts for period ${widget.period}: ${periodContracts.length}");
      
      setState(() {
        _contracts = periodContracts;
        _filteredContracts = List.from(periodContracts);
        _totalContracts = periodContracts.length;
        _totalRevenue = totalRevenue;
        _totalCosts = totalCosts;
        _netProfit = totalRevenue - totalCosts;
        
        // Update filter options
        _loaiHinhOptions = ['Tất cả', ...loaiHinhSet.toList()..sort()];
        _trangThaiOptions = ['Tất cả', ...trangThaiSet.toList()..sort()];
        _nguoiTaoOptions = ['Tất cả', ...nguoiTaoSet.toList()..sort()];
        
        _isLoading = false;
      });

      _applyFilters();

    } catch (e) {
      print('Error loading contracts for period: $e');
      setState(() {
        _error = 'Lỗi khi tải dữ liệu: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<LinkHopDongModel> filtered = List.from(_contracts);

    // Apply search filter
    String searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      filtered = filtered.where((contract) {
        return (contract.tenHopDong?.toLowerCase().contains(searchTerm) ?? false);
      }).toList();
    }

    // Apply loaiHinh filter
    if (_selectedLoaiHinh != 'Tất cả') {
      filtered = filtered.where((contract) {
        return contract.loaiHinh == _selectedLoaiHinh;
      }).toList();
    }

    // Apply trangThai filter
    if (_selectedTrangThai != 'Tất cả') {
      filtered = filtered.where((contract) {
        return contract.trangThai == _selectedTrangThai;
      }).toList();
    }

    // Apply nguoiTao filter
    if (_selectedNguoiTao != 'Tất cả') {
      filtered = filtered.where((contract) {
        return contract.nguoiTao == _selectedNguoiTao;
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'Tên hợp đồng':
          comparison = (a.tenHopDong ?? '').compareTo(b.tenHopDong ?? '');
          break;
        case 'Ngày kết thúc':
          String dateA = a.thoiHanKetthuc ?? ''; // Fixed spelling
          String dateB = b.thoiHanKetthuc ?? ''; // Fixed spelling
          comparison = dateA.compareTo(dateB);
          break;
        case 'Doanh thu hiện tại':
          double revenueA = _safeToDouble(a.doanhThuDangThucHien);
          double revenueB = _safeToDouble(b.doanhThuDangThucHien);
          comparison = revenueA.compareTo(revenueB);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredContracts = filtered;
    });
  }

  void _showContractDetails(LinkHopDongModel contract) {
    showDialog(
      context: context,
      builder: (BuildContext context) => _buildContractDetailDialog(contract),
    );
  }

bool _canEditContract(LinkHopDongModel contract) {
  // Admin can edit any contract regardless of period
  if (widget.userRole.toLowerCase().trim() == 'admin') {
    return true;
  }
  
  // Regular user can edit only if they are the creator AND it's current or next period
  String usernameLower = widget.username.toLowerCase().trim();
  String nguoiTaoLower = (contract.nguoiTao ?? '').toLowerCase().trim();
  
  if (usernameLower == nguoiTaoLower && nguoiTaoLower.isNotEmpty) {
    String contractPeriod = _extractPeriodFromThang(contract.thang);
    
    // Convert ISO date strings to YYYY-MM format for comparison
    String currentPeriodFormatted = DateFormat('yyyy-MM').format(DateTime.parse(widget.currentPeriod));
    String nextPeriodFormatted = DateFormat('yyyy-MM').format(DateTime.parse(widget.nextPeriod));
    
    return contractPeriod == currentPeriodFormatted || contractPeriod == nextPeriodFormatted;
  }
  
  return false;
}

  Widget _buildContractDetailDialog(LinkHopDongModel contract) {
  final revenue = _safeToDouble(contract.doanhThuDangThucHien);
  final costs = _calculateTotalCosts(contract);
  final profit = revenue - costs;
  final canEdit = _canEditContract(contract);

  return Dialog(
    insetPadding: EdgeInsets.all(16),
    child: Container(
      width: MediaQuery.of(context).size.width * 0.95,
      height: MediaQuery.of(context).size.height * 0.9,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chi tiết hợp đồng'),
          backgroundColor: Color(0xFF024965),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: canEdit ? [
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                _navigateToEditContract(contract);
              },
              tooltip: 'Chỉnh sửa hợp đồng',
            ),
          ] : null,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contract header
              _buildDetailSection('Thông tin cơ bản', [
                _buildDetailRow('Tên hợp đồng', contract.tenHopDong),
                _buildDetailRow('Mã kinh doanh', contract.maKinhDoanh),
                _buildDetailRow('Số hợp đồng', contract.soHopDong),
                _buildDetailRow('Địa chỉ', contract.diaChi),
                _buildDetailRow('Miền', contract.vungMien),
                _buildDetailRow('Loại hình', contract.loaiHinh),
                _buildDetailRow('Trạng thái', contract.trangThai),
                _buildDetailRow('Người tạo', contract.nguoiTao),
                _buildDetailRow('Tháng thực hiện', _formatDate(contract.thang)),
                _buildDetailRow('Ghi chú', contract.ghiChuHopDong),
              ]),
              SizedBox(height: 16),
              if (contract.uid != null) ...[
  _buildDetailSection('Chi tiết chi phí theo từng mục', [
    Container(
      child: _buildCostRecordsSection(contract.uid!),
    ),
  ]),
  SizedBox(height: 16),
],
              // Worker information
              _buildDetailSection('Thông tin công nhân', [
                _buildDetailRow('Công nhân theo HĐ', contract.congNhanHopDong?.toString()),
                _buildDetailRow('Công nhân tăng', contract.congNhanHDTang?.toString()),
                _buildDetailRow('Công nhân giảm', contract.congNhanHDGiam?.toString()),
                _buildDetailRow('Công nhân được có', contract.congNhanDuocCo?.toString()),
                _buildDetailRow('Giám sát cố định', contract.giamSatCoDinh?.toString()),
              ]),
              SizedBox(height: 16),

              // Revenue information
              _buildDetailSection('Thông tin doanh thu & Commission', [
                _buildDetailRow('Doanh thu cũ', _formatCurrency(contract.doanhThuCu?.toDouble() ?? 0)),
                _buildDetailRow('Doanh thu đang thực hiện', _formatCurrency(contract.doanhThuDangThucHien?.toDouble() ?? 0)),
                _buildDetailRow('Doanh thu xuất hoá đơn', _formatCurrency(contract.doanhThuXuatHoaDon?.toDouble() ?? 0)),
                _buildDetailRow('Doanh thu chênh lệch', _formatCurrency(contract.doanhThuChenhLech?.toDouble() ?? 0)),
                _buildDetailRow('Doanh thu tăng CN & giá', _formatCurrency(contract.doanhThuTangCNGia?.toDouble() ?? 0)),
                _buildDetailRow('Doanh thu giảm CN & giá', _formatCurrency(contract.doanhThuGiamCNGia?.toDouble() ?? 0)),
                _buildDetailRow('Com cũ', _formatCurrency(contract.comCu?.toDouble() ?? 0)),
                _buildDetailRow('10% Com cũ', _formatCurrency(contract.comCu10phantram?.toDouble() ?? 0)),
                _buildDetailRow('Com KH thực nhận', _formatCurrency(contract.comKHThucNhan?.toDouble() ?? 0)),
                _buildDetailRow('Com giảm', _formatCurrency(contract.comGiam?.toDouble() ?? 0)),
                _buildDetailRow('Com tăng không thuế', _formatCurrency(contract.comTangKhongThue?.toDouble() ?? 0)),
                _buildDetailRow('Com tăng tính thuế', _formatCurrency(contract.comTangTinhThue?.toDouble() ?? 0)),
                _buildDetailRow('Com mới', _formatCurrency(contract.comMoi?.toDouble() ?? 0)),
                _buildDetailRow('Phần trăm thuế mới', _formatCurrency(contract.phanTramThueMoi?.toDouble() ?? 0)),
                _buildDetailRow('Com thực nhận', _formatCurrency(contract.comThucNhan?.toDouble() ?? 0)),
                _buildDetailRow('Tên KH nhận com', contract.comTenKhachHang),
              ]),
              SizedBox(height: 16),

              // Contract period
              _buildDetailSection('Thời gian hợp đồng', [
                _buildDetailRow('Thời hạn hợp đồng', '${contract.thoiHanHopDong ?? 'N/A'} tháng'),
                _buildDetailRow('Thời hạn bắt đầu', _formatDate(contract.thoiHanBatDau)),
                _buildDetailRow('Thời hạn kết thúc', _formatDate(contract.thoiHanKetthuc)),
              ]),
              SizedBox(height: 16),

              // Cost breakdown
              _buildDetailSection('Chi phí chi tiết', [
                _buildDetailRow('Chi phí giám sát', _formatCurrency(contract.chiPhiGiamSat?.toDouble() ?? 0)),
                _buildDetailRow('Chi phí vật tư', _formatCurrency(contract.chiPhiVatLieu?.toDouble() ?? 0)),
                _buildDetailRow('Chi phí CV định kỳ', _formatCurrency(contract.chiPhiCVDinhKy?.toDouble() ?? 0)),
                _buildDetailRow('Chi phí lễ tết tăng ca', _formatCurrency(contract.chiPhiLeTetTCa?.toDouble() ?? 0)),
                _buildDetailRow('Chi phí phụ cấp', _formatCurrency(contract.chiPhiPhuCap?.toDouble() ?? 0)),
                _buildDetailRow('Chi phí ngoại giao', _formatCurrency(contract.chiPhiNgoaiGiao?.toDouble() ?? 0)),
                _buildDetailRow('Chi phí máy móc', _formatCurrency(contract.chiPhiMayMoc?.toDouble() ?? 0)),
                _buildDetailRow('Chi phí lương', _formatCurrency(contract.chiPhiLuong?.toDouble() ?? 0)),
              ]),
              SizedBox(height: 16),

              // Calculations
              _buildDetailSection('Tính toán & Net', [
                _buildDetailRow('Giá trị còn lại', _formatCurrency(contract.giaTriConLai?.toDouble() ?? 0)),
                _buildDetailRow('Net CN', _formatCurrency(contract.netCN?.toDouble() ?? 0)),
                _buildDetailRow('Giá Net CN', _formatCurrency(contract.giaNetCN?.toDouble() ?? 0)),
                _buildDetailRow('Net Vùng', contract.netVung),
                _buildDetailRow('Chênh lệch giá', _formatCurrency(contract.chenhLechGia?.toDouble() ?? 0)),
                _buildDetailRow('Chênh lệch tổng', _formatCurrency(contract.chenhLechTong?.toDouble() ?? 0)),
              ]),
              SizedBox(height: 16),

              // Additional info
              _buildDetailSection('Thông tin bổ sung', [
                _buildDetailRow('Đáo hạn hợp đồng', contract.daoHanHopDong),
                _buildDetailRow('Công việc cần giải quyết', contract.congViecCanGiaiQuyet),
              ]),
              SizedBox(height: 16),

              // Worker shifts
              _buildDetailSection('Thông tin ca làm việc', [
                _buildDetailRow('Công nhân ca 1', contract.congNhanCa1),
                _buildDetailRow('Công nhân ca 2', contract.congNhanCa2),
                _buildDetailRow('Công nhân ca 3', contract.congNhanCa3),
                _buildDetailRow('Công nhân ca HC', contract.congNhanCaHC),
                _buildDetailRow('Công nhân ca khác', contract.congNhanCaKhac),
                _buildDetailRow('Ghi chú botrí nhân sự', contract.congNhanGhiChuBoTriNhanSu),
              ]),
              SizedBox(height: 16),

              // System info
              if (contract.uid != null) ...[
                _buildDetailSection('Thông tin hệ thống', [
                  _buildDetailRow('Mã hợp đồng', '${contract.uid}'),
                  _buildDetailRow('Mã số thuế', '${contract.fileHopDong}'),
                  _buildDetailRow('Ngày cập nhật cuối', _formatDate(contract.ngayCapNhatCuoi)),
                ]),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
Widget _buildDetailSection(String title, List<Widget> rows) {
  return Card(
    elevation: 4,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF024965),
            ),
          ),
          SizedBox(height: 12),
          ...rows,
        ],
      ),
    ),
  );
}

Widget _buildDetailRow(String label, String? value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value ?? 'N/A',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF024965),
            ),
          ),
        ),
      ],
    ),
  );
}
  String _extractPeriodFromThang(String? thang) {
    if (thang == null || thang.isEmpty) return '';
    
    try {
      // Since thang is stored as string (YYYY-MM-DD format)
      if (thang.length >= 7 && thang.contains('-')) {
        List<String> parts = thang.split('-');
        if (parts.length >= 2) {
          return '${parts[0]}-${parts[1]}';
        }
      }
      
      DateTime date = DateTime.parse(thang);
      return DateFormat('yyyy-MM').format(date);
    } catch (e) {
      // Try other formats
      if (thang.length >= 6) {
        if (RegExp(r'^\d{6}$').hasMatch(thang)) {
          return '${thang.substring(0, 4)}-${thang.substring(4, 6)}';
        }
        
        if (thang.contains('/') || thang.contains('-')) {
          List<String> parts = thang.split(RegExp(r'[/-]'));
          if (parts.length == 2) {
            if (parts[1].length == 4) {
              return '${parts[1]}-${parts[0].padLeft(2, '0')}';
            } else if (parts[0].length == 4) {
              return '${parts[0]}-${parts[1].padLeft(2, '0')}';
            }
          }
        }
      }
      
      return '';
    }
  }

  double _calculateTotalCosts(LinkHopDongModel contract) {
    return _safeToDouble(contract.chiPhiGiamSat) +
           _safeToDouble(contract.chiPhiVatLieu) +
           _safeToDouble(contract.chiPhiCVDinhKy) +
           _safeToDouble(contract.chiPhiLeTetTCa) +
           _safeToDouble(contract.chiPhiPhuCap) +
           _safeToDouble(contract.chiPhiNgoaiGiao) +
           _safeToDouble(contract.chiPhiMayMoc) +
           _safeToDouble(contract.chiPhiLuong);
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(amount)} VND';
  }

  String _formatPeriod(String period) {
    try {
      if (period.contains('-') && period.length >= 7) {
        List<String> parts = period.split('-');
        if (parts.length >= 2) {
          String year = parts[0];
          String month = parts[1];
          return '$month/$year';
        }
      }
      
      DateTime date = DateTime.parse('$period-01');
      return DateFormat('MM/yyyy').format(date);
    } catch (e) {
      return period;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'hoạt động':
      case 'duy trì':
        return Colors.green.withOpacity(0.2);
      case 'pending':
      case 'chờ duyệt':
        return Colors.orange.withOpacity(0.2);
      case 'expired':
      case 'hết hạn':
        return Colors.red.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hợp đồng tháng ${_formatPeriod(widget.period)}'),
        backgroundColor: Color(0xFF024965),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorWidget()
              : _buildContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              _error,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadContractsForPeriod,
              child: Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          _buildSummaryCard(),
          SizedBox(height: 16),
          
          // Search and Filter Card
          _buildSearchAndFilterCard(),
          SizedBox(height: 16),
          
          // Contracts List
          _buildContractsCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng quan tháng ${_formatPeriod(widget.period)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF024965),
              ),
            ),
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Số hợp đồng',
                    '${_filteredContracts.length}/${_totalContracts}',
                    Icons.description,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Tổng doanh thu',
                    _formatCurrency(_totalRevenue),
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Tổng chi phí',
                    _formatCurrency(_totalCosts),
                    Icons.money_off,
                    Colors.orange,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Lợi nhuận ròng',
                    _formatCurrency(_netProfit),
                    Icons.trending_up,
                    _netProfit >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      'Tìm kiếm và lọc',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF024965),
      ),
    ),
    Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isGeneratingExcel ? null : _generateAndShareExcel,
          icon: _isGeneratingExcel 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.download, size: 18),
          label: Text(_isGeneratingExcel ? 'Đang tạo...' : 'Tải về'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _navigateToNewContract,
          icon: Icon(Icons.add, size: 18),
          label: Text('Thêm mới'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF024965),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    ),
  ],
),
            SizedBox(height: 16),
            
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên hợp đồng...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterDropdown('Loại hình', _selectedLoaiHinh, _loaiHinhOptions, (value) {
                    setState(() {
                      _selectedLoaiHinh = value!;
                    });
                    _applyFilters();
                  }),
                  SizedBox(width: 8),
                  _buildFilterDropdown('Trạng thái', _selectedTrangThai, _trangThaiOptions, (value) {
                    setState(() {
                      _selectedTrangThai = value!;
                    });
                    _applyFilters();
                  }),
                  SizedBox(width: 8),
                  _buildFilterDropdown('Người tạo', _selectedNguoiTao, _nguoiTaoOptions, (value) {
                    setState(() {
                      _selectedNguoiTao = value!;
                    });
                    _applyFilters();
                  }),
                  SizedBox(width: 8),
                  _buildFilterDropdown('Sắp xếp', _sortBy, _sortOptions, (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    _applyFilters();
                  }),
                  SizedBox(width: 8),
                  Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.grey), 
    borderRadius: BorderRadius.circular(8),
  ),
  child: IconButton(
    icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
    onPressed: () {
      setState(() {
        _sortAscending = !_sortAscending;
      });
      _applyFilters();
    },
    tooltip: _sortAscending ? 'Tăng dần' : 'Giảm dần',
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

  Widget _buildFilterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: value,
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            isExpanded: true,
          ),
        ],
      ),
    );
  }

 Widget _buildContractsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                            // View mode toggle
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.view_list,
                        color: !_isTableView ? Color(0xFF024965) : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isTableView = false;
                        });
                      },
                      tooltip: 'Chế độ danh sách',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.table_chart,
                        color: _isTableView ? Color(0xFF024965) : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isTableView = true;
                        });
                      },
                      tooltip: 'Chế độ bảng',
                    ),
                  ],
                ),
            // Header with view mode toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách hợp đồng (${_filteredContracts.length} hợp đồng)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF024965),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            if (_filteredContracts.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
                    SizedBox(height: 8),
                    Text(
                      _contracts.isEmpty 
                          ? 'Không có hợp đồng nào trong tháng này'
                          : 'Không tìm thấy hợp đồng phù hợp',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              _isTableView ? _buildTableView() : _buildListView(),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _filteredContracts.length,
      separatorBuilder: (context, index) => Divider(),
      itemBuilder: (context, index) {
        final contract = _filteredContracts[index];
        final revenue = _safeToDouble(contract.doanhThuDangThucHien);
        final costs = _calculateTotalCosts(contract);
        final profit = revenue - costs;
        final canEdit = _canEditContract(contract);
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(0xFF024965),
            child: Text(
              contract.maKinhDoanh ?? '${index + 1}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            contract.tenHopDong ?? 'Không có tên',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Địa chỉ: ${contract.diaChi ?? 'N/A'}'),
              Text('Doanh thu: ${_formatCurrency(revenue)}'),
              Text(
                'Lợi nhuận: ${_formatCurrency(profit)}',
                style: TextStyle(
                  color: profit >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (contract.loaiHinh != null)
                Text('Loại: ${contract.loaiHinh}'),
              if (contract.nguoiTao != null)
                Text('Người tạo: ${contract.nguoiTao}'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text(
                      contract.trangThai ?? 'N/A',
                      style: TextStyle(fontSize: 10),
                    ),
                    backgroundColor: _getStatusColor(contract.trangThai),
                  ),
                  if (contract.thoiHanKetthuc != null)
                    Text(
                      _formatDate(contract.thoiHanKetthuc),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                ],
              ),
              if (canEdit) ...[
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.edit, color: Color(0xFF024965)),
                  onPressed: () => _navigateToEditContract(contract),
                  tooltip: 'Chỉnh sửa',
                ),
              ],
            ],
          ),
          onTap: () => _showContractDetails(contract),
        );
      },
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 64,
        ),
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 8,
          headingRowHeight: 60,
          dataRowHeight: 80,
          border: TableBorder.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
          columns: [
            DataColumn(
              label: Container(
                width: 150,
                child: Text(
                  'Tên hợp đồng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF024965),
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Mã KD',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'CN Được có',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Loại hình',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Trạng thái',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Doanh thu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Chi phí',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Lợi nhuận',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Người tạo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Ngày KT',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Thao tác',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF024965),
                ),
              ),
            ),
          ],
          rows: _filteredContracts.map((contract) {
            final revenue = _safeToDouble(contract.doanhThuDangThucHien);
            final costs = _calculateTotalCosts(contract);
            final profit = revenue - costs;
            final canEdit = _canEditContract(contract);
            
            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: 150,
                    child: Text(
                      contract.tenHopDong ?? 'N/A',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Text(contract.maKinhDoanh ?? 'N/A'),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Text(
                    contract.congNhanDuocCo?.toString()?? '',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Text(contract.loaiHinh ?? 'N/A'),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Chip(
                    label: Text(
                      contract.trangThai ?? 'N/A',
                      style: TextStyle(fontSize: 10),
                    ),
                    backgroundColor: _getStatusColor(contract.trangThai),
                  ),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Text(
                    _formatCurrency(revenue),
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Text(
                    _formatCurrency(costs),
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Text(
                    _formatCurrency(profit),
                    style: TextStyle(
                      color: profit >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Text(contract.nguoiTao ?? 'N/A'),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Text(_formatDate(contract.thoiHanKetthuc)),
                  onTap: () => _showContractDetails(contract),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.visibility, size: 16),
                        onPressed: () => _showContractDetails(contract),
                        tooltip: 'Xem chi tiết',
                      ),
                      if (canEdit)
                        IconButton(
                          icon: Icon(Icons.edit, size: 16, color: Color(0xFF024965)),
                          onPressed: () => _navigateToEditContract(contract),
                          tooltip: 'Chỉnh sửa',
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
   return Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: color.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: color.withOpacity(0.3)), 
  ),
  child: Column(
    children: [
      Icon(icon, color: color, size: 24),
      SizedBox(height: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  ),
);
 }

 Widget _buildCostDetail(String title, dynamic cost) {
   double amount = _safeToDouble(cost);
   return Padding(
     padding: EdgeInsets.symmetric(vertical: 4.0),
     child: Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Text(
           '• $title:',
           style: TextStyle(fontSize: 14),
         ),
         Text(
           _formatCurrency(amount),
           style: TextStyle(
             color: amount > 0 ? Colors.orange : Colors.grey,
             fontWeight: FontWeight.w500,
           ),
         ),
       ],
     ),
   );
 }
 }