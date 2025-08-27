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
import 'projecttimelinemayexcel.dart';

class MachineryUsageReport extends StatefulWidget {
  final String username;

  const MachineryUsageReport({Key? key, required this.username}) : super(key: key);

  @override
  _MachineryUsageReportState createState() => _MachineryUsageReportState();
}

class _MachineryUsageReportState extends State<MachineryUsageReport> 
    with SingleTickerProviderStateMixin {
  bool _isExcelExporting = false;

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
double? _extractAreaM2(String? chiTiet) {
  if (chiTiet == null || chiTiet.trim().isEmpty) return null;

  // Look for a line that (optionally) starts with a bullet, then the label,
  // optional "(m2|m²)", then ":", then the number.
  // Works across multiple lines due to multiLine: true
  final reg = RegExp(
    r'(?:^|[\r\n])\s*[*\-\u2022]?\s*Diện\s*tích\s*sử\s*dụng(?:\s*\((?:m2|m²)\))?\s*:\s*([0-9\.,]+)',
    multiLine: true,
    caseSensitive: false,
    unicode: true,
  );

  final m = reg.firstMatch(chiTiet);
  if (m == null) return null;

  var raw = m.group(1)!.trim();

  // Normalize number to standard "1234.56"
  // vi-style "1.234,5" -> "1234.5"
  // en-style "1,234.5" -> "1234.5"
  if (raw.contains(',') && raw.contains('.')) {
    // assume comma is decimal sep, dot is thousands
    raw = raw.replaceAll('.', '').replaceAll(',', '.');
  } else if (raw.contains(',')) {
    // "125,5" -> "125.5"
    raw = raw.replaceAll(',', '.');
  } else {
    // Handle "1.234" as thousands if looks like ### group
    final dotIdx = raw.indexOf('.');
    if (dotIdx != -1) {
      final tail = raw.substring(dotIdx + 1);
      if (tail.length == 3 && RegExp(r'^\d{3}$').hasMatch(tail)) {
        raw = raw.replaceAll('.', '');
      }
    }
  }

  final v = double.tryParse(raw);
  if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
  return v;
}
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
  Future<void> _exportExcelCsv() async {
  if (_isExcelExporting) return;
  setState(() => _isExcelExporting = true);

  try {
    // Export exactly what user is seeing: _filteredData
    final filePath = await MachineryExcelExporter.exportExcel(
      records: _filteredData,
      selectedPeriod: _selectedPeriod,
    );
    if (!mounted) return;

    final fileDir = File(filePath).parent.path;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xuất Excel (CSV) thành công'),
        content: Text('Đã lưu:\n$filePath'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              MachineryExcelExporter.openFile(filePath);
            },
            child: const Text('Mở file'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              MachineryExcelExporter.openFolder(fileDir);
            },
            child: const Text('Mở thư mục'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Share.shareXFiles([XFile(filePath)], text: 'Báo cáo máy móc ${_selectedPeriod}');
            },
            child: const Text('Chia sẻ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    _showSuccess('Xuất CSV thành công');
  } catch (e) {
    _showError('Lỗi xuất CSV: $e');
  } finally {
    if (mounted) setState(() => _isExcelExporting = false);
  }
}

String _getMachineType(String? chiTiet2) {
  if (chiTiet2 == null || chiTiet2.isEmpty) return 'Không xác định';
  
  final parts = chiTiet2.split('-');
  if (parts.length != 2) return 'Không xác định';
  
  final machineCode = parts[0].toUpperCase();
  
  // Machine type mapping based on your provided data
  final machineTypes = {
    'BD': 'Bộ đàm',
    'BGG': 'Bộ giàn giáo', 
    'BGN': 'Bộ giàn nhỏ',
    'MBN': 'Máy bơm nước',
    'MCC': 'Máy cắt cỏ',
    'MCHA': 'Máy chà hút acquy',
    'MCHDD': 'Máy chà hút dây điện',
    'MDBD': 'Máy đánh bóng đá',
    'MDSC': 'Máy đánh sàn chậm',
    'MDSN': 'Máy đánh sàn nhanh',
    'MG': 'Máy giặt',
    'MHB': 'Máy hút bụi',
    'MHN': 'Máy hút nước',
    'MNL': 'Máy người lái',
    'MPAL': 'Máy phun áp lực',
    'MS': 'Máy sấy',
    'MTT': 'Máy thổi thảm',
    'MTC': 'Máy thông cống',
    'MTL': 'Máy thổi lá',
    'TR': 'Thùng rác',
    'XCDI': 'Xe chở đồ inox',
    'XCRA': 'Xe chở rác acquy',
    'XGRMT': 'Xe gom rác môi trường',
    'XI2X': 'Xe inox 2 xô',
    'XLB': 'Xe làm buồng',
    'XVD': 'Xe vắt đơn',
    'OD': 'Ống dây',
    'DT': 'Điện thoại',
  };
  
  return machineTypes[machineCode] ?? 'Không xác định ($machineCode)';
}
Widget _buildMachineUsageSummary() {
  // Count individual machines and types; also collect which projects used each machine
  final machineUsage = <String, int>{};
  final machineTypeUsage = <String, int>{};
  final machineProjects = <String, Set<String>>{};

  for (final record in _filteredData) {
    final code = record.chiTiet2;
    if (!_isValidMachineCode(code)) continue;

    // count machines
    machineUsage[code!] = (machineUsage[code] ?? 0) + 1;

    // count machine types
    final machineType = _getMachineType(code);
    machineTypeUsage[machineType] = (machineTypeUsage[machineType] ?? 0) + 1;

    // collect projects for this machine
    final bp = record.boPhan;
    if (_isValidProject(bp)) {
      machineProjects.putIfAbsent(code, () => <String>{}).add(bp!.trim());
    }
  }

  // Totals for proper percentages (only from valid machine records)
  final totalMachineEvents = machineUsage.values.fold<int>(0, (a, b) => a + b);

  // Sort by usage count
  final sortedMachines = machineUsage.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final sortedMachineTypes = machineTypeUsage.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê sử dụng máy móc',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          if (machineUsage.isEmpty)
            Center(child: Text('Không có dữ liệu máy móc'))
          else
            Column(
              children: [
                // Machine Types Summary
                ExpansionTile(
                  title: Text(
                    'Loại máy (${sortedMachineTypes.length} loại)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  initiallyExpanded: true,
                  children: [
                    Container(
                      height: 200,
                      child: ListView.builder(
                        itemCount: sortedMachineTypes.length,
                        itemBuilder: (context, index) {
                          final entry = sortedMachineTypes[index];
                          final percentage = totalMachineEvents > 0
                              ? (entry.value / totalMachineEvents * 100)
                              : 0.0;

                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation(Colors.blue),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Individual Machines Summary (with projects used)
                ExpansionTile(
                  title: Text(
                    'Máy cụ thể (${sortedMachines.length} máy)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    Container(
                      height: 300,
                      child: ListView.builder(
                        itemCount: sortedMachines.length,
                        itemBuilder: (context, index) {
                          final entry = sortedMachines[index];
                          final machineType = _getMachineType(entry.key);
                          final percentage = totalMachineEvents > 0
                              ? (entry.value / totalMachineEvents * 100)
                              : 0.0;

                          final projects = (machineProjects[entry.key] ?? <String>{}).toList()..sort();
                          final shown = projects.take(3).toList();
                          final more = projects.length - shown.length;
                          final projectsSummary = projects.isEmpty
                              ? 'Chưa xác định dự án'
                              : (shown.join(', ') + (more > 0 ? ' +$more' : ''));

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(machineType, style: TextStyle(fontSize: 12)),
                                  SizedBox(height: 2),
                                  Text(
                                    'Dự án: $projectsSummary',
                                    style: TextStyle(fontSize: 12, color: Colors.black87),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${entry.value} lần (${percentage.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ),
  );
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
bool _isValidMachineCode(String? code) {
  if (code == null) return false;
  final c = code.trim();
  if (c.isEmpty) return false;
  // Filter out codes that start with "hm" (case-insensitive)
  return !c.toLowerCase().startsWith('hm');
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

  Future<void> _generatePDFReport() async {
  if (_isExporting) return;

  setState(() {
    _isExporting = true;
  });

  try {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/RobotoCondensed-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // ===== Common precomputation (period, counts, etc.) =====
    final dateGroups = <String, int>{};
    final resultCounts = <String, int>{'✔️': 0, '❌': 0, '⚠️': 0};
    final projectData = <String, Map<String, int>>{};
    final allDates = <String>{};

    for (final record in _filteredData) {
      final dateStr = DateFormat('dd/MM').format(record.ngay);
      dateGroups[dateStr] = (dateGroups[dateStr] ?? 0) + 1;
      allDates.add(dateStr);

      if (record.ketQua != null) {
        resultCounts[record.ketQua!] = (resultCounts[record.ketQua!] ?? 0) + 1;
      }

      if (record.boPhan != null && _isValidProject(record.boPhan)) {
        projectData.putIfAbsent(record.boPhan!, () => <String, int>{});
        projectData[record.boPhan!]![dateStr] =
            (projectData[record.boPhan!]![dateStr] ?? 0) + 1;
      }
    }

    final sortedDates = allDates.toList()..sort();
    final sortedProjects = projectData.keys.toList()
      ..sort((a, b) =>
          (projectData[b]!.values.fold<int>(0, (x, y) => x + y))
              .compareTo(projectData[a]!.values.fold<int>(0, (x, y) => x + y)));

    final nonOkIncidents = _filteredData
        .where((r) => r.ketQua == '❌' || r.ketQua == '⚠️')
        .toList();

    final projectIncidents = <String, List<TaskHistoryModel>>{};
    for (final incident in nonOkIncidents) {
      if (incident.boPhan != null && _isValidProject(incident.boPhan)) {
        projectIncidents.putIfAbsent(incident.boPhan!, () => <TaskHistoryModel>[]);
        projectIncidents[incident.boPhan!]!.add(incident);
      }
    }

    final sortedIncidentProjects = projectIncidents.keys.toList()
      ..sort((a, b) => projectIncidents[b]!.length.compareTo(projectIncidents[a]!.length));

    // Build all days in selected month for daily chart-like list
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

    // ===== Page 1: Overview =====
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (context) => [
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

          // Summary
          pw.Text('TỔNG QUAN',
              style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
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

          // Result percentage
          pw.Text('KẾT QUẢ THEO PHẦN TRĂM',
              style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          if (_filteredData.isEmpty)
            pw.Text('Không có dữ liệu', style: pw.TextStyle(font: ttf, fontSize: 12))
          else
            pw.Column(
              children: resultCounts.entries.map((entry) {
                final percentage =
                    _filteredData.isNotEmpty ? (entry.value / _filteredData.length * 100) : 0.0;
                final barWidth = 200.0;
                final fillWidth = barWidth * (percentage / 100);
                final color = entry.key == '✔️'
                    ? PdfColors.green
                    : entry.key == '❌'
                        ? PdfColors.red
                        : PdfColors.orange;
                return pw.Padding(
                  padding: pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 15,
                        height: 15,
                        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(2)),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        width: 80,
                        child: pw.Text(_formatKetQua(entry.key), style: pw.TextStyle(font: ttf, fontSize: 12)),
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
                                  color: color,
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
          pw.SizedBox(height: 20),

          // Daily counts (as tags)
          pw.Text('SỐ LƯỢNG BÁO CÁO THEO NGÀY',
              style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text(
            'Biểu đồ cột thể hiện số lượng báo cáo theo từng ngày trong tháng ${DateFormat('MM/yyyy').format(selectedDate)}',
            style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Wrap(
              spacing: 4,
              runSpacing: 4,
              children: allDateEntries
                  .where((e) => e.value > 0)
                  .map((e) => pw.Container(
                        padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text('${e.key}: ${e.value}', style: pw.TextStyle(font: ttf, fontSize: 9)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );

    // ===== Page 2: Machine usage statistics (filtered hm*, show projects) =====
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (context) {
          // Build machine stats with filters + project aggregation
          final machineUsage = <String, int>{};
          final machineTypeUsage = <String, int>{};
          final machineProjects = <String, Set<String>>{};

          for (final record in _filteredData) {
            final code = record.chiTiet2;
            if (!_isValidMachineCode(code)) continue;

            machineUsage[code!] = (machineUsage[code] ?? 0) + 1;

            final machineType = _getMachineType(code);
            machineTypeUsage[machineType] = (machineTypeUsage[machineType] ?? 0) + 1;

            final bp = record.boPhan;
            if (_isValidProject(bp)) {
              machineProjects.putIfAbsent(code, () => <String>{}).add(bp!.trim());
            }
          }

          final sortedMachineTypes = machineTypeUsage.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final sortedMachines = machineUsage.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final totalMachineEvents =
              machineUsage.values.fold<int>(0, (a, b) => a + b);

          return [
            // Header
            pw.Row(
              children: [
                pw.Container(
                  width: 30,
                  height: 30,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Center(
                    child: pw.Text('🔧', style: pw.TextStyle(color: PdfColors.white, fontSize: 16)),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Text(
                  'THỐNG KÊ SỬ DỤNG MÁY MÓC',
                  style: pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Spacer(),
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'Tháng ${DateFormat('MM/yyyy').format(DateTime.parse('${_selectedPeriod}-01'))}',
                    style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Summary cards
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue200),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('${sortedMachineTypes.length}',
                          style: pw.TextStyle(
                              font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text('Loại máy', style: pw.TextStyle(font: ttf, fontSize: 12)),
                    ],
                  ),
                  pw.Container(width: 1, height: 40, color: PdfColors.blue200),
                  pw.Column(
                    children: [
                      pw.Text('${sortedMachines.length}',
                          style: pw.TextStyle(
                              font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text('Máy cụ thể', style: pw.TextStyle(font: ttf, fontSize: 12)),
                    ],
                  ),
                  pw.Container(width: 1, height: 40, color: PdfColors.blue200),
                  pw.Column(
                    children: [
                      pw.Text('${totalMachineEvents}',
                          style: pw.TextStyle(
                              font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text('Lượt sử dụng', style: pw.TextStyle(font: ttf, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            // Machine types table
            pw.Text('THỐNG KÊ THEO LOẠI MÁY',
                style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            if (sortedMachineTypes.isEmpty)
              pw.Text('Không có dữ liệu máy móc', style: pw.TextStyle(font: ttf, fontSize: 12))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(4),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.blue100),
                    children: [
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Loại máy', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Số lần', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Tỷ lệ', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(6),
                        child: pw.Text('Biểu đồ', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...sortedMachineTypes.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final row = e.value;
                    final pct = totalMachineEvents > 0 ? (row.value / totalMachineEvents * 100) : 0.0;
                    final barWidth = 100.0;
                    final fillWidth = barWidth * (pct / 100);
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.grey50 : PdfColors.white),
                      children: [
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('$idx', style: pw.TextStyle(font: ttf, fontSize: 10))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(row.key, style: pw.TextStyle(font: ttf, fontSize: 10))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('${row.value}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('${pct.toStringAsFixed(1)}%', style: pw.TextStyle(font: ttf, fontSize: 10))),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(6),
                          child: pw.Container(
                            width: barWidth,
                            height: 8,
                            decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4)),
                            child: pw.Stack(
                              children: [
                                if (fillWidth > 0)
                                  pw.Container(
                                    width: fillWidth,
                                    height: 8,
                                    decoration: pw.BoxDecoration(color: PdfColors.blue, borderRadius: pw.BorderRadius.circular(4)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 25),

            // Individual machines table (with project list)
            pw.Text('CHI TIẾT TỪNG MÁY',
                style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            if (sortedMachines.isEmpty)
              pw.Text('Không có dữ liệu máy cụ thể', style: pw.TextStyle(font: ttf, fontSize: 12))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(4),
                  3: pw.FlexColumnWidth(3), // Dự án
                  4: pw.FlexColumnWidth(2),
                  5: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.green100),
                    children: [
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Mã máy', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Loại máy', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Dự án', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))), // NEW
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Số lần', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Tỷ lệ', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...sortedMachines.take(20).toList().asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final row = e.value;
                    final machineType = _getMachineType(row.key);
                    final pct = totalMachineEvents > 0 ? (row.value / totalMachineEvents * 100) : 0.0;

                    final projects = (machineProjects[row.key] ?? <String>{}).toList()..sort();
                    final shown = projects.take(3).toList();
                    final more = projects.length - shown.length;
                    final projectsSummary = projects.isEmpty ? '—' : (shown.join(', ') + (more > 0 ? ' +$more' : ''));

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: idx % 2 == 0 ? PdfColors.grey50 : PdfColors.white),
                      children: [
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('$idx', style: pw.TextStyle(font: ttf, fontSize: 10))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(row.key, style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(machineType, style: pw.TextStyle(font: ttf, fontSize: 9))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(projectsSummary, style: pw.TextStyle(font: ttf, fontSize: 9))), // NEW
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('${row.value}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('${pct.toStringAsFixed(1)}%', style: pw.TextStyle(font: ttf, fontSize: 10))),
                      ],
                    );
                  }),
                ],
              ),

            if (sortedMachines.length > 20) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.yellow50,
                  border: pw.Border.all(color: PdfColors.yellow200),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Lưu ý: Chỉ hiển thị 20 máy được sử dụng nhiều nhất. Tổng số máy: ${sortedMachines.length}',
                  style: pw.TextStyle(font: ttf, fontSize: 10, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],

            pw.SizedBox(height: 20),
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TÓM TẮT THỐNG KÊ:',
                      style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  if (sortedMachineTypes.isNotEmpty)
                    pw.Text('• Loại máy được sử dụng nhiều nhất: ${sortedMachineTypes.first.key} (${sortedMachineTypes.first.value} lần)',
                        style: pw.TextStyle(font: ttf, fontSize: 10)),
                  if (sortedMachines.isNotEmpty)
                    pw.Text('• Máy cụ thể được sử dụng nhiều nhất: ${sortedMachines.first.key} (${sortedMachines.first.value} lần)',
                        style: pw.TextStyle(font: ttf, fontSize: 10)),
                  pw.Text('• Tổng lượt sử dụng tất cả máy: $totalMachineEvents lần',
                      style: pw.TextStyle(font: ttf, fontSize: 10)),
                  pw.Text(
                    '• Trung bình mỗi máy được sử dụng: ${machineUsage.isNotEmpty ? (totalMachineEvents / machineUsage.length).toStringAsFixed(1) : 0} lần',
                    style: pw.TextStyle(font: ttf, fontSize: 10),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // ===== Page 3: Project detail table =====
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Text('DANH SÁCH DỰ ÁN CHI TIẾT',
              style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('Tổng số dự án: ${sortedProjects.length}',
              style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),

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
                    ...sortedDates.take(15).map(
                      (d) => pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(d.split('/')[0],
                            style: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                ...sortedProjects.take(20).map((project) {
                  final totalCount = projectData[project]!.values.fold<int>(0, (x, y) => x + y);
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
                        child: pw.Text('$totalCount', style: pw.TextStyle(font: ttf, fontSize: 9)),
                      ),
                      ...sortedDates.take(15).map((d) {
                        final c = projectData[project]![d] ?? 0;
                        return pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              color: c > 0 ? PdfColors.green100 : PdfColors.grey100,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                c > 0 ? '$c' : '-',
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 8,
                                  color: c > 0 ? PdfColors.green800 : PdfColors.grey600,
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

          if (sortedProjects.length > 20) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Lưu ý: Chỉ hiển thị 20 dự án đầu tiên. Tổng số dự án: ${sortedProjects.length}',
              style: pw.TextStyle(font: ttf, fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ],
      ),
    );

    // ===== Page 4: Incidents =====
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
                  decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(2)),
                  child: pw.Center(
                    child: pw.Text('!', style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text('SỰ CỐ KHÔNG ĐẠT YÊU CẦU',
                    style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Spacer(),
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(color: PdfColors.red100, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text('Tổng: ${nonOkIncidents.length}',
                      style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            ...sortedIncidentProjects.map((project) {
              final incidents = projectIncidents[project]!;
              final incidentDates = incidents.map((i) => DateFormat('dd/MM').format(i.ngay)).toSet().toList()..sort();
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
                            style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 12),
                            maxLines: 2,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(color: PdfColors.red200, borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Text('${incidents.length} sự cố',
                              style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        if (failureCount > 0)
                          pw.Container(
                            padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(color: PdfColors.red100, borderRadius: pw.BorderRadius.circular(3)),
                            child: pw.Text('Không làm: $failureCount', style: pw.TextStyle(font: ttf, fontSize: 9)),
                          ),
                        if (failureCount > 0) pw.SizedBox(width: 6),
                        if (warningCount > 0)
                          pw.Container(
                            padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(color: PdfColors.orange100, borderRadius: pw.BorderRadius.circular(3)),
                            child: pw.Text('Chưa tốt: $warningCount', style: pw.TextStyle(font: ttf, fontSize: 9)),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Ngày xảy ra: ${incidentDates.join(", ")}',
                        style: pw.TextStyle(font: ttf, fontSize: 10, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    } else {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 60, height: 60,
                  decoration: pw.BoxDecoration(color: PdfColors.green, shape: pw.BoxShape.circle),
                  child: pw.Center(
                    child: pw.Text('✓', style: pw.TextStyle(color: PdfColors.white, fontSize: 30, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('KHÔNG CÓ SỰ CỐ NÀO TRONG KỲ NÀY',
                    style: pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                pw.SizedBox(height: 8),
                pw.Text('Tất cả báo cáo đều đạt yêu cầu', style: pw.TextStyle(font: ttf, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    // ===== Save & Share =====
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
  return Column(
    children: [
      // Add project filter at the top
      Container(
        padding: EdgeInsets.all(16),
        color: Colors.grey[50],
        child: Row(
          children: [
            Icon(Icons.filter_list, color: Colors.grey[600]),
            SizedBox(width: 8),
            Text(
              'Lọc theo dự án:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 16),
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
            if (_selectedProject != null && _selectedProject != 'Tất cả')
              IconButton(
                icon: Icon(Icons.clear, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _selectedProject = 'Tất cả';
                    _applyFilters();
                  });
                },
                tooltip: 'Xóa bộ lọc',
              ),
          ],
        ),
      ),
      // Existing summary content
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportCountChart(),
              SizedBox(height: 24),
              _buildResultPercentage(),
              SizedBox(height: 24),
              _buildMachineUsageSummary(),  // ADD THIS LINE
              SizedBox(height: 24),
              _buildProjectList(),
              SizedBox(height: 24),
              _buildNonOkIncidents(),
            ],
          ),
        ),
      ),
    ],
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

  // NEW: total area per project
  final projectAreaTotals = <String, double>{};

  // Collect all dates in the period + counts + area
  for (final record in _filteredData) {
    final dateStr = DateFormat('dd/MM').format(record.ngay);
    allDates.add(dateStr);

    final proj = record.boPhan;
    if (proj != null && _isValidProject(proj)) {
      projectData.putIfAbsent(proj, () => {});
      projectData[proj]![dateStr] = (projectData[proj]![dateStr] ?? 0) + 1;

      // NEW: extract and sum area
      final area = _extractAreaM2(record.chiTiet);
      if (area != null) {
        projectAreaTotals[proj] = (projectAreaTotals[proj] ?? 0) + area;
      }
    }
  }

  final sortedDates = allDates.toList()..sort();

  // Sort projects by total count desc (as before)
final sortedProjects = projectData.keys.toList()
  ..sort((a, b) => (projectData[b]!.values.fold<int>(0, (x, y) => x + y))
      .compareTo(projectData[a]!.values.fold<int>(0, (x, y) => x + y)));

  final numFmt = NumberFormat.decimalPattern('vi_VN'); // for nicer area rendering

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
                    label: SizedBox(
                      width: 240,
                      child: Text('Dự án', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // NEW: Area column inserted BEFORE Tổng
                  DataColumn(
                    label: Text('Diện tích (m²)', style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text('Tổng', style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                  // Show ALL dates
                  ...sortedDates.map((date) => DataColumn(
                        label: Text(date, style: TextStyle(fontSize: 12)),
                      )),
                ],
                rows: sortedProjects.map((project) {
                  final totalCount = projectData[project]!.values.fold<int>(0, (a, b) => a + b);

                  final area = projectAreaTotals[project] ?? 0.0;
                  // Show empty string if area == 0 and no records had an area parsed
                  final areaCellText = area > 0
                      ? numFmt.format(area)
                      : ''; // keep it visually clean when no area parsed

                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 240,
                          child: Text(
                            project,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      // NEW: area cell
                      DataCell(
                        Text(
                          areaCellText,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                      DataCell(Text(
                        totalCount.toString(),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()]),
                      )),
                      // All dates
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
                // Fix: Combine date and time properly
                '${DateFormat('dd/MM/yyyy').format(record.ngay)} ${record.gio ?? ''}',
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
// Excel (CSV) Export button
IconButton(
  icon: _isExcelExporting
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
      : const Icon(Icons.grid_on),
  onPressed: _isExcelExporting ? null : _exportExcelCsv,
  tooltip: 'Xuất Excel (CSV)',
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