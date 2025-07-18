import 'package:flutter/material.dart';
import 'dart:async';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'projecttimeline3single.dart';

class ProjectProgressDashboard extends StatefulWidget {
  final String username;

  const ProjectProgressDashboard({Key? key, required this.username}) : super(key: key);

  @override
  _ProjectProgressDashboardState createState() => _ProjectProgressDashboardState();
}

class _ProjectProgressDashboardState extends State<ProjectProgressDashboard> {
  bool _isLoading = false;
  List<ProjectProgress> _projectsData = [];
  List<ProjectProgress> _filteredProjectsData = [];
  final dbHelper = DBHelper();
  
  // Timer configuration
  Timer? _reloadTimer;
  final Duration _reloadInterval = Duration(minutes: 15); 
  DateTime? _lastUpdate;
  
  // Filter dropdown
  String? _selectedChiTiet2;
  List<String> _chiTiet2Options = [];
  
  // Auto-scroll configuration for TV display
  Timer? _inactivityTimer;
  Timer? _autoScrollTimer;
  final Duration _inactivityTimeout = Duration(seconds: 10);
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScrolling = false;
  
  // Date selection
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _availableDates = [];
  bool _isGeneratingExcel = false;
  
  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _startInactivityTimer();
    _loadAvailableDates();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _inactivityTimer?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableDates() async {
    try {
      final db = await dbHelper.database;
      
      // Get distinct dates from task history
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT DISTINCT DATE(Ngay) as date_only
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE Ngay IS NOT NULL
        ORDER BY date_only DESC
        LIMIT 30
      ''');

      List<DateTime> dates = [];
      for (var result in results) {
        try {
          DateTime date = DateTime.parse(result['date_only']);
          dates.add(date);
        } catch (e) {
          print('Error parsing date: ${result['date_only']}');
        }
      }
      
      // Always include today if not in list
      DateTime today = DateTime.now();
      DateTime todayDate = DateTime(today.year, today.month, today.day);
      if (!dates.any((d) => d.year == todayDate.year && d.month == todayDate.month && d.day == todayDate.day)) {
        dates.insert(0, todayDate);
      }
      
      setState(() {
        _availableDates = dates;
        // Keep selected date as today if it's available
        if (dates.isNotEmpty) {
          _selectedDate = dates.firstWhere(
            (d) => d.year == todayDate.year && d.month == todayDate.month && d.day == todayDate.day,
            orElse: () => dates.first,
          );
        }
      });
    } catch (e) {
      print('Error loading available dates: $e');
    }
  }

  void _onDateChanged(DateTime? newDate) {
    if (newDate != null && newDate != _selectedDate) {
      setState(() {
        _selectedDate = newDate;
      });
      _resetInactivityTimer();
      _loadChiTiet2Options();
      _loadProjectsData();
    }
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

  Future<void> _handleShare(List<int> fileBytes, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Báo cáo tiến độ dự án ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chia sẻ file thành công: $fileName'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error sharing file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chia sẻ file: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handleSaveToAppFolder(List<int> fileBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final appFolder = Directory('${directory.path}/BaoCao_TienDo');
      
      // Create folder if it doesn't exist
      if (!await appFolder.exists()) {
        await appFolder.create(recursive: true);
      }
      
      final filePath = '${appFolder.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      // Show success dialog with option to open folder
      await _showSaveSuccessDialog(appFolder.path, fileName);
      
    } catch (e) {
      print('Error saving to app folder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu file: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
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
              Text('File báo cáo tiến độ đã được lưu:'),
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
              Text('Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
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

  Future<void> _generateAndShareExcel() async {
    setState(() {
      _isGeneratingExcel = true;
    });

    try {
      // Show choice dialog first
      final choice = await _showExportChoiceDialog();
      if (choice == null) {
        setState(() {
          _isGeneratingExcel = false;
        });
        return; // User cancelled
      }

      // Create Excel workbook
      var excel = xl.Excel.createExcel();
      
      // Get or create sheet
      xl.Sheet sheet;
      if (excel.tables.containsKey('Sheet1')) {
        sheet = excel.tables['Sheet1']!;
      } else {
        sheet = excel['Tiến độ dự án'];
      }
      
      // Add headers
      List<String> headers = [
        'STT',
        'Tên dự án',
        'Số báo cáo',
        'Hình ảnh đã nộp',
        'Hình ảnh mục tiêu',
        'Tỷ lệ hoàn thành (%)',
        'Trạng thái'
      ];
      
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
        cell.cellStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: '#4472C4',
          fontColorHex: '#FFFFFF',
        );
      }
      
      // Add data rows
      for (int i = 0; i < _filteredProjectsData.length; i++) {
  var project = _filteredProjectsData[i];
  var percentage = project.targetImages == 0 ? 100.0 : 
                  (project.imagesSubmitted / project.targetImages * 100).clamp(0.0, 100.0);
  
  List<dynamic> rowData = [
    i + 1,
    project.projectName,
    project.totalReports,
    project.imagesSubmitted,
    project.targetImages == 0 ? 'N/A' : project.targetImages,
    project.targetImages == 0 ? 'N/A' : double.parse(percentage.toStringAsFixed(1)),
    project.targetImages == 0 ? 'N/A' : (percentage >= 100 ? 'Hoàn thành' : 'Đang thực hiện')
  ];
  
  for (int j = 0; j < rowData.length; j++) {
    var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
    cell.value = rowData[j];
    
    // Color coding based on percentage
    if (j == 6 && project.targetImages > 0) { // Status column, only for projects with targets
      xl.CellStyle? cellStyle;
      if (percentage >= 100) {
        cellStyle = xl.CellStyle(
          backgroundColorHex: '#C6EFCE',
          fontColorHex: '#006100',
        );
      } else if (percentage >= 70) {
        cellStyle = xl.CellStyle(
          backgroundColorHex: '#FFEB9C',
          fontColorHex: '#9C5700',
        );
      } else {
        cellStyle = xl.CellStyle(
          backgroundColorHex: '#FFC7CE',
          fontColorHex: '#9C0006',
        );
      }
      cell.cellStyle = cellStyle;
    }
  }
}
      
      // Add summary row
      int summaryRow = _filteredProjectsData.length + 2;
      
      // Calculate totals
      int totalReports = _filteredProjectsData.fold(0, (sum, p) => sum + p.totalReports);
      int totalSubmitted = _filteredProjectsData.fold(0, (sum, p) => sum + p.imagesSubmitted);
      int totalTarget = _filteredProjectsData.fold(0, (sum, p) => sum + p.targetImages);
      double overallPercentage = totalTarget > 0 ? (totalSubmitted / totalTarget * 100) : 0;
      
      // Summary row data
      List<dynamic> summaryData = [
        'TỔNG CỘNG',
        '${_filteredProjectsData.length} dự án',
        totalReports,
        totalSubmitted,
        totalTarget,
        '${overallPercentage.toStringAsFixed(1)}%',
        ''
      ];
      
      // Add summary row to sheet
      for (int i = 0; i < summaryData.length; i++) {
        var cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: summaryRow));
        cell.value = summaryData[i];
        cell.cellStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: '#D9E1F2',
        );
      }
      
      // Add title row
      var titleCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow + 2));
      titleCell.value = 'Báo cáo tiến độ dự án - ${DateFormat('dd/MM/yyyy').format(_selectedDate)}';
      titleCell.cellStyle = xl.CellStyle(
        bold: true,
        fontSize: 14,
      );
      
      // Add generation timestamp
      var timestampCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow + 3));
      timestampCell.value = 'Tạo lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';
      timestampCell.cellStyle = xl.CellStyle(
        italic: true,
        fontSize: 10,
      );
      
      // Generate filename
      String fileName = 'TienDoDuAn_${DateFormat('dd-MM-yyyy').format(_selectedDate)}.xlsx';
      List<int>? fileBytes = excel.save();
      
      if (fileBytes != null) {
        if (choice == 'share') {
          await _handleShare(fileBytes, fileName);
        } else {
          await _handleSaveToAppFolder(fileBytes, fileName);
        }
      } else {
        throw Exception('Không thể tạo file Excel');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tạo file Excel: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      print('Error generating Excel: $e');
    } finally {
      setState(() {
        _isGeneratingExcel = false;
      });
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, () {
      if (mounted && !_isAutoScrolling) {
        _startAutoScroll();
      }
    });
  }

  void _resetInactivityTimer() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
    }
    _startInactivityTimer();
  }

  void _startAutoScroll() {
    if (!mounted || _filteredProjectsData.isEmpty) return; 
    
    setState(() {
      _isAutoScrolling = true;
    });

    _autoScrollTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (!mounted || !_scrollController.hasClients) {
        timer.cancel();
        return;
      }

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final currentOffset = _scrollController.offset;
      
      if (maxScrollExtent <= 0) {
        timer.cancel();
        setState(() {
          _isAutoScrolling = false;
        });
        _startInactivityTimer();
        return;
      }

      if (currentOffset < maxScrollExtent) {
        _scrollController.animateTo(
          currentOffset + 2.0,
          duration: Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      } else {
        timer.cancel();
        _scrollController.animateTo(
          0.0,
          duration: Duration(seconds: 2),
          curve: Curves.easeInOut,
        ).then((_) {
          if (mounted) {
            setState(() {
              _isAutoScrolling = false;
            });
            _startInactivityTimer();
          }
        });
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    setState(() {
      _isAutoScrolling = false;
    });
  }

  Future<void> _initializeDashboard() async {
    await _loadChiTiet2Options();
    await _loadProjectsData();
    _startReloadTimer();
  }

  void _startReloadTimer() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer.periodic(_reloadInterval, (timer) {
      _loadProjectsData();
    });
  }

  Future<void> _loadChiTiet2Options() async {
    try {
      final db = await dbHelper.database;
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT DISTINCT ChiTiet2
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE Ngay >= ? AND Ngay < ?
        AND ChiTiet2 IS NOT NULL AND ChiTiet2 != ''
        ORDER BY ChiTiet2
      ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

      setState(() {
        _chiTiet2Options = results.map((item) => item['ChiTiet2'] as String).toList();
        _chiTiet2Options.insert(0, 'Tất cả');
      });
    } catch (e) {
      print('Error loading ChiTiet2 options: $e');
    }
  }

  bool _shouldFilterProject(String projectName) {
    if (projectName.length < 10) return true;
    if (projectName.toLowerCase().startsWith('hm') && 
        RegExp(r'^hm\d+').hasMatch(projectName.toLowerCase())) return true;
    if (projectName.toLowerCase() == 'unknown') return true;
    if (projectName == projectName.toUpperCase() && !projectName.contains(' ')) return true;
    
    if (projectName.toLowerCase().startsWith('http:') || 
        projectName.toLowerCase().startsWith('https:')) return true;
    
    return false;
  }
Future<Map<String, List<int>>> _getHourlyReports() async {
  try {
    final db = await dbHelper.database;
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    String whereClause = 'WHERE Ngay >= ? AND Ngay < ?';
    List<String> queryParams = [startOfDay.toIso8601String(), endOfDay.toIso8601String()];
    
    if (_selectedChiTiet2 != null && _selectedChiTiet2 != 'Tất cả') {
      whereClause += ' AND ChiTiet2 = ?';
      queryParams.add(_selectedChiTiet2!);
    }

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        BoPhan as project_name,
        Gio as hour_value
      FROM ${DatabaseTables.taskHistoryTable}
      $whereClause
      AND BoPhan IS NOT NULL AND BoPhan != ''
      AND Gio IS NOT NULL AND Gio != ''
      ORDER BY BoPhan, hour_value
    ''', queryParams);

    Map<String, List<int>> projectHours = {};
    
    for (var item in results) {
      final projectName = item['project_name'] as String;
      final hourValue = item['hour_value'];
      
      if (hourValue != null && !_shouldFilterProject(projectName)) {
        int? hour;
        
        // Try to parse hour from different formats
        if (hourValue is int) {
          hour = hourValue;
        } else if (hourValue is String) {
          // Handle formats like "9", "09", "9:00", "09:30", etc.
          final hourStr = hourValue.trim();
          if (hourStr.contains(':')) {
            // Extract hour part from "HH:MM" format
            final parts = hourStr.split(':');
            if (parts.isNotEmpty) {
              hour = int.tryParse(parts[0]);
            }
          } else {
            // Direct hour value
            hour = int.tryParse(hourStr);
          }
        }
        
        if (hour != null && hour >= 0 && hour <= 23) {
          if (!projectHours.containsKey(projectName)) {
            projectHours[projectName] = [];
          }
          if (!projectHours[projectName]!.contains(hour)) {
            projectHours[projectName]!.add(hour);
          }
        }
      }
    }
    
    // Sort hours for each project
    projectHours.forEach((key, value) {
      value.sort();
    });
    
    return projectHours;
  } catch (e) {
    print('Error loading hourly reports: $e');
    return {};
  }
}

Map<String, List<int>> _projectHourlyReports = {};

  Future<void> _loadProjectsData() async {
  if (_isLoading) return;

  setState(() {
    _isLoading = true;
  });

  try {
    final db = await dbHelper.database;
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    String whereClause = 'WHERE Ngay >= ? AND Ngay < ?';
    List<String> queryParams = [startOfDay.toIso8601String(), endOfDay.toIso8601String()];
    
    if (_selectedChiTiet2 != null && _selectedChiTiet2 != 'Tất cả') {
      whereClause += ' AND ChiTiet2 = ?';
      queryParams.add(_selectedChiTiet2!);
    }

    // Load hourly reports data
    final hourlyReports = await _getHourlyReports();

    // First, get project data with user information
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        BoPhan as project_name,
        COUNT(*) as total_reports,
        COUNT(CASE WHEN HinhAnh IS NOT NULL AND HinhAnh != '' THEN 1 END) as images_submitted,
        NguoiDung as main_user,
        COUNT(*) as user_reports
      FROM ${DatabaseTables.taskHistoryTable}
      $whereClause
      GROUP BY BoPhan, NguoiDung
      HAVING BoPhan IS NOT NULL AND BoPhan != ''
      ORDER BY BoPhan, user_reports DESC
    ''', queryParams);

    // Find the main user (most reports) for each project
    Map<String, String> projectMainUsers = {};
    
    for (var item in results) {
      final projectName = item['project_name'] as String;
      final userName = item['main_user'] as String;
      
      if (!projectMainUsers.containsKey(projectName)) {
        projectMainUsers[projectName] = userName;
      }
    }

    // Now get aggregated project data
    final List<Map<String, dynamic>> aggregatedResults = await db.rawQuery('''
      SELECT 
        BoPhan as project_name,
        COUNT(*) as total_reports,
        COUNT(CASE WHEN HinhAnh IS NOT NULL AND HinhAnh != '' THEN 1 END) as images_submitted
      FROM ${DatabaseTables.taskHistoryTable}
      $whereClause
      GROUP BY BoPhan
      HAVING BoPhan IS NOT NULL AND BoPhan != ''
      ORDER BY BoPhan
    ''', queryParams);

    // Count how many projects each user is the main reporter for
    Map<String, int> userProjectCounts = {};
    for (var entry in projectMainUsers.entries) {
      final user = entry.value;
      userProjectCounts[user] = (userProjectCounts[user] ?? 0) + 1;
    }

    // Identify users who are main reporters for multiple projects
    Set<String> multiProjectUsers = userProjectCounts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();

    final allProjectsData = aggregatedResults
        .where((item) => !_shouldFilterProject(item['project_name'] as String))
        .map((item) {
          final projectName = item['project_name'] as String;
          final mainUser = projectMainUsers[projectName] ?? '';
          
          // Apply requirement rules in order of priority
          int targetImages;
          if (projectName.toLowerCase().contains('nhà máy')) {
            targetImages = 0; // Nhà máy projects have 0 requirement
          } else if (projectName.toLowerCase().contains('bệnh viện')) {
            targetImages = 10; // Bệnh viện projects have 10 requirement
          } else if (multiProjectUsers.contains(mainUser)) {
            targetImages = 8; // Projects where main user reports on multiple projects
          } else {
            targetImages = 15; // Default requirement
          }
          
          return ProjectProgress(
            projectName: projectName,
            totalReports: item['total_reports'] as int,
            imagesSubmitted: item['images_submitted'] as int,
            targetImages: targetImages,
          );
        })
        .toList()
        ..sort((a, b) {
          // Handle projects with 0 target (always show as 100%)
          final percentageA = a.targetImages == 0 ? 100.0 : (a.imagesSubmitted / a.targetImages * 100);
          final percentageB = b.targetImages == 0 ? 100.0 : (b.imagesSubmitted / b.targetImages * 100);
          return percentageA.compareTo(percentageB);
        });

    // Filter for display (hide projects with 0 counts)
    final displayProjectsData = allProjectsData
        .where((project) => project.imagesSubmitted > 0)
        .toList();

    setState(() {
      _projectsData = allProjectsData; // Keep all projects for Excel export
      _filteredProjectsData = displayProjectsData; // Only show non-zero projects in UI
      _projectHourlyReports = hourlyReports; // Store hourly reports data
      _lastUpdate = DateTime.now();
    });
  } catch (e) {
    print('Error loading projects data: $e');
    _showError('Lỗi tải dữ liệu dự án: ${e.toString()}');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
Widget _buildHourlyCircles(String projectName) {
  final hours = _projectHourlyReports[projectName] ?? [];
  
  if (hours.isEmpty) {
    return SizedBox.shrink();
  }
  
  return Container(
    padding: EdgeInsets.symmetric(vertical: 2),
    child: Wrap(
      spacing: 4,
      runSpacing: 2,
      children: hours.map((hour) {
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade600,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Center(
            child: Text(
              '$hour',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}
  void _onChiTiet2FilterChanged(String? value) {
    _resetInactivityTimer();
    setState(() {
      _selectedChiTiet2 = value;
    });
    _loadProjectsData();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getProgressColor(double percentage) {
  if (percentage >= 100) return Color(0xFF2E7D32); // Dark green - completed
  if (percentage >= 90) return Color(0xFF388E3C);  // Green - nearly done
  if (percentage >= 70) return Color(0xFF1976D2);  // Blue - good progress
  if (percentage >= 50) return Color(0xFFFF8F00);  // Orange - moderate progress
  if (percentage >= 30) return Color(0xFFE65100);  // Dark orange - low progress
  return Color(0xFFD32F2F);                        // Red - very low progress
}

  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= 1920) {
      return 6;
    } else if (screenWidth >= 1600) {
      return 6; 
    } else if (screenWidth >= 1400) {
      return 5; 
    } else if (screenWidth >= 1200) {
      return 4; 
    } else if (screenWidth >= 900) {
      return 3; 
    } else if (screenWidth >= 600) {
      return 2; 
    } else {
      return 1;
    }
  }

  Widget _buildProjectCard(ProjectProgress project) {
  final percentage = project.targetImages == 0 ? 100.0 : 
                    (project.imagesSubmitted / project.targetImages * 100).clamp(0.0, 100.0);
  final progressColor = _getProgressColor(percentage);

  return Container(
    height: 120,
    margin: EdgeInsets.zero,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: progressColor,
        width: 3,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white,
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage / 100,
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                color: progressColor.withOpacity(0.2),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2, 
                  child: Center(
                    child: Text(
                      project.projectName,
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.1, 
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Hourly circles section
                Container(
                  height: 28,
                  child: _buildHourlyCircles(project.projectName),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          project.targetImages == 0 ? 'N/A' : '${project.imagesSubmitted}/${project.targetImages}',
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: progressColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          project.targetImages == 0 ? 'N/A' : '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildFilterDropdown() {
    return Container(
      constraints: BoxConstraints(maxWidth: 150), 
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: DropdownButton<String>(
        value: _selectedChiTiet2 ?? 'Tất cả',
        hint: Text('Filter', style: TextStyle(fontSize: 12)),
        underline: Container(), 
        isExpanded: true,
        icon: Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(fontSize: 12, color: Colors.black87),
        items: _chiTiet2Options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: _onChiTiet2FilterChanged,
      ),
    );
  }

  Widget _buildDateDropdown() {
    return Container(
      constraints: BoxConstraints(maxWidth: 140),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
       color: Colors.white.withOpacity(0.9),
       borderRadius: BorderRadius.circular(6),
       border: Border.all(color: Colors.grey[400]!),
     ),
     child: DropdownButton<DateTime>(
       value: _selectedDate,
       underline: Container(),
       isExpanded: true,
       icon: Icon(Icons.arrow_drop_down, size: 20),
       style: TextStyle(fontSize: 12, color: Colors.black87),
       items: _availableDates.map((DateTime date) {
         return DropdownMenuItem<DateTime>(
           value: date,
           child: Text(
             DateFormat('dd/MM').format(date),
             style: TextStyle(fontSize: 12),
           ),
         );
       }).toList(),
       onChanged: _onDateChanged,
     ),
   );
 }

 Widget _buildHeader() {
   return AppBar(
     elevation: 0,
     backgroundColor: Color.fromARGB(255, 79, 255, 214),
     leading: IconButton(
       icon: Icon(Icons.arrow_back, color: Colors.black87),
       onPressed: () {
         _resetInactivityTimer();
         Navigator.of(context).pop();
       },
     ),
     title: Row(
       children: [
         Icon(
           Icons.dashboard,
           size: 24, 
           color: Colors.black87,
         ),
         SizedBox(width: 8),
         Text(
           'Tiến độ dự án',
           style: TextStyle(
             fontSize: 20,
             fontWeight: FontWeight.bold,
             color: Colors.black87,
           ),
         ),
         SizedBox(width: 12),
         if (_chiTiet2Options.isNotEmpty) ...[
           _buildFilterDropdown(),
           SizedBox(width: 8),
         ],
         if (_availableDates.isNotEmpty) ...[
           _buildDateDropdown(),
           SizedBox(width: 8),
         ],
         // Excel export button
         Container(
           decoration: BoxDecoration(
             color: Colors.green,
             borderRadius: BorderRadius.circular(6),
           ),
           child: IconButton(
             icon: _isGeneratingExcel 
                 ? SizedBox(
                     width: 16,
                     height: 16,
                     child: CircularProgressIndicator(
                       strokeWidth: 2,
                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                     ),
                   )
                 : Icon(Icons.download, size: 20, color: Colors.white),
             onPressed: _isGeneratingExcel ? null : () {
               _resetInactivityTimer();
               _generateAndShareExcel();
             },
             tooltip: 'Tải xuống Excel',
           ),
         ),
         Container(
  margin: EdgeInsets.only(left: 8),
  decoration: BoxDecoration(
    color: Colors.orange,
    borderRadius: BorderRadius.circular(6),
  ),
  child: TextButton.icon(
    icon: Icon(Icons.analytics, size: 18, color: Colors.white),
    label: Text(
      'Tổng hợp theo bộ phận',
      style: TextStyle(fontSize: 12, color: Colors.white),
    ),
    onPressed: () {
      _resetInactivityTimer();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectTimeline3Single(username: widget.username),
        ),
      );
    },
    style: TextButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
  ),
),
         if (_isAutoScrolling) ...[
           SizedBox(width: 8),
           Icon(
             Icons.auto_awesome_motion,
             size: 16,
             color: Colors.black54,
           ),
         ],
       ],
     ),
     actions: [
       if (_filteredProjectsData.isNotEmpty) ...[  
    Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Text(
          '${_filteredProjectsData.length}/${_filteredProjectsData.where((p) => p.imagesSubmitted >= p.targetImages).length}', // Changed from _projectsData
          style: TextStyle(
            fontSize: 16, 
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  ],
       if (_isLoading)
         Padding(
           padding: EdgeInsets.symmetric(horizontal: 16),
           child: SizedBox(
             width: 20,
             height: 20,
             child: CircularProgressIndicator(
               strokeWidth: 2,
               valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
             ),
           ),
         ),
       if (!_isLoading && _lastUpdate != null)
         Padding(
           padding: EdgeInsets.symmetric(horizontal: 12),
           child: Center(
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(
                   Icons.access_time,
                   size: 16,
                   color: Colors.black54,
                 ),
                 SizedBox(width: 4),
                 Text(
                   '${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}',
                   style: TextStyle(
                     color: Colors.black87,
                     fontSize: 14,
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ],
             ),
           ),
         ),
     ],
   );
 }

@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: _resetInactivityTimer,
    onPanUpdate: (_) => _resetInactivityTimer(),
    child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: _buildHeader(),
      ),
      body: _filteredProjectsData.isEmpty && !_isLoading // Changed from _projectsData to _filteredProjectsData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 72,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Không có dự án ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _resetInactivityTimer();
                      _loadProjectsData();
                    },
                    icon: Icon(Icons.refresh, size: 24),
                    label: Text(
                      'Tải lại',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(8),
              child: GridView.builder(
                controller: _scrollController,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.5, 
                ),
                itemCount: _filteredProjectsData.length, // Changed from _projectsData to _filteredProjectsData
                itemBuilder: (context, index) {
                  return _buildProjectCard(_filteredProjectsData[index]); // Changed from _projectsData to _filteredProjectsData
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          _resetInactivityTimer();
          _loadProjectsData();
        },
        child: Icon(Icons.refresh, size: 27), 
        backgroundColor: Color.fromARGB(255, 79, 255, 214),
        tooltip: 'Tải lại',
      ),
    ),
  );
}
}

// Model class for project progress data
class ProjectProgress {
final String projectName;
final int totalReports;
final int imagesSubmitted;
final int targetImages;

ProjectProgress({
  required this.projectName,
  required this.totalReports,
  required this.imagesSubmitted,
  required this.targetImages,
});
}