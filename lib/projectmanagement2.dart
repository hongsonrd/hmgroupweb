import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_state.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'projectviewscreen.dart';
import 'projectworkreport.dart';
import 'projectmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'projectdailyview.dart';
import 'dart:typed_data' show Uint8List;
import 'package:sqflite/sqflite.dart';
import 'http_client.dart';
import 'package:file_picker/file_picker.dart';
import 'projecttimeline.dart';
import 'projecttimeline2.dart';
import 'dart:math' as Math;
import 'dart:async';

class ProjectManagement2 extends StatefulWidget {
    ProjectManagement2({Key? key}) : super(key: key);
  @override
  _ProjectManagement2State createState() => _ProjectManagement2State();
}

class SearchableDropdown extends StatefulWidget {
  final String value;
  final List<String> items;
  final Function(String?) onChanged;
  final String hintText;

  SearchableDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hintText,
  });

  @override
  _SearchableDropdownState createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
  }

  @override
  void didUpdateWidget(SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _filteredItems = List.from(widget.items);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height,
        width: size.width,
        child: Material(
          elevation: 4,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: 250,
              minHeight: 50,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _filteredItems = widget.items
                            .where((item) => item.toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return ListTile(
                        title: Text(item),
                        selected: item == widget.value,
                        onTap: () {
                          widget.onChanged(item);
                          _hideOverlay();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
    setState(() {});
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
    _searchController.clear();
    setState(() {
      _filteredItems = widget.items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleDropdown,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.value.isEmpty ? widget.hintText : widget.value,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectManagement2State extends State<ProjectManagement2> {
  final UserState _userState = UserState();
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  String? _selectedBoPhan;
  String? _selectedDate;
  List<String> _boPhanList = [];
  List<String> _dateList = [];
  String _syncStatus = '';
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  String? _selectedStartDate;
  String? _selectedEndDate;
  String? userType;
  final Map<String, GlobalKey> _chartKeys = {
  'phanLoaiChart': GlobalKey(),
  'issueResolutionChart': GlobalKey(),
  'issueTypeChart': GlobalKey(),
};
String _formatKetQua(Object? ketQua) {
    if (ketQua == null) return '';
    final ketQuaStr = ketQua.toString();
    switch (ketQuaStr) {
      case '✔️':
        return 'Đạt';
      case '❌':
        return 'Không làm';
      case '⚠️':
        return 'Chưa tốt';
      default:
        return ketQuaStr;
    }
  }
  @override
  void initState() {
    super.initState();
    _loadUserType(); 
    _loadInitialData();
    Future.delayed(Duration(milliseconds: 100), () {
    if (mounted) {
      _loadProjects();
    }
  });
Future.delayed(Duration(seconds: 2), () {
    _checkAndLoadHistory();
  });
  }
  Future<void> _loadInitialData() async {
  await _loadBoPhanList();
  await _loadDateList();
  if (_selectedDate != null) {
    await _loadTaskHistoryData();
  }
}
Future<void> _exportToPDF() async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Đang tạo báo cáo..."),
          ],
        ),
      ),
    );

    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username.toUpperCase();
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final fontData = await rootBundle.load("assets/fonts/RobotoCondensed-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final logoImage = await rootBundle.load('assets/logo2.png');
    final logo = pw.MemoryImage((logoImage.buffer.asUint8List()));
    final pdf = pw.Document();
    final phanLoaiChart = await _captureChart('phanLoaiChart');
    final issueResolutionChart = await _captureChart('issueResolutionChart');
    final issueTypeChart = await _captureChart('issueTypeChart');

    // First page with header and stats
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            color: PdfColor.fromHex('#FF0000'),
            padding: pw.EdgeInsets.all(10),
            child: pw.Row(
              children: [
                pw.Image(logo, width: 50, height: 50),
                pw.SizedBox(width: 10),
                pw.Expanded(child: pw.Text('BÁO CÁO THỐNG KÊ', 
                  style: pw.TextStyle(font: ttf, fontSize: 24, color: PdfColor.fromHex('#FFFFFF'))))
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Ngày giờ: ${formatter.format(now)}', style: pw.TextStyle(font: ttf)),
          pw.Text('Người dùng: $username', style: pw.TextStyle(font: ttf)),
          pw.Divider(),
          pw.Text('Khoảng thời gian: $_selectedStartDate đến $_selectedEndDate', style: pw.TextStyle(font: ttf)),
          pw.Text('Bộ phận: $_selectedBoPhan', style: pw.TextStyle(font: ttf)),
          pw.Text('Danh sách bộ phận: ${_boPhanList.where((dept) => dept != 'Tất cả').join(", ")}', 
            style: pw.TextStyle(font: ttf)),
          pw.SizedBox(height: 20),
          pw.Text('Thống kê tổng quan:', style: pw.TextStyle(font: ttf, fontSize: 16)),
          pw.Text('- Số lượt báo cáo: $totalReports', style: pw.TextStyle(font: ttf)),
          pw.Text('- Số dự án báo cáo: $uniqueProjects', style: pw.TextStyle(font: ttf)),
          pw.Text('- Số vấn đề xảy ra: $issuesCount', style: pw.TextStyle(font: ttf)),
          
          if (phanLoaiChart != null) ...[
            pw.SizedBox(height: 20),
            pw.Text('Chủ đề báo cáo', style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Expanded(flex: 2, child: pw.Image(pw.MemoryImage(phanLoaiChart), height: 180)),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: phanLoaiStats.map((item) => pw.Text('${item['name']}: ${item['value']}', 
                  style: pw.TextStyle(font: ttf))).toList(),
              ))
            ])
          ],
        ],
      ),
    ));

    // Second page with remaining charts
    if (issueResolutionChart != null || issueTypeChart != null) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (issueResolutionChart != null) ...[
              pw.Text('Tỉ lệ vấn đề được giải quyết', 
                style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Expanded(flex: 2, child: pw.Image(pw.MemoryImage(issueResolutionChart), height: 180)),
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: issueResolutionStats.map((item) => pw.Text('${item['name']}: ${item['value']}',
                    style: pw.TextStyle(font: ttf))).toList(),
                ))
              ]),
              pw.SizedBox(height: 30),
            ],
            
            if (issueTypeChart != null) ...[
              pw.Text('Phân loại vấn đề', 
                style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Expanded(flex: 2, child: pw.Image(pw.MemoryImage(issueTypeChart), height: 180)),
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: issuePhanLoaiStats.map((item) => pw.Text('${item['name']}: ${item['value']}',
                    style: pw.TextStyle(font: ttf))).toList(),
                ))
              ])
            ],
          ],
        ),
      ));
    }

    final output = await getTemporaryDirectory();
    final pdfFile = File('${output.path}/bao_cao_${_selectedStartDate}_${_selectedEndDate}.pdf');
    await pdfFile.writeAsBytes(await pdf.save());
    final excelFile = await _generateExcel();

    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Đang chia sẻ báo cáo..."),
          ],
        ),
      ),
    );

    await Share.shareFiles([pdfFile.path, excelFile.path], text: 'Báo cáo thống kê');
    Navigator.pop(context);

  } catch (e) {
    Navigator.pop(context);
    print('Error exporting report: $e');
    _showError('Không thể xuất báo cáo: ${e.toString()}');
  }
}

Future<Uint8List?> _captureChart(String chartId) async {
  try {
    print('Attempting to capture chart: $chartId');
    final key = _chartKeys[chartId];
    if (key == null) {
      print('Key not found for chart: $chartId');
      return null;
    }
    if (key.currentContext == null) {
      print('No context found for chart: $chartId');
      return null;
    }
    final RenderRepaintBoundary boundary = 
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      print('Failed to get byte data for chart: $chartId');
      return null;
    }
    print('Successfully captured chart: $chartId');
    return byteData.buffer.asUint8List();
  } catch (e) {
    print('Error capturing chart $chartId: $e');
    return null;
  }
}
String _getWeekNumber(DateTime date) {
  int weekNumber = date.difference(date.subtract(Duration(days: date.weekday - 1))).inDays ~/ 7 + 1;
  return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
}

String _getMonthYear(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

Future<void> _addSupervisorReport(Sheet sheet, List<Map<String, dynamic>> groupedData, DBHelper dbHelper) async {
  sheet.appendRow([
    'Thời gian', 'Bộ phận', 'Nhân sự Đủ', 'Nhân sự Thiếu', 'Chất lượng đạt', 'CL phát sinh',
    'Vật tư đủ', 'Vật tư vấn đề', 'Máy móc đủ', 'Máy móc vấn đề',
    'Xe/Giỏ đồ đủ', 'Xe/Giỏ đồ vấn đề', 'Ý kiến KH đạt', 'Ý kiến KH vấn đề'
  ]);

  for (var group in groupedData) {
    String dateRange = group['dateRange'];
    String startDate = group['startDate'];
    String endDate = group['endDate'];

    String boPhanQuery = 'SELECT DISTINCT BoPhan FROM ${DatabaseTables.vtHistoryTable} WHERE date(Ngay) BETWEEN ? AND ?';
    List<dynamic> boPhanArgs = [startDate, endDate];
    if (_selectedBoPhan != 'Tất cả') {
      boPhanQuery += ' AND BoPhan = ?';
      boPhanArgs.add(_selectedBoPhan);
    }
  final db = await dbHelper.database;
    final boPhanList = await db.rawQuery(boPhanQuery, boPhanArgs);
    for (var boPhan in boPhanList) {
      final currentBoPhan = boPhan['BoPhan'];

      final statusQuery = '''
        SELECT ViTri, TrangThai FROM ${DatabaseTables.vtHistoryTable}
        WHERE date(Ngay) BETWEEN ? AND ? AND BoPhan = ?
        GROUP BY ViTri HAVING date(Ngay) = MAX(date(Ngay))
      ''';
      final statusResults = await db.rawQuery(statusQuery, [startDate, endDate, currentBoPhan]);

      List<String> sufficient = [];
      List<String> insufficient = [];
      for (var status in statusResults) {
        if (status['TrangThai'] == 'Đang làm việc') {
          sufficient.add(status['ViTri'].toString());
        } else {
          insufficient.add('${status['ViTri']} (${status['TrangThai']})');
        }
      }

      Future<Map<String, List<String>>> getCategoryStats(String category) async {
        final query = '''
          SELECT KetQua, ChiTiet, ChiTiet2 FROM ${DatabaseTables.taskHistoryTable}
          WHERE date(Ngay) BETWEEN ? AND ? AND BoPhan = ? AND PhanLoai = ?
        ''';
        final results = await db.rawQuery(query, [startDate, endDate, currentBoPhan, category]);
        
        List<String> passed = [];
        List<String> failed = [];
        for (var result in results) {
          String detail = result['ChiTiet'].toString();
          if (result['ChiTiet2'] != null && result['ChiTiet2'].toString().isNotEmpty) {
            detail += ' (${result['ChiTiet2']})';
          }
          if (result['KetQua'] == '✔️') {
            passed.add(detail);
          } else {
            failed.add(detail);
          }
        }
        return {'passed': passed, 'failed': failed};
      }

      final qualityStats = await getCategoryStats('Kiểm tra chất lượng');
      final qualityStats2 = await getCategoryStats('Chất lượng');
      final suppliesStats = await getCategoryStats('Vật tư');
      final machineStats = await getCategoryStats('Máy móc');
      final cartStats = await getCategoryStats('Xe/Giỏ đồ');
      final customerStats = await getCategoryStats('Ý kiến khách hàng');

      List<String> passedQuality = [...qualityStats['passed']!, ...qualityStats2['passed']!];
      List<String> failedQuality = [...qualityStats['failed']!, ...qualityStats2['failed']!];

      sheet.appendRow([
        dateRange,
        currentBoPhan,
        '${sufficient.length}\n${sufficient.join("\n")}',
        '${insufficient.length}\n${insufficient.join("\n")}',
        '${passedQuality.length}\n${passedQuality.join("\n")}',
        '${failedQuality.length}\n${failedQuality.join("\n")}',
        '${suppliesStats['passed']!.length}\n${suppliesStats['passed']!.join("\n")}',
        '${suppliesStats['failed']!.length}\n${suppliesStats['failed']!.join("\n")}',
        '${machineStats['passed']!.length}\n${machineStats['passed']!.join("\n")}',
        '${machineStats['failed']!.length}\n${machineStats['failed']!.join("\n")}',
        '${cartStats['passed']!.length}\n${cartStats['passed']!.join("\n")}',
        '${cartStats['failed']!.length}\n${cartStats['failed']!.join("\n")}',
        '${customerStats['passed']!.length}\n${customerStats['passed']!.join("\n")}',
        '${customerStats['failed']!.length}\n${customerStats['failed']!.join("\n")}',
      ]);
    }
  }
}
Future<File> _generateExcel() async {
 final excel = Excel.createExcel();
 final db = await dbHelper.database;
 final interactionSheet = excel['Tương tác'];
interactionSheet.appendRow([
  'Ngày', 'Giờ', 'Người dùng', 'Bộ phận', 'Giám sát', 
  'Nội dung', 'Chủ đề', 'Phân loại'
]);

String interactionQuery = '''
  SELECT * FROM ${DatabaseTables.interactionTable}
  WHERE date(Ngay) BETWEEN ? AND ?
''';
List<dynamic> interactionArgs = [_selectedStartDate, _selectedEndDate];

if (_selectedBoPhan != 'Tất cả') {
  interactionQuery += ' AND BoPhan = ?';
  interactionArgs.add(_selectedBoPhan);
}
interactionQuery += ' ORDER BY date(Ngay) DESC, Gio DESC';

final interactionResults = await db.rawQuery(interactionQuery, interactionArgs);
for (var row in interactionResults) {
  interactionSheet.appendRow([
    row['Ngay'],
    row['Gio'],
    row['NguoiDung'],
    row['BoPhan'],
    row['GiamSat'],
    row['NoiDung'],
    row['ChuDe'],
    row['PhanLoai']
  ]);
}
 final summarySheet = excel['Tổng hợp theo ngày'];
 
 summarySheet.appendRow(['Ngày', 'Bộ phận', 'Số báo cáo', 'Số vấn đề', 'Vấn đề chưa giải quyết']);

 String summaryQuery = '''
   SELECT date(Ngay) as date, BoPhan, COUNT(*) as report_count,
   SUM(CASE WHEN KetQua != '✔️' THEN 1 ELSE 0 END) as issue_count,
   SUM(CASE WHEN KetQua != '✔️' AND (GiaiPhap IS NULL OR trim(GiaiPhap) = '') THEN 1 ELSE 0 END) as unresolved_count
   FROM ${DatabaseTables.taskHistoryTable}
   WHERE date(Ngay) BETWEEN ? AND ?
 ''';
 
 List<dynamic> summaryArgs = [_selectedStartDate, _selectedEndDate];
 if (_selectedBoPhan != 'Tất cả') {
   summaryQuery += ' AND BoPhan = ?';
   summaryArgs.add(_selectedBoPhan);
 }
 summaryQuery += ' GROUP BY date(Ngay), BoPhan ORDER BY date DESC, BoPhan';

 final summaryResults = await db.rawQuery(summaryQuery, summaryArgs);
 for (var row in summaryResults) {
   summarySheet.appendRow([row['date'], row['BoPhan'], row['report_count'], row['issue_count'], row['unresolved_count']]);
 }

 final detailSheet = excel['Chi tiết báo cáo'];
 detailSheet.appendRow(['Ngày', 'Giờ', 'Bộ phận', 'Vị trí', 'Phân loại', 'Kết quả', 'Chi tiết', 'Lịch làm việc', 'Giải pháp', 'Hình ảnh']);

 String detailQuery = 'SELECT * FROM ${DatabaseTables.taskHistoryTable} WHERE date(Ngay) BETWEEN ? AND ?';
 List<dynamic> detailArgs = [_selectedStartDate, _selectedEndDate];
 if (_selectedBoPhan != 'Tất cả') {
   detailQuery += ' AND BoPhan = ?';
   detailArgs.add(_selectedBoPhan);
 }
 detailQuery += ' ORDER BY date(Ngay) DESC, Gio DESC';

 final detailResults = await db.rawQuery(detailQuery, detailArgs);
 for (var row in detailResults) {
   detailSheet.appendRow([
     row['Ngay'], row['Gio'], row['BoPhan'], row['ViTri'], row['PhanLoai'],
     _formatKetQua(row['KetQua']), row['ChiTiet'], row['ChiTiet2'], 
     row['GiaiPhap'], row['HinhAnh'] ?? ''
   ]);
 }

 final personnelSheet = excel['Báo cáo nhân sự'];
 List<String> dateRange = [];
 DateTime startDate = DateTime.parse(_selectedStartDate!);
 DateTime endDate = DateTime.parse(_selectedEndDate!);
 for (var date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
   dateRange.add(DateFormat('yyyy-MM-dd').format(date));
 }

 List<dynamic> headers = ['Bộ phận', 'Vị trí'];
 headers.addAll(dateRange);
 personnelSheet.appendRow(headers);

 String vtQuery = '''
   SELECT DISTINCT BoPhan, ViTri FROM ${DatabaseTables.vtHistoryTable}
   WHERE date(Ngay) BETWEEN ? AND ?
 ''';
 List<dynamic> vtArgs = [_selectedStartDate, _selectedEndDate];
 if (_selectedBoPhan != 'Tất cả') {
   vtQuery += ' AND BoPhan = ?';
   vtArgs.add(_selectedBoPhan);
 }
 vtQuery += ' ORDER BY BoPhan, ViTri';

 final locations = await db.rawQuery(vtQuery, vtArgs);
 for (var location in locations) {
   List<dynamic> row = [location['BoPhan'], location['ViTri']];
   String? lastStatus;
   for (String date in dateRange) {
     final statusQuery = '''
       SELECT TrangThai, PhuongAn, HoTro FROM ${DatabaseTables.vtHistoryTable}
       WHERE date(Ngay) = ? AND BoPhan = ? AND ViTri = ?
       ORDER BY Gio DESC LIMIT 1
     ''';
     final statusResult = await db.rawQuery(statusQuery, [date, location['BoPhan'], location['ViTri']]);
     if (statusResult.isNotEmpty) {
       final entry = statusResult.first;
       lastStatus = _formatStatus(entry['TrangThai']?.toString(), entry['PhuongAn']?.toString(), entry['HoTro']?.toString());
     }
     row.add(lastStatus ?? '');
   }
   personnelSheet.appendRow(row);
 }

 final supervisorSheet = excel['Báo cáo giám sát'];
supervisorSheet.appendRow([
  'Ngày', 'Bộ phận', 'Nhân sự Đủ', 'Nhân sự Thiếu', 'Chất lượng đạt', 'Chất lượng vấn đề',
  'Vật tư đủ', 'Vật tư vấn đề', 'Máy móc đủ', 'Máy móc vấn đề',
  'Xe/Giỏ đồ đủ', 'Xe/Giỏ đồ vấn đề', 'Ý kiến KH đạt', 'Ý kiến KH vấn đề'
]);

for (String date in dateRange) {
  String boPhanQuery = 'SELECT DISTINCT BoPhan FROM ${DatabaseTables.vtHistoryTable} WHERE date(Ngay) <= ?';
  List<dynamic> boPhanArgs = [date];
  if (_selectedBoPhan != 'Tất cả') {
    boPhanQuery += ' AND BoPhan = ?';
    boPhanArgs.add(_selectedBoPhan);
  }

  final boPhanList = await db.rawQuery(boPhanQuery, boPhanArgs);
  for (var boPhan in boPhanList) {
    final currentBoPhan = boPhan['BoPhan'];
    
    // Personnel status query remains the same
    final statusQuery = '''
      SELECT ViTri, TrangThai FROM ${DatabaseTables.vtHistoryTable}
      WHERE date(Ngay) <= ? AND BoPhan = ?
      GROUP BY ViTri HAVING MAX(date(Ngay))
    ''';
    final statusResults = await db.rawQuery(statusQuery, [date, currentBoPhan]);

    List<String> sufficient = [];
    List<String> insufficient = [];
    for (var status in statusResults) {
      if (status['TrangThai'] == 'Đang làm việc') {
        sufficient.add(status['ViTri'].toString());
      } else {
        insufficient.add('${status['ViTri']} (${status['TrangThai']})');
      }
    }

    // Function to get category stats
    Future<Map<String, List<String>>> getCategoryStats(String category) async {
      final query = '''
        SELECT KetQua, ChiTiet, ChiTiet2 FROM ${DatabaseTables.taskHistoryTable}
        WHERE date(Ngay) = ? AND BoPhan = ? AND PhanLoai = ?
      ''';
      final results = await db.rawQuery(query, [date, currentBoPhan, category]);
      
      List<String> passed = [];
      List<String> failed = [];
      for (var result in results) {
        String detail = result['ChiTiet'].toString();
        if (result['ChiTiet2'] != null && result['ChiTiet2'].toString().isNotEmpty) {
          detail += ' (${result['ChiTiet2']})';
        }
        if (result['KetQua'] == '✔️') {
          passed.add(detail);
        } else {
          failed.add(detail);
        }
      }
      return {'passed': passed, 'failed': failed};
    }

    // Get stats for each category
    final qualityStats = await getCategoryStats('Kiểm tra chất lượng');
    final qualityStats2 = await getCategoryStats('Chất lượng');
    final suppliesStats = await getCategoryStats('Vật tư');
    final machineStats = await getCategoryStats('Máy móc');
    final cartStats = await getCategoryStats('Xe/Giỏ đồ');
    final customerStats = await getCategoryStats('Ý kiến khách hàng');

    // Combine quality stats
    List<String> passedQuality = [...qualityStats['passed']!, ...qualityStats2['passed']!];
    List<String> failedQuality = [...qualityStats['failed']!, ...qualityStats2['failed']!];

    supervisorSheet.appendRow([
      date,
      currentBoPhan,
      '${sufficient.length}\n${sufficient.join("\n")}',
      '${insufficient.length}\n${insufficient.join("\n")}',
      '${passedQuality.length}\n${passedQuality.join("\n")}',
      '${failedQuality.length}\n${failedQuality.join("\n")}',
      '${suppliesStats['passed']!.length}\n${suppliesStats['passed']!.join("\n")}',
      '${suppliesStats['failed']!.length}\n${suppliesStats['failed']!.join("\n")}',
      '${machineStats['passed']!.length}\n${machineStats['passed']!.join("\n")}',
      '${machineStats['failed']!.length}\n${machineStats['failed']!.join("\n")}',
      '${cartStats['passed']!.length}\n${cartStats['passed']!.join("\n")}',
      '${cartStats['failed']!.length}\n${cartStats['failed']!.join("\n")}',
      '${customerStats['passed']!.length}\n${customerStats['passed']!.join("\n")}',
      '${customerStats['failed']!.length}\n${customerStats['failed']!.join("\n")}',
    ]);
  }
}

final weeklySheet = excel['Báo cáo tuần'];
final monthlySheet = excel['Báo cáo tháng'];

// Group data by weeks
List<Map<String, dynamic>> weeklyGroups = [];
DateTime currentDate = startDate;
while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
  DateTime weekStart = currentDate.subtract(Duration(days: currentDate.weekday - 1));
  DateTime weekEnd = weekStart.add(Duration(days: 6));
  if (weekEnd.isAfter(endDate)) weekEnd = endDate;
  
  weeklyGroups.add({
    'dateRange': 'Tuần ${_getWeekNumber(currentDate)}',
    'startDate': DateFormat('yyyy-MM-dd').format(weekStart),
    'endDate': DateFormat('yyyy-MM-dd').format(weekEnd),
  });
  
  currentDate = weekEnd.add(Duration(days: 1));
}

// Group data by months
List<Map<String, dynamic>> monthlyGroups = [];
currentDate = startDate;
while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
  DateTime monthStart = DateTime(currentDate.year, currentDate.month, 1);
  DateTime monthEnd = DateTime(currentDate.year, currentDate.month + 1, 0);
  if (monthEnd.isAfter(endDate)) monthEnd = endDate;
  
  monthlyGroups.add({
    'dateRange': 'Tháng ${_getMonthYear(currentDate)}',
    'startDate': DateFormat('yyyy-MM-dd').format(monthStart),
    'endDate': DateFormat('yyyy-MM-dd').format(monthEnd),
  });
  
  currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
}

await _addSupervisorReport(weeklySheet, weeklyGroups, dbHelper);
await _addSupervisorReport(monthlySheet, monthlyGroups, dbHelper);

 for (var table in excel.tables.keys) {
   final sheet = excel.tables[table]!;
   for (var colIndex = 0; colIndex < sheet.maxCols; colIndex++) {
     sheet.setColWidth(colIndex, table == 'Báo cáo giám sát' ? 35.0 : 25.0);
   }
 }

 // Generate the Excel file with a unique filename including timestamp
 final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
 final fileName = 'BaoCaoTongHop_${_selectedStartDate}_${_selectedEndDate}_$dateStr.xlsx';
 final fileBytes = excel.encode()!;
 
 // Platform-specific saving logic
 if (Platform.isWindows) {
   try {
     // First attempt: Use file_picker save dialog to let user choose location
     String? outputFile = await FilePicker.platform.saveFile(
       dialogTitle: 'Lưu báo cáo tổng hợp',
       fileName: fileName,
       type: FileType.custom,
       allowedExtensions: ['xlsx'],
     );
     
     if (outputFile != null) {
       // User selected a location
       final file = File(outputFile);
       await file.writeAsBytes(fileBytes);
       
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('File đã được lưu tại: $outputFile'),
           backgroundColor: Colors.green,
         ),
       );
       
       return file;
     } else {
       // If user cancels dialog, fall back to saving in Downloads folder
       return await _saveToDownloadsWindows(fileBytes, fileName);
     }
   } catch (e) {
     // If FilePicker fails, fall back to Documents folder
     return await _saveToDocumentsWindows(fileBytes, fileName);
   }
 } else {
   // For mobile platforms, save to temp directory and use Share.shareFiles
   final output = await getTemporaryDirectory();
   final file = File('${output.path}/$fileName');
   await file.writeAsBytes(fileBytes);
   return file;
 }
}

// Helper methods for Windows platform
Future<File> _saveToDownloadsWindows(List<int> fileBytes, String fileName) async {
  try {
    final userHome = Platform.environment['USERPROFILE'];
    if (userHome != null) {
      final downloadsPath = '$userHome\\Downloads';
      final directory = Directory(downloadsPath);
      
      if (await directory.exists()) {
        final filePath = '$downloadsPath\\$fileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File đã được lưu tại: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
        return file;
      }
    }
    // If Downloads folder not accessible, fall back to Documents
    return await _saveToDocumentsWindows(fileBytes, fileName);
  } catch (e) {
    print('Error saving to Downloads: $e');
    return await _saveToDocumentsWindows(fileBytes, fileName);
  }
}

Future<File> _saveToDocumentsWindows(List<int> fileBytes, String fileName) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}\\$fileName';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File đã được lưu tại: $filePath'),
        backgroundColor: Colors.green,
      ),
    );
    return file;
  } catch (e) {
    print('Error saving to Documents: $e');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi lưu file: $e'),
        backgroundColor: Colors.red,
      ),
    );
    
    // Return an empty temporary file in case of error
    final temp = await getTemporaryDirectory();
    final file = File('${temp.path}/$fileName');
    await file.writeAsBytes(fileBytes);
    return file;
  }
}

String _formatStatus(String? trangThai, String? phuongAn, String? hoTro) {
 List<String> parts = [];
 if (trangThai != null && trangThai.isNotEmpty) parts.add(trangThai);
 if (phuongAn != null && phuongAn.isNotEmpty) parts.add(phuongAn);
 String status = parts.join(' / ');
 if (hoTro != null && hoTro.isNotEmpty) status += ' + $hoTro';
 return status;
}
Future<void> _saveUserType(String type) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('userType', type);
}
Future<void> _loadUserType() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    userType = prefs.getString('userType');
  });
}
Future<void> _checkAndLoadHistory() async {
  await Future.delayed(Duration(seconds: 1));
  if (userType != null && await _shouldLoadHistory()) {
    _loadHistory();
  }
}
Future<bool> _shouldLoadHistory() async {
  if (userType == null) {
    return false;
  }

  final prefs = await SharedPreferences.getInstance();
  final lastSync = prefs.getInt('lastHistorySync') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  return (now - lastSync) > 1 * 60 * 60 * 1000; // 1 hour
}

Future<void> _updateLastSyncTime() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('lastHistorySync', DateTime.now().millisecondsSinceEpoch);
}
Future<void> _loadDateList() async {
  try {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT date(Ngay) as date
      FROM ${DatabaseTables.taskHistoryTable}
      ORDER BY date DESC
    ''');
    
    setState(() {
      _dateList = result.map((row) => row['date'] as String).toList();
      if (_dateList.isNotEmpty) {
        _selectedEndDate = _dateList.first;
        _selectedStartDate = _dateList.first;
      }
    });
    if (_dateList.isNotEmpty) {
      await _loadTaskHistoryData();
    }
  } catch (e) {
    print('Error loading date list: $e');
    _showError('Error loading dates: $e');
  }
}
  Future<void> _loadBoPhanList() async {
    try {
      final List<String> boPhanList = await dbHelper.getUserBoPhanList();
      print('Loaded BoPhan list: $boPhanList'); // Debug print
      if (mounted) {
        setState(() {
          // Make sure we have unique values
          final uniqueBoPhanList = {'Tất cả', ...boPhanList.toSet()}.toList();
          _boPhanList = uniqueBoPhanList;
          // Set default selection only if it's not already set
          _selectedBoPhan ??= 'Tất cả';
        });
        print('Updated _boPhanList: $_boPhanList'); // Debug print
        print('Selected BoPhan: $_selectedBoPhan'); // Debug print
      }
    } catch (e) {
      print('Error loading BoPhan list: $e');
      _showError('Error loading department list: $e');
    }
  }
void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
Future<void> _loadHistory() async {
  if (_isLoadingHistory) return;
  
  setState(() {
    _isLoadingHistory = true;
    _syncStatus = 'Đang đồng bộ lịch sử...';
  });
  
  try {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username.toLowerCase();
    
  // Step 1: Try to fetch task history with userType
setState(() => _syncStatus = 'Đang lấy lịch sử báo cáo...');
final taskHistoryResponse = await AuthenticatedHttpClient.get(
  Uri.parse('$baseUrl/historybaocao2/$username')
);

if (taskHistoryResponse.statusCode != 200) {
  throw Exception('Failed to load task history: ${taskHistoryResponse.statusCode}');
}

// Add debug logging
print('Task history response: ${taskHistoryResponse.body}');

final List<dynamic> taskHistoryData = json.decode(taskHistoryResponse.body);
await dbHelper.clearTable(DatabaseTables.taskHistoryTable);

final taskHistories = <TaskHistoryModel>[];
List<String> errorMessages = [];

for (int i = 0; i < taskHistoryData.length; i++) {
  try {
    final data = taskHistoryData[i];
    // Log the data we're processing
    print('Processing task history item: $data');
    
    final ngayStr = data['Ngay'] as String? ?? '';
    
    // Only add validation if the date is not null/empty
    if (ngayStr.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ngayStr)) {
      errorMessages.add('Invalid date format: Record #$i, Format="$ngayStr"');
      continue;
    }
    
    // Safely handle potential null values
    taskHistories.add(TaskHistoryModel(
      uid: data['UID'] ?? '',
      taskId: data['TaskID'] ?? '',
      ngay: data['Ngay'] != null ? DateTime.parse(data['Ngay']) : DateTime.now(),
      gio: data['Gio'] ?? '',
      nguoiDung: data['NguoiDung'] ?? '',
      ketQua: data['KetQua'] ?? '',
      chiTiet: data['ChiTiet'] ?? '',
      chiTiet2: data['ChiTiet2'] ?? '',
      viTri: data['ViTri'] ?? '',
      boPhan: data['BoPhan'] ?? '',
      phanLoai: data['PhanLoai'] ?? '',
      hinhAnh: data['HinhAnh'], // Can be null
      giaiPhap: data['GiaiPhap'], // Can be null
    ));
  } catch (e) {
    final error = e.toString();
    final recordInfo = json.encode(taskHistoryData[i]).substring(0, 100) + '...';
    errorMessages.add('Error on record #$i: ${error.substring(0, 100)}\nRecord: $recordInfo');
    print('Error processing task history item: $e');
    print('Problematic data: ${taskHistoryData[i]}');
    // Continue with next item instead of failing whole process
  }
}

// Only proceed if we have valid items
if (taskHistories.isNotEmpty) {
  await dbHelper.batchInsertTaskHistory(taskHistories);
  print('Successfully inserted ${taskHistories.length} task history records');
} else {
  print('No valid task history records to insert');
}

    // Step 2: Try to fetch position history
    try {
      setState(() => _syncStatus = 'Đang lấy lịch sử vị trí...');
      final vtHistoryResponse = await AuthenticatedHttpClient.get(
        Uri.parse('$baseUrl/historyvitri/$username')
      );

      if (vtHistoryResponse.statusCode == 200) {
        final List<dynamic> vtHistoryData = json.decode(vtHistoryResponse.body);
        await dbHelper.clearTable(DatabaseTables.vtHistoryTable);

        final vtHistories = vtHistoryData.map((data) => VTHistoryModel(
          uid: data['UID'],
          ngay: DateTime.parse(data['Ngay']),
          gio: data['Gio'],
          nguoiDung: data['NguoiDung'],
          boPhan: data['BoPhan'],
          viTri: data['ViTri'],
          nhanVien: data['NhanVien'],
          trangThai: data['TrangThai'],
          hoTro: data['HoTro'],
          phuongAn: data['PhuongAn'],
        )).toList();

        await dbHelper.batchInsertVTHistory(vtHistories);
      }
    } catch (e) {
      print('Error fetching position history, skipping: $e');
    }

    // Step 3: Try to fetch uniform data
    try {
      setState(() => _syncStatus = 'Đang lấy dữ liệu đồng phục...');
      final dongPhucResponse = await AuthenticatedHttpClient.get(
        Uri.parse('$baseUrl/dongphucql/$username')
      );

      if (dongPhucResponse.statusCode == 200) {
        final List<dynamic> dongPhucData = json.decode(dongPhucResponse.body);
        await dbHelper.clearTable(DatabaseTables.dongPhucTable);
        
        final dongPhucModels = dongPhucData.map((data) => 
          DongPhucModel.fromMap(data as Map<String, dynamic>)
        ).toList();

        await dbHelper.batchInsertDongPhuc(dongPhucModels);

        // Step 4: Try to fetch uniform list
        setState(() => _syncStatus = 'Đang lấy danh sách đồng phục...');
        final chiTietDPResponse = await AuthenticatedHttpClient.get(
          Uri.parse('$baseUrl/dongphuclist')
        );

        if (chiTietDPResponse.statusCode == 200) {
          final List<dynamic> chiTietDPData = json.decode(chiTietDPResponse.body);
          await dbHelper.clearTable(DatabaseTables.chiTietDPTable);
          
          final chiTietDPModels = chiTietDPData.map((data) => 
            ChiTietDPModel.fromMap(data as Map<String, dynamic>)
          ).toList();

          await dbHelper.batchInsertChiTietDP(chiTietDPModels);
        }
      }
    } catch (e) {
      print('Error fetching uniform data: $e');
    }

    // Step 5: Try to fetch interaction history
    try {
      setState(() => _syncStatus = 'Đang lấy lịch sử tương tác...');
      final interactionResponse = await AuthenticatedHttpClient.get(
        Uri.parse('$baseUrl/historytuongtac/$username')
      );

      if (interactionResponse.statusCode == 200) {
        final List<dynamic> interactionData = json.decode(interactionResponse.body);
        await dbHelper.clearTable(DatabaseTables.interactionTable);

        final interactions = interactionData.map((data) => InteractionModel(
          uid: data['UID'],
          ngay: DateTime.parse(data['Ngay']),
          gio: data['Gio'],
          nguoiDung: data['NguoiDung'],
          boPhan: data['BoPhan'],
          giamSat: data['GiamSat'],
          noiDung: data['NoiDung'],
          chuDe: data['ChuDe'],
          phanLoai: data['PhanLoai'],
        )).toList();

        await dbHelper.batchInsertInteraction(interactions);
      }
    } catch (e) {
      print('Error fetching interaction history, skipping: $e');
    }
    // Step 6: Try to fetch department attendance history
try {
  print('=== STEP 6: ATTENDANCE HISTORY SYNC START ===');
  print('Current time: ${DateTime.now()}');
  print('Username: $username');
  print('Base URL: $baseUrl');
  
  setState(() => _syncStatus = 'Đang lấy lịch sử chấm công...');
  
  final attendanceUrl = '$baseUrl/chamcongqldv/$username';
  print('Fetching attendance data from: $attendanceUrl');
  
  // Add timeout to the request
  final chamCongResponse = await http.get(
    Uri.parse(attendanceUrl)
  ).timeout(Duration(seconds: 230));

  print('Attendance API response status: ${chamCongResponse.statusCode}');
  print('Response headers: ${chamCongResponse.headers}');
  print('Response body length: ${chamCongResponse.body.length}');
  print('Response body preview (first 500 chars): ${chamCongResponse.body.length > 500 ? chamCongResponse.body.substring(0, 500) + "..." : chamCongResponse.body}');
  
  if (chamCongResponse.statusCode == 200) {
    print('✓ Successfully received attendance data');
    
    // Check if response is empty
    if (chamCongResponse.body.trim().isEmpty) {
      print('⚠️ WARNING: Response body is empty');
      return;
    }
    
    // Try to parse JSON
    List<dynamic> chamCongData;
    try {
      chamCongData = json.decode(chamCongResponse.body);
      print('✓ JSON parsing successful');
      print('Parsed attendance records count: ${chamCongData.length}');
    } catch (jsonError) {
      print('❌ JSON parsing failed: $jsonError');
      print('Raw response: ${chamCongResponse.body}');
      return;
    }
    
    // Check if data is empty
    if (chamCongData.isEmpty) {
      print('⚠️ WARNING: No attendance records returned from API');
      return;
    }
    
    // Log first few records for inspection
    print('Sample attendance records:');
    for (int i = 0; i < Math.min(3, chamCongData.length); i++) {
      print('Record $i: ${chamCongData[i]}');
    }

    print('Clearing existing attendance table...');
    final clearResult = await dbHelper.clearTable(DatabaseTables.chamCongCNTable);
    print('✓ Table cleared successfully');

    print('Converting attendance data to models...');
    final List<ChamCongCNModel> chamCongModels = [];
    int successCount = 0;
    int errorCount = 0;
    
    for (int i = 0; i < chamCongData.length; i++) {
      try {
        final model = ChamCongCNModel.fromMap(chamCongData[i] as Map<String, dynamic>);
        chamCongModels.add(model);
        successCount++;
        
        // Log every 100th record to track progress
        if ((i + 1) % 100 == 0) {
          print('Processed ${i + 1}/${chamCongData.length} records...');
        }
      } catch (e) {
        errorCount++;
        print('❌ Error converting attendance record $i: $e');
        print('Problematic attendance data: ${chamCongData[i]}');
        
        // Stop if too many errors
        if (errorCount > 10) {
          print('❌ Too many conversion errors, stopping...');
          break;
        }
      }
    }

    print('Conversion summary:');
    print('- Successfully converted: $successCount records');
    print('- Failed to convert: $errorCount records');
    print('- Total models to insert: ${chamCongModels.length}');

    if (chamCongModels.isNotEmpty) {
      print('Inserting ${chamCongModels.length} attendance records...');
      
      try {
        await dbHelper.batchInsertChamCongCN(chamCongModels);
        print('✓ Attendance records inserted successfully');
        
        // Verify insertion
        final db = await dbHelper.database;
        final verifyResult = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseTables.chamCongCNTable}');
        final insertedCount = Sqflite.firstIntValue(verifyResult) ?? 0;
        print('✓ Verification: $insertedCount records found in database');
        
        if (insertedCount != chamCongModels.length) {
          print('⚠️ WARNING: Expected ${chamCongModels.length} but found $insertedCount in database');
        }
        
      } catch (insertError) {
        print('❌ Error inserting attendance records: $insertError');
        print('Insert error type: ${insertError.runtimeType}');
        rethrow;
      }
    } else {
      print('⚠️ WARNING: No valid attendance models to insert');
    }
    
    print('✓ Attendance history sync completed successfully');
  } else {
    print('❌ Failed to fetch attendance data');
    print('Status code: ${chamCongResponse.statusCode}');
    print('Status text: ${chamCongResponse.reasonPhrase}');
    print('Response body: ${chamCongResponse.body}');
  }
} catch (e) {
  print('=== ATTENDANCE SYNC ERROR ===');
  print('Error type: ${e.runtimeType}');
  print('Error message: $e');
  print('Stack trace:');
  print(StackTrace.current);
  print('=== END ATTENDANCE SYNC ERROR ===');
} finally {
  print('=== STEP 6: ATTENDANCE HISTORY SYNC END ===');
} 

// Step 7: Try to fetch order history
try {
  print('Starting order history sync...');
  setState(() => _syncStatus = 'Đang lấy lịch sử đơn hàng...');
  
  print('Fetching order data from: $baseUrl/orderdon/$username');
  final orderResponse = await AuthenticatedHttpClient.get(
    Uri.parse('$baseUrl/orderdon/$username')
  );

  print('Order API response status: ${orderResponse.statusCode}');
  if (orderResponse.statusCode == 200) {
    print('Successfully received order data');
    final List<dynamic> orderData = json.decode(orderResponse.body);
    print('Parsed order records: ${orderData.length}');

    print('Clearing existing orders table...');
    await dbHelper.clearTable(DatabaseTables.orderTable);

    print('Converting order data to models...');
    final orderModels = orderData.map((data) {
      try {
        return OrderModel.fromMap(data as Map<String, dynamic>);
      } catch (e) {
        print('Error converting order record: $e');
        print('Problematic order data: $data');
        rethrow;
      }
    }).toList();

    print('Inserting ${orderModels.length} order records...');
    await dbHelper.batchInsertOrders(orderModels);
    print('Order history sync completed');
  } else {
    print('Failed to fetch order data: ${orderResponse.body}');
  }
} catch (e) {
  print('ERROR in order sync:');
  print('Error type: ${e.runtimeType}');
  print('Error message: $e');
  print('Stack trace: ${StackTrace.current}');
}

// Step 8: Try to fetch order details
try {
  print('Starting order details sync...');
  setState(() => _syncStatus = 'Đang lấy chi tiết đơn hàng...');
  
  print('Fetching order details from: $baseUrl/orderchitiet/$username');
  final orderChiTietResponse = await AuthenticatedHttpClient.get(
    Uri.parse('$baseUrl/orderchitiet/$username')
  );

  print('Order details API response status: ${orderChiTietResponse.statusCode}');
  if (orderChiTietResponse.statusCode == 200) {
    print('Successfully received order details data');
    final List<dynamic> orderChiTietData = json.decode(orderChiTietResponse.body);
    print('Parsed order detail records: ${orderChiTietData.length}');

    print('Clearing existing order details table...');
    await dbHelper.clearTable(DatabaseTables.orderChiTietTable);

    print('Converting order details to models...');
    final orderChiTietModels = orderChiTietData.map((data) {
      try {
        return OrderChiTietModel.fromMap(data as Map<String, dynamic>);
      } catch (e) {
        print('Error converting order detail record: $e');
        print('Problematic order detail data: $data');
        rethrow;
      }
    }).toList();

    print('Inserting ${orderChiTietModels.length} order detail records...');
    await dbHelper.batchInsertOrderChiTiet(orderChiTietModels);
    print('Order details sync completed');
  } else {
    print('Failed to fetch order details: ${orderChiTietResponse.body}');
  }
} catch (e) {
  print('ERROR in order details sync:');
  print('Error type: ${e.runtimeType}');
  print('Error message: $e');
  print('Stack trace: ${StackTrace.current}');
}
    await _updateLastSyncTime();
    _showSuccess('Đồng bộ lịch sử thành công');
    await _loadDateList();
    
  } catch (e) {
    print('Error syncing history: $e');
    _showError('Không thể đồng bộ lịch sử: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        _syncStatus = '';
      });
    }
  }
}
  Future<void> _loadProjects() async {
  if (_isLoading) return;
  
  setState(() {
    _isLoading = true;
    _syncStatus = 'Đang đồng bộ...';
  });
  
  try {
    final userCredentials = Provider.of<UserCredentials>(context, listen: false);
    final username = userCredentials.username.toLowerCase();
    
    // Step 1: Get user role
    setState(() => _syncStatus = 'Đang lấy thông tin người dùng...');
    final roleResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/myrole/$username')
    );

    if (roleResponse.statusCode != 200) {
      throw Exception('Failed to load user role: ${roleResponse.statusCode}');
    }

    // Save user type
    userType = (await roleResponse.body).trim();
    await _saveUserType(userType!);
    // Step 2: Fetch project list
        try {
      setState(() => _syncStatus = 'Đang lấy danh sách dự án...');
      print('Fetching project list for: $username');
      final projectResponse = await AuthenticatedHttpClient.get(
        Uri.parse('$baseUrl/projectlist/$username')
      );
      
      print('Project list response status: ${projectResponse.statusCode}');
      if (projectResponse.statusCode != 200) {
        print('PL data: ${projectResponse.body}');
        throw Exception('Failed to load projects: ${projectResponse.statusCode}');
      }

      final String responseText = projectResponse.body;
      print('Project list response length: ${responseText.length}');
      print('Project list response preview: ${projectResponse.body}');

      final List<dynamic> projectData = json.decode(responseText);
      print('Project list JSON parse successful, count: ${projectData.length}');
      
      await dbHelper.clearTable(DatabaseTables.projectListTable);
      print('Project list table cleared');
      
      final List<ProjectListModel> projects = [];
      for (var i = 0; i < projectData.length; i++) {
        final project = projectData[i];
        print('Processing project $i: ${project.toString()}');
        try {
          final model = ProjectListModel(
            boPhan: project['BoPhan'] ?? '',
            maBP: project['MaBP'] ?? '',
          );
          projects.add(model);
        } catch (e) {
          print('Error creating project model for item $i: $e');
          print('Problematic data: $project');
          throw e;
        }
      }

      await dbHelper.batchInsertProjectList(projects);
      print('Projects inserted successfully');
    } catch (e) {
      print('ERROR in Step 2 - Project list fetching:');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      throw e;
    }

    // Step 3: Fetch staff bio data
    setState(() => _syncStatus = 'Đang lấy thông tin công nhân...');
    final staffbioResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/staffbio')
    );

    if (staffbioResponse.statusCode != 200) {
      throw Exception('Failed to load staff bio: ${staffbioResponse.statusCode}');
    }

    final List<dynamic> staffbioData = json.decode(staffbioResponse.body);
    await dbHelper.clearTable(DatabaseTables.staffbioTable);

    final staffbios = staffbioData.map((data) => StaffbioModel.fromMap(data)).toList();
    await dbHelper.batchInsertStaffbio(staffbios);

    // Step 4: Fetch staff list
    setState(() => _syncStatus = 'Đang lấy danh sách công nhân...');
    final staffListResponse = await AuthenticatedHttpClient.get(
      Uri.parse('$baseUrl/dscn/$username')
    );

    if (staffListResponse.statusCode != 200) {
      throw Exception('Failed to load staff list: ${staffListResponse.statusCode}');
    }

    final List<dynamic> staffListData = json.decode(staffListResponse.body);
    await dbHelper.clearTable(DatabaseTables.staffListTable);

    final staffList = staffListData.map((data) => StaffListModel(
      uid: data['UID'],
      manv: data['MaNV'],
      nguoiDung: data['NguoiDung'],
      vt: data['VT'],
      boPhan: data['BoPhan'],
    )).toList();

    await dbHelper.batchInsertStaffList(staffList);

    // Reload BoPhan list after all syncs
    await _loadBoPhanList();

    _showSuccess('Đồng bộ thành công');
  } catch (e) {
    print('Error syncing: $e');
    _showError('Không thể đồng bộ: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }
}
List<Map<String, dynamic>> _filteredTaskHistory = [];
  Future<void> _loadTaskHistoryData() async {
  if (_selectedStartDate == null || _selectedEndDate == null) return;

  try {
    final db = await dbHelper.database;
    String query = '''
      SELECT * FROM ${DatabaseTables.taskHistoryTable}
      WHERE date(Ngay) BETWEEN ? AND ?
    ''';
    List<dynamic> args = [_selectedStartDate, _selectedEndDate];

    if (_selectedBoPhan != 'Tất cả') {
      query += ' AND BoPhan = ?';
      args.add(_selectedBoPhan);
    }

    final List<Map<String, dynamic>> results = await db.rawQuery(query, args);
    setState(() {
      _filteredTaskHistory = results;
    });
  } catch (e) {
    print('Error loading task history: $e');
    _showError('Error loading task history data');
  }
}
  // Dashboard Stats Calculations
  int get totalReports => _filteredTaskHistory.length;
  
  int get uniqueProjects {
    return _filteredTaskHistory
        .map((item) => item['BoPhan'] as String)
        .toSet()
        .length;
  }
  
  int get issuesCount {
    return _filteredTaskHistory
        .where((item) => item['KetQua'] != '✔️')
        .length;
  }

  List<Map<String, dynamic>> get phanLoaiStats {
    final map = <String, int>{};
    for (var item in _filteredTaskHistory) {
      final phanLoai = item['PhanLoai'] as String? ?? 'Khác';
      map[phanLoai] = (map[phanLoai] ?? 0) + 1;
    }
    return map.entries
        .map((e) => {'name': e.key, 'value': e.value})
        .toList();
  }

  List<Map<String, dynamic>> get issueResolutionStats {
    int resolved = _filteredTaskHistory
        .where((item) => 
            item['KetQua'] != '✔️' && 
            item['GiaiPhap'] != null && 
            item['GiaiPhap'].toString().trim().isNotEmpty)
        .length;
    
    int unresolved = _filteredTaskHistory
        .where((item) => 
            item['KetQua'] != '✔️' && 
            (item['GiaiPhap'] == null || 
            item['GiaiPhap'].toString().trim().isEmpty))
        .length;

    return [
      {'name': 'Đã giải quyết', 'value': resolved},
      {'name': 'Chưa giải quyết', 'value': unresolved},
    ];
  }

  List<Map<String, dynamic>> get issuePhanLoaiStats {
    final map = <String, int>{};
    for (var item in _filteredTaskHistory) {
      if (item['KetQua'] != '✔️') {
        final phanLoai = item['PhanLoai'] as String? ?? 'Khác';
        map[phanLoai] = (map[phanLoai] ?? 0) + 1;
      }
    }
    return map.entries
        .map((e) => {'name': e.key, 'value': e.value})
        .toList();
  }

  List<Map<String, dynamic>> get recentIssues {
    return _filteredTaskHistory
        .where((item) => item['KetQua'] != '✔️')
        .toList()
      ..sort((a, b) => DateTime.parse(b['Ngay'])
          .compareTo(DateTime.parse(a['Ngay'])));
  }
  String _getUserTypeTitle(String username) {
  switch(userType) {
    case 'HM-DV':
      return 'Quản lý dịch vụ $username';
    case 'HM-KT':
      return 'Kế toán $username';
    case 'HM-NS':
      return 'Nhân sự $username';
    case 'HM-QA':
      return 'Nhân viên QA $username';
    case 'HM-CSKH':
      return 'Kinh doanh $username';
    case 'HM-TD':
      return 'Tuyển dụng $username';
    case 'HM-RD':
      return 'Nhân viên R&D $username';
    case 'HM-DVV':
      return 'NV DVV $username';
    case 'HM-HS':
      return 'Hotel Supply $username';
    default:
      return 'User $username';
  }
}
Future<int> _getProjectCount() async {
  final db = await dbHelper.database;
  final result = await db.rawQuery(
    'SELECT COUNT(DISTINCT BoPhan) as count FROM ${DatabaseTables.projectListTable}'
  );
  return Sqflite.firstIntValue(result) ?? 0;
}

Future<int> _getStaffCount() async {
  final db = await dbHelper.database;
  final result = await db.rawQuery('''
    SELECT COUNT(*) as count FROM ${DatabaseTables.vtHistoryTable}
    WHERE TrangThai = 'Đang làm việc'
    GROUP BY ViTri
  ''');
  return result.length;
}
Widget _buildCompactButton(
  String label,
  IconData icon,
  Color color,
  VoidCallback? onPressed, {
  bool isLoading = false,
}) {
  return SizedBox(
    height: 36,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,  // White background
        foregroundColor: color,         // Text and icon color
        padding: EdgeInsets.symmetric(horizontal: 8),
        elevation: 1,                   // Minimal elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: color.withOpacity(0.3)),  // Lighter border
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,  // Center the content
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, size: 16),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
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
          Color.fromARGB(255, 114, 255, 217),
          Color.fromARGB(255, 201, 255, 236),
          Color.fromARGB(255, 79, 255, 214),
          Color.fromARGB(255, 188, 255, 235),
        ],
      ),
    ),
  ),
  title: Text(
    _getUserTypeTitle(username),
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
),
    body: SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync Status
            if (_syncStatus.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  _syncStatus,
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Action Buttons Grid
  Container(
  margin: EdgeInsets.symmetric(vertical: 4),
  height: 76,
  child: Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _buildCompactButton(
              'Đồng bộ',
              Icons.sync,
              Color(0xFF2196F3),
              _isLoading ? null : _loadProjects,
              isLoading: _isLoading,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildCompactButton(
              'Nhận LS',
              Icons.history,
              Color(0xFF4CAF50),
              _isLoadingHistory ? null : _loadHistory,
              isLoading: _isLoadingHistory,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildCompactButton(
              'Chi tiết',
              Icons.assignment,
              Color(0xFF9C27B0),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectViewScreen(
                    selectedDate: _selectedEndDate,
                    selectedBoPhan: _selectedBoPhan,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child:
          _buildCompactButton(
            'Timeline',
            Icons.timeline,
            Color(0xFF3F51B5),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectTimeline(
                  username: userCredentials.username.toLowerCase(),
                ),
              ),
            ),
          ),),
          Expanded(
            child:
          _buildCompactButton(
            'TV1',
            Icons.timeline,
            Color(0xFF3F51B5),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageSlideshow(
                  username: userCredentials.username.toLowerCase(),
                ),
              ),
            ),
          ),),
        ],
      ),
      SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: _buildCompactButton(
              'Báo cáo',
              Icons.work,
              Color(0xFFFF5722),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectWorkReport(
                    selectedDate: _selectedEndDate,
                    selectedBoPhan: _selectedBoPhan,
                    userType: userType,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildCompactButton(
              'Tổng hợp',
              Icons.analytics,
              Color(0xFF009688),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDailyView(
                    startDate: _selectedStartDate,
                    endDate: _selectedEndDate,
                    selectedBoPhan: _selectedBoPhan,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildCompactButton(
              'Xuất',
              Icons.file_download,
              Color(0xFF607D8B),
              _exportToPDF,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildCompactButton(
              'Quản lý', 
              Icons.settings,
              Color(0xFF795548),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectManager(),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),
// Date Range Selection
SizedBox(height: 24),
Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ngày bắt đầu:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: _selectedStartDate,
              isExpanded: true,
              underline: SizedBox(),
              items: _dateList.map((String date) {
                return DropdownMenuItem<String>(
                  value: date,
                  child: Text(date),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedStartDate = newValue;
                  if (_selectedEndDate == null) {
                    _selectedEndDate = newValue;
                  }
                });
                _loadTaskHistoryData();
              },
            ),
          ),
        ],
      ),
    ),
    SizedBox(width: 16),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ngày kết thúc:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButton<String>(
              value: _selectedEndDate,
              isExpanded: true,
              underline: SizedBox(),
              items: _dateList.map((String date) {
                return DropdownMenuItem<String>(
                  value: date,
                  child: Text(date),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedEndDate = newValue;
                  if (_selectedStartDate == null) {
                    _selectedStartDate = newValue;
                  }
                });
                _loadTaskHistoryData();
              },
            ),
          ),
        ],
      ),
    ),
  ],
),
            // Department Dropdown
            SizedBox(height: 16),
            Text(
              'Chọn Bộ Phận:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            SearchableDropdown(
  value: _selectedBoPhan ?? '',
  items: _boPhanList,
  hintText: 'Chọn bộ phận',
  onChanged: (String? newValue) {
    setState(() {
      _selectedBoPhan = newValue;
    });
    _loadTaskHistoryData();
  },
),
FutureBuilder<List<int>>(
  future: Future.wait([
    _getProjectCount(),
    _getStaffCount(),
  ]),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final projectCount = snapshot.data![0];
      final staffCount = snapshot.data![1];
      return Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Tổng số dự án: $projectCount | Số nhân sự đủ: $staffCount',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      );
    }
    return SizedBox();
  },
),
            // Statistics Cards
            SizedBox(height: 24),
            Row(
              children: [
                _buildStatCard(
                  'Số lượt báo cáo',
                  totalReports.toString(),
                  Icons.assignment,
                ),
                SizedBox(width: 16),
                _buildStatCard(
                  'Số dự án báo cáo',
                  uniqueProjects.toString(),
                  Icons.business,
                ),
                SizedBox(width: 16),
                _buildStatCard(
                  'Số vấn đề xảy ra',
                  issuesCount.toString(),
                  Icons.warning,
                ),
              ],
            ),

            // Pie Charts
            SizedBox(height: 24),
            _buildPieChart(
              'Chủ đề báo cáo',
              phanLoaiStats,
            ),
            
            SizedBox(height: 24),
            _buildPieChart(
              'Tỉ lệ vấn đề được giải quyết',
              issueResolutionStats,
            ),
            
            SizedBox(height: 24),
            _buildPieChart(
              'Phân loại vấn đề',
              issuePhanLoaiStats,
            ),

            // Recent Issues List
            SizedBox(height: 24),
            Text(
              'Các vấn đề gần đây',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _buildRecentIssuesList(),
            SizedBox(height: 24), // Bottom padding
          ],
        ),
      ),
    ),
  );
}
    Widget _buildStatCard(String title, String value, IconData icon) {
  return Expanded(
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, 
            color: Color.fromARGB(255, 204, 0, 0),
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 204, 0, 0),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPieChart(String title, List<Map<String, dynamic>> data) {
  if (data.isEmpty) return SizedBox();
  
  String chartId;
  if (title == 'Chủ đề báo cáo') {
    chartId = 'phanLoaiChart';
  } else if (title == 'Tỉ lệ vấn đề được giải quyết') {
    chartId = 'issueResolutionChart';
  } else {
    chartId = 'issueTypeChart';
  }

  final List<Color> colorScheme = title == 'Chủ đề báo cáo' ? [
    Colors.blue[400]!,
    Colors.green[400]!,
    Colors.orange[400]!,
    Colors.purple[400]!,
    Colors.teal[400]!,
    Colors.indigo[400]!,
  ] : title == 'Tỉ lệ vấn đề được giải quyết' ? [
    Colors.red[400]!,
    Colors.grey[400]!,
  ] : [
    Colors.deepOrange[400]!,
    Colors.yellow[700]!,
    Colors.cyan[400]!,
    Colors.pink[400]!,
    Colors.lime[700]!,
  ];

  return Container(
    height: 300,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: RepaintBoundary(
                  key: _chartKeys[chartId],
                  child: PieChart(
                    PieChartData(
                      sections: data.map((item) {
                        final index = data.indexOf(item) % colorScheme.length;
                        return PieChartSectionData(
                          value: item['value'].toDouble(),
                          title: '${((item['value'] / totalReports) * 100).toStringAsFixed(1)}%',
                          color: colorScheme[index],
                          radius: 100,
                          titleStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              // Legend stays the same
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.map((item) {
                    final index = data.indexOf(item) % colorScheme.length;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: colorScheme[index],
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item['name']}: ${item['value']}',
                              style: TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildRecentIssuesList() {
  final issues = _filteredTaskHistory
    .where((item) => item['KetQua'] != '✔️')
    .take(5)
    .toList();
  
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: issues.length,
      separatorBuilder: (context, index) => Divider(),
      itemBuilder: (context, index) {
        final issue = issues[index];
        return ExpansionTile(
          title: Text(
            issue['ChiTiet'] ?? 'No details',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${issue['BoPhan']} - ${issue['Ngay']} ${issue['Gio']}',
            style: TextStyle(fontSize: 12),
          ),
          trailing: issue['GiaiPhap'] != null && 
                    issue['GiaiPhap'].toString().trim().isNotEmpty
              ? Icon(Icons.check_circle, color: Colors.green)
              : Icon(Icons.warning, color: Colors.orange),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (issue['ChiTiet2'] != null && issue['ChiTiet2'].toString().isNotEmpty)
                    Text(
                      'Chi tiết bổ sung: ${issue['ChiTiet2']}',
                      style: TextStyle(fontSize: 14),
                    ),
                  SizedBox(height: 8),
                  if (issue['GiaiPhap'] != null && issue['GiaiPhap'].toString().isNotEmpty)
                    Text(
                      'Giải pháp: ${issue['GiaiPhap']}',
                      style: TextStyle(fontSize: 14),
                    ),
                  SizedBox(height: 8),
                  Text(
                    'Vị trí: ${issue['ViTri'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (issue['HinhAnh'] != null && issue['HinhAnh'].toString().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Image.network(
                        issue['HinhAnh'],
                        errorBuilder: (context, error, stackTrace) =>
                          Text('Unable to load image'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
}