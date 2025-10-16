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
  List<Map<String, dynamic>> _otherCaseData = [];
  Map<String, Map<String, Map<int, double>>> _userLeaveData = {};
  Map<String, Map<String, dynamic>> _userInfoMap = {};
  Set<int> _availableYears = {};
  List<String> _filteredUsers = [];
  bool _hasData = false;
  bool _isLoading = false;
  bool _isExporting = false;

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
      await _loadOtherCaseData();
      
      Navigator.of(context).pop();
      
      setState(() {
        _hasData = true;
        _isLoading = false;
        _calculateLeaveData();
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
      print('Error loading leave data: $e');
      rethrow;
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
      if (truongHop.contains('Nghỉ phép 1/2 ngày')) {
        phepValue = daysDifference * 0.5;
      } else if (truongHop.contains('Nghỉ phép')) {
        phepValue = daysDifference * 1.0;
      } else {
        continue;
      }
      
      final year = ngayBatDau.year;
      final month = ngayBatDau.month;
      
      _availableYears.add(year);
      
      if (!_userLeaveData.containsKey(nguoiDung)) {
        _userLeaveData[nguoiDung] = {};
      }
      if (!_userLeaveData[nguoiDung]!.containsKey(year.toString())) {
        _userLeaveData[nguoiDung]![year.toString()] = {};
      }
      
      _userLeaveData[nguoiDung]![year.toString()]![month] = 
        (_userLeaveData[nguoiDung]![year.toString()]![month] ?? 0) + phepValue;
    }
  }

  Future<void> _exportToExcel() async {
  if (_userLeaveData.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không có dữ liệu để xuất')),
    );
    return;
  }

  setState(() {
    _isExporting = true;
  });

  try {
    final excel = excel_pkg.Excel.createExcel();
    final sortedYears = _availableYears.toList()..sort();

    // Remove default sheet if it exists
    if (excel.sheets.keys.contains('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Create sheets for each year
    for (int yearIndex = 0; yearIndex < sortedYears.length; yearIndex++) {
      final year = sortedYears[yearIndex];
      final sheetName = 'Nam $year';
      
      // Create new sheet
      excel_pkg.Sheet sheet = excel[sheetName];

      // Header row with styling
      final headers = [
        'Người dùng',
        'Tên',
        'User ID',
        'BP',
        'Tổng năm',
        ...List.generate(12, (i) => 'T${i + 1}'),
      ];
      
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
        
        // Apply header styling similar to first file
        cell.cellStyle = excel_pkg.CellStyle(
          bold: true,
          backgroundColorHex: '#4472C4',
          fontColorHex: '#FFFFFF',
        );
      }

      // Data rows
      var rowIndex = 1;
      for (final username in _filteredUsers) {
        final yearData = _userLeaveData[username]?[year.toString()] ?? {};
        final userInfo = _userInfoMap[username];
        
        double yearlyTotal = 0;
        yearData.forEach((month, value) {
          yearlyTotal += value;
        });

        if (yearlyTotal > 0) {
          final rowData = [
            username,
            userInfo?['Name']?.toString() ?? 'N/A',
            userInfo?['UserID']?.toString() ?? 'N/A',
            userInfo?['BP']?.toString() ?? 'N/A',
            yearlyTotal.toStringAsFixed(1),
            ...List.generate(12, (i) {
              final month = i + 1;
              final value = yearData[month] ?? 0;
              return value > 0 ? value.toStringAsFixed(1) : '-';
            }),
          ];

          for (var i = 0; i < rowData.length; i++) {
            var cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
            cell.value = rowData[i];
          }
          
          rowIndex++;
        }
      }
    }

    // Generate filename with timestamp
    final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String fileName = 'TongHopPhep_$timestamp.xlsx';
    
    // Save and handle file using the pattern from first file
    await _saveAndHandleFile(excel, fileName, _filteredUsers.length);

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

Future<void> _saveAndHandleFile(excel_pkg.Excel excelFile, String fileName, int recordCount) async {
  try {
    final fileBytes = excelFile.save();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      // Mobile/Web: Use share_plus
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Xuất tổng hợp phép - $recordCount nhân viên',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xuất file thành công'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Desktop: Save to app folder and show dialog
      final directory = await getApplicationDocumentsDirectory();
      final appFolder = Directory('${directory.path}/ProjectCongNhan');
      
      // Create app folder if it doesn't exist
      if (!await appFolder.exists()) {
        await appFolder.create(recursive: true);
      }
      
      final filePath = '${appFolder.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      // Show success dialog with options
      if (mounted) {
        _showDesktopSaveDialog(filePath, appFolder.path, recordCount, fileName);
      }
    }
  } catch (e) {
    print('Error saving Excel file: $e');
    rethrow;
  }
}

void _showDesktopSaveDialog(String filePath, String folderPath, int recordCount, String fileName) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Xuất Excel thành công'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đã xuất thành công tổng hợp phép'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 16, color: Colors.green[700]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Tên file: $fileName',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.green[700]),
                      SizedBox(width: 4),
                      Text(
                        'Số nhân viên: $recordCount',
                        style: TextStyle(
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text('File đã được lưu tại:'),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                filePath,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
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
              try {
                final uri = Uri.file(folderPath);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  // Fallback: try to open with system default
                  if (Platform.isWindows) {
                    await Process.run('explorer', [folderPath]);
                  } else if (Platform.isMacOS) {
                    await Process.run('open', [folderPath]);
                  } else if (Platform.isLinux) {
                    await Process.run('xdg-open', [folderPath]);
                  }
                }
              } catch (e) {
                print('Error opening folder: $e');
              }
            },
            icon: Icon(Icons.folder_open),
            label: Text('Mở thư mục'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final uri = Uri.file(filePath);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  // Fallback: try to open with system default
                  if (Platform.isWindows) {
                    await Process.run('start', ['', filePath], runInShell: true);
                  } else if (Platform.isMacOS) {
                    await Process.run('open', [filePath]);
                  } else if (Platform.isLinux) {
                    await Process.run('xdg-open', [filePath]);
                  }
                }
              } catch (e) {
                print('Error opening file: $e');
              }
            },
            icon: Icon(Icons.file_open),
            label: Text('Mở file'),
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

  Widget _buildLeaveTable() {
    if (_filteredUsers.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    final sortedYears = _availableYears.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: sortedYears.map((year) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Năm $year',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                DataTable(
                  columnSpacing: 15,
                  headingRowHeight: 56,
                  dataRowHeight: 48,
                  headingRowColor: MaterialStateProperty.all(
                    Colors.blue.shade100,
                  ),
                  border: TableBorder.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                  columns: [
                    const DataColumn(
                      label: Text(
                        'Username',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Tên',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'User ID',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'BP',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Tổng năm',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    ...List.generate(12, (index) {
                      return DataColumn(
                        label: Text(
                          'T${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      );
                    }),
                  ],
                  rows: _filteredUsers.map((username) {
                    final yearData = _userLeaveData[username]?[year.toString()] ?? {};
                    final userInfo = _userInfoMap[username];
                    
                    double yearlyTotal = 0;
                    yearData.forEach((month, value) {
                      yearlyTotal += value;
                    });
                    
                    if (yearlyTotal == 0) return null;
                    
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            userInfo?['Name']?.toString() ?? 'N/A',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            userInfo?['UserID']?.toString() ?? 'N/A',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            userInfo?['BP']?.toString() ?? 'N/A',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            yearlyTotal.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        ...List.generate(12, (index) {
                          final month = index + 1;
                          final value = yearData[month] ?? 0;
                          return DataCell(
                            Text(
                              value > 0 ? value.toStringAsFixed(1) : '-',
                              style: TextStyle(
                                color: value > 0 ? Colors.black87 : Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }).whereType<DataRow>().toList(),
                ),
                const SizedBox(height: 32),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tổng hợp phép'),
        backgroundColor: const Color.fromARGB(255, 190, 226, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search bar
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
              
              // Filter and action buttons
              Row(
                children: [
                  // BP Filter
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
                              child: Text('BP: $bp', style: const TextStyle(fontSize: 13)),
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
                  
                  // Sync button (dark pill)
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
                  
                  // Export button
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
                ],
              ),
              const SizedBox(height: 16),
            ] else
              // Sync button only when no data
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
            
            // Data display area
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
                                  const Icon(
                                    Icons.sync,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
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