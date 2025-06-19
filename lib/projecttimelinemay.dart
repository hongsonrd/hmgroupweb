import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'http_client.dart';
import 'dart:math' as math;

class MachineryUsageReport extends StatefulWidget {
  final String username;

  const MachineryUsageReport({Key? key, required this.username}) : super(key: key);

  @override
  _MachineryUsageReportState createState() => _MachineryUsageReportState();
}

class _MachineryUsageReportState extends State<MachineryUsageReport> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  bool _isLoading = false;
  bool _isExporting = false;
  List<TaskHistoryModel> _allData = [];
  List<TaskHistoryModel> _filteredData = [];
  
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app/historybaocaomay';
  String _syncStatus = '';
  
  // Filter controls
  String _selectedPeriod = '';
  List<String> _availablePeriods = [];
  String? _selectedProject;
  String? _selectedKetQua;
  List<String> _availableProjects = ['Tất cả'];
  List<String> _availableKetQua = ['Tất cả', '✔️', '❌', '⚠️'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupAutoSync();
    _initializePeriods();
    _checkAndSync();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupAutoSync() {
    // Auto sync every 30 minutes
    Stream.periodic(Duration(minutes: 30)).listen((_) {
      if (mounted) _checkAndSync();
    });
  }

  void _initializePeriods() {
    final now = DateTime.now();
    _availablePeriods = List.generate(12, (index) {
      final date = DateTime(now.year, now.month - index, 1);
      return DateFormat('yyyy-MM').format(date);
    });
    _selectedPeriod = DateFormat('yyyy-MM').format(now);
  }

  Future<void> _checkAndSync() async {
    if (await _shouldSync()) {
      await _syncData();
    } else {
      await _loadData();
    }
  }

  Future<bool> _shouldSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('lastMachinerySync') ?? 0;
    final lastSyncDate = prefs.getString('lastMachinerySyncDate') ?? '';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Sync if: first time today OR more than 30 minutes passed
    return lastSyncDate != today || (now - lastSync) > 30 * 60 * 1000;
  }

  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setInt('lastMachinerySync', DateTime.now().millisecondsSinceEpoch);
    await prefs.setString('lastMachinerySyncDate', today);
  }

  Future<void> _syncData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ dữ liệu máy móc...';
    });

    try {
      final response = await AuthenticatedHttpClient.get(
        Uri.parse('$baseUrl')
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        await dbHelper.clearTable(DatabaseTables.taskHistoryTable);

        final taskHistories = data.map((item) => TaskHistoryModel(
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
        )).toList();

        await dbHelper.batchInsertTaskHistory(taskHistories);
        await _updateLastSyncTime();
        
        _showSuccess('Đồng bộ thành công');
        await _loadData();
      } else {
        throw Exception('Failed to sync data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing machinery data: $e');
      _showError('Không thể đồng bộ: ${e.toString()}');
      await _loadData(); // Load cached data
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT * FROM ${DatabaseTables.taskHistoryTable}
        WHERE strftime('%Y-%m', Ngay) = ?
        ORDER BY Ngay DESC, Gio DESC
      ''', [_selectedPeriod]);

      final allData = results.map((item) => TaskHistoryModel(
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
      )).toList();

      setState(() {
        _allData = allData;
        _loadAvailableProjects();
        _applyFilters();
      });
    } catch (e) {
      print('Error loading machinery data: $e');
      _showError('Lỗi tải dữ liệu');
    }
  }

  void _loadAvailableProjects() {
    final projects = _allData
        .where((item) => _isValidProject(item.boPhan))
        .map((item) => item.boPhan!)
        .toSet()
        .toList()
        ..sort();
    
    setState(() {
      _availableProjects = ['Tất cả', ...projects];
      if (_selectedProject != null && !_availableProjects.contains(_selectedProject)) {
        _selectedProject = 'Tất cả';
      }
    });
  }

  bool _isValidProject(String? boPhan) {
    if (boPhan == null || boPhan.trim().isEmpty) return false;
    if (boPhan.length <= 6) return false;
    
    final lowerBoPhan = boPhan.toLowerCase();
    if (lowerBoPhan.startsWith('hm') || lowerBoPhan.startsWith('http')) return false;
    
    if (boPhan == boPhan.toUpperCase() && !boPhan.contains(' ')) {
      return false;
    }
    
    return true;
  }

  void _applyFilters() {
    List<TaskHistoryModel> filtered = List.from(_allData);
    
    if (_selectedProject != null && _selectedProject != 'Tất cả') {
      filtered = filtered.where((item) => item.boPhan == _selectedProject).toList();
    }
    
    if (_selectedKetQua != null && _selectedKetQua != 'Tất cả') {
      filtered = filtered.where((item) => item.ketQua == _selectedKetQua).toList();
    }
    
    setState(() {
      _filteredData = filtered;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  // Generate PDF Report - Enhanced with detailed content (Fixed)
Future<void> _generatePDFReport() async {
  if (_isExporting) return;
  
  setState(() {
    _isExporting = true;
  });

  try {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/RobotoCondensed-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // Prepare all data similar to Tab 1
    final dateGroups = <String, int>{};
    final resultCounts = <String, int>{'✔️': 0, '❌': 0, '⚠️': 0};
    final projectData = <String, Map<String, int>>{};
    final allDates = <String>{};

    // Process data
    for (final record in _filteredData) {
      final dateStr = DateFormat('dd/MM').format(record.ngay);
      dateGroups[dateStr] = (dateGroups[dateStr] ?? 0) + 1;
      allDates.add(dateStr);
      
      if (record.ketQua != null) {
        resultCounts[record.ketQua!] = (resultCounts[record.ketQua!] ?? 0) + 1;
      }
      
      if (record.boPhan != null && _isValidProject(record.boPhan)) {
        if (!projectData.containsKey(record.boPhan!)) {
          projectData[record.boPhan!] = {};
        }
        projectData[record.boPhan!]![dateStr] = 
            (projectData[record.boPhan!]![dateStr] ?? 0) + 1;
      }
    }

    final sortedDates = allDates.toList()..sort();
    final sortedProjects = projectData.keys.toList()
      ..sort((a, b) => (projectData[b]!.values.fold(0, (a, b) => a + b))
          .compareTo(projectData[a]!.values.fold(0, (a, b) => a + b)));

    // Filter non-OK incidents
    final nonOkIncidents = _filteredData.where((record) => 
      record.ketQua == '❌' || record.ketQua == '⚠️'
    ).toList();

    // Group incidents by project
    final projectIncidents = <String, List<TaskHistoryModel>>{};
    for (final incident in nonOkIncidents) {
      if (incident.boPhan != null && _isValidProject(incident.boPhan)) {
        if (!projectIncidents.containsKey(incident.boPhan!)) {
          projectIncidents[incident.boPhan!] = [];
        }
        projectIncidents[incident.boPhan!]!.add(incident);
      }
    }

    final sortedIncidentProjects = projectIncidents.keys.toList()
      ..sort((a, b) => projectIncidents[b]!.length.compareTo(projectIncidents[a]!.length));

    // Generate all dates in the selected month for chart data
    final selectedDate = DateTime.parse('${_selectedPeriod}-01');
    final year = selectedDate.year;
    final month = selectedDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    
    final allDateEntries = <MapEntry<String, int>>[];
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dateStr = DateFormat('dd/MM').format(date);
      final count = dateGroups[dateStr] ?? 0;
      allDateEntries.add(MapEntry(dateStr, count));
    }

    // Create PDF with multiple pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BÁO CÁO SỬ DỤNG MÁY MÓC',
                  style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Thời gian: ${DateFormat('MM/yyyy').format(selectedDate)}',
                  style: pw.TextStyle(font: ttf, fontSize: 14),
                ),
                pw.Text(
                  'Ngày tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Summary section
          pw.Text(
            'TỔNG QUAN',
            style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Tổng số báo cáo: ${_filteredData.length}', 
                  style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Số dự án tham gia: ${sortedProjects.length}', 
                  style: pw.TextStyle(font: ttf, fontSize: 12)),
                pw.Text('Số sự cố không đạt: ${nonOkIncidents.length}', 
                  style: pw.TextStyle(font: ttf, fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Result percentage section
          pw.Text(
            'KẾT QUẢ THEO PHẦN TRĂM',
            style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          if (_filteredData.length == 0)
            pw.Text('Không có dữ liệu', style: pw.TextStyle(font: ttf, fontSize: 12))
          else
            pw.Container(
              child: pw.Column(
                children: resultCounts.entries.map((entry) {
                  final percentage = _filteredData.length > 0 ? (entry.value / _filteredData.length * 100) : 0.0;
                  final barWidth = 200.0; // Total width for progress bar
                  final fillWidth = barWidth * (percentage / 100);
                  
                  return pw.Padding(
                    padding: pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 15,
                          height: 15,
                          decoration: pw.BoxDecoration(
                            color: entry.key == '✔️' ? PdfColors.green : 
                                   entry.key == '❌' ? PdfColors.red : PdfColors.orange,
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Container(
                          width: 80,
                          child: pw.Text(_formatKetQua(entry.key), 
                            style: pw.TextStyle(font: ttf, fontSize: 12)),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Container(
                          width: barWidth,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Stack(
                            children: [
                              if (fillWidth > 0)
                                pw.Container(
                                  width: fillWidth,
                                  height: 12,
                                  decoration: pw.BoxDecoration(
                                    color: entry.key == '✔️' ? PdfColors.green : 
                                           entry.key == '❌' ? PdfColors.red : PdfColors.orange,
                                    borderRadius: pw.BorderRadius.circular(6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text('${entry.value} (${percentage.toStringAsFixed(1)}%)', 
                          style: pw.TextStyle(font: ttf, fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          pw.SizedBox(height: 20),
          
          // Daily report chart data
          pw.Text(
            'SỐ LƯỢNG BÁO CÁO THEO NGÀY',
            style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Biểu đồ cột thể hiện số lượng báo cáo theo từng ngày trong tháng ${DateFormat('MM/yyyy').format(selectedDate)}',
            style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 8),
          // Create a simple text representation of the chart
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Wrap(
              spacing: 4,
              runSpacing: 4,
              children: allDateEntries.where((entry) => entry.value > 0).map((entry) {
                return pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    '${entry.key}: ${entry.value}',
                    style: pw.TextStyle(font: ttf, fontSize: 9),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );

    // Second page for project details
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Text(
            'DANH SÁCH DỰ ÁN CHI TIẾT',
            style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Tổng số dự án: ${sortedProjects.length}',
            style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),
          
          // Project table
          if (projectData.isEmpty)
            pw.Text('Không có dữ liệu dự án', style: pw.TextStyle(font: ttf, fontSize: 12))
          else
            pw.Table(
              columnWidths: {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(1),
                ...Map.fromIterables(
                  List.generate(math.min(sortedDates.length, 15), (i) => i + 2),
                  List.generate(math.min(sortedDates.length, 15), (i) => pw.FlexColumnWidth(0.8)),
                ),
              },
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Dự án', 
                        style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Tổng', 
                        style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    ...sortedDates.take(15).map((date) => pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(date.split('/')[0], // Show only day
                        style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    )),
                  ],
                ),
                // Data rows
                ...sortedProjects.take(20).map((project) { // Limit to first 20 projects for PDF
                  final totalCount = projectData[project]!.values.fold(0, (a, b) => a + b);
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          project.length > 40 ? '${project.substring(0, 37)}...' : project,
                          style: pw.TextStyle(font: ttf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(totalCount.toString(),
                          style: pw.TextStyle(font: ttf, fontSize: 9)),
                      ),
                      ...sortedDates.take(15).map((date) {
                        final count = projectData[project]![date] ?? 0;
                        return pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              color: count > 0 ? PdfColors.green100 : PdfColors.grey100,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                count > 0 ? count.toString() : '-',
                                style: pw.TextStyle(
                                  font: ttf, 
                                  fontSize: 8,
                                  color: count > 0 ? PdfColors.green800 : PdfColors.grey600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          
          if (sortedProjects.length > 20)
            pw.SizedBox(height: 10),
          if (sortedProjects.length > 20)
            pw.Text(
              'Lưu ý: Chỉ hiển thị 20 dự án đầu tiên. Tổng số dự án: ${sortedProjects.length}',
              style: pw.TextStyle(font: ttf, fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
        ],
      ),
    );

    // Third page for incidents
    if (nonOkIncidents.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (context) => [
            pw.Row(
              children: [
                pw.Container(
                  width: 20,
                  height: 20,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Center(
                    child: pw.Text('!', 
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  'SỰ CỐ KHÔNG ĐẠT YÊU CẦU',
                  style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Spacer(),
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'Tổng: ${nonOkIncidents.length}',
                    style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            
            ...sortedIncidentProjects.map((project) {
              final incidents = projectIncidents[project]!;
              final incidentDates = incidents.map((i) => DateFormat('dd/MM').format(i.ngay)).toSet().toList()
                ..sort();
              
              final failureCount = incidents.where((i) => i.ketQua == '❌').length;
              final warningCount = incidents.where((i) => i.ketQua == '⚠️').length;

              return pw.Container(
                margin: pw.EdgeInsets.only(bottom: 12),
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  border: pw.Border.all(color: PdfColors.red200),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            project,
                            style: pw.TextStyle(
                              font: ttf,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red200,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            '${incidents.length} sự cố',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        if (failureCount > 0) ...[
                          pw.Container(
                            padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.red100,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              'Không làm: $failureCount',
                              style: pw.TextStyle(font: ttf, fontSize: 9),
                            ),
                          ),
                          pw.SizedBox(width: 6),
                        ],
                        if (warningCount > 0) ...[
                          pw.Container(
                            padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.orange100,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              'Chưa tốt: $warningCount',
                              style: pw.TextStyle(font: ttf, fontSize: 9),
                            ),
                          ),
                        ],
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Ngày xảy ra: ${incidentDates.join(", ")}',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    } else {
      // Add a page showing no incidents
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 60,
                  height: 60,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text('✓', 
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 30, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'KHÔNG CÓ SỰ CỐ NÀO TRONG KỲ NÀY',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Tất cả báo cáo đều đạt yêu cầu',
                  style: pw.TextStyle(font: ttf, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/machinery_report_detailed_${_selectedPeriod}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], 
      text: 'Báo cáo chi tiết sử dụng máy móc ${_selectedPeriod}');
      
    _showSuccess('Xuất PDF chi tiết thành công');
  } catch (e) {
    print('Error generating PDF: $e');
    _showError('Lỗi xuất PDF: ${e.toString()}');
  } finally {
    setState(() {
      _isExporting = false;
    });
  }
}

  String _formatKetQua(String? ketQua) {
    if (ketQua == null) return '';
    switch (ketQua) {
      case '✔️': return 'Đạt';
      case '❌': return 'Không làm';
      case '⚠️': return 'Chưa tốt';
      default: return ketQua;
    }
  }

  Color _getStatusColor(String? ketQua) {
    if (ketQua == null) return Colors.grey;
    switch (ketQua) {
      case '✔️': return Colors.green;
      case '❌': return Colors.red;
      case '⚠️': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportCountChart(),
          SizedBox(height: 24),
          _buildResultPercentage(),
          SizedBox(height: 24),
          _buildProjectList(),
          SizedBox(height: 24),
        _buildNonOkIncidents(),
        ],
      ),
    );
  }

  Widget _buildReportCountChart() {
  final dateGroups = <String, int>{};
  
  // First, populate with actual data
  for (final record in _filteredData) {
    final dateStr = DateFormat('dd/MM').format(record.ngay);
    dateGroups[dateStr] = (dateGroups[dateStr] ?? 0) + 1;
  }

  // Generate all dates in the selected month
  final selectedDate = DateTime.parse('${_selectedPeriod}-01');
  final year = selectedDate.year;
  final month = selectedDate.month;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  
  // Create entries for all days in the month
  final allDateEntries = <MapEntry<String, int>>[];
  for (int day = 1; day <= daysInMonth; day++) {
    final date = DateTime(year, month, day);
    final dateStr = DateFormat('dd/MM').format(date);
    final count = dateGroups[dateStr] ?? 0;
    allDateEntries.add(MapEntry(dateStr, count));
  }

  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số lượng báo cáo theo ngày (${DateFormat('MM/yyyy').format(selectedDate)})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Container(
            height: 250, // Increased height for better visibility
            child: allDateEntries.isEmpty
                ? Center(child: Text('Không có dữ liệu'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: math.max(MediaQuery.of(context).size.width - 64, allDateEntries.length * 25.0),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: allDateEntries.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b) + 2,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.blueGrey,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final date = allDateEntries[group.x.toInt()].key;
                                final count = rod.toY.round();
                                return BarTooltipItem(
                                  '$date\n$count báo cáo',
                                  TextStyle(color: Colors.white, fontSize: 12),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: daysInMonth > 20 ? 2 : 1, // Show every 2nd day for months > 20 days
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < allDateEntries.length) {
                                    // Show only day number for space efficiency
                                    final dayOnly = allDateEntries[index].key.split('/')[0];
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        dayOnly,
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    );
                                  }
                                  return Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: allDateEntries.asMap().entries.map((entry) {
                            final hasData = entry.value.value > 0;
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.value.toDouble(),
                                  color: hasData ? Colors.blue : Colors.grey[300],
                                  width: daysInMonth > 20 ? 12 : 16,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                                ),
                              ],
                            );
                          }).toList(),
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

  Widget _buildResultPercentage() {
    final resultCounts = <String, int>{'✔️': 0, '❌': 0, '⚠️': 0};
    for (final record in _filteredData) {
      if (record.ketQua != null) {
        resultCounts[record.ketQua!] = (resultCounts[record.ketQua!] ?? 0) + 1;
      }
    }

    final total = _filteredData.length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kết quả theo phần trăm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            if (total == 0)
              Center(child: Text('Không có dữ liệu'))
            else
              Column(
                children: resultCounts.entries.map((entry) {
                  final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getStatusColor(entry.key),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Text(_formatKetQua(entry.key)),
                        ),
                        Expanded(
                          flex: 3,
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(_getStatusColor(entry.key)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('${entry.value} (${percentage.toStringAsFixed(1)}%)'),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList() {
  final projectData = <String, Map<String, int>>{};
  final allDates = <String>{};

  // Collect all dates in the period
  for (final record in _filteredData) {
    final dateStr = DateFormat('dd/MM').format(record.ngay);
    allDates.add(dateStr);
    
    if (record.boPhan != null && _isValidProject(record.boPhan)) {
      if (!projectData.containsKey(record.boPhan!)) {
        projectData[record.boPhan!] = {};
      }
      projectData[record.boPhan!]![dateStr] = 
          (projectData[record.boPhan!]![dateStr] ?? 0) + 1;
    }
  }

  final sortedDates = allDates.toList()..sort();
  final sortedProjects = projectData.keys.toList()
    ..sort((a, b) => (projectData[b]!.values.fold(0, (a, b) => a + b))
        .compareTo(projectData[a]!.values.fold(0, (a, b) => a + b)));

  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Danh sách dự án',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tổng: ${sortedProjects.length} dự án',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (projectData.isEmpty)
            Center(child: Text('Không có dữ liệu'))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                columns: [
                  DataColumn(
                    label: Container(
                      width: 240,
                      child: Text(
                        'Dự án',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  DataColumn(label: Text('Tổng')),
                  // Show ALL dates, not just 10
                  ...sortedDates.map((date) => DataColumn(
                    label: Text(date, style: TextStyle(fontSize: 12)),
                  )),
                ],
                rows: sortedProjects.map((project) { // Show ALL projects, not just 10
                  final totalCount = projectData[project]!.values.fold(0, (a, b) => a + b);
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          width: 240,
                          child: Text(
                            project,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      DataCell(Text(totalCount.toString())),
                      // Show ALL dates
                      ...sortedDates.map((date) {
                        final count = projectData[project]![date] ?? 0;
                        return DataCell(
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: count > 0 ? Colors.green[100] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                count > 0 ? count.toString() : '-',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: count > 0 ? Colors.green[800] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    ),
  );
}
Widget _buildNonOkIncidents() {
  // Filter non-OK incidents (❌ and ⚠️)
  final nonOkIncidents = _filteredData.where((record) => 
    record.ketQua == '❌' || record.ketQua == '⚠️'
  ).toList();

  if (nonOkIncidents.isEmpty) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sự cố không đạt yêu cầu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 48, color: Colors.green),
                  SizedBox(height: 8),
                  Text(
                    'Không có sự cố nào trong kỳ này',
                    style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Group incidents by project
  final projectIncidents = <String, List<TaskHistoryModel>>{};
  for (final incident in nonOkIncidents) {
    if (incident.boPhan != null && _isValidProject(incident.boPhan)) {
      if (!projectIncidents.containsKey(incident.boPhan!)) {
        projectIncidents[incident.boPhan!] = [];
      }
      projectIncidents[incident.boPhan!]!.add(incident);
    }
  }

  // Sort projects by incident count (descending)
  final sortedProjects = projectIncidents.keys.toList()
    ..sort((a, b) => projectIncidents[b]!.length.compareTo(projectIncidents[a]!.length));

  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'Sự cố không đạt yêu cầu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tổng: ${nonOkIncidents.length}',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...sortedProjects.map((project) {
            final incidents = projectIncidents[project]!;
            final incidentDates = incidents.map((i) => DateFormat('dd/MM').format(i.ngay)).toSet().toList()
              ..sort();
            
            // Group by incident type
            final failureCount = incidents.where((i) => i.ketQua == '❌').length;
            final warningCount = incidents.where((i) => i.ketQua == '⚠️').length;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                //border: Border.left(color: Colors.red, width: 4),
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.red[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${incidents.length} sự cố',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      if (failureCount > 0) ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '❌ $failureCount',
                            style: TextStyle(fontSize: 11, color: Colors.red[700]),
                          ),
                        ),
                        SizedBox(width: 4),
                      ],
                      if (warningCount > 0) ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⚠️ $warningCount',
                            style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ngày xảy ra: ${incidentDates.join(", ")}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    ),
  );
}
  Widget _buildDetailTab() {
    return Column(
      children: [
        // Filters
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedProject ?? 'Tất cả',
                  isExpanded: true,
                  items: _availableProjects.map((project) {
                    return DropdownMenuItem<String>(
                      value: project,
                      child: Text(
                        project,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProject = value;
                      _applyFilters();
                    });
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedKetQua ?? 'Tất cả',
                  isExpanded: true,
                  items: _availableKetQua.map((ketQua) {
                    return DropdownMenuItem<String>(
                      value: ketQua,
                      child: Text(_formatKetQua(ketQua)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedKetQua = value;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // Records list
        Expanded(
          child: _filteredData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.report_off, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'Không có báo cáo nào',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredData.length,
                  itemBuilder: (context, index) {
                    final record = _filteredData[index];
                    return _buildRecordItem(record);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecordItem(TaskHistoryModel record) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _getStatusColor(record.ketQua),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          record.boPhan ?? 'Không có dự án',
          style: TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.chiTiet ?? 'Không có mô tả',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(record.ngay),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (record.hinhAnh?.isNotEmpty == true) ...[
                  SizedBox(width: 8),
                  Icon(Icons.image, size: 16, color: Colors.blue),
                ],
              ],
            ),
          ],
        ),
        trailing: Text(
          _formatKetQua(record.ketQua),
          style: TextStyle(
            color: _getStatusColor(record.ketQua),
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => _showRecordDetail(record),
      ),
    );
  }

  void _showRecordDetail(TaskHistoryModel record) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chi tiết báo cáo máy móc',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Thời gian', '${DateFormat('dd/MM/yyyy').format(record.ngay)} ${record.gio ?? ''}'),
                        _buildDetailRow('Dự án', record.boPhan ?? ''),
                        _buildDetailRow('Vị trí', record.viTri ?? ''),
                        _buildDetailRow('Phân loại', record.phanLoai ?? ''),
                        _buildDetailRow('Kết quả', _formatKetQua(record.ketQua)),
                        _buildDetailRow('Chi tiết', record.chiTiet ?? ''),
                        if (record.chiTiet2?.isNotEmpty == true)
                          _buildDetailRow('Chi tiết 2', record.chiTiet2!),
                        if (record.giaiPhap?.isNotEmpty == true)
                          _buildDetailRow('Giải pháp', record.giaiPhap!),
                        if (record.hinhAnh?.isNotEmpty == true) ...[
                          SizedBox(height: 16),
                          Text(
                            'Hình ảnh:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            constraints: BoxConstraints(maxHeight: 300),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                record.hinhAnh!,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null)
                                  return child;
                                 return Container(
                                   height: 200,
                                   child: Center(
                                     child: CircularProgressIndicator(
                                       value: loadingProgress.expectedTotalBytes != null
                                           ? loadingProgress.cumulativeBytesLoaded /
                                               loadingProgress.expectedTotalBytes!
                                           : null,
                                     ),
                                   ),
                                 );
                               },
                               errorBuilder: (context, error, stackTrace) {
                                 print('Image load error: $error');
                                 return Container(
                                   height: 200,
                                   decoration: BoxDecoration(
                                     color: Colors.grey[200],
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: Column(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     children: [
                                       Icon(
                                         Icons.broken_image,
                                         size: 64,
                                         color: Colors.grey[400],
                                       ),
                                       SizedBox(height: 8),
                                       Text(
                                         'Không thể tải hình ảnh',
                                         style: TextStyle(
                                           color: Colors.grey[600],
                                         ),
                                       ),
                                     ],
                                   ),
                                 );
                               },
                             ),
                           ),
                         ),
                       ],
                     ],
                   ),
                 ),
               ),
               Container(
                 padding: EdgeInsets.all(16),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                     TextButton(
                       onPressed: () => Navigator.of(context).pop(),
                       child: Text('Đóng'),
                     ),
                   ],
                 ),
               ),
             ],
           ),
         ),
       );
     },
   );
 }

 Widget _buildDetailRow(String label, String value) {
   return Padding(
     padding: EdgeInsets.symmetric(vertical: 6),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           label + ':',
           style: TextStyle(
             fontWeight: FontWeight.bold,
             fontSize: 14,
           ),
         ),
         SizedBox(height: 2),
         Text(
           value,
           style: TextStyle(fontSize: 14),
         ),
       ],
     ),
   );
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: Text('Báo cáo máy móc - ${widget.username.toUpperCase()}'),
       flexibleSpace: Container(
         decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topLeft,
             end: Alignment.bottomRight,
             colors: [
               Color.fromARGB(255, 255, 193, 7),
               Color.fromARGB(255, 255, 235, 59),
               Color.fromARGB(255, 255, 152, 0),
               Color.fromARGB(255, 255, 224, 130),
             ],
           ),
         ),
       ),
       bottom: TabBar(
         controller: _tabController,
         tabs: [
           Tab(text: 'Tổng quan', icon: Icon(Icons.analytics)),
           Tab(text: 'Chi tiết', icon: Icon(Icons.list)),
         ],
       ),
       actions: [
         // Period selector
         Container(
           padding: EdgeInsets.symmetric(horizontal: 8),
           child: DropdownButton<String>(
             value: _selectedPeriod,
             dropdownColor: Colors.white,
             underline: Container(),
             items: _availablePeriods.map((period) {
               return DropdownMenuItem<String>(
                 value: period,
                 child: Text(
                   DateFormat('MM/yyyy').format(DateTime.parse('$period-01')),
                   style: TextStyle(color: Colors.black87),
                 ),
               );
             }).toList(),
             onChanged: (value) {
               if (value != null) {
                 setState(() {
                   _selectedPeriod = value;
                 });
                 _loadData();
               }
             },
             icon: Icon(Icons.calendar_month, color: Colors.black87),
           ),
         ),
         // PDF Export button
         IconButton(
           icon: _isExporting 
             ? SizedBox(
                 width: 20,
                 height: 20,
                 child: CircularProgressIndicator(
                   strokeWidth: 2,
                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                 ),
               )
             : Icon(Icons.picture_as_pdf),
           onPressed: _isExporting ? null : _generatePDFReport,
           tooltip: 'Xuất PDF',
         ),
         // Manual sync button
         IconButton(
           icon: _isLoading 
             ? SizedBox(
                 width: 20,
                 height: 20,
                 child: CircularProgressIndicator(
                   strokeWidth: 2,
                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                 ),
               )
             : Icon(Icons.sync),
           onPressed: _isLoading ? null : _syncData,
           tooltip: 'Đồng bộ dữ liệu',
         ),
       ],
     ),
     body: Column(
       children: [
         if (_syncStatus.isNotEmpty)
           Container(
             width: double.infinity,
             padding: EdgeInsets.all(16),
             color: Colors.orange[50],
             child: Text(
               _syncStatus,
               style: TextStyle(
                 color: Colors.orange[700],
                 fontWeight: FontWeight.bold,
               ),
               textAlign: TextAlign.center,
             ),
           ),
         Expanded(
           child: TabBarView(
             controller: _tabController,
             children: [
               _buildSummaryTab(),
               _buildDetailTab(),
             ],
           ),
         ),
       ],
     ),
   );
 }
}