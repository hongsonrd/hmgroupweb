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

class ChamCongThangPhepScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String approverUsername;
  final List<Map<String, dynamic>> accountData;
  
  const ChamCongThangPhepScreen({
    Key? key,
    required this.username,
    this.userRole = '',
    this.approverUsername = '',
    this.accountData = const [],
  }) : super(key: key);
  
  @override
  _ChamCongThangPhepScreenState createState() => _ChamCongThangPhepScreenState();
}

class _ChamCongThangPhepScreenState extends State<ChamCongThangPhepScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedBP = 'Tất cả';
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _otherCaseData = [];
  List<Map<String, dynamic>> _phepChuanData = [];
  Map<String, Map<String, Map<int, double>>> _userLeaveData = {};
  Map<String, Map<int, double>> _userActualLeaveData = {};
  Map<String, double> _userAllowedTotal = {};
  Map<String, Map<int, Map<String, double>>> _userAdjustments = {};
  Map<String, Map<String, dynamic>> _userInfoMap = {};
  Set<int> _availableYears = {};
  List<String> _filteredUsers = [];
  bool _hasData = false;
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _buildUserInfoMap();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _buildUserInfoMap() {
    for (final account in widget.accountData) {
      final username = account['Username']?.toString() ?? '';
      if (username.isNotEmpty) {
        _userInfoMap[username] = {
          'Name': account['Name']?.toString() ?? 'N/A',
          'UserID': account['UserID']?.toString() ?? 'N/A',
          'BP': account['BP']?.toString() ?? 'N/A',
        };
      }
    }
  }

  List<String> _getBPOptions() {
    final bpSet = <String>{'Tất cả'};
    for (final user in _userLeaveData.keys) {
      final bp = _userInfoMap[user]?['BP'] ?? '';
      if (bp.isNotEmpty && bp != 'N/A') {
        bpSet.add(bp);
      }
    }
    return bpSet.toList()..sort();
  }

  void _filterUsers() {
    final searchQuery = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _userLeaveData.keys.where((username) {
        final userInfo = _userInfoMap[username];
        final name = userInfo?['Name']?.toString().toLowerCase() ?? '';
        final userID = userInfo?['UserID']?.toString().toLowerCase() ?? '';
        final bp = userInfo?['BP']?.toString() ?? '';
        final user = username.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            user.contains(searchQuery) ||
            name.contains(searchQuery) ||
            userID.contains(searchQuery);
        final matchesBP = _selectedBP == 'Tất cả' || bp == _selectedBP;
        return matchesSearch && matchesBP;
      }).toList()..sort();
    });
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đồng bộ'),
          ),
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
    try {
      await Future.wait([
        _loadOtherCaseData(),
        _loadPhepChuanData(),
      ]);
      Navigator.of(context).pop();
      setState(() {
        _hasData = true;
        _isLoading = false;
        _calculateLeaveData();
        _processPhepChuanData();
        _filterUsers();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đồng bộ dữ liệu thành công'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi đồng bộ: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          _otherCaseData = data.cast<Map<String, dynamic>>();
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
          _phepChuanData = data.cast<Map<String, dynamic>>();
        });
      } else {
        throw Exception('Failed to load phep chuan data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading phep chuan data: $e');
    }
  }

  void _processPhepChuanData() {
    _userActualLeaveData.clear();
    _userAllowedTotal.clear();
    for (final record in _phepChuanData) {
      final nguoiDung = record['NguoiDung']?.toString() ?? '';
      final soPhep = (record['SoPhep'] as num?)?.toDouble() ?? 0.0;
      if (nguoiDung.isEmpty) continue;
      try {
        final thangValue = record['Thang'];
        DateTime? thang;
        if (thangValue != null) {
          thang = DateTime.parse(thangValue.toString());
        }
        if (thang == null) continue;
        if (thang.day == 1) {
          if (!_userActualLeaveData.containsKey(nguoiDung)) {
            _userActualLeaveData[nguoiDung] = {};
          }
          _userActualLeaveData[nguoiDung]![thang.month] = soPhep;
        }
        if (thang.month == 12 && thang.day == 31) {
          _userAllowedTotal[nguoiDung] = soPhep;
        }
      } catch (e) {
        print('Error processing phep chuan record: $e');
        continue;
      }
    }
  }

  void _calculateLeaveData() {
    _userLeaveData.clear();
    _availableYears.clear();
    for (final record in _otherCaseData) {
      final nguoiDung = record['NguoiDung']?.toString() ?? 'Unknown';
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
        if (!_userLeaveData.containsKey(nguoiDung)) {
          _userLeaveData[nguoiDung] = {};
        }
        final year = ngayBatDau.year;
        _availableYears.add(year);
        if (!_userLeaveData[nguoiDung]!.containsKey('Phép')) {
          _userLeaveData[nguoiDung]!['Phép'] = {};
        }
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
            _userLeaveData[nguoiDung]!['Phép']![month] = 
              (_userLeaveData[nguoiDung]!['Phép']![month] ?? 0) + monthPhepValue;
          }
          currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
        }
      }
    }
  }

  double _calculateTotal(Map<int, double> monthlyData) {
    return monthlyData.values.fold(0.0, (sum, value) => sum + value);
  }

  double _getAdjustmentValue(String username, int month) {
    return _userAdjustments[username]?[month]?['adjustment'] ?? 0.0;
  }

  double _getPreviousMonthValue(String username, int month) {
    if (month <= 1) return 0.0;
    final previousMonth = month - 1;
    if (_userActualLeaveData[username]?.containsKey(previousMonth) ?? false) {
      return _userActualLeaveData[username]![previousMonth]!;
    }
    return _userLeaveData[username]?['Phép']?[previousMonth] ?? 0.0;
  }

  Map<String, Map<int, bool>> _changedAdjustments = {};

  void _updateAdjustmentValue(String username, int month, double value) {
    setState(() {
      if (!_userAdjustments.containsKey(username)) {
        _userAdjustments[username] = {};
      }
      if (!_userAdjustments[username]!.containsKey(month)) {
        _userAdjustments[username]![month] = {};
      }
      _userAdjustments[username]![month]!['adjustment'] = value;
      
      // Mark as changed
      if (!_changedAdjustments.containsKey(username)) {
        _changedAdjustments[username] = {};
      }
      _changedAdjustments[username]![month] = true;
    });
  }

  bool _isAdjustmentChanged(String username, int month) {
    return _changedAdjustments[username]?[month] ?? false;
  }

  Future<void> _submitData() async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      int successCount = 0;
      int errorCount = 0;
      final currentDate = DateTime.now();
      final currentMonth = currentDate.month;
      final currentDay = currentDate.day;
      
      for (final username in _userLeaveData.keys) {
        final userInfo = _userInfoMap[username];
        final uid = userInfo?['UserID'] ?? 'auto';
        
        // Only process changed adjustments
        final userChanges = _changedAdjustments[username] ?? {};
        
        for (final month in userChanges.keys) {
          if (userChanges[month] == true) {
            // Double-check month is editable (same logic as UI)
            final canEdit = month < currentMonth || (month == currentMonth && currentDay > 15);
            if (!canEdit) {
              print('Skipping month $month for $username - not editable');
              continue;
            }
            
            final adjustmentValue = _getAdjustmentValue(username, month);
            
            try {
              final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongphepchuangui/$uid/$username/$month/$adjustmentValue');
              final response = await http.post(url, headers: {'Content-Type': 'application/json'});
              
              if (response.statusCode == 200) {
                successCount++;
                print('Successfully submitted $username month $month: $adjustmentValue');
              } else {
                errorCount++;
                print('Failed to submit $username month $month: ${response.statusCode} - ${response.body}');
              }
            } catch (e) {
              errorCount++;
              print('Error submitting $username month $month: $e');
            }
          }
        }
      }
      
      setState(() {
        _isSubmitting = false;
        // Clear changed flags after successful submission
        if (errorCount == 0) {
          _changedAdjustments.clear();
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hoàn thành: $successCount thành công, $errorCount lỗi'),
          backgroundColor: errorCount == 0 ? Colors.green : Colors.orange,
        ),
      );
      
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi dữ liệu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _calculateAdjustmentTotal(String username) {
    double total = 0.0;
    for (int month = 1; month <= 12; month++) {
      total += _getAdjustmentValue(username, month);
    }
    return total;
  }

  Widget _buildLeaveTable() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final username = _filteredUsers[index];
        final userData = _userLeaveData[username] ?? {};
        final userInfo = _userInfoMap[username];
        final allowedTotal = _userAllowedTotal[username] ?? 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${userInfo?['Name'] ?? 'N/A'} (ID: ${userInfo?['UserID'] ?? 'N/A'}) | BP: ${userInfo?['BP'] ?? 'N/A'} | $username',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildUserLeaveRow('Đăng ký', userData['Phép'] ?? {}, allowedTotal),
                _buildUserLeaveRow('Thực tế', _userActualLeaveData[username] ?? {}, allowedTotal),
                _buildAdjustmentRow(username, allowedTotal),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserLeaveRow(String type, Map<int, double> monthlyData, double allowedTotal) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              type,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: type == 'Đăng ký' ? Colors.blue : Colors.green,
              ),
            ),
          ),
          ...List.generate(12, (i) {
            final month = i + 1;
            final value = monthlyData[month] ?? 0.0;
            final hasValue = value > 0.0;
            
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: hasValue ? (type == 'Đăng ký' ? Colors.blue.shade50 : Colors.green.shade50) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasValue ? value.toStringAsFixed(1) : '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: hasValue ? (type == 'Đăng ký' ? Colors.blue.shade800 : Colors.green.shade800) : Colors.grey,
                  ),
                ),
              ),
            );
          }),
          SizedBox(
            width: 60,
            child: Text(
              _calculateTotal(monthlyData) > 0 
                ? '${_calculateTotal(monthlyData).toStringAsFixed(1)}${allowedTotal > 0 ? ' / ${allowedTotal.toStringAsFixed(1)}' : ''}'
                : '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentRow(String username, double allowedTotal) {
    final currentDate = DateTime.now();
    final currentMonth = currentDate.month;
    final currentDay = currentDate.day;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Text(
              'ĐC T.trước',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Colors.orange,
              ),
            ),
          ),
          ...List.generate(12, (i) {
            final month = i + 1;
            final value = _getAdjustmentValue(username, month);
            final hasValue = value != 0.0;
            final isChanged = _isAdjustmentChanged(username, month);
            
            // Can edit if it's previous month OR current month but after 15th day
            final canEdit = month < currentMonth || (month == currentMonth && currentDay > 15);
            
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 28,
                decoration: BoxDecoration(
                  color: isChanged 
                    ? Colors.red.shade100 
                    : canEdit 
                      ? Colors.orange.shade50 
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: isChanged 
                    ? Border.all(color: Colors.red.shade300, width: 1)
                    : null,
                ),
                child: canEdit 
                  ? TextFormField(
                      initialValue: hasValue ? value.toString() : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: isChanged ? Colors.red.shade800 : Colors.black87,
                        fontWeight: isChanged ? FontWeight.bold : FontWeight.normal,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        hintText: '-',
                        hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onChanged: (textValue) {
                        final newValue = double.tryParse(textValue) ?? 0.0;
                        _updateAdjustmentValue(username, month, newValue);
                      },
                    )
                  : Center(
                      child: Text(
                        hasValue ? value.toStringAsFixed(1) : '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: hasValue ? Colors.orange.shade800 : Colors.grey,
                        ),
                      ),
                    ),
              ),
            );
          }),
          SizedBox(
            width: 60,
            child: Text(
              _calculateAdjustmentTotal(username) != 0 
                ? '${_calculateAdjustmentTotal(username).toStringAsFixed(1)}${allowedTotal > 0 ? ' / ${allowedTotal.toStringAsFixed(1)}' : ''}'
                : '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
      
      final headers = ['Username', 'Tên', 'User ID', 'BP', 'Loại', 
        'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12', 'Tổng'];
      
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
      }

      int rowIndex = 1;
      for (final username in _filteredUsers) {
        final userData = _userLeaveData[username] ?? {};
        final userInfo = _userInfoMap[username];
        final allowedTotal = _userAllowedTotal[username] ?? 0.0;

        final registeredValues = [
          username,
          userInfo?['Name'] ?? 'N/A',
          userInfo?['UserID'] ?? 'N/A',
          userInfo?['BP'] ?? 'N/A',
          'Đăng ký',
          ...List.generate(12, (i) {
            final value = userData['Phép']?[i + 1] ?? 0.0;
            return value > 0 ? value.toStringAsFixed(1) : '-';
          }),
          '${_calculateTotal(userData['Phép'] ?? {}).toStringAsFixed(1)}${allowedTotal > 0 ? ' / ${allowedTotal.toStringAsFixed(1)}' : ''}'
        ];

        for (var i = 0; i < registeredValues.length; i++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex)).value = registeredValues[i].toString();
        }
        rowIndex++;

        final actualValues = [
          '', '', '', '', 'Thực tế',
          ...List.generate(12, (i) {
            final value = _userActualLeaveData[username]?[i + 1] ?? 0.0;
            return value > 0 ? value.toStringAsFixed(1) : '-';
          }),
          '${_calculateTotal(_userActualLeaveData[username] ?? {}).toStringAsFixed(1)}${allowedTotal > 0 ? ' / ${allowedTotal.toStringAsFixed(1)}' : ''}'
        ];

        for (var i = 0; i < actualValues.length; i++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex)).value = actualValues[i].toString();
        }
        rowIndex++;

        final adjustmentValues = [
          '', '', '', '', 'ĐC T.trước',
          ...List.generate(12, (i) {
            final value = _getAdjustmentValue(username, i + 1);
            return value.toStringAsFixed(1);
          }),
          '${_calculateAdjustmentTotal(username).toStringAsFixed(1)}${allowedTotal > 0 ? ' / ${allowedTotal.toStringAsFixed(1)}' : ''}'
        ];

        for (var i = 0; i < adjustmentValues.length; i++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex)).value = adjustmentValues[i].toString();
        }
        rowIndex++;
      }

      final fileBytes = excel.encode();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'BangChamCongPhep_$dateStr.xlsx';

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
        title: const Text('Chấm Công Tháng - Phép'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_hasData) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo Username, Tên, hoặc User ID...',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBP,
                          isExpanded: true,
                          items: _getBPOptions().map((bp) {
                            return DropdownMenuItem(
                              value: bp,
                              child: Text(
                                'BP: $bp',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBP = value!;
                              _filterUsers();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        items: (_availableYears.toList()..sort((a, b) => b.compareTo(a)))
                            .map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(
                              'Năm: $year',
                              style: const TextStyle(fontSize: 13),
                            ),
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
                              Text(
                                'Đồng bộ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              else
                                const Icon(Icons.file_download, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'Xuất Excel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isSubmitting ? null : _submitData,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSubmitting)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              else
                                const Icon(Icons.save, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'Lưu ĐC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
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
                            Text(
                              'Đồng bộ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
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
                                  Text(
                                    'Nhấn "Đồng bộ" để tải dữ liệu',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
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