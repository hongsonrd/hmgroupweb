import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'projecttimeline3file.dart';

class ProjectTimeline3Single extends StatefulWidget {
  final String username;

  const ProjectTimeline3Single({Key? key, required this.username}) : super(key: key);

  @override
  _ProjectTimeline3SingleState createState() => _ProjectTimeline3SingleState();
}

class _ProjectTimeline3SingleState extends State<ProjectTimeline3Single> {
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isDownloading = false;
  final dbHelper = DBHelper();
  final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  // Monthly period selection
  DateTime _selectedMonth = DateTime.now();
  List<DateTime> _availableMonths = [];
  
  // Project selection with search
  String? _selectedProject;
  List<String> _availableProjects = [];
  List<String> _filteredProjects = [];
  final TextEditingController _projectSearchController = TextEditingController();
  bool _isProjectDropdownOpen = false;
  
  // Images count data by date
  List<ImageCountByDate> _imageCountData = [];
  
  @override
  void initState() {
    super.initState();
    _initializeData();
    _projectSearchController.addListener(_filterProjects);
  }

  @override
  void dispose() {
    _projectSearchController.dispose();
    super.dispose();
  }

  // Download image functionality
  Future<void> _downloadImage(String imageUrl, String title) async {
    if (imageUrl.isEmpty) {
      _showError('URL hình ảnh không hợp lệ');
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Không thể tải hình ảnh từ server');
      }

      final Uint8List imageBytes = response.bodyBytes;
      
      // Generate filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final projectName = _selectedProject?.replaceAll(RegExp(r'[^\w\s-]'), '') ?? 'Unknown';
      final fileName = 'Image_${projectName}_${timestamp}.jpg';

      // Check platform and handle accordingly
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: Use share_plus
        await _shareImage(imageBytes, fileName, title);
      } else {
        // Desktop: Save to folder and show dialog
        await _saveImageToFolder(imageBytes, fileName, title);
      }
      
    } catch (e) {
      print('Error downloading image: $e');
      _showError('Lỗi khi tải hình ảnh: ${e.toString()}');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _shareImage(Uint8List imageBytes, String fileName, String title) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Hình ảnh từ dự án: $_selectedProject\n$title',
      );
      
      _showSuccess('Đã chia sẻ hình ảnh thành công');
    } catch (e) {
      print('Error sharing image: $e');
      _showError('Lỗi khi chia sẻ hình ảnh: ${e.toString()}');
    }
  }

  Future<void> _saveImageToFolder(Uint8List imageBytes, String fileName, String title) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imageFolder = Directory('${directory.path}/HinhAnh_DuAn');
      
      // Create folder if it doesn't exist
      if (!await imageFolder.exists()) {
        await imageFolder.create(recursive: true);
      }
      
      final filePath = '${imageFolder.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      // Show success dialog with option to open folder
      await _showImageSaveSuccessDialog(imageFolder.path, fileName, title);
      
    } catch (e) {
      print('Error saving image to folder: $e');
      _showError('Lỗi khi lưu hình ảnh: ${e.toString()}');
    }
  }

  Future<void> _showImageSaveSuccessDialog(String folderPath, String fileName, String title) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Lưu hình ảnh thành công'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hình ảnh đã được lưu:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      fileName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (title.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text('Dự án: $_selectedProject'),
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
      _showError('Không thể mở thư mục: ${e.toString()}');
    }
  }

  // Updated image popup with download button
  void _showImagePopup(String imageUrl, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title, download button, and close button
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Download button
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          icon: _isDownloading 
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(Icons.download, color: Colors.white, size: 20),
                          onPressed: _isDownloading ? null : () {
                            Navigator.of(context).pop(); // Close popup first
                            _downloadImage(imageUrl, title);
                          },
                          tooltip: Platform.isAndroid || Platform.isIOS ? 'Chia sẻ hình ảnh' : 'Tải xuống hình ảnh',
                          padding: EdgeInsets.all(8),
                          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Image container
                Flexible(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 3.0,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 16),
                                  Text(
                                    'Đang tải hình ảnh...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Không thể tải hình ảnh',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
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

  // Rest of your existing methods remain the same...
  void _filterProjects() {
    String query = _projectSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProjects = List.from(_availableProjects);
      } else {
        _filteredProjects = _availableProjects
            .where((project) => project.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _initializeData() async {
    await _loadAvailableMonths();
    await _loadAvailableProjects();
    if (_availableProjects.isNotEmpty) {
      await _loadImageCountData();
    }
  }

  Future<void> _loadAvailableMonths() async {
    try {
      final db = await dbHelper.database;
      
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT DISTINCT 
          strftime('%Y-%m', Ngay) as month_year,
          strftime('%Y', Ngay) as year,
          strftime('%m', Ngay) as month
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE Ngay IS NOT NULL
        ORDER BY month_year DESC
        LIMIT 12
      ''');

      List<DateTime> months = [];
      for (var result in results) {
        try {
          int year = int.parse(result['year']);
          int month = int.parse(result['month']);
          DateTime monthDate = DateTime(year, month, 1);
          months.add(monthDate);
        } catch (e) {
          print('Error parsing month: ${result['month_year']}');
        }
      }
      
      DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      if (!months.any((m) => m.year == currentMonth.year && m.month == currentMonth.month)) {
        months.insert(0, currentMonth);
      }
      
      setState(() {
        _availableMonths = months;
        if (months.isNotEmpty) {
          _selectedMonth = months.first;
        }
      });
    } catch (e) {
      print('Error loading available months: $e');
    }
  }

  Future<void> _loadAvailableProjects() async {
    try {
      final db = await dbHelper.database;
      
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT DISTINCT BoPhan as project_name
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE BoPhan IS NOT NULL AND BoPhan != ''
        AND LENGTH(BoPhan) >= 10
        AND NOT (LOWER(BoPhan) LIKE 'hm%' AND BoPhan GLOB 'hm[0-9]*')
        AND LOWER(BoPhan) != 'unknown'
        AND NOT (BoPhan = UPPER(BoPhan) AND BoPhan NOT LIKE '% %')
        AND NOT (LOWER(BoPhan) LIKE 'http:%' OR LOWER(BoPhan) LIKE 'https:%')
        ORDER BY BoPhan
      ''');

      List<String> projects = results.map((item) => item['project_name'] as String).toList();
      
      setState(() {
        _availableProjects = projects;
        _filteredProjects = List.from(projects);
        if (projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = projects.first;
        }
      });
    } catch (e) {
      print('Error loading available projects: $e');
    }
  }

  Future<void> _loadImageCountData() async {
    if (_selectedProject == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await dbHelper.database;
      
      DateTime startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      DateTime endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT 
          DATE(Ngay) as date_only,
          COUNT(*) as total_reports,
          COUNT(CASE WHEN HinhAnh IS NOT NULL AND HinhAnh != '' THEN 1 END) as images_submitted
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE BoPhan = ?
        AND Ngay >= ? AND Ngay < ?
        GROUP BY DATE(Ngay)
        ORDER BY date_only ASC
      ''', [_selectedProject, startOfMonth.toIso8601String(), endOfMonth.toIso8601String()]);

      List<ImageCountByDate> imageData = results.map((item) {
        return ImageCountByDate(
          date: DateTime.parse(item['date_only']),
          totalReports: item['total_reports'] as int,
          imagesSubmitted: item['images_submitted'] as int,
        );
      }).toList();

      setState(() {
        _imageCountData = imageData;
      });
    } catch (e) {
      print('Error loading image count data: $e');
      _showError('Lỗi tải dữ liệu hình ảnh: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMonthChanged(DateTime? newMonth) {
    if (newMonth != null && newMonth != _selectedMonth) {
      setState(() {
        _selectedMonth = newMonth;
      });
      _loadImageCountData();
    }
  }

  void _onProjectChanged(String? newProject) {
    if (newProject != null && newProject != _selectedProject) {
      setState(() {
        _selectedProject = newProject;
        _projectSearchController.text = newProject;
        _isProjectDropdownOpen = false;
      });
      _loadImageCountData();
    }
  }

  Future<void> _performEnhancedSync() async {
    if (_selectedProject == null) {
      _showError('Vui lòng chọn dự án trước khi đồng bộ');
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final requestBody = {
        'project_name': _selectedProject,
        'period': '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}',
        'username': widget.username,
      };

      print('Syncing with data: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/historybaocaobp/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (data.isEmpty) {
          _showSuccess('Không có dữ liệu mới để đồng bộ');
          return;
        }

        int insertedCount = 0;
        int updatedCount = 0;
        
        final db = await dbHelper.database;
        
        for (var item in data) {
          try {
            final existingRecord = await db.query(
              DatabaseTables.taskHistoryTable,
              where: 'UID = ?',
              whereArgs: [item['UID']],
              limit: 1,
            );

            final taskHistory = TaskHistoryModel(
              uid: item['UID'],
              taskId: item['TaskID'],
              ngay: DateTime.parse(item['Ngay']),
              gio: item['Gio'],
              nguoiDung: item['NguoiDung'],
              ketQua: item['KetQua'],
              chiTiet: item['ChiTiet'],
              chiTiet2: item['ChiTiet2'],
              viTri: item['ViTri'],
              boPhan: item['BoPhan'],
              phanLoai: item['PhanLoai'],
              hinhAnh: item['HinhAnh'],
              giaiPhap: item['GiaiPhap'],
            );

            if (existingRecord.isEmpty) {
              await db.insert(
                DatabaseTables.taskHistoryTable,
                taskHistory.toMap(),
              );
              insertedCount++;
            } else {
              await db.update(
                DatabaseTables.taskHistoryTable,
                taskHistory.toMap(),
                where: 'UID = ?',
                whereArgs: [item['UID']],
              );
              updatedCount++;
            }
          } catch (e) {
            print('Error processing record ${item['UID']}: $e');
          }
        }

        await _loadAvailableMonths();
        await _loadAvailableProjects();
        await _loadImageCountData();
        
        String successMessage = 'Đồng bộ thành công: ';
        if (insertedCount > 0) {
          successMessage += '$insertedCount bản ghi mới';
        }
        if (updatedCount > 0) {
          if (insertedCount > 0) successMessage += ', ';
          successMessage += '$updatedCount bản ghi cập nhật';
        }
        
        _showSuccess(successMessage);
        
      } else if (response.statusCode == 404) {
        _showError('Không tìm thấy dữ liệu cho dự án và thời gian được chọn');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
      
    } catch (e) {
      print('Error during enhanced sync: $e');
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        _showError('Lỗi kết nối mạng. Vui lòng kiểm tra kết nối internet.');
      } else if (e.toString().contains('TimeoutException')) {
        _showError('Hết thời gian chờ. Vui lòng thử lại.');
      } else {
        _showError('Lỗi đồng bộ: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _showDayDetails(DateTime selectedDate) async {
    if (_selectedProject == null) return;

    try {
      final db = await dbHelper.database;
      
      DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime endOfDay = startOfDay.add(Duration(days: 1));
      
      final List<Map<String, dynamic>> reportResults = await db.rawQuery('''
        SELECT 
          Gio,
          ChiTiet,
          ChiTiet2,
          HinhAnh,
          strftime('%H:%M', Ngay, '+' || Gio || ' hours') as time_display
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE BoPhan = ?
        AND Ngay >= ? AND Ngay < ?
        ORDER BY Ngay ASC, Gio ASC
      ''', [_selectedProject, startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

      final List<Map<String, dynamic>> imageResults = await db.rawQuery('''
        SELECT 
          HinhAnh,
          Gio,
          ChiTiet,
          ChiTiet2,
          strftime('%H:%M', Ngay, '+' || Gio || ' hours') as time_display
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE BoPhan = ?
        AND Ngay >= ? AND Ngay < ?
        AND HinhAnh IS NOT NULL AND HinhAnh != ''
        ORDER BY Ngay ASC, Gio ASC
      ''', [_selectedProject, startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

      List<DayReport> reports = reportResults.map((item) {
        return DayReport(
          time: item['time_display'] ?? item['Gio']?.toString() ?? '',
          detail1: item['ChiTiet'] ?? '',
          detail2: item['ChiTiet2'] ?? '',
          image: item['HinhAnh'] ?? '',
          status: '',
          duration: item['Gio']?.toString() ?? '',
        );
      }).toList();

      List<DayImage> images = imageResults.map((item) {
        return DayImage(
          imageUrl: item['HinhAnh'] ?? '',
          time: item['time_display'] ?? item['Gio']?.toString() ?? '',
          detail1: item['ChiTiet'] ?? '',
          detail2: item['ChiTiet2'] ?? '',
          duration: item['Gio']?.toString() ?? '',
        );
      }).toList();

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return DayDetailsDialog(
            selectedDate: selectedDate,
            projectName: _selectedProject!,
            reports: reports,
            images: images,
            onImageDownload: _downloadImage, // Pass the download function
          );
        },
      );
    } catch (e) {
      print('Error loading day details: $e');
      _showError('Lỗi tải chi tiết ngày: ${e.toString()}');
    }
  }

  // Helper widget to build cached network image with click handler
  Widget _buildCachedImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    String title = 'Hình ảnh',
  }) {
    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 8),
              Text(
                'Đang tải...',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                color: Colors.grey[400],
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                'Lỗi tải ảnh',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return GestureDetector(
      onTap: () => _showImagePopup(imageUrl, title),
      child: imageWidget,
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildMonthDropdown() {
    return Container(
      constraints: BoxConstraints(maxWidth: 160),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButton<DateTime>(
        value: _selectedMonth,
        hint: Text('Chọn tháng', style: TextStyle(fontSize: 14)),
        underline: Container(),
        isExpanded: true,
        icon: Icon(Icons.calendar_month, size: 20),
        style: TextStyle(fontSize: 14, color: Colors.black87),
        items: _availableMonths.map((DateTime month) {
          return DropdownMenuItem<DateTime>(
            value: month,
            child: Text(
              '${month.month.toString().padLeft(2, '0')}-${month.year}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
        onChanged: _onMonthChanged,
      ),
    );
  }

  Widget _buildSearchableProjectDropdown() {
    return Container(
      constraints: BoxConstraints(maxWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.business, size: 20, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _projectSearchController,
                    decoration: InputDecoration(
                      hintText: _selectedProject ?? 'Tìm kiếm dự án...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    onTap: () {
                      setState(() {
                        _isProjectDropdownOpen = !_isProjectDropdownOpen;
                      });
                    },
                    onChanged: (value) {
                      setState(() {
                        _isProjectDropdownOpen = true;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isProjectDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isProjectDropdownOpen = !_isProjectDropdownOpen;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          if (_isProjectDropdownOpen) ...[
            SizedBox(height: 4),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _filteredProjects.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Không tìm thấy dự án nào',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredProjects.length,
                      itemBuilder: (context, index) {
                        final project = _filteredProjects[index];
                        final isSelected = project == _selectedProject;
                        
                        return InkWell(
                          onTap: () => _onProjectChanged(project),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue[50] : null,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (isSelected) ...[
                                  Icon(Icons.check, size: 16, color: Colors.blue[600]),
                                  SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    project,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? Colors.blue[600] : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
bool _isGeneratingReport = false;
Future<void> _generateReport() async {
  if (_selectedProject == null || _imageCountData.isEmpty) {
    _showError('Không có dữ liệu để tạo báo cáo');
    return;
  }

  // Show configuration dialog first
  final ReportConfig? config = await _showReportConfigDialog();
  if (config == null) {
    return; // User cancelled
  }

  // Get weekly images for selection
  final detailedData = await _getDetailedReportDataForImageSelection();
  final weeklyImagesData = await _getWeeklyImagesForSelection(detailedData);
  
  // Show image selection dialogs for each week
  Map<int, List<Map<String, dynamic>>> selectedWeeklyImages = {};
  
  for (var weekData in weeklyImagesData) {
    final weekNumber = weekData['weekNumber'] as int;
    final availableImages = weekData['images'] as List<Map<String, dynamic>>;
    
    if (availableImages.isNotEmpty) {
      // Show up to 20 images but pre-select best 10
      final displayImages = availableImages.take(20).toList();
      final preSelected = availableImages.take(10).toList();
      
      final selectedImages = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => WeeklyImageSelectionDialog(
          weekNumber: weekNumber,
          startDate: weekData['startDate'],
          endDate: weekData['endDate'],
          availableImages: displayImages,
          preSelectedImages: preSelected,
        ),
      );
      
      if (selectedImages != null) {
        selectedWeeklyImages[weekNumber] = selectedImages;
      } else {
        // User cancelled image selection
        return;
      }
    }
  }

  setState(() {
    _isGeneratingReport = true;
  });

  try {
    final filePath = await ProjectTimeline3FileGenerator.generateReport(
      projectName: _selectedProject!,
      selectedMonth: _selectedMonth,
      username: widget.username,
      imageCountData: _imageCountData,
      reportConfig: config,
      selectedWeeklyImages: selectedWeeklyImages, // Pass selected images
    );

    if (filePath != null) {
      _showReportSuccessDialog(filePath);
    } else {
      _showError('Lỗi khi tạo báo cáo PDF');
    }
  } catch (e) {
    print('Error generating report: $e');
    _showError('Lỗi khi tạo báo cáo: ${e.toString()}');
  } finally {
    setState(() {
      _isGeneratingReport = false;
    });
  }
}

// Add helper methods
Future<List<Map<String, dynamic>>> _getDetailedReportDataForImageSelection() async {
  try {
    final db = await dbHelper.database;
    
    DateTime startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    DateTime endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    
    final results = await db.rawQuery('''
      SELECT 
        Ngay,
        Gio,
        PhanLoai,
        KetQua,
        ChiTiet,
        ChiTiet2,
        HinhAnh,
        GiaiPhap,
        ViTri
      FROM ${DatabaseTables.taskHistoryTable}
      WHERE BoPhan = ?
      AND Ngay >= ? AND Ngay < ?
      ORDER BY Ngay ASC, Gio ASC
    ''', [_selectedProject, startOfMonth.toIso8601String(), endOfMonth.toIso8601String()]);

    return results;
  } catch (e) {
    print('Error getting detailed data: $e');
    return [];
  }
}

Future<List<Map<String, dynamic>>> _getWeeklyImagesForSelection(List<Map<String, dynamic>> data) async {
  Map<int, Map<String, dynamic>> weeklyImages = {};
  
  for (var item in data) {
    if (item['HinhAnh'] != null && item['HinhAnh'].toString().isNotEmpty) {
      try {
        final date = DateTime.parse(item['Ngay']);
        final weekNumber = _getWeekNumber(date);
        
        if (!weeklyImages.containsKey(weekNumber)) {
          weeklyImages[weekNumber] = {
            'weekNumber': weekNumber,
            'startDate': _getStartOfWeek(date),
            'endDate': _getEndOfWeek(date),
            'images': <Map<String, dynamic>>[],
          };
        }
        
        weeklyImages[weekNumber]!['images'].add({
          'url': item['HinhAnh'],
          'area': item['GiaiPhap'] ?? '',
          'detail': item['ChiTiet'] ?? '',
          'detail2': item['ChiTiet2'] ?? '',
          'date': date,
          'location': item['ViTri'] ?? '',
          'topic': item['PhanLoai'] ?? '',
        });
      } catch (e) {
        print('Error processing image for week grouping: $e');
      }
    }
  }
  
  return weeklyImages.values.toList()..sort((a, b) => a['weekNumber'].compareTo(b['weekNumber']));
}

// Helper methods for week calculations
int _getWeekNumber(DateTime date) {
  final startOfYear = DateTime(date.year, 1, 1);
  final dayOfYear = date.difference(startOfYear).inDays + 1;
  return ((dayOfYear - 1) / 7).floor() + 1;
}

DateTime _getStartOfWeek(DateTime date) {
  final daysFromMonday = date.weekday - 1;
  return date.subtract(Duration(days: daysFromMonday));
}

DateTime _getEndOfWeek(DateTime date) {
  final daysToSunday = 7 - date.weekday;
  return date.add(Duration(days: daysToSunday));
}

Future<ReportConfig?> _showReportConfigDialog() async {
  // First, get unique GiaiPhap values from database
  List<String> giaiPhapCategories = await _getUniqueGiaiPhapValues();
  
  return showDialog<ReportConfig>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return ReportConfigDialog(
        projectName: _selectedProject!,
        giaiPhapCategories: giaiPhapCategories,
      );
    },
  );
}

Future<List<String>> _getUniqueGiaiPhapValues() async {
  if (_selectedProject == null) return [];
  
  try {
    final db = await dbHelper.database;
    
    DateTime startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    DateTime endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT DISTINCT GiaiPhap
      FROM ${DatabaseTables.taskHistoryTable}
      WHERE BoPhan = ?
      AND Ngay >= ? AND Ngay < ?
      AND GiaiPhap IS NOT NULL AND GiaiPhap != ''
      AND HinhAnh IS NOT NULL AND HinhAnh != ''
      ORDER BY GiaiPhap ASC
    ''', [_selectedProject, startOfMonth.toIso8601String(), endOfMonth.toIso8601String()]);

    return results.map((item) => item['GiaiPhap'] as String).toList();
  } catch (e) {
    print('Error loading GiaiPhap values: $e');
    return [];
  }
}

Future<void> _showReportSuccessDialog(String filePath) async {
  final fileName = filePath.split('/').last;
  final folderPath = filePath.substring(0, filePath.lastIndexOf('/'));
  
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.green),
            SizedBox(width: 8),
            Text('Tạo báo cáo thành công'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Báo cáo PDF đã được tạo:'),
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
            Text('Dự án: $_selectedProject'),
            Text('Tháng: ${_selectedMonth.month.toString().padLeft(2, '0')}-${_selectedMonth.year}'),
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
              await ProjectTimeline3FileGenerator.openFile(filePath);
            },
            icon: Icon(Icons.open_in_new, size: 16),
            label: Text('Mở báo cáo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
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

  Widget _buildSyncAndReportButtons() {
  return Row(
    children: [
      // Sync button
      Expanded(
        flex: 2,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.blue[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            icon: _isSyncing 
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.sync, size: 20, color: Colors.white),
            label: Text(
              _isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: _isSyncing ? null : _performEnhancedSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
      
      SizedBox(width: 12),
      
      // Report button
      Expanded(
        flex: 2,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[600]!, Colors.green[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            icon: _isGeneratingReport 
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.picture_as_pdf, size: 20, color: Colors.white),
            label: Text(
              _isGeneratingReport ? 'Đang tạo...' : 'Tạo báo cáo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: _isGeneratingReport ? null : _generateReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    ],
  );
}
  Widget _buildImageCountList() {
    if (_imageCountData.isEmpty && !_isLoading) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'Không có dữ liệu hình ảnh\ncho dự án này trong tháng ${_selectedMonth.month.toString().padLeft(2, '0')}-${_selectedMonth.year}',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _performEnhancedSync,
                icon: Icon(Icons.cloud_download),
                label: Text('Đồng bộ dữ liệu từ server'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _imageCountData.length,
        itemBuilder: (context, index) {
          final data = _imageCountData[index];
          final percentage = (data.imagesSubmitted / 15 * 100).clamp(0.0, 100.0);
          
          return Card(
            margin: EdgeInsets.symmetric(vertical: 4),
            elevation: 2,
            child: InkWell(
              onTap: () => _showDayDetails(data.date),
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getProgressColor(percentage),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      data.date.day.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  '${data.date.day.toString().padLeft(2, '0')}-${data.date.month.toString().padLeft(2, '0')}-${data.date.year}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      'Tổng báo cáo: ${data.totalReports}',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Hình ảnh đã nộp: ${data.imagesSubmitted}/15',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getProgressColor(percentage).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getProgressColor(percentage),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _getProgressColor(percentage),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 90) return Colors.green[600]!;
    if (percentage >= 70) return Colors.blue[600]!;
    if (percentage >= 50) return Colors.orange[600]!;
    if (percentage >= 30) return Colors.deepOrange[600]!;
    return Colors.red[600]!;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isProjectDropdownOpen) {
          setState(() {
            _isProjectDropdownOpen = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Color.fromARGB(255, 79, 255, 214),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              Icon(
                Icons.analytics,
                size: 24,
                color: Colors.black87,
              ),
              SizedBox(width: 8),
              Text(
                'Tổng hợp theo bộ phận',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthDropdown(),
                      SizedBox(width: 12),
                      Expanded(child: _buildSearchableProjectDropdown()),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSyncAndReportButtons()),
                      SizedBox(width: 12),
                      if (_imageCountData.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today, 
                                   size: 18, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Text(
                                '${_imageCountData.length} ngày có dữ liệu',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (_isLoading)
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Đang tải dữ liệu...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            
            if (!_isLoading)
              _buildImageCountList(),
          ],
        ),
      ),
    );
  }
}

// Updated Day details dialog with download functionality
class DayDetailsDialog extends StatefulWidget {
  final DateTime selectedDate;
  final String projectName;
  final List<DayReport> reports;
  final List<DayImage> images;
  final Function(String, String) onImageDownload; // Add download callback

  const DayDetailsDialog({
    Key? key,
    required this.selectedDate,
    required this.projectName,
    required this.reports,
    required this.images,
    required this.onImageDownload, // Required parameter
  }) : super(key: key);

  @override
  _DayDetailsDialogState createState() => _DayDetailsDialogState();
}

class _DayDetailsDialogState extends State<DayDetailsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Updated image zoom popup with download button
  void _showImagePopup(String imageUrl, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Download button
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          icon: _isDownloading 
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(Icons.download, color: Colors.white, size: 20),
                          onPressed: _isDownloading ? null : () async {
                            setState(() {
                              _isDownloading = true;
                            });
                            Navigator.of(context).pop(); // Close popup first
                            await widget.onImageDownload(imageUrl, title);
                            setState(() {
                              _isDownloading = false;
                            });
                          },
                          tooltip: Platform.isAndroid || Platform.isIOS ? 'Chia sẻ hình ảnh' : 'Tải xuống hình ảnh',
                          padding: EdgeInsets.all(8),
                          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 3.0,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 16),
                                  Text(
                                    'Đang tải hình ảnh...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Không thể tải hình ảnh',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 79, 255, 214),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.black87),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết ngày ${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          widget.projectName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue[600],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.blue[600],
                tabs: [
                  Tab(
                    icon: Icon(Icons.image),
                    text: 'Hình ảnh (${widget.images.length})',
                  ),
                  Tab(
                    icon: Icon(Icons.list_alt),
                    text: 'Báo cáo (${widget.reports.length})',
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Images tab with download buttons
                  widget.images.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Không có hình ảnh nào trong ngày này',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: widget.images.length,
                          itemBuilder: (context, index) {
                            final image = widget.images[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image thumbnail with tap to zoom
                                    GestureDetector(
                                      onTap: () => _showImagePopup(
                                        image.imageUrl,
                                        'Hình ảnh lúc ${image.time}',
                                      ),
                                      child: Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.grey[200],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: image.imageUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: image.imageUrl,
                                                  width: 60,
                                                  height: 60,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => Center(
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey[400],
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.image,
                                                  color: Colors.grey[400],
                                                ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Colors.blue[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                image.time,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue[600],
                                                ),
                                              ),
                                              if (image.duration.isNotEmpty) ...[
                                                SizedBox(width: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[100],
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${image.duration}h',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.green[700],
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (image.detail1.isNotEmpty) ...[
                                            SizedBox(height: 4),
                                            Text(
                                              image.detail1,
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ],
                                          if (image.detail2.isNotEmpty) ...[
                                            SizedBox(height: 4),
                                            Text(
                                              image.detail2,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Download button for each image
                                    Column(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.download, color: Colors.white, size: 16),
                                            onPressed: () => widget.onImageDownload(
                                              image.imageUrl,
                                              'Hình ảnh lúc ${image.time}',
                                            ),
                                            tooltip: Platform.isAndroid || Platform.isIOS ? 'Chia sẻ' : 'Tải xuống',
                                            padding: EdgeInsets.all(8),
                                            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () => _showImagePopup(
                                            image.imageUrl,
                                            'Hình ảnh lúc ${image.time}',
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[100],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.zoom_in,
                                              color: Colors.blue[700],
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  
                  // Reports tab (unchanged but with download option for images)
                  widget.reports.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Không có báo cáo nào trong ngày này',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: widget.reports.length,
                          itemBuilder: (context, index) {
                            final report = widget.reports[index];
                            final hasImage = report.image.isNotEmpty;
                            
                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.blue[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          report.time,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[600],
                                          ),
                                        ),
                                        if (report.duration.isNotEmpty) ...[
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${report.duration}h',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        Spacer(),
                                        if (hasImage) ...[
                                          // Download button for report image
                                          Container(
                                            margin: EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: IconButton(
                                              icon: Icon(Icons.download, color: Colors.white, size: 14),
                                              onPressed: () => widget.onImageDownload(
                                                report.image,
                                                'Báo cáo lúc ${report.time}',
                                              ),
                                              tooltip: Platform.isAndroid || Platform.isIOS ? 'Chia sẻ' : 'Tải xuống',
                                              padding: EdgeInsets.all(6),
                                              constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                                            ),
                                          ),
                                          // View image button
                                          GestureDetector(
                                            onTap: () => _showImagePopup(
                                              report.image,
                                              'Hình ảnh báo cáo lúc ${report.time}',
                                            ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green[50],
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.green[300]!,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.image,
                                                    size: 14,
                                                    color: Colors.green[700],
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Xem hình',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.green[700],
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ] else
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.red[300]!,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.image_not_supported,
                                                  size: 14,
                                                  color: Colors.red[700],
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Không có hình',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red[700],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    
                                    if (report.detail1.isNotEmpty) ...[
                                      SizedBox(height: 8),
                                      Text(
                                        report.detail1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    if (report.detail2.isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        report.detail2,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Model classes remain the same
class ImageCountByDate {
  final DateTime date;
  final int totalReports;
  final int imagesSubmitted;

  ImageCountByDate({
    required this.date,
    required this.totalReports,
    required this.imagesSubmitted,
  });
}

class DayReport {
  final String time;
  final String detail1;
  final String detail2;
  final String image;
  final String status;
  final String duration;

  DayReport({
    required this.time,
    required this.detail1,
    required this.detail2,
    required this.image,
    required this.status,
    required this.duration,
  });
}

class DayImage {
  final String imageUrl;
  final String time;
  final String detail1;
  final String detail2;
  final String duration;

  DayImage({
    required this.imageUrl,
    required this.time,
    required this.detail1,
    required this.detail2,
    required this.duration,
  });
}

class CategoryRating {
  final String name;
  double rating;

  CategoryRating({
    required this.name,
    this.rating = 0.0,
  });
}
class ReportConfigDialog extends StatefulWidget {
  final String projectName;
  final List<String> giaiPhapCategories;

  const ReportConfigDialog({
    Key? key,
    required this.projectName,
    required this.giaiPhapCategories,
  }) : super(key: key);

  @override
  _ReportConfigDialogState createState() => _ReportConfigDialogState();
}

class _ReportConfigDialogState extends State<ReportConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _improvementController = TextEditingController();
  final _customAudienceController = TextEditingController();
  
  String _selectedAudience = 'Ban quản lý';
  bool _isCustomAudience = false;
  
  List<CategoryRating> _categoryRatings = [];
  
  final List<String> _predefinedAudiences = [
    'Ban quản lý',
    'Phòng TCHC',
    'Ban quản trị',
    'Phòng quản trị',
    'Ban lãnh đạo',
    'Quý công ty',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCategoryRatings();
  }

  @override
  void dispose() {
    _improvementController.dispose();
    _customAudienceController.dispose();
    super.dispose();
  }

  void _initializeCategoryRatings() {
    _categoryRatings = [
      // Add GiaiPhap categories from database
      ...widget.giaiPhapCategories.map((category) => CategoryRating(name: category)),
      // Add fixed categories
      CategoryRating(name: 'Máy móc, trang thiết bị, dụng cụ làm việc'),
      CategoryRating(name: 'Tác phong làm việc của nhân viên'),
    ];
  }

  void _updateRating(int index, double value) {
    setState(() {
      _categoryRatings[index].rating = value;
    });
  }

  void _submitConfiguration() {
    if (_formKey.currentState!.validate()) {
      final audience = _isCustomAudience 
          ? _customAudienceController.text.trim()
          : _selectedAudience;
      
      final categoryRatings = <String, double>{};
      for (final category in _categoryRatings) {
        categoryRatings[category.name] = category.rating;
      }
      
      final config = ReportConfig(
        audience: audience,
        categoryRatings: categoryRatings,
        improvementSuggestions: _improvementController.text.trim(),
      );
      
      Navigator.of(context).pop(config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 79, 255, 214),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.black87, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cấu hình báo cáo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          widget.projectName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Audience Selection
                      _buildSectionTitle('Đối tượng báo cáo', Icons.people),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            // Predefined audiences
                            ..._predefinedAudiences.map((audience) => 
                              RadioListTile<String>(
                                title: Text(audience),
                                value: audience,
                                groupValue: _isCustomAudience ? null : _selectedAudience,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedAudience = value!;
                                    _isCustomAudience = false;
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            
                            // Custom audience option
                            RadioListTile<bool>(
                              title: Text('Khác (tự nhập)'),
                              value: true,
                              groupValue: _isCustomAudience,
                              onChanged: (value) {
                                setState(() {
                                  _isCustomAudience = value!;
                                });
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            
                            if (_isCustomAudience) ...[
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _customAudienceController,
                                decoration: InputDecoration(
                                  hintText: 'Nhập tên đối tượng báo cáo...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                validator: (value) {
                                  if (_isCustomAudience && (value == null || value.trim().isEmpty)) {
                                    return 'Vui lòng nhập tên đối tượng báo cáo';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Category Ratings
                      _buildSectionTitle('Đánh giá theo danh mục', Icons.assessment),
                      SizedBox(height: 12),
                      
                      if (_categoryRatings.isEmpty)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange[600]),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Không tìm thấy danh mục phân loại hình ảnh cho dự án này.',
                                  style: TextStyle(color: Colors.orange[700]),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: _categoryRatings.asMap().entries.map((entry) {
                              final index = entry.key;
                              final category = entry.value;
                              final isFixed = index >= widget.giaiPhapCategories.length;
                              
                              return Container(
                                margin: EdgeInsets.only(bottom: 16),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isFixed)
                                          Icon(Icons.star, size: 16, color: Colors.amber[600])
                                        else
                                          Icon(Icons.category, size: 16, color: Colors.blue[600]),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            category.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getRatingColor(category.rating).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: _getRatingColor(category.rating)),
                                          ),
                                          child: Text(
                                            '${category.rating.toInt()}%',
                                            style: TextStyle(
                                              color: _getRatingColor(category.rating),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 6,
                                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                                        overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                                      ),
                                      child: Slider(
                                        value: category.rating,
                                        min: 0,
                                        max: 100,
                                        divisions: 100,
                                        activeColor: _getRatingColor(category.rating),
                                        inactiveColor: Colors.grey[300],
                                        onChanged: (value) => _updateRating(index, value),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      SizedBox(height: 24),

                      // Improvement Suggestions
                      _buildSectionTitle('Tồn tại & đề xuất cải tiến', Icons.lightbulb),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextFormField(
                          controller: _improvementController,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: 'Nhập các vấn đề tồn tại và đề xuất cải tiến...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.all(12),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập nội dung tồn tại & đề xuất cải tiến';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Hủy',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _submitConfiguration,
                      icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: Text(
                        'Tạo báo cáo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[600]),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 80) return Colors.green[600]!;
    if (rating >= 60) return Colors.blue[600]!;
    if (rating >= 40) return Colors.orange[600]!;
    if (rating >= 20) return Colors.deepOrange[600]!;
    return Colors.red[600]!;
  }
}
class WeeklyImageSelectionDialog extends StatefulWidget {
  final int weekNumber;
  final DateTime startDate;
  final DateTime endDate;
  final List<Map<String, dynamic>> availableImages;
  final List<Map<String, dynamic>> preSelectedImages;

  const WeeklyImageSelectionDialog({
    Key? key,
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.availableImages,
    required this.preSelectedImages,
  }) : super(key: key);

  @override
  _WeeklyImageSelectionDialogState createState() => _WeeklyImageSelectionDialogState();
}

class _WeeklyImageSelectionDialogState extends State<WeeklyImageSelectionDialog> {
  Set<String> selectedImageUrls = {};
  final int maxSelection = 10;

  @override
  void initState() {
    super.initState();
    // Pre-select images that were already chosen
    selectedImageUrls = widget.preSelectedImages.map((img) => img['url'] as String).toSet();
  }

  void _toggleImageSelection(String imageUrl) {
    setState(() {
      if (selectedImageUrls.contains(imageUrl)) {
        selectedImageUrls.remove(imageUrl);
      } else if (selectedImageUrls.length < maxSelection) {
        selectedImageUrls.add(imageUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chỉ có thể chọn tối đa $maxSelection hình ảnh cho mỗi tuần'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  List<Map<String, dynamic>> _getSelectedImages() {
    return widget.availableImages
        .where((img) => selectedImageUrls.contains(img['url']))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 79, 255, 214),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.photo_library, color: Colors.black87, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chọn hình ảnh - Tuần ${widget.weekNumber}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${DateFormat('dd/MM').format(widget.startDate)} - ${DateFormat('dd/MM').format(widget.endDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Selection info
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã chọn ${selectedImageUrls.length}/$maxSelection hình ảnh. Nhấn vào hình để chọn/bỏ chọn.',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),

            // Image grid
            Expanded(
              child: widget.availableImages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'Không có hình ảnh nào cho tuần này',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: widget.availableImages.length,
                      itemBuilder: (context, index) {
                        final image = widget.availableImages[index];
                        final imageUrl = image['url'] as String;
                        final isSelected = selectedImageUrls.contains(imageUrl);

                        return GestureDetector(
                          onTap: () => _toggleImageSelection(imageUrl),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.green : Colors.grey[300]!,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Image
                                Expanded(
                                  flex: 5,
                                  child: Container(
                                    width: double.infinity,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(11),
                                        topRight: Radius.circular(11),
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[200],
                                          child: Center(
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[200],
                                          child: Center(
                                            child: Icon(Icons.broken_image, color: Colors.grey[400]),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Info and selection indicator
                                Container(
                                  padding: EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      if (image['area'].toString().isNotEmpty)
                                        Text(
                                          image['area'],
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                            color: isSelected ? Colors.green : Colors.grey,
                                            size: 20,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            isSelected ? 'Đã chọn' : 'Chọn',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isSelected ? Colors.green : Colors.grey,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Hủy', style: TextStyle(fontSize: 16)),
                  ),
                  Spacer(),
                  Text(
                    '${selectedImageUrls.length}/$maxSelection đã chọn',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_getSelectedImages()),
                    child: Text(
                      'Xác nhận',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
}