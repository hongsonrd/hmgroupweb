import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/painting.dart' as flutter_painting;
class PayACEditScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String selectedPeriod;
  final List<Map<String, dynamic>> historyData;
  final List<Map<String, dynamic>> policyData;
  final List<Map<String, dynamic>> standardData;
  const PayACEditScreen({Key? key, required this.username, required this.userRole, required this.selectedPeriod, required this.historyData, required this.policyData, required this.standardData}) : super(key: key);
  @override
  _PayACEditScreenState createState() => _PayACEditScreenState();
}
class _PayACEditScreenState extends State<PayACEditScreen> {
  List<Map<String, dynamic>> _editableRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _isLoading = false;
  bool _hasChanges = false;
  String _selectedDepartment = 'Tất cả';
  List<String> _departmentOptions = ['Tất cả'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, TextEditingController> _controllers = {};
  Set<int> _modifiedIndices = {};
  final _numberFormat = NumberFormat('#,###', 'en_US');
  @override
  void initState() {
    super.initState();
    _initializeEditableRecords();
    _initializeDepartments();
    _applyFilters();
  }
  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }
  Future<String?> _showExportChoiceDialog() async {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Xuất file Excel'),
        content: Text('Bạn muốn chia sẻ file hay lưu vào thư mục ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('share'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.share, size: 16),
                SizedBox(width: 4),
                Text('Chia sẻ'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder, size: 16),
                SizedBox(width: 4),
                Text('Lưu vào thư mục'),
              ],
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _handleShareFile(String filePath, String fileName) async {
  try {
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Bảng lương KT ${DateFormat('MM/yyyy').format(DateTime.parse(widget.selectedPeriod))}',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chia sẻ file thành công: $fileName'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    print('Error sharing file: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chia sẻ file: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}

Future<void> _handleSaveToAppFolder(String sourceFilePath, String fileName) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final appFolder = Directory('${directory.path}/BangLuongKT');
    
    // Create folder if it doesn't exist
    if (!await appFolder.exists()) {
      await appFolder.create(recursive: true);
    }
    
    final filePath = '${appFolder.path}/$fileName';
    final sourceFile = File(sourceFilePath);
    await sourceFile.copy(filePath);
    
    // Show success dialog with option to open folder
    if (mounted) {
      await _showSaveSuccessDialog(appFolder.path, fileName);
    }
    
  } catch (e) {
    print('Error saving to app folder: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu file: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}

Future<void> _showSaveSuccessDialog(String folderPath, String fileName) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Lưu thành công'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File bảng lương kế toán đã được lưu:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                fileName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 8),
            Text('Ngày tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            SizedBox(height: 8),
            Text('Đường dẫn thư mục:'),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                folderPath,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _openFolder(folderPath);
            },
            icon: Icon(Icons.folder_open, size: 16),
            label: Text('Mở thư mục'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _openFolder(String folderPath) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [folderPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [folderPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [folderPath]);
    }
  } catch (e) {
    print('Error opening folder: $e');
  }
}
  void _initializeEditableRecords() {
    _editableRecords = widget.historyData.where((record) => record['giaiDoan'] == widget.selectedPeriod).map((record) {
      final userId = record['userId']?.toString() ?? '';
      final policyInfo = _getPolicyInfo(userId);
      final tongCongSua = (record['tongCongSua'] ?? 0).toDouble();
      final truDiMuonSua = (record['truDiMuonSua'] ?? 0);
      final tongTangCaSua = (record['tongTangCaSua'] ?? 0).toDouble();
      final loaiCong = record['loaiCong'] ?? 'Vp';
      final soCongChuan = (record['soCongChuan'] ?? 30).toDouble();
      final soCongLe = (record['soCongLe'] ?? 0).toDouble();
      final mucCongLe = (policyInfo['mucBhxh'] ?? 0) * 2.0;
      final thanhTienCongLe = soCongChuan > 0 ? (soCongLe * mucCongLe / soCongChuan) : 0.0;
      final mucLuongChinh = policyInfo['dangThuViec'] ? (policyInfo['mucLuong'] ?? 0) : (policyInfo['mucLuongChinh'] ?? 0);
      final mucTangCa = _calculateMucTangCa(policyInfo, mucLuongChinh, soCongChuan);
      final thanhTienTangCa = tongTangCaSua * mucTangCa;
final truyThu = int.tryParse(record['truyThu']?.toString() ?? '0') ?? 0;
final truyLinh = int.tryParse(record['truyLinh']?.toString() ?? '0') ?? 0;
      final tongThucNhan = (soCongChuan > 0 ? (mucLuongChinh * tongCongSua / soCongChuan) : 0.0) + thanhTienTangCa + thanhTienCongLe + truyLinh - truyThu + (policyInfo['hoTroKhac'] ?? 0) + (policyInfo['dieuChinhKhac'] ?? 0) - (policyInfo['truBhxh'] ?? 0) - (policyInfo['truCongDoan'] ?? 0) - (policyInfo['phuCapDienThoai'] ?? 0) - (policyInfo['phuCapGuiXe'] ?? 0) - (policyInfo['phuCapAnUong'] ?? 0) - (policyInfo['phuCapTrangPhuc'] ?? 0) - truDiMuonSua;
      final thueTncnSauGiamTru = (tongThucNhan - (policyInfo['thueGiamTruPhuThuoc'] ?? 0) - (policyInfo['thueGiamTruBanThan'] ?? 0) - (policyInfo['thueGiamTruTrangPhuc'] ?? 0) - (policyInfo['thueGiamTruDienThoai'] ?? 0) - (policyInfo['thueGiamTruAn'] ?? 0) - (policyInfo['thueGiamTruXangXe'] ?? 0)).clamp(0.0, double.infinity);
      final thanhToanLan1Raw = tongThucNhan * 0.4;
      final thanhToanLan1Capped = thanhToanLan1Raw > 11000000 ? 11000000 : thanhToanLan1Raw;
      final thanhToanLan1 = (thanhToanLan1Capped / 10000).floor() * 10000.0;
      final capForLan1AndLan2 = 11000000 + (policyInfo['thueGiamTruPhuThuoc'] ?? 0) + (policyInfo['thueGiamTruTrangPhuc'] ?? 0) + (policyInfo['thueGiamTruDienThoai'] ?? 0) + (policyInfo['thueGiamTruAn'] ?? 0) + (policyInfo['thueGiamTruXangXe'] ?? 0);
      var thanhToanLan2 = tongThucNhan - thanhToanLan1;
      if (thanhToanLan1 + thanhToanLan2 > capForLan1AndLan2) {
        thanhToanLan2 = capForLan1AndLan2 - thanhToanLan1;
        if (thanhToanLan2 < 0) thanhToanLan2 = 0;
      }
      final hinhThucLan2 = tongThucNhan - thanhToanLan1 - thanhToanLan2;
      return {
        'uid': record['uid'],
        'giaiDoan': record['giaiDoan'],
        'userId': userId,
        'phanNhom': record['phanNhom'],
        'maNhanVien': record['maNhanVien'],
        'tenNhanVien': record['tenNhanVien'],
        'soTaiKhoan': record['soTaiKhoan'] ?? '',
        'tongCongGoc': record['tongCongGoc'] ?? 0.0,
        'tongCongSua': tongCongSua,
        'phutDiMuonGoc': record['phutDiMuonGoc'] ?? 0,
        'truDiMuonGoc': record['truDiMuonGoc'] ?? 0,
        'truDiMuonSua': truDiMuonSua,
        'tongTangCaGoc': record['tongTangCaGoc'] ?? 0.0,
        'phutDiMuonSua': record['phutDiMuonSua'] ?? 0,
        'tongTangCaSua': tongTangCaSua,
        'loaiCong': loaiCong,
        'soCongChuan': soCongChuan,
        'soCongLe': soCongLe,
        'mucCongLe': mucCongLe,
        'thanhTienCongLe': thanhTienCongLe,
        'mucLuongChinh': mucLuongChinh,
        'truBhxh': policyInfo['truBhxh'] ?? 0,
        'truCongDoan': policyInfo['truCongDoan'] ?? 0,
        'phuCapDienThoai': policyInfo['phuCapDienThoai'] ?? 0,
        'phuCapGuiXe': policyInfo['phuCapGuiXe'] ?? 0,
        'phuCapAnUong': policyInfo['phuCapAnUong'] ?? 0,
        'phuCapTrangPhuc': policyInfo['phuCapTrangPhuc'] ?? 0,
        'hoTroKhac': policyInfo['hoTroKhac'] ?? 0,
        'dieuChinhKhac': policyInfo['dieuChinhKhac'] ?? 0,
        'mucTangCa': mucTangCa,
        'thanhTienTangCa': thanhTienTangCa,
        'truyThu': truyThu,
        'truyLinh': truyLinh,
        'tongThucNhan': tongThucNhan,
        'ghiChu': record['ghiChu']?.toString() ?? '', 
        'thueGiamTruPhuThuoc': policyInfo['thueGiamTruPhuThuoc'] ?? 0,
        'thueGiamTruBanThan': policyInfo['thueGiamTruBanThan'] ?? 0,
        'thueGiamTruTrangPhuc': policyInfo['thueGiamTruTrangPhuc'] ?? 0,
        'thueGiamTruDienThoai': policyInfo['thueGiamTruDienThoai'] ?? 0,
        'thueGiamTruAn': policyInfo['thueGiamTruAn'] ?? 0,
        'thueGiamTruXangXe': policyInfo['thueGiamTruXangXe'] ?? 0,
        'thueTncnSauGiamTru': thueTncnSauGiamTru,
        'thanhToanLan1': thanhToanLan1,
        'hinhThucLan1': 2,
        'thanhToanLan2': thanhToanLan2,
        'hinhThucLan2': hinhThucLan2,
        'isModified': false,
      };
    }).toList();
    _editableRecords.sort((a, b) {
      final deptCompare = (a['phanNhom'] ?? '').toString().compareTo((b['phanNhom'] ?? '').toString());
      if (deptCompare != 0) return deptCompare;
      return (a['tenNhanVien'] ?? '').toString().compareTo((b['tenNhanVien'] ?? '').toString());
    });
  }
  void _initializeDepartments() {
    final departments = _editableRecords.map((item) => item['phanNhom']?.toString() ?? 'Không xác định').toSet().toList();
    departments.sort();
    setState(() {
      _departmentOptions = ['Tất cả'] + departments;
    });
  }
  void _applyFilters() {
    _filteredRecords = _editableRecords.where((record) {
      if (_selectedDepartment != 'Tất cả' && record['phanNhom']?.toString() != _selectedDepartment) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final tenNhanVien = record['tenNhanVien']?.toString().toLowerCase() ?? '';
        if (!tenNhanVien.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();
  }
  Map<String, dynamic> _getPolicyInfo(String userId) {
    if (userId.isEmpty) {
      return {'mucBhxh': 0, 'mucLuongChinh': 0, 'mucLuong': 0, 'dangThuViec': false, 'truBhxh': 0, 'truCongDoan': 0, 'phuCapDienThoai': 0, 'phuCapGuiXe': 0, 'phuCapAnUong': 0, 'phuCapTrangPhuc': 0, 'hoTroKhac': 0, 'dieuChinhKhac': 0, 'hinhThucTangCa': '', 'mucCoDinhTangCa': 0, 'thueGiamTruPhuThuoc': 0, 'thueGiamTruBanThan': 0, 'thueGiamTruTrangPhuc': 0, 'thueGiamTruDienThoai': 0, 'thueGiamTruAn': 0, 'thueGiamTruXangXe': 0};
    }
    final matchingPolicies = widget.policyData.where((policy) => policy['userId']?.toString() == userId).toList();
    if (matchingPolicies.isEmpty) {
      return {'mucBhxh': 0, 'mucLuongChinh': 0, 'mucLuong': 0, 'dangThuViec': false, 'truBhxh': 0, 'truCongDoan': 0, 'phuCapDienThoai': 0, 'phuCapGuiXe': 0, 'phuCapAnUong': 0, 'phuCapTrangPhuc': 0, 'hoTroKhac': 0, 'dieuChinhKhac': 0, 'hinhThucTangCa': '', 'mucCoDinhTangCa': 0, 'thueGiamTruPhuThuoc': 0, 'thueGiamTruBanThan': 0, 'thueGiamTruTrangPhuc': 0, 'thueGiamTruDienThoai': 0, 'thueGiamTruAn': 0, 'thueGiamTruXangXe': 0};
    }
    matchingPolicies.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['ngay']?.toString() ?? '');
        final dateB = DateTime.parse(b['ngay']?.toString() ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });
    final latest = matchingPolicies.first;
    return {'mucBhxh': (latest['mucBhxh'] ?? 0), 'mucLuongChinh': (latest['mucLuongChinh'] ?? 0), 'mucLuong': (latest['mucLuong'] ?? 0), 'dangThuViec': latest['dangThuViec'] == true, 'truBhxh': (latest['truBhxh'] ?? 0), 'truCongDoan': (latest['truCongDoan'] ?? 0), 'phuCapDienThoai': (latest['phuCapDienThoai'] ?? 0), 'phuCapGuiXe': (latest['phuCapGuiXe'] ?? 0), 'phuCapAnUong': (latest['phuCapAnUong'] ?? 0), 'phuCapTrangPhuc': (latest['phuCapTrangPhuc'] ?? 0), 'hoTroKhac': (latest['hoTroKhac'] ?? 0), 'dieuChinhKhac': (latest['dieuChinhKhac'] ?? 0), 'hinhThucTangCa': latest['hinhThucTangCa']?.toString() ?? '', 'mucCoDinhTangCa': (latest['mucCoDinhTangCa'] ?? 0), 'thueGiamTruPhuThuoc': (latest['thueGiamTruPhuThuoc'] ?? 0), 'thueGiamTruBanThan': (latest['thueGiamTruBanThan'] ?? 0), 'thueGiamTruTrangPhuc': (latest['thueGiamTruTrangPhuc'] ?? 0), 'thueGiamTruDienThoai': (latest['thueGiamTruDienThoai'] ?? 0), 'thueGiamTruAn': (latest['thueGiamTruAn'] ?? 0), 'thueGiamTruXangXe': (latest['thueGiamTruXangXe'] ?? 0)};
  }
  double _calculateMucTangCa(Map<String, dynamic> policyInfo, num mucLuongChinh, double soCongChuan) {
    if (soCongChuan == 0) return 0.0;
    final hinhThuc = policyInfo['hinhThucTangCa']?.toString() ?? '';
    if (hinhThuc == 'Cố Định') {
      return (policyInfo['mucCoDinhTangCa'] ?? 0).toDouble();
    } else if (hinhThuc == 'BHXH') {
      final mucBhxh = (policyInfo['mucBhxh'] ?? 0).toDouble();
      return mucBhxh / soCongChuan / 8;
    } else if (hinhThuc == 'Luong') {
      return mucLuongChinh / soCongChuan / 8;
    }
    return 0.0;
  }
  void _recalculateRecord(int index) {
    final record = _editableRecords[index];
    final userId = record['userId']?.toString() ?? '';
    final policyInfo = _getPolicyInfo(userId);
    final tongCongSua = (record['tongCongSua'] ?? 0).toDouble();
    final truDiMuonSua = (record['truDiMuonSua'] ?? 0);
    final tongTangCaSua = (record['tongTangCaSua'] ?? 0).toDouble();
    final soCongChuan = (record['soCongChuan'] ?? 30).toDouble();
    final soCongLe = (record['soCongLe'] ?? 0).toDouble();
    final mucCongLe = (policyInfo['mucBhxh'] ?? 0) * 2.0;
    final thanhTienCongLe = soCongChuan > 0 ? (soCongLe * mucCongLe / soCongChuan) : 0.0;
    final mucLuongChinh = policyInfo['dangThuViec'] ? (policyInfo['mucLuong'] ?? 0) : (policyInfo['mucLuongChinh'] ?? 0);
    final mucTangCa = _calculateMucTangCa(policyInfo, mucLuongChinh, soCongChuan);
    final thanhTienTangCa = tongTangCaSua * mucTangCa;
    final truyThu = int.tryParse(record['truyThu']?.toString() ?? '0') ?? 0;
    final truyLinh = int.tryParse(record['truyLinh']?.toString() ?? '0') ?? 0;
    final tongThucNhan = (soCongChuan > 0 ? (mucLuongChinh * tongCongSua / soCongChuan) : 0.0) + thanhTienTangCa + thanhTienCongLe + truyLinh - truyThu + (policyInfo['hoTroKhac'] ?? 0) + (policyInfo['dieuChinhKhac'] ?? 0) - (policyInfo['truBhxh'] ?? 0) - (policyInfo['truCongDoan'] ?? 0) - (policyInfo['phuCapDienThoai'] ?? 0) - (policyInfo['phuCapGuiXe'] ?? 0) - (policyInfo['phuCapAnUong'] ?? 0) - (policyInfo['phuCapTrangPhuc'] ?? 0) - truDiMuonSua;
    final thueTncnSauGiamTru = (tongThucNhan - (policyInfo['thueGiamTruPhuThuoc'] ?? 0) - (policyInfo['thueGiamTruBanThan'] ?? 0) - (policyInfo['thueGiamTruTrangPhuc'] ?? 0) - (policyInfo['thueGiamTruDienThoai'] ?? 0) - (policyInfo['thueGiamTruAn'] ?? 0) - (policyInfo['thueGiamTruXangXe'] ?? 0)).clamp(0.0, double.infinity);
    final thanhToanLan1Raw = tongThucNhan * 0.4;
    final thanhToanLan1Capped = thanhToanLan1Raw > 11000000 ? 11000000 : thanhToanLan1Raw;
    final thanhToanLan1 = (thanhToanLan1Capped / 10000).floor() * 10000.0;
    final capForLan1AndLan2 = 11000000 + (policyInfo['thueGiamTruPhuThuoc'] ?? 0) + (policyInfo['thueGiamTruTrangPhuc'] ?? 0) + (policyInfo['thueGiamTruDienThoai'] ?? 0) + (policyInfo['thueGiamTruAn'] ?? 0) + (policyInfo['thueGiamTruXangXe'] ?? 0);
    var thanhToanLan2 = tongThucNhan - thanhToanLan1;
    if (thanhToanLan1 + thanhToanLan2 > capForLan1AndLan2) {
      thanhToanLan2 = capForLan1AndLan2 - thanhToanLan1;
      if (thanhToanLan2 < 0) thanhToanLan2 = 0;
    }
    final hinhThucLan2 = tongThucNhan - thanhToanLan1 - thanhToanLan2;
    setState(() {
      _editableRecords[index]['mucCongLe'] = mucCongLe;
      _editableRecords[index]['thanhTienCongLe'] = thanhTienCongLe;
      _editableRecords[index]['mucLuongChinh'] = mucLuongChinh;
      _editableRecords[index]['mucTangCa'] = mucTangCa;
      _editableRecords[index]['thanhTienTangCa'] = thanhTienTangCa;
      _editableRecords[index]['tongThucNhan'] = tongThucNhan;
      _editableRecords[index]['thueTncnSauGiamTru'] = thueTncnSauGiamTru;
      _editableRecords[index]['thanhToanLan1'] = thanhToanLan1;
      _editableRecords[index]['thanhToanLan2'] = thanhToanLan2;
      _editableRecords[index]['hinhThucLan2'] = hinhThucLan2;
    });
  }
  String _formatNumber(num value) {
    if (value.isInfinite || value.isNaN) return '0';
    return _numberFormat.format(value.round());
  }
  Future<void> _exportToExcel() async {
  try {
    setState(() { _isLoading = true; });
    
    // Show choice dialog first
    final choice = await _showExportChoiceDialog();
    if (choice == null) {
      setState(() { _isLoading = false; });
      return; // User cancelled
    }

    var excel = excel_pkg.Excel.createExcel();
    excel.delete('Sheet1');
    
    // Sheet 1 - Full data with 37 columns
    var sheet1 = excel['BangLuongKT'];
    final headers1 = ['STT', 'Phòng ban', 'Mã NV', 'Tên NV', 'Tổng công', 'Trừ muộn', 'Tăng ca', 'Loại công', 'Công chuẩn', 'Công lễ', 'Mức công lễ', 'Tiền công lễ', 'Lương chính', 'Trừ BHXH', 'Trừ CĐ', 'PC Đ.thoại', 'PC Gửi xe', 'PC Ăn', 'PC T.phục', 'Hỗ trợ khác', 'Đ.chỉnh khác', 'Mức tăng ca', 'Tiền tăng ca', 'Truy thu', 'Truy lĩnh', 'Tổng thực nhận', 'Trừ Thuế GT PT', 'Trừ Thuế GT BT', 'Trừ Thuế GT TP', 'Trừ Thuế GT ĐT', 'Trừ Thuế GT Ăn', 'Trừ Thuế GT XX', 'Thuế TNCN sau GT', 'TT Lần 1', 'TT Lần 2', 'HT Lần 2', 'Ghi chú'];
    for (var i = 0; i < headers1.length; i++) {
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers1[i];
    }
    
    for (var i = 0; i < _editableRecords.length; i++) {
      final record = _editableRecords[i];
      final rowIndex = i + 1;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = i + 1;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = record['phanNhom']?.toString() ?? '';
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = record['maNhanVien']?.toString() ?? '';
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = record['tenNhanVien']?.toString() ?? '';
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = double.tryParse(record['tongCongSua']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = int.tryParse(record['truDiMuonSua']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = double.tryParse(record['tongTangCaSua']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = record['loaiCong']?.toString() ?? '';
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = double.tryParse(record['soCongChuan']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = double.tryParse(record['soCongLe']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = double.tryParse(record['mucCongLe']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value = double.tryParse(record['thanhTienCongLe']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).value = double.tryParse(record['mucLuongChinh']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex)).value = double.tryParse(record['truBhxh']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: rowIndex)).value = double.tryParse(record['truCongDoan']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: rowIndex)).value = double.tryParse(record['phuCapDienThoai']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: rowIndex)).value = double.tryParse(record['phuCapGuiXe']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: rowIndex)).value = double.tryParse(record['phuCapAnUong']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: rowIndex)).value = double.tryParse(record['phuCapTrangPhuc']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 19, rowIndex: rowIndex)).value = double.tryParse(record['hoTroKhac']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 20, rowIndex: rowIndex)).value = double.tryParse(record['dieuChinhKhac']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 21, rowIndex: rowIndex)).value = double.tryParse(record['mucTangCa']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 22, rowIndex: rowIndex)).value = double.tryParse(record['thanhTienTangCa']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 23, rowIndex: rowIndex)).value = int.tryParse(record['truyThu']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 24, rowIndex: rowIndex)).value = int.tryParse(record['truyLinh']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 25, rowIndex: rowIndex)).value = double.tryParse(record['tongThucNhan']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 26, rowIndex: rowIndex)).value = double.tryParse(record['thueGiamTruPhuThuoc']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 27, rowIndex: rowIndex)).value = double.tryParse(record['thueGiamTruBanThan']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 28, rowIndex: rowIndex)).value = double.tryParse(record['thueGiamTruTrangPhuc']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 29, rowIndex: rowIndex)).value = double.tryParse(record['thueGiamTruDienThoai']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 30, rowIndex: rowIndex)).value = double.tryParse(record['thueGiamTruAn']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 31, rowIndex: rowIndex)).value = double.tryParse(record['thueGiamTruXangXe']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 32, rowIndex: rowIndex)).value = double.tryParse(record['thueTncnSauGiamTru']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 33, rowIndex: rowIndex)).value = double.tryParse(record['thanhToanLan1']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 34, rowIndex: rowIndex)).value = double.tryParse(record['thanhToanLan2']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 35, rowIndex: rowIndex)).value = double.tryParse(record['hinhThucLan2']?.toString() ?? '0') ?? 0;
      sheet1.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 36, rowIndex: rowIndex)).value = record['ghiChu']?.toString() ?? '';
    }
    
    // Sheet 2
    var sheet2 = excel['ThanhToanLan1'];
    final headers2 = ['Họ tên', 'Số tiền', 'Tiền mặt', 'Số tài khoản người hưởng', 'Ngân hàng người hưởng', 'Tỉnh TP', 'Ghi chú'];
    for (var i = 0; i < headers2.length; i++) {
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers2[i];
    }
    
    for (var i = 0; i < _editableRecords.length; i++) {
      final record = _editableRecords[i];
      final rowIndex = i + 1;
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = record['tenNhanVien']?.toString() ?? '';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = double.tryParse(record['thanhToanLan1']?.toString() ?? '0') ?? 0;
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = 0;
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = record['soTaiKhoan']?.toString() ?? '';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = 'Techcombank';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = 'Hà Nội';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = record['ghiChu']?.toString() ?? '';
    }
    
    // Sheet 3
    var sheet3 = excel['ThanhToanLan2'];
    final headers3 = ['Họ tên', 'Số tiền', 'Tiền mặt', 'Số tài khoản người hưởng', 'Ngân hàng người hưởng', 'Tỉnh TP', 'Ghi chú'];
    for (var i = 0; i < headers3.length; i++) {
      sheet3.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers3[i];
    }
    
    for (var i = 0; i < _editableRecords.length; i++) {
      final record = _editableRecords[i];
      final rowIndex = i + 1;
      sheet3.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = record['tenNhanVien']?.toString() ?? '';
      sheet3.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = double.tryParse(record['thanhToanLan2']?.toString() ?? '0') ?? 0;
      sheet3.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = double.tryParse(record['hinhThucLan2']?.toString() ?? '0') ?? 0;
      sheet3.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = record['soTaiKhoan']?.toString() ?? '';
      sheet3.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = 'Techcombank';
      sheet3.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = 'Hà Nội';
      sheet3.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = record['ghiChu']?.toString() ?? '';
    }
    
    var fileBytes = excel.encode();
    if (fileBytes != null) {
      final directory = await getTemporaryDirectory();
      final fileName = 'BangLuongKT_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';
      File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes);
      
      if (choice == 'share') {
        await _handleShareFile(filePath, fileName);
      } else {
        await _handleSaveToAppFolder(filePath, fileName);
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất Excel: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }
}
  Future<void> _submitChanges() async {
    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có thay đổi để lưu'), backgroundColor: Colors.orange));
      return;
    }
    final modifiedRecords = _modifiedIndices.map((index) => _editableRecords[index]).toList();
    print('=== PAY AC EDIT SUBMIT ===');
    print('Total modified records: ${modifiedRecords.length}');
    final processedRecords = modifiedRecords.map((record) {
      final processed = Map<String, dynamic>.from(record);
      processed.remove('isModified');
      print('Record UID: ${processed['uid']}, userId: ${processed['userId']}, truyThu: ${processed['truyThu']}, truyLinh: ${processed['truyLinh']}, ghiChu: ${processed['ghiChu']}');
      return processed;
    }).toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận lưu thay đổi'),
        content: Text('Bạn có chắc muốn lưu ${processedRecords.length} bản ghi đã thay đổi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {_isLoading = true;});
    try {
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/paycreation');
      final requestBody = {'username': widget.username, 'userRole': widget.userRole, 'selectedMonth': widget.selectedPeriod, 'selectedBranch': 'HANOI', 'records': processedRecords, 'submittedAt': DateTime.now().toIso8601String()};
      print('Sending to server: ${processedRecords.length} records');
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(requestBody));
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {_isLoading = false;});
        final shouldExport = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thành công!'),
            content: const Text('Lưu thay đổi thành công!\n\nBạn có muốn xuất dữ liệu ra file Excel?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Xuất Excel')),
            ],
          ),
        );
        if (shouldExport == true) {
          await _exportToExcel();
        }
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Submit error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      setState(() {_isLoading = false;});
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Chỉnh sửa lương KT - ${DateFormat('MM/yyyy').format(DateTime.parse(widget.selectedPeriod))}'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          if (_hasChanges) TextButton.icon(icon: const Icon(Icons.save, color: Colors.white), label: const Text('Lưu', style: TextStyle(color: Colors.white)), onPressed: _submitChanges),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildSpreadsheet(),
    );
  }
  Widget _buildSpreadsheet() {
    final columnWidths = [60.0, 120.0, 100.0, 150.0, 100.0, 100.0, 100.0, 100.0, 110.0, 90.0, 100.0, 110.0, 110.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 110.0, 120.0, 120.0, 120.0, 120.0, 120.0, 120.0, 120.0, 110.0, 100.0, 110.0, 100.0, 200.0];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Text('Chỉnh sửa ${_filteredRecords.length} bản ghi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[600])),
                  const Spacer(),
                  if (_hasChanges) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)), child: Text('${_modifiedIndices.length} thay đổi', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: InputDecoration(labelText: 'Phòng ban', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: _departmentOptions.map((dept) => DropdownMenuItem(value: dept, child: Text(dept))).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value!;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Tìm theo tên NV',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear), onPressed: () {_searchController.clear(); setState(() {_searchQuery = ''; _applyFilters();});}) : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          color: Colors.green[50],
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final newOffset = _horizontalController.offset + pointerSignal.scrollDelta.dy;
                _horizontalController.jumpTo(newOffset.clamp(0.0, _horizontalController.position.maxScrollExtent));
              }
            },
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHeaderCell('STT', columnWidths[0]),
                  _buildHeaderCell('Phòng ban', columnWidths[1]),
                  _buildHeaderCell('Mã NV', columnWidths[2]),
                  _buildHeaderCell('Tên NV', columnWidths[3]),
                  _buildHeaderCell('Tổng công', columnWidths[4]),
                  _buildHeaderCell('Trừ muộn', columnWidths[5]),
                  _buildHeaderCell('Tăng ca', columnWidths[6]),
                  _buildHeaderCell('Loại công', columnWidths[7]),
                  _buildHeaderCell('Công chuẩn', columnWidths[8]),
                  _buildHeaderCell('Công lễ', columnWidths[9]),
                  _buildHeaderCell('Mức công lễ', columnWidths[10]),
                  _buildHeaderCell('Tiền công lễ', columnWidths[11]),
                  _buildHeaderCell('Lương chính', columnWidths[12]),
                  _buildHeaderCell('Trừ BHXH', columnWidths[13]),
                  _buildHeaderCell('Trừ CĐ', columnWidths[14]),
                  _buildHeaderCell('PC Đ.thoại', columnWidths[15]),
                  _buildHeaderCell('PC Gửi xe', columnWidths[16]),
                  _buildHeaderCell('PC Ăn', columnWidths[17]),
                  _buildHeaderCell('PC T.phục', columnWidths[18]),
                  _buildHeaderCell('Hỗ trợ khác', columnWidths[19]),
                  _buildHeaderCell('Đ.chỉnh khác', columnWidths[20]),
                  _buildHeaderCell('Mức tăng ca', columnWidths[21]),
                  _buildHeaderCell('Tiền tăng ca', columnWidths[22]),
                  _buildHeaderCell('Truy thu', columnWidths[23]),
                  _buildHeaderCell('Truy lĩnh', columnWidths[24]),
                  _buildHeaderCell('Tổng thực nhận', columnWidths[25]),
                  _buildHeaderCell('Trừ Thuế GT PT', columnWidths[26]),
                  _buildHeaderCell('Trừ Thuế GT BT', columnWidths[27]),
                  _buildHeaderCell('Trừ Thuế GT TP', columnWidths[28]),
                  _buildHeaderCell('Trừ Thuế GT ĐT', columnWidths[29]),
                  _buildHeaderCell('Trừ Thuế GT Ăn', columnWidths[30]),
                  _buildHeaderCell('Trừ Thuế GT XX', columnWidths[31]),
                  _buildHeaderCell('Thuế TNCN sau GT', columnWidths[32]),
                  _buildHeaderCell('TT Lần 1', columnWidths[33]),
                  _buildHeaderCell('TT Lần 2', columnWidths[34]),
                  _buildHeaderCell('HT Lần 2', columnWidths[35]),
                  _buildHeaderCell('Ghi chú', columnWidths[36]),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                if (pointerSignal.scrollDelta.dx != 0) {
                  final newOffset = _horizontalController.offset + pointerSignal.scrollDelta.dx;
                  _horizontalController.jumpTo(newOffset.clamp(0.0, _horizontalController.position.maxScrollExtent));
                } else {
                  final newOffset = _verticalController.offset + pointerSignal.scrollDelta.dy;
                  _verticalController.jumpTo(newOffset.clamp(0.0, _verticalController.position.maxScrollExtent));
                }
              }
            },
            child: SingleChildScrollView(
              controller: _verticalController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: _filteredRecords.asMap().entries.map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    final actualIndex = _editableRecords.indexOf(record);
                    return Container(
                      decoration: BoxDecoration(border: flutter_painting.Border(bottom: BorderSide(color: Colors.grey[300]!))),
                      child: Row(
                        children: [
                          _buildDataCell(Text('${index + 1}'), columnWidths[0]),
                          _buildDataCell(Text(record['phanNhom']?.toString() ?? ''), columnWidths[1]),
                          _buildDataCell(Text(record['maNhanVien']?.toString() ?? ''), columnWidths[2]),
                          _buildDataCell(Text(record['tenNhanVien']?.toString() ?? ''), columnWidths[3]),
                          _buildDataCell(Text(record['tongCongSua']?.toString() ?? '0'), columnWidths[4]),
                          _buildDataCell(Text(record['truDiMuonSua']?.toString() ?? '0'), columnWidths[5]),
                          _buildDataCell(Text(record['tongTangCaSua']?.toString() ?? '0'), columnWidths[6]),
                          _buildDataCell(Text(record['loaiCong']?.toString() ?? ''), columnWidths[7]),
                          _buildDataCell(Text(record['soCongChuan']?.toString() ?? '0'), columnWidths[8]),
                          _buildDataCell(Text(record['soCongLe']?.toString() ?? '0'), columnWidths[9]),
                          _buildDataCell(Text(_formatNumber(record['mucCongLe'] ?? 0)), columnWidths[10]),
                          _buildDataCell(Text(_formatNumber(record['thanhTienCongLe'] ?? 0)), columnWidths[11]),
                          _buildDataCell(Text(_formatNumber(record['mucLuongChinh'] ?? 0)), columnWidths[12]),
                          _buildDataCell(Text(_formatNumber(record['truBhxh'] ?? 0)), columnWidths[13]),
                          _buildDataCell(Text(_formatNumber(record['truCongDoan'] ?? 0)), columnWidths[14]),
                          _buildDataCell(Text(_formatNumber(record['phuCapDienThoai'] ?? 0)), columnWidths[15]),
                          _buildDataCell(Text(_formatNumber(record['phuCapGuiXe'] ?? 0)), columnWidths[16]),
                          _buildDataCell(Text(_formatNumber(record['phuCapAnUong'] ?? 0)), columnWidths[17]),
                          _buildDataCell(Text(_formatNumber(record['phuCapTrangPhuc'] ?? 0)), columnWidths[18]),
                          _buildDataCell(Text(_formatNumber(record['hoTroKhac'] ?? 0)), columnWidths[19]),
                          _buildDataCell(Text(_formatNumber(record['dieuChinhKhac'] ?? 0)), columnWidths[20]),
                          _buildDataCell(Text(_formatNumber(record['mucTangCa'] ?? 0)), columnWidths[21]),
                          _buildDataCell(Text(_formatNumber(record['thanhTienTangCa'] ?? 0)), columnWidths[22]),
                          _buildDataCell(_buildEditableIntCell(actualIndex, 'truyThu', record['truyThu']), columnWidths[23]),
                          _buildDataCell(_buildEditableIntCell(actualIndex, 'truyLinh', record['truyLinh']), columnWidths[24]),
                          _buildDataCell(Text(_formatNumber(record['tongThucNhan'] ?? 0), style: TextStyle(fontWeight: FontWeight.bold)), columnWidths[25]),
                          _buildDataCell(Text(_formatNumber(record['thueGiamTruPhuThuoc'] ?? 0)), columnWidths[26]),
                          _buildDataCell(Text(_formatNumber(record['thueGiamTruBanThan'] ?? 0)), columnWidths[27]),
                          _buildDataCell(Text(_formatNumber(record['thueGiamTruTrangPhuc'] ?? 0)), columnWidths[28]),
                          _buildDataCell(Text(_formatNumber(record['thueGiamTruDienThoai'] ?? 0)), columnWidths[29]),
                          _buildDataCell(Text(_formatNumber(record['thueGiamTruAn'] ?? 0)), columnWidths[30]),
                          _buildDataCell(Text(_formatNumber(record['thueGiamTruXangXe'] ?? 0)), columnWidths[31]),
                          _buildDataCell(Text(_formatNumber(record['thueTncnSauGiamTru'] ?? 0)), columnWidths[32]),
                          _buildDataCell(Text(_formatNumber(record['thanhToanLan1'] ?? 0)), columnWidths[33]),
                          _buildDataCell(Text(_formatNumber(record['thanhToanLan2'] ?? 0)), columnWidths[34]),
                          _buildDataCell(Text(_formatNumber(record['hinhThucLan2'] ?? 0)), columnWidths[35]),
                          _buildDataCell(_buildEditableTextCell(actualIndex, 'ghiChu', record['ghiChu']), columnWidths[36]),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: flutter_painting.Border.all(color: Colors.grey[300]!)),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
    );
  }
  Widget _buildDataCell(Widget child, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: flutter_painting.Border(left: BorderSide(color: Colors.grey[300]!), right: BorderSide(color: Colors.grey[300]!))),
      child: child,
    );
  }
  Widget _buildEditableIntCell(int index, String field, dynamic value) {
    final key = '$index-$field';
    if (!_controllers.containsKey(key)) {
      final actualValue = _editableRecords[index][field];
    _controllers[key] = TextEditingController(text: actualValue?.toString() ?? '0');
    }
    final controller = _controllers[key]!;
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
        onChanged: (newValue) {
          final parsedValue = int.tryParse(newValue) ?? 0;
          _editableRecords[index][field] = parsedValue;
          _modifiedIndices.add(index);
          _recalculateRecord(index);
          setState(() {
            _hasChanges = true;
          });
        },
      ),
    );
  }
  Widget _buildEditableTextCell(int index, String field, dynamic value) {
    final key = '$index-$field';
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: value?.toString() ?? '');
    }
    final controller = _controllers[key]!;
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\u00C0-\u1EF9]'))],
        decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
        onChanged: (newValue) {
          _editableRecords[index][field] = newValue;
          _modifiedIndices.add(index);
          setState(() {
            _hasChanges = true;
          });
        },
      ),
    );
  }
}