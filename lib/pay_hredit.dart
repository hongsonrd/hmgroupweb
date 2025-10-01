import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter/gestures.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';
import 'package:flutter/painting.dart' as flutter_painting;
import 'dart:io';

class PayHREditScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String selectedPeriod;
  final List<Map<String, dynamic>> historyData;
  final List<Map<String, dynamic>> policyData;
  final List<Map<String, dynamic>> standardData;
  const PayHREditScreen({Key? key, required this.username, required this.userRole, required this.selectedPeriod, required this.historyData, required this.policyData, required this.standardData}) : super(key: key);
  @override
  _PayHREditScreenState createState() => _PayHREditScreenState();
}
class _PayHREditScreenState extends State<PayHREditScreen> {
  List<Map<String, dynamic>> _editableRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _isLoading = false;
  bool _hasChanges = false;
  final _uuid = Uuid();
  String _selectedDepartment = 'Tất cả';
  List<String> _departmentOptions = ['Tất cả'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, TextEditingController> _controllers = {};
  Set<int> _modifiedIndices = {};
  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  Future<void> _initializeData() async {
    await _initializeEditableRecords();
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
      text: 'Bảng lương ${DateFormat('MM/yyyy').format(DateTime.parse(widget.selectedPeriod))}',
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
    final appFolder = Directory('${directory.path}/BangLuong');
    
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
            Text('File bảng lương đã được lưu:'),
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
  Future<void> _initializeEditableRecords() async {
    final bankAccountMap = await _loadBankAccounts();
    _editableRecords = widget.historyData.where((record) => record['giaiDoan'] == widget.selectedPeriod).map((record) {
      final userId = record['userId']?.toString() ?? '';
      final maNhanVien = record['maNhanVien']?.toString() ?? '';
      final loaiCong = _getLoaiCong(userId);
      final soCongChuan = _getSoCongChuan(loaiCong);
      return {
        'uid': record['uid'],
        'giaiDoan': record['giaiDoan'],
        'userId': record['userId'],
        'phanNhom': record['phanNhom'],
        'maNhanVien': maNhanVien,
        'tenNhanVien': record['tenNhanVien'],
        'soTaiKhoan': bankAccountMap[maNhanVien] ?? record['soTaiKhoan'] ?? '',
        'tongCongGoc': record['tongCongGoc'] ?? 0.0,
        'tongCongSua': record['tongCongSua'] ?? record['tongCongGoc'] ?? 0.0,
        'phutDiMuonGoc': record['phutDiMuonGoc'] ?? 0,
        'phutDiMuonSua': record['phutDiMuonSua'] ?? record['phutDiMuonGoc'] ?? 0,
        'truDiMuonGoc': record['truDiMuonGoc'] ?? 0,
        'truDiMuonSua': record['truDiMuonSua'] ?? record['truDiMuonGoc'] ?? 0,
        'tongTangCaGoc': record['tongTangCaGoc'] ?? 0.0,
        'tongTangCaSua': record['tongTangCaSua'] ?? record['tongTangCaGoc'] ?? 0.0,
        'loaiCong': loaiCong,
        'soCongChuan': soCongChuan,
        'soCongLe': record['soCongLe'] ?? 0.0,
        'isNew': false,
        'isModified': false,
      };
    }).toList();
    _editableRecords.sort((a, b) {
      final deptCompare = (a['phanNhom'] ?? '').toString().compareTo((b['phanNhom'] ?? '').toString());
      if (deptCompare != 0) return deptCompare;
      return (a['tenNhanVien'] ?? '').toString().compareTo((b['tenNhanVien'] ?? '').toString());
    });
  }
  Future<Map<String, String>> _loadBankAccounts() async {
    try {
      final dbHelper = DBHelper();
      final staffbioList = await dbHelper.getAllStaffbio();
      final Map<String, String> bankAccountMap = {};
      for (var staff in staffbioList) {
        if (staff['MaNV'] != null && staff['So_tai_khoan'] != null) {
          bankAccountMap[staff['MaNV'].toString()] = staff['So_tai_khoan'].toString();
        }
      }
      return bankAccountMap;
    } catch (e) {
      print('Error loading bank accounts: $e');
      return {};
    }
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
  String _getLoaiCong(String userId) {
    if (userId.isEmpty) return 'Vp';
    final matchingPolicies = widget.policyData.where((policy) => policy['userId']?.toString() == userId).toList();
    if (matchingPolicies.isEmpty) return 'Vp';
    matchingPolicies.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['ngay']?.toString() ?? '');
        final dateB = DateTime.parse(b['ngay']?.toString() ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });
    final loaiCong = matchingPolicies.first['loaiCong']?.toString() ?? 'Vp';
    final validTypes = ['Gs', 'Vp', 'Cn', 'Khac'];
    if (validTypes.contains(loaiCong)) {
      return loaiCong;
    }
    return 'Vp';
  }
  double _getSoCongChuan(String loaiCong) {
    try {
      final selectedDate = DateTime.parse(widget.selectedPeriod);
      final matchingStandards = widget.standardData.where((standard) {
        final chiNhanh = standard['chiNhanh']?.toString().toUpperCase() ?? '';
        return chiNhanh == 'HANOI';
      }).toList();
      if (matchingStandards.isEmpty) return 30.0;
      matchingStandards.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['giaiDoan']?.toString() ?? '');
          final dateB = DateTime.parse(b['giaiDoan']?.toString() ?? '');
          final diffA = selectedDate.difference(dateA).abs();
          final diffB = selectedDate.difference(dateB).abs();
          return diffA.compareTo(diffB);
        } catch (e) {
          return 0;
        }
      });
      final closest = matchingStandards.first;
      switch (loaiCong) {
        case 'Gs': return (closest['congGs'] ?? 30.0).toDouble();
        case 'Vp': return (closest['congVp'] ?? 30.0).toDouble();
        case 'Cn': return (closest['congCn'] ?? 30.0).toDouble();
        case 'Khac': return (closest['congKhac'] ?? 30.0).toDouble();
        default: return 30.0;
      }
    } catch (e) {
      return 30.0;
    }
  }
  void _addNewRecord() {
    showDialog(
      context: context,
      builder: (context) => _NewRecordDialog(
        selectedPeriod: widget.selectedPeriod,
        onRecordCreated: (newRecord) {
          setState(() {
            _editableRecords.add(newRecord);
            final newIndex = _editableRecords.length - 1;
            _modifiedIndices.add(newIndex);
            _hasChanges = true;
            _editableRecords.sort((a, b) {
              final deptCompare = (a['phanNhom'] ?? '').toString().compareTo((b['phanNhom'] ?? '').toString());
              if (deptCompare != 0) return deptCompare;
              return (a['tenNhanVien'] ?? '').toString().compareTo((b['tenNhanVien'] ?? '').toString());
            });
            _initializeDepartments();
            _applyFilters();
          });
        },
        getLoaiCong: _getLoaiCong,
        getSoCongChuan: _getSoCongChuan,
        getBankAccount: (maNV) async {
          final map = await _loadBankAccounts();
          return map[maNV] ?? '';
        },
      ),
    );
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

    var excelFile = excel_pkg.Excel.createExcel();
    excel_pkg.Sheet sheetObject = excelFile['Bảng lương'];
    
    final headers = ['STT', 'Phòng ban', 'Mã NV', 'Tên NV', 'Số TK', 'Loại công', 'Công chuẩn', 'Công lễ', 'Tổng công (Gốc)', 'Tổng công (Sửa)', 'Đi muộn (Gốc)', 'Đi muộn (Sửa)', 'Trừ muộn (Gốc)', 'Trừ muộn (Sửa)', 'Tăng ca (Gốc)', 'Tăng ca (Sửa)'];
    
    for (var i = 0; i < headers.length; i++) {
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
    }
    
    for (var i = 0; i < _editableRecords.length; i++) {
      final record = _editableRecords[i];
      final rowIndex = i + 1;
      
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = i + 1;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = record['phanNhom']?.toString() ?? '';
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = record['maNhanVien']?.toString() ?? '';
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = record['tenNhanVien']?.toString() ?? '';
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = record['soTaiKhoan']?.toString() ?? '';
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = record['loaiCong']?.toString() ?? '';
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = double.tryParse(record['soCongChuan']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = double.tryParse(record['soCongLe']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = double.tryParse(record['tongCongGoc']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = double.tryParse(record['tongCongSua']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = int.tryParse(record['phutDiMuonGoc']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value = int.tryParse(record['phutDiMuonSua']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).value = int.tryParse(record['truDiMuonGoc']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex)).value = int.tryParse(record['truDiMuonSua']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: rowIndex)).value = double.tryParse(record['tongTangCaGoc']?.toString() ?? '0') ?? 0;
      sheetObject.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: rowIndex)).value = double.tryParse(record['tongTangCaSua']?.toString() ?? '0') ?? 0;
    }
    
    var fileBytes = excelFile.encode();
    if (fileBytes != null) {
      final directory = await getTemporaryDirectory();
      final fileName = 'BangLuong_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
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
    final processedRecords = modifiedRecords.map((record) {
      final processed = Map<String, dynamic>.from(record);
      ['soCongChuan', 'soCongLe', 'tongCongSua', 'tongTangCaSua'].forEach((field) {
        if (processed[field] is String) {
          var value = (processed[field] as String).replaceAll(',', '.');
          var parsed = double.tryParse(value);
          if (parsed != null) {
            processed[field] = parsed;
          } else {
            processed[field] = 0.0;
          }
        }
      });
      if (processed['soCongChuan'] is num) {
        var val = (processed['soCongChuan'] as num).toDouble();
        if (val < 20) val = 20;
        if (val > 45) val = 45;
        processed['soCongChuan'] = val;
      }
      processed.remove('isModified');
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
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(requestBody));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      setState(() {_isLoading = false;});
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Chỉnh sửa lương - ${DateFormat('MM/yyyy').format(DateTime.parse(widget.selectedPeriod))}'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(icon: const Icon(Icons.add_circle, color: Colors.white), label: const Text('Thêm', style: TextStyle(color: Colors.white)), onPressed: _addNewRecord),
          if (_hasChanges) TextButton.icon(icon: const Icon(Icons.save, color: Colors.white), label: const Text('Lưu', style: TextStyle(color: Colors.white)), onPressed: _submitChanges),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildSpreadsheet(),
    );
  }
  Widget _buildSpreadsheet() {
    final columnWidths = [60.0, 120.0, 100.0, 150.0, 120.0, 100.0, 110.0, 90.0, 130.0, 130.0, 120.0, 120.0, 120.0, 120.0, 120.0, 120.0, 100.0];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Text('Chỉnh sửa ${_filteredRecords.length} bản ghi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[600])),
                  const Spacer(),
                  if (_hasChanges) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)), child: Text('${_modifiedIndices.length} thay đổi', style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 12))),
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
          color: Colors.blue[50],
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
                  _buildHeaderCell('Số TK', columnWidths[4]),
                  _buildHeaderCell('Loại công', columnWidths[5]),
                  _buildHeaderCell('Công chuẩn', columnWidths[6]),
                  _buildHeaderCell('Công lễ', columnWidths[7]),
                  _buildHeaderCell('Tổng công (Gốc)', columnWidths[8]),
                  _buildHeaderCell('Tổng công (Sửa)', columnWidths[9]),
                  _buildHeaderCell('Đi muộn (Gốc)', columnWidths[10]),
                  _buildHeaderCell('Đi muộn (Sửa)', columnWidths[11]),
                  _buildHeaderCell('Trừ muộn (Gốc)', columnWidths[12]),
                  _buildHeaderCell('Trừ muộn (Sửa)', columnWidths[13]),
                  _buildHeaderCell('Tăng ca (Gốc)', columnWidths[14]),
                  _buildHeaderCell('Tăng ca (Sửa)', columnWidths[15]),
                  _buildHeaderCell('Hành động', columnWidths[16]),
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
                          _buildDataCell(Text(record['soTaiKhoan']?.toString() ?? ''), columnWidths[4]),
                          _buildDataCell(_buildLoaiCongDropdown(actualIndex, record), columnWidths[5]),
                          _buildDataCell(_buildEditableCell(actualIndex, 'soCongChuan', record['soCongChuan']), columnWidths[6]),
                          _buildDataCell(_buildEditableCell(actualIndex, 'soCongLe', record['soCongLe']), columnWidths[7]),
                          _buildDataCell(Text(record['tongCongGoc']?.toString() ?? '0'), columnWidths[8]),
                          _buildDataCell(_buildEditableCell(actualIndex, 'tongCongSua', record['tongCongSua']), columnWidths[9]),
                          _buildDataCell(Text(record['phutDiMuonGoc']?.toString() ?? '0'), columnWidths[10]),
                          _buildDataCell(_buildEditableCell(actualIndex, 'phutDiMuonSua', record['phutDiMuonSua'], isInt: true), columnWidths[11]),
                          _buildDataCell(Text(record['truDiMuonGoc']?.toString() ?? '0'), columnWidths[12]),
                          _buildDataCell(_buildEditableCell(actualIndex, 'truDiMuonSua', record['truDiMuonSua'], isInt: true), columnWidths[13]),
                          _buildDataCell(Text(record['tongTangCaGoc']?.toString() ?? '0'), columnWidths[14]),
                          _buildDataCell(_buildEditableCell(actualIndex, 'tongTangCaSua', record['tongTangCaSua']), columnWidths[15]),
                          _buildDataCell(IconButton(icon: Icon(Icons.delete, color: Colors.red[600], size: 20), onPressed: () => _deleteRecord(actualIndex)), columnWidths[16]),
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
  Widget _buildLoaiCongDropdown(int index, Map<String, dynamic> record) {
    return DropdownButton<String>(
      value: record['loaiCong']?.toString() ?? 'Vp',
      items: ['Gs', 'Vp', 'Cn', 'Khac'].map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
      onChanged: (value) {
        setState(() {
          _editableRecords[index]['loaiCong'] = value;
          _editableRecords[index]['soCongChuan'] = _getSoCongChuan(value!);
          _modifiedIndices.add(index);
          _hasChanges = true;
        });
      },
    );
  }
  Widget _buildEditableCell(int index, String field, dynamic value, {bool isInt = false}) {
    final key = '$index-$field';
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: value?.toString() ?? (isInt ? '0' : '0'));
    }
    final controller = _controllers[key]!;
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        keyboardType: isInt ? TextInputType.number : TextInputType.numberWithOptions(decimal: true),
        inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : [FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d*'))],
        decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
        onChanged: (newValue) {
          if (isInt) {
            _editableRecords[index][field] = int.tryParse(newValue) ?? 0;
          } else {
            _editableRecords[index][field] = newValue.replaceAll(',', '.');
          }
          _modifiedIndices.add(index);
          setState(() {
            _hasChanges = true;
          });
        },
      ),
    );
  }
  void _deleteRecord(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa bản ghi của ${_editableRecords[index]['tenNhanVien']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _modifiedIndices.add(index);
                _editableRecords.removeAt(index);
                _hasChanges = true;
                _initializeDepartments();
                _applyFilters();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
class _NewRecordDialog extends StatefulWidget {
  final String selectedPeriod;
  final Function(Map<String, dynamic>) onRecordCreated;
  final String Function(String) getLoaiCong;
  final double Function(String) getSoCongChuan;
  final Future<String> Function(String) getBankAccount;
  const _NewRecordDialog({required this.selectedPeriod, required this.onRecordCreated, required this.getLoaiCong, required this.getSoCongChuan, required this.getBankAccount,});
  @override
  _NewRecordDialogState createState() => _NewRecordDialogState();
}
class _NewRecordDialogState extends State<_NewRecordDialog> {
  final _userIdController = TextEditingController();
  final _phanNhomController = TextEditingController();
  final _maNhanVienController = TextEditingController();
  final _tenNhanVienController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm bản ghi mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _userIdController, decoration: InputDecoration(labelText: 'User ID *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _phanNhomController, decoration: InputDecoration(labelText: 'Phòng ban *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _maNhanVienController, decoration: InputDecoration(labelText: 'Mã nhân viên *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _tenNhanVienController, decoration: InputDecoration(labelText: 'Tên nhân viên *', border: OutlineInputBorder())),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () async {
            if (_userIdController.text.isEmpty || _phanNhomController.text.isEmpty || _maNhanVienController.text.isEmpty || _tenNhanVienController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin bắt buộc'), backgroundColor: Colors.red));
              return;
            }
            final loaiCong = widget.getLoaiCong(_userIdController.text);
            final soCongChuan = widget.getSoCongChuan(loaiCong);
            final soTaiKhoan = await widget.getBankAccount(_maNhanVienController.text);
            final newRecord = {
              'uid': Uuid().v4(),
              'giaiDoan': widget.selectedPeriod,
              'userId': _userIdController.text,
              'phanNhom': _phanNhomController.text,
              'maNhanVien': _maNhanVienController.text,
              'tenNhanVien': _tenNhanVienController.text,
              'soTaiKhoan': soTaiKhoan,
              'tongCongGoc': 0.0,
              'tongCongSua': 0.0,
              'phutDiMuonGoc': 0,
              'phutDiMuonSua': 0,
              'truDiMuonGoc': 0,
              'truDiMuonSua': 0,
              'tongTangCaGoc': 0.0,
              'tongTangCaSua': 0.0,
              'loaiCong': loaiCong,
              'soCongChuan': soCongChuan,
              'soCongLe': 0.0,
              'isNew': true,
              'isModified': true,
            };
            widget.onRecordCreated(newRecord);
            Navigator.pop(context);
          },
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}