import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'dart:typed_data';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';

class ProjectManagementCongNhan extends StatefulWidget {
  @override
  _ProjectManagementCongNhanState createState() => _ProjectManagementCongNhanState();
}

class _ProjectManagementCongNhanState extends State<ProjectManagementCongNhan> {
  bool _isLoading = false;
  bool _isExporting = false;
  List<TaskHistoryModel> _taskHistoryList = [];
  List<TaskHistoryModel> _filteredTaskHistoryList = [];
  List<String> _projectList = [];
  List<String> _staffList = [];
  String? _selectedProject;
  String? _selectedStaff;
  DateTime? _selectedDate;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');
  Map<String, String> _staffNamesCache = {}; // Cache for staff names

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadStaffNames();
      await _loadProjects();
      await _loadStaffFilter();
      await _loadTaskHistory();
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải dữ liệu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStaffNames() async {
    try {
      final dbHelper = DBHelper();
      final staffbioList = await dbHelper.getAllStaffbio();
      
      final Map<String, String> staffNames = {};
      for (var staff in staffbioList) {
        if (staff['MaNV'] != null && staff['Ho_ten'] != null) {
          staffNames[staff['MaNV'].toString().toLowerCase()] = staff['Ho_ten'].toString();
        }
      }
      
      setState(() {
        _staffNamesCache = staffNames;
      });
    } catch (e) {
      print('Error loading staff names: $e');
    }
  }

  String _getStaffDisplayName(String? nguoiDung) {
    if (nguoiDung == null) return '❓❓❓';
    
    // Convert NguoiDung to uppercase to match MaNV format
    final maNV = nguoiDung.toUpperCase();
    final staffName = _staffNamesCache[nguoiDung.toLowerCase()];
    
    return staffName ?? '❓❓❓';
  }

  Future<void> _loadProjects() async {
    try {
      final dbHelper = DBHelper();
      final taskHistory = await dbHelper.query(DatabaseTables.taskHistoryTable);
      
      // Get unique project names from task history
      final projects = taskHistory
          .map((record) => record['BoPhan'] as String?)
          .where((project) => project != null && project.isNotEmpty)
          .toSet()
          .toList()
          .cast<String>();
      
      projects.sort();
      
      setState(() {
        _projectList = ['Tất cả'] + projects;
        _selectedProject = 'Tất cả';
      });
    } catch (e) {
      print('Error loading projects: $e');
    }
  }

  Future<void> _loadStaffFilter() async {
    try {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      final currentUsername = userCredentials.username.toLowerCase();
      
      final dbHelper = DBHelper();
      final taskHistory = await dbHelper.query(
        DatabaseTables.taskHistoryTable,
        where: 'LOWER(NguoiDung) != ?',
        whereArgs: [currentUsername],
      );
      
      // Get unique staff names from task history
      final staffUsernames = taskHistory
          .map((record) => record['NguoiDung'] as String?)
          .where((staff) => staff != null && staff.isNotEmpty)
          .toSet()
          .toList()
          .cast<String>();
      
      // Convert to display names and sort
      final staffDisplayNames = staffUsernames
          .map((username) => _getStaffDisplayName(username))
          .toSet()
          .toList();
      
      staffDisplayNames.sort();
      
      setState(() {
        _staffList = ['Tất cả'] + staffDisplayNames;
        _selectedStaff = 'Tất cả';
      });
    } catch (e) {
      print('Error loading staff filter: $e');
    }
  }

  String? _getUsernameFromDisplayName(String displayName) {
    if (displayName == 'Tất cả') return null;
    
    // Find the username that matches this display name
    for (var entry in _staffNamesCache.entries) {
      if (entry.value == displayName) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _loadTaskHistory() async {
    try {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      final currentUsername = userCredentials.username.toLowerCase();
      
      final dbHelper = DBHelper();
      final records = await dbHelper.query(
        DatabaseTables.taskHistoryTable,
        where: 'LOWER(NguoiDung) != ?',
        whereArgs: [currentUsername],
      );

      final taskHistory = records.map((record) => TaskHistoryModel.fromMap(record)).toList();
      
      // Sort by date and time (latest first)
      taskHistory.sort((a, b) {
        int dateCompare = b.ngay.compareTo(a.ngay);
        if (dateCompare == 0) {
          return b.gio.compareTo(a.gio);
        }
        return dateCompare;
      });

      setState(() {
        _taskHistoryList = taskHistory;
        _applyFilters();
      });
    } catch (e) {
      print('Error loading task history: $e');
    }
  }

  void _applyFilters() {
    List<TaskHistoryModel> filtered = List.from(_taskHistoryList);
    
    // Filter by project
    if (_selectedProject != null && _selectedProject != 'Tất cả') {
      filtered = filtered.where((record) => record.boPhan == _selectedProject).toList();
    }
    
    // Filter by staff
    if (_selectedStaff != null && _selectedStaff != 'Tất cả') {
      final username = _getUsernameFromDisplayName(_selectedStaff!);
      if (username != null) {
        filtered = filtered.where((record) => 
          record.nguoiDung?.toLowerCase() == username).toList();
      }
    }
    
    // Filter by date
    if (_selectedDate != null) {
      filtered = filtered.where((record) {
        return record.ngay.year == _selectedDate!.year &&
               record.ngay.month == _selectedDate!.month &&
               record.ngay.day == _selectedDate!.day;
      }).toList();
    }
    
    setState(() {
      _filteredTaskHistoryList = filtered;
    });
  }

  Future<void> _exportToExcel() async {
  setState(() {
    _isExporting = true;
  });

  try {
    // Create Excel workbook
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Báo cáo công nhân'];
    
    // Remove default sheet
    excel.delete('Sheet1');

    // Add headers
    List<String> headers = [
      'STT',
      'Ngày',
      'Giờ', 
      'Nhân viên',
      'Vị trí',
      'Dự án',
      'Kết quả',
      'Chi tiết',
      'Kế hoạch',
      'Khu vực',
      'Phân loại',
      'Có hình ảnh'
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '#0066CC',
        fontColorHex: '#FFFFFF',
      );
    }

    // Add data rows
    for (int i = 0; i < _filteredTaskHistoryList.length; i++) {
      final record = _filteredTaskHistoryList[i];
      int rowIndex = i + 1;

      List<String> rowData = [
        (i + 1).toString(),
        _dateFormat.format(record.ngay),
        record.gio,
        _getStaffDisplayName(record.nguoiDung),
        record.viTri ?? '',
        record.boPhan ?? '',
        '${record.ketQua ?? ''} ${_getResultText(record.ketQua)}',
        record.chiTiet ?? '',
        record.chiTiet2 ?? '',
        record.giaiPhap ?? '', // This is now "Khu vực"
        record.phanLoai ?? '',
        (record.hinhAnh != null && record.hinhAnh!.isNotEmpty) ? 'Có' : 'Không'
      ];

      for (int j = 0; j < rowData.length; j++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
        cell.value = rowData[j];
        
        // Color code result column
        if (j == 6) { // Result column
          Color resultColor = _getResultColor(record.ketQua);
          if (resultColor == Colors.green) {
            cell.cellStyle = CellStyle(backgroundColorHex: '#90EE90');
          } else if (resultColor == Colors.orange) {
            cell.cellStyle = CellStyle(backgroundColorHex: '#FFA500');
          } else if (resultColor == Colors.red) {
            cell.cellStyle = CellStyle(backgroundColorHex: '#FFB6C1');
          }
        }
      }
    }

    // Save file
    final directory = await getTemporaryDirectory();
    final now = DateTime.now();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'BaoCao_CongNhan_$timestamp.xlsx';
    final filePath = '${directory.path}/$fileName';
    
    List<int>? fileBytes = excel.save();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)], 
        text: 'Báo cáo công nhân - ${_dateFormat.format(now)}'
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xuất Excel thành công: ${_filteredTaskHistoryList.length} bản ghi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  } catch (e) {
    print('Error exporting to Excel: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xuất Excel: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isExporting = false;
      });
    }
  }
}

  Future<void> _syncData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đồng bộ thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showImageDialog(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không có hình ảnh')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text('Hình ảnh báo cáo'),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.share),
                      onPressed: () => _shareImage(imageUrl),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Không thể tải hình ảnh'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareImage(String imageUrl) async {
    try {
      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final temp = await getTemporaryDirectory();
        final file = File('${temp.path}/shared_image.jpg');
        await file.writeAsBytes(bytes);
        
        await Share.shareXFiles([XFile(file.path)], text: 'Hình ảnh báo cáo');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chia sẻ hình ảnh: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getResultColor(String? result) {
    switch (result) {
      case '✔️':
        return Colors.green;
      case '⚠️':
        return Colors.orange;
      case '❌':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getResultText(String? result) {
    switch (result) {
      case '✔️':
        return 'Hoàn thành';
      case '⚠️':
        return 'Cảnh báo';
      case '❌':
        return 'Không đạt';
      default:
        return 'Không xác định';
    }
  }

  Widget _buildImageThumbnail(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return SizedBox.shrink();

  return InkWell(
    onTap: () => _showImageDialog(imageUrl),
    child: Container(
      width: 60,
      height: 60,
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!), 
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[100],
            child: Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final userCredentials = Provider.of<UserCredentials>(context);
    String username = userCredentials.username.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 45,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 114, 255, 175),
                Color.fromARGB(255, 201, 255, 225),
                Color.fromARGB(255, 79, 255, 249),
                Color.fromARGB(255, 188, 255, 248),
              ],
            ),
          ),
        ),
        title: Text(
          'Công nhân của GS $username',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _syncData,
            style: TextButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            ),
            child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color.fromARGB(255, 0, 204, 34),
                    ),
                  ),
                )
              : Text(
                  'Đồng bộ',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color.fromARGB(255, 0, 204, 34),
                  ),
                ),
          ),
          SizedBox(width: 16)
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bộ lọc',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isExporting ? null : _exportToExcel,
                          icon: _isExporting 
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.file_download, size: 18),
                          label: Text('Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    // First row of filters
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedProject,
                            decoration: InputDecoration(
                              labelText: 'Dự án',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _projectList.map((String project) {
                              return DropdownMenuItem<String>(
                                value: project,
                                child: Text(project),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedProject = newValue;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStaff,
                            decoration: InputDecoration(
                              labelText: 'Nhân viên',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _staffList.map((String staff) {
                              return DropdownMenuItem<String>(
                                value: staff,
                                child: Text(staff),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedStaff = newValue;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    // Second row - Date filter
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(Duration(days: 30)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                });
                                _applyFilters();
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Ngày',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedDate != null
                                        ? _dateFormat.format(_selectedDate!)
                                        : 'Tất cả',
                                  ),
                                  if (_selectedDate != null)
                                    IconButton(
                                      icon: Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedDate = null;
                                        });
                                        _applyFilters();
                                      },
                                    )
                                  else
                                    Icon(Icons.calendar_today, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: SizedBox()), // Empty space to balance layout
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            
            // Results count
            Text(
              'Tổng: ${_filteredTaskHistoryList.length} báo cáo',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 8),

            // Task History List
            if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color.fromARGB(255, 0, 204, 34),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Đang tải dữ liệu...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredTaskHistoryList.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Không có báo cáo nào',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredTaskHistoryList.length,
                  itemBuilder: (context, index) {
                    final record = _filteredTaskHistoryList[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row with image thumbnail
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Result badge and time
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getResultColor(record.ketQua),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${record.ketQua} ${_getResultText(record.ketQua)}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${_dateFormat.format(record.ngay)} ${record.gio}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      
                                      // Staff and position info
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 16, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _getStaffDisplayName(record.nguoiDung),
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 16, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text(record.viTri ?? 'N/A'),
                                          SizedBox(width: 16),
                                          Icon(Icons.business, size: 16, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              record.boPhan ?? 'N/A',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Image thumbnail
                                _buildImageThumbnail(record.hinhAnh),
                              ],
                            ),
                            
                            if (record.chiTiet != null && record.chiTiet!.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                'Chi tiết:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(record.chiTiet!),
                            ],
                            
                            if (record.chiTiet2 != null && record.chiTiet2!.isNotEmpty) ...[
                              SizedBox(height: 4),
                             Text(
                               'Kế hoạch:',
                               style: TextStyle(
                                 fontWeight: FontWeight.w500,
                                 fontSize: 12,
                                 color: Colors.grey[700],
                               ),
                             ),
                             Text(record.chiTiet2!),
                           ],
                           
                           if (record.giaiPhap != null && record.giaiPhap!.isNotEmpty) ...[
                             SizedBox(height: 4),
                             Text(
                               'Khu vực:',
                               style: TextStyle(
                                 fontWeight: FontWeight.w500,
                                 fontSize: 12,
                                 color: Colors.grey[700],
                               ),
                             ),
                             Text(
                               record.giaiPhap!,
                               style: TextStyle(color: Colors.blue[700]),
                             ),
                           ],
                           
                           if (record.phanLoai != null && record.phanLoai!.isNotEmpty) ...[
                             SizedBox(height: 8),
                             Container(
                               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Colors.grey[200],
                                 borderRadius: BorderRadius.circular(8),
                               ),
                               child: Text(
                                 record.phanLoai!,
                                 style: TextStyle(
                                   fontSize: 10,
                                   color: Colors.grey[600],
                                 ),
                               ),
                             ),
                           ],
                         ],
                       ),
                     ),
                   );
                 },
               ),
             ),
         ],
       ),
     ),
   );
 }
}