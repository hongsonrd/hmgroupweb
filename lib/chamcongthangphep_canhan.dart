import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChamCongThangPhepScreen extends StatefulWidget {
  final String username;
  
  const ChamCongThangPhepScreen({
    Key? key,
    required this.username,
  }) : super(key: key);
  
  @override
  _ChamCongThangPhepScreenState createState() => _ChamCongThangPhepScreenState();
}

class _ChamCongThangPhepScreenState extends State<ChamCongThangPhepScreen> {
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _otherCaseData = [];
  List<Map<String, dynamic>> _phepChuanData = [];
  Map<int, double> _monthlyLeaveData = {};
  Map<int, double> _actualLeaveData = {};
  double _allowedTotal = 0.0;
  Set<int> _availableYears = {};
  bool _hasData = false;
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _checkAndAutoSync();
  }

  Future<void> _checkAndAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncDate = prefs.getString('last_sync_date_${widget.username}');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastSyncDate != today) {
      await _startSyncProcess();
      await prefs.setString('last_sync_date_${widget.username}', today);
    } else {
      final hasData = prefs.getBool('has_data_${widget.username}') ?? false;
      if (hasData) {
        await _startSyncProcess();
      }
    }
  }

  Future<void> _showSyncConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đồng bộ'),
        content: const Text('Bạn có muốn tải dữ liệu phép?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          // TextButton(
          //   onPressed: () => Navigator.of(context).pop(true),
          //   child: const Text('Đồng bộ'),
          // ),
        ],
      ),
    );
    if (confirm == true) {
      _startSyncProcess();
    }
  }

  Future<void> _startSyncProcess() async {
    setState(() {
      _isLoading = true;
    });
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Đang đồng bộ dữ liệu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải dữ liệu phép...'),
            ],
          ),
        ),
      );
    }
    
    try {
      await Future.wait([
        _loadOtherCaseData(),
        _loadPhepChuanData(),
      ]);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _hasData = true;
        _isLoading = false;
        _calculateLeaveData();
        _processPhepChuanData();
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_data_${widget.username}', true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đồng bộ dữ liệu thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi đồng bộ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadOtherCaseData() async {
    try {
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongbphep');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _otherCaseData = data.cast<Map<String, dynamic>>()
              .where((record) => record['NguoiDung']?.toString() == widget.username)
              .toList();
        });
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading other case data: $e');
    }
  }

  Future<void> _loadPhepChuanData() async {
    try {
      final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongphepchuan');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _phepChuanData = data.cast<Map<String, dynamic>>()
              .where((record) => record['NguoiDung']?.toString() == widget.username)
              .toList();
        });
      } else {
        throw Exception('Failed to load phep chuan data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading phep chuan data: $e');
    }
  }

  void _processPhepChuanData() {
    _actualLeaveData.clear();
    _allowedTotal = 0.0;
    for (final record in _phepChuanData) {
      final soPhep = (record['SoPhep'] as num?)?.toDouble() ?? 0.0;
      try {
        final thangValue = record['Thang'];
        DateTime? thang;
        if (thangValue != null) {
          thang = DateTime.parse(thangValue.toString());
        }
        if (thang == null) continue;
        if (thang.day == 1) {
          _actualLeaveData[thang.month] = soPhep;
        }
        if (thang.month == 12 && thang.day == 31) {
          _allowedTotal = soPhep;
        }
      } catch (e) {
        continue;
      }
    }
  }

  void _calculateLeaveData() {
    _monthlyLeaveData.clear();
    _availableYears.clear();
    for (final record in _otherCaseData) {
      final truongHop = record['TruongHop']?.toString() ?? '';
      DateTime? ngayBatDau;
      DateTime? ngayKetThuc;
      try {
        if (record['NgayBatDau'] != null) {
          ngayBatDau = DateTime.parse(record['NgayBatDau'].toString());
        }
        if (record['NgayKetThuc'] != null) {
          ngayKetThuc = DateTime.parse(record['NgayKetThuc'].toString());
        }
      } catch (e) {
        continue;
      }
      if (ngayBatDau == null || ngayKetThuc == null) continue;
      final daysDifference = ngayKetThuc.difference(ngayBatDau).inDays + 1;
      double phepValue = 0;
      if (truongHop.toLowerCase().contains('phép')) {
        try {
          final soNgayPhep = record['SoNgayPhep'];
          if (soNgayPhep != null) {
            phepValue = (soNgayPhep is num) ? soNgayPhep.toDouble() : double.tryParse(soNgayPhep.toString()) ?? 0;
          } else {
            phepValue = daysDifference.toDouble();
          }
        } catch (e) {
          phepValue = daysDifference.toDouble();
        }
      }
      if (phepValue > 0) {
        _availableYears.add(ngayBatDau.year);
        DateTime currentDate = DateTime(ngayBatDau.year, ngayBatDau.month, 1);
        final endDate = DateTime(ngayKetThuc.year, ngayKetThuc.month, 1);
        while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
          final month = currentDate.month;
          final monthStart = DateTime(currentDate.year, currentDate.month, 1);
          final monthEnd = DateTime(currentDate.year, currentDate.month + 1, 0);
          final effectiveStart = ngayBatDau.isAfter(monthStart) ? ngayBatDau : monthStart;
          final effectiveEnd = ngayKetThuc.isBefore(monthEnd) ? ngayKetThuc : monthEnd;
          if (effectiveStart.isBefore(effectiveEnd) || effectiveStart.isAtSameMomentAs(effectiveEnd)) {
            final daysInMonth = effectiveEnd.difference(effectiveStart).inDays + 1;
            final monthPhepValue = (phepValue / daysDifference) * daysInMonth;
            _monthlyLeaveData[month] = (_monthlyLeaveData[month] ?? 0) + monthPhepValue;
          }
          currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
        }
      }
    }
  }

  double _calculateTotal(Map<int, double> monthlyData) {
    return monthlyData.values.fold(0.0, (sum, value) => sum + value);
  }

  Widget _buildLeaveTable() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tài khoản: ${widget.username}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (_allowedTotal > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tổng phép năm: ${_allowedTotal.toStringAsFixed(1)} ngày',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tổng phép còn lại: ${(_allowedTotal - _calculateTotal(_actualLeaveData)).toStringAsFixed(1)} ngày',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                    Text(
                    'Mọi thắc mắc vui lòng liên hệ bộ phận Nhân sự công ty\n ⚠️Số Đăng ký là số phép đã duyệt qua app\n ⚠️Số Thực tế là số phép BP Nhân sự thực tế tính dùng của tháng đó. Số này được chốt khi đến tháng kế tiếp\n ⚠️Phép còn lại là bằng tổng phép được có của năm trừ số phép Nhân sự đã tính',
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(12, (i) {
            final month = i + 1;
            final registered = _monthlyLeaveData[month] ?? 0.0;
            final actual = _actualLeaveData[month] ?? 0.0;
            final hasData = registered > 0 || actual > 0;
            
            if (!hasData) return const SizedBox.shrink();
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tháng $month',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDataRow('Đăng ký', registered, Colors.blue),
                    const SizedBox(height: 8),
                    _buildDataRow('Thực tế', actual, Colors.green),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Card(
            margin: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow('Tổng đăng ký', _calculateTotal(_monthlyLeaveData), Colors.blue),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Tổng thực tế', _calculateTotal(_actualLeaveData), Colors.green),
                  if (_allowedTotal > 0) ...[
                    const Divider(height: 24),
                    _buildSummaryRow('Phép được phép', _allowedTotal, Colors.orange),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value > 0 ? '${value.toStringAsFixed(1)} ngày' : '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        Text(
          value > 0 ? '${value.toStringAsFixed(1)} ngày' : '-',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _exportToExcel() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn hành động'),
        content: const Text('Bạn muốn chia sẻ file hay lưu vào thư mục ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('share'),
            child: const Text('Chia sẻ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Lưu vào App'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Sheet1'];
      
      final headers = ['Thông tin', 'Giá trị'];
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
      }

      int rowIndex = 1;
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Username';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = widget.username;
      rowIndex++;

      if (_allowedTotal > 0) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Tổng phép năm';
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = _allowedTotal.toStringAsFixed(1);
        rowIndex++;
      }

      rowIndex++;
      for (int month = 1; month <= 12; month++) {
        final registered = _monthlyLeaveData[month] ?? 0.0;
        final actual = _actualLeaveData[month] ?? 0.0;
        
        if (registered > 0 || actual > 0) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Tháng $month';
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = '';
          rowIndex++;

          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Đăng ký';
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = registered > 0 ? registered.toStringAsFixed(1) : '-';
          rowIndex++;

          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Thực tế';
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = actual > 0 ? actual.toStringAsFixed(1) : '-';
          rowIndex++;
        }
      }

      rowIndex++;
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Tổng đăng ký';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = _calculateTotal(_monthlyLeaveData).toStringAsFixed(1);
      rowIndex++;

      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Tổng thực tế';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = _calculateTotal(_actualLeaveData).toStringAsFixed(1);

      final fileBytes = excel.encode();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'ChamCongPhep_${widget.username}_$dateStr.xlsx';

      if (kIsWeb) {
        await _handleWebDownload(fileBytes, fileName);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final tempFilePath = '${directory.path}/$fileName';
        final file = File(tempFilePath);
        await file.writeAsBytes(fileBytes);

        if (choice == 'share') {
          await _handleShareFile(tempFilePath, fileName);
        } else if (choice == 'save') {
          await _handleSaveToAppFolder(tempFilePath, fileName);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xuất file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _handleWebDownload(List<int> fileBytes, String fileName) async {
    try {
      final base64String = base64Encode(fileBytes);
      final dataUrl = 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64String';
      
      if (await canLaunch(dataUrl)) {
        await launch(dataUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File đã được tải xuống'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Không thể mở file');
      }
    } catch (e) {
      throw Exception('Lỗi tải file trên web: $e');
    }
  }

  Future<void> _handleShareFile(String filePath, String fileName) async {
    try {
      await Share.shareXFiles([XFile(filePath)], text: 'Bảng chấm công phép');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File đã được chia sẻ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chia sẻ file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSaveToAppFolder(String filePath, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File đã được lưu: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm Công Phép Của Tôi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_hasData) ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          isExpanded: true,
                          items: (_availableYears.toList()..sort((a, b) => b.compareTo(a)))
                              .map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text('Năm: $year', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value!;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showSyncConfirmation,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text('Đồng bộ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isExporting ? null : _exportToExcel,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isExporting)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                )
                              else
                                const Icon(Icons.file_download, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              const Text('Xuất Excel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _showSyncConfirmation,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Đồng bộ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasData
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _buildLeaveTable(),
                        )
                      : Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Nhấn "Đồng bộ" để tải dữ liệu', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 16),
                                  const Icon(Icons.sync, size: 48, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}