// checklist_list.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class ChecklistListScreen extends StatefulWidget {
  final String username;

  const ChecklistListScreen({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  _ChecklistListScreenState createState() => _ChecklistListScreenState();
}

class _ChecklistListScreenState extends State<ChecklistListScreen> {
  bool _isLoading = false;
  String _syncStatus = '';
  
  List<ChecklistListModel> _checklists = [];
  List<ChecklistListModel> _filteredChecklists = [];
  List<ChecklistItemModel> _items = [];
  List<ChecklistReportModel> _reports = [];
  
  final TextEditingController _searchController = TextEditingController();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  static const String _listsKey = 'checklist_lists_v1';
  static const String _itemsKey = 'checklist_items_v1';
  static const String _reportsKey = 'checklist_reports_v1';
  static const String _lastSyncKey = 'checklist_lists_last_sync';

  String? _selectedProject;
  List<String> _projectOptions = [];
  
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _useBlankDate = false;

  // Icon mapping for items
  static const Map<String, IconData> _iconMap = {
    'Icons.wallpaper': Icons.wallpaper,
   'Icons.receipt_long': Icons.receipt_long,
   'Icons.blender': Icons.blender,
   'Icons.ad_units': Icons.ad_units,
   'Icons.grid_view': Icons.grid_view,
   'Icons.miscellaneous_services': Icons.miscellaneous_services,
   'Icons.plumbing': Icons.plumbing,
   'Icons.inventory_2': Icons.inventory_2,
   'Icons.countertops': Icons.countertops,
   'Icons.dry': Icons.dry,
   'Icons.soap': Icons.soap,
   'Icons.roofing': Icons.roofing,
   'Icons.view_week': Icons.view_week,
   'Icons.lightbulb': Icons.lightbulb,
   'Icons.label': Icons.label,
   'Icons.delete': Icons.delete,
   'Icons.water_damage': Icons.water_damage,
   'Icons.filter_alt': Icons.filter_alt,
   'Icons.water_drop': Icons.water_drop,
   'Icons.meeting_room': Icons.meeting_room,
   'Icons.shower': Icons.shower,
   'Icons.water_drop_outlined': Icons.water_drop_outlined,
   'Icons.texture': Icons.texture,
   'Icons.airplay': Icons.airplay,
   'Icons.handyman': Icons.handyman,
   'Icons.air': Icons.air,
   'Icons.blur_on': Icons.blur_on,
   'Icons.verified': Icons.verified,
   'Icons.build': Icons.build,
   'Icons.security': Icons.security,
   'Icons.description': Icons.description,
   'Icons.assignment': Icons.assignment,
   'Icons.check_circle': Icons.check_circle,
   'Icons.warning': Icons.warning,
   'Icons.info': Icons.info,
   'Icons.settings': Icons.settings,
   'Icons.home': Icons.home,
   'Icons.work': Icons.work,
   'Icons.cleaning_services': Icons.cleaning_services,
   'Icons.electrical_services': Icons.electrical_services,
   'Icons.schedule': Icons.schedule,
   'Icons.task_alt': Icons.task_alt,
   'Icons.checklist': Icons.checklist,
   'Icons.list_alt': Icons.list_alt,
   'Icons.fact_check': Icons.fact_check,
   'Icons.rule': Icons.rule,
   'Icons.inventory': Icons.inventory,
   'Icons.construction': Icons.construction,
   'Icons.engineering': Icons.engineering,
  };

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_filterChecklists);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ... [Keep all the existing sync and data loading methods unchanged] ...

  Future<void> _initializeData() async {
    await _checkAndSyncData();
    _extractProjects();
  }

  Future<void> _checkAndSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final today = DateTime.now();
    final isNewDay = lastSyncDate.day != today.day || 
                     lastSyncDate.month != today.month || 
                     lastSyncDate.year != today.year;
    
    if (lastSync == 0 || isNewDay) {
      await _syncAllData();
    } else {
      await _loadLocalData();
    }
  }

  Future<void> _syncAllData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ dữ liệu checklist...';
    });

    try {
      await Future.wait([
        _syncChecklists(),
        _syncItems(),
        _syncReports(),
      ]);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      
      _showSuccess('Đồng bộ thành công - ${_checklists.length} checklists');
      
    } catch (e) {
      print('Error syncing data: $e');
      _showError('Không thể đồng bộ dữ liệu: ${e.toString()}');
      await _loadLocalData();
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _syncChecklists() async {
    final response = await http.get(Uri.parse('$baseUrl/checklistlist/${widget.username}'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      _checklists = data.map((item) => ChecklistListModel.fromMap(item)).toList();
      await _saveChecklistsLocally();
    }
  }

  Future<void> _syncItems() async {
    final response = await http.get(Uri.parse('$baseUrl/checklistitem/${widget.username}'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      _items = data.map((item) => ChecklistItemModel.fromMap(item)).toList();
      await _saveItemsLocally();
    }
  }

  Future<void> _syncReports() async {
    final response = await http.get(Uri.parse('$baseUrl/checklistreport/${widget.username}'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      _reports = data.map((item) => ChecklistReportModel.fromMap(item)).toList();
      await _saveReportsLocally();
    }
  }

  Future<void> _saveChecklistsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _checklists.map((item) => json.encode(item.toMap())).toList();
    await prefs.setStringList(_listsKey, jsonList);
  }

  Future<void> _saveItemsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _items.map((item) => json.encode(item.toMap())).toList();
    await prefs.setStringList(_itemsKey, jsonList);
  }

  Future<void> _saveReportsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _reports.map((item) => json.encode(item.toMap())).toList();
    await prefs.setStringList(_reportsKey, jsonList);
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final checklistsJson = prefs.getStringList(_listsKey) ?? [];
      _checklists = checklistsJson.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistListModel.fromMap(map);
      }).toList();

      final itemsJson = prefs.getStringList(_itemsKey) ?? [];
      _items = itemsJson.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistItemModel.fromMap(map);
      }).toList();

      final reportsJson = prefs.getStringList(_reportsKey) ?? [];
      _reports = reportsJson.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistReportModel.fromMap(map);
      }).toList();

      setState(() {
        _filteredChecklists = _checklists;
      });
    } catch (e) {
      print('Error loading local data: $e');
    }
  }

  void _extractProjects() {
    final projects = _checklists
        .map((c) => c.projectName)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    
    setState(() {
      _projectOptions = projects;
      if (projects.isNotEmpty) _selectedProject = projects.first;
    });
  }

  void _filterChecklists() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChecklists = _checklists.where((checklist) {
        final matchesSearch = query.isEmpty || 
            (checklist.checklistTitle?.toLowerCase().contains(query) ?? false) ||
            (checklist.projectName?.toLowerCase().contains(query) ?? false);
        final matchesProject = _selectedProject == null || checklist.projectName == _selectedProject;
        return matchesSearch && matchesProject;
      }).toList();
    });
  }

  List<ChecklistItemModel> _getItemsForChecklist(ChecklistListModel checklist) {
    if (checklist.checklistTaskList == null || checklist.checklistTaskList!.isEmpty) {
      return [];
    }
    
    final itemIds = checklist.checklistTaskList!.split('/');
    return _items.where((item) => itemIds.contains(item.itemId)).toList();
  }

  List<ChecklistReportModel> _getReportsForChecklist(ChecklistListModel checklist) {
    return _reports.where((report) => report.checklistId == checklist.checklistId).toList();
  }

  // Show in-app checklist preview
  void _showChecklistPreview(ChecklistListModel checklist) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: ChecklistPreviewScreen(
          checklist: checklist,
          items: _getItemsForChecklist(checklist),
          reports: _getReportsForChecklist(checklist),
          selectedStartDate: _selectedStartDate,
          selectedEndDate: _selectedEndDate,
          useBlankDate: _useBlankDate,
          iconMap: _iconMap,
          onGeneratePDF: () {
            Navigator.pop(context);
            _generateAndSharePDF(checklist);
          },
        ),
      ),
    );
  }

  void _showDateRangePicker(ChecklistListModel checklist) {
  // Set default dates if none selected
  if (_selectedStartDate == null && !_useBlankDate) {
    _selectedStartDate = DateTime.now().subtract(Duration(days: 2)); // Start from 2 days ago
  }
  if (_selectedEndDate == null && !_useBlankDate && checklist.checklistDateType == 'Multi') {
    _selectedEndDate = DateTime.now(); // End today
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Chọn khoảng thời gian'),
      content: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text('Để trống ngày tháng'),
              value: _useBlankDate,
              onChanged: (value) {
                setDialogState(() {
                  _useBlankDate = value ?? false;
                  if (_useBlankDate) {
                    _selectedStartDate = null;
                    _selectedEndDate = null;
                  } else {
                    // Set default dates when unchecking blank date
                    _selectedStartDate = DateTime.now().subtract(Duration(days: 2));
                    if (checklist.checklistDateType == 'Multi') {
                      _selectedEndDate = DateTime.now();
                    }
                  }
                });
              },
            ),
            if (!_useBlankDate) ...[
              ListTile(
                title: Text('Ngày bắt đầu'),
                subtitle: Text(_selectedStartDate?.toString().split(' ')[0] ?? 'Chưa chọn'),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedStartDate ?? DateTime.now().subtract(Duration(days: 2)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setDialogState(() => _selectedStartDate = date);
                  }
                },
              ),
              if (checklist.checklistDateType == 'Multi')
                ListTile(
                  title: Text('Ngày kết thúc'),
                  subtitle: Text(_selectedEndDate?.toString().split(' ')[0] ?? 'Chưa chọn'),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedEndDate ?? DateTime.now(),
                      firstDate: _selectedStartDate ?? DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setDialogState(() => _selectedEndDate = date);
                    }
                  },
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showChecklistPreview(checklist);
          },
          child: Text('Xem trước'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _generateAndSharePDF(checklist);
          },
          child: Text('Tạo PDF'),
        ),
      ],
    ),
  );
}

  // PDF generation with proper images and report integration
  Future<void> _generateAndSharePDF(ChecklistListModel checklist) async {
    try {
      setState(() {
        _isLoading = true;
        _syncStatus = 'Đang tạo PDF...';
      });

      final pdf = await _createPDF(checklist);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/checklist_${checklist.checklistId}.pdf');
      await file.writeAsBytes(await pdf.save());

      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });

      await Share.shareXFiles([XFile(file.path)], text: 'Checklist: ${checklist.checklistTitle}');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
      _showError('Không thể tạo PDF: ${e.toString()}');
    }
  }

  Future<pw.Document> _createPDF(ChecklistListModel checklist) async {
    final pdf = pw.Document();
    final items = _getItemsForChecklist(checklist);
    final reports = _getReportsForChecklist(checklist);

    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    // Load logo images
    pw.ImageProvider? logoMain;
    pw.ImageProvider? logoSecondary;
    
    if (checklist.logoMain != null && checklist.logoMain!.isNotEmpty) {
      try {
        final logoMainBytes = await rootBundle.load(checklist.logoMain!);
        logoMain = pw.MemoryImage(logoMainBytes.buffer.asUint8List());
      } catch (e) {
        print('Error loading main logo: $e');
      }
    }
    
    if (checklist.logoSecondary != null && checklist.logoSecondary!.isNotEmpty) {
      try {
        final logoSecondaryBytes = await rootBundle.load(checklist.logoSecondary!);
        logoSecondary = pw.MemoryImage(logoSecondaryBytes.buffer.asUint8List());
      } catch (e) {
        print('Error loading secondary logo: $e');
      }
    }

    List<DateTime> dateRange = [];
    if (checklist.checklistDateType == 'Multi') {
      if (_useBlankDate) {
        dateRange = [];
      } else if (_selectedStartDate != null && _selectedEndDate != null) {
        for (DateTime date = _selectedStartDate!; 
             date.isBefore(_selectedEndDate!.add(Duration(days: 1))); 
             date = date.add(Duration(days: 1))) {
          dateRange.add(date);
        }
      } else if (_selectedStartDate != null) {
        dateRange = [_selectedStartDate!];
      }
    } else {
      dateRange = _selectedStartDate != null ? [_selectedStartDate!] : [DateTime.now()];
    }

    List<String> timeColumns = [];
    if (checklist.checklistTimeType == 'PeriodicOut' && 
        checklist.checklistPeriodicStart != null && 
        checklist.checklistPeriodicEnd != null &&
        checklist.checklistPeriodInterval != null) {
      timeColumns = _generatePeriodicTimeColumns(
        checklist.checklistPeriodicStart!,
        checklist.checklistPeriodicEnd!,
        checklist.checklistPeriodInterval!,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildPDFHeader(checklist, font, boldFont, logoMain, logoSecondary),
            pw.SizedBox(height: 20),
            _buildPDFTable(checklist, items, reports, dateRange, timeColumns, font, boldFont),
            pw.SizedBox(height: 20),
            _buildPDFFooter(checklist, font),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFHeader(ChecklistListModel checklist, pw.Font font, pw.Font boldFont, 
                           pw.ImageProvider? logoMain, pw.ImageProvider? logoSecondary) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            logoMain != null 
                ? pw.Container(width: 80, height: 60, child: pw.Image(logoMain))
                : pw.Container(width: 80, height: 60),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    checklist.checklistTitle ?? '',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (checklist.checklistPretext != null && checklist.checklistPretext!.isNotEmpty)
                    pw.Text(
                      checklist.checklistPretext!,
                      style: pw.TextStyle(font: font, fontSize: 12),
                      textAlign: pw.TextAlign.center,
                    ),
                ],
              ),
            ),
            logoSecondary != null 
                ? pw.Container(width: 80, height: 60, child: pw.Image(logoSecondary))
                : pw.Container(width: 80, height: 60),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Dự án: ${checklist.projectName ?? ''}', style: pw.TextStyle(font: font)),
            pw.Text('Khu vực: ${checklist.areaName ?? ''}', style: pw.TextStyle(font: font)),
            pw.Text('Tầng: ${checklist.floorName ?? ''}', style: pw.TextStyle(font: font)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFTable(
  ChecklistListModel checklist,
  List<ChecklistItemModel> items,
  List<ChecklistReportModel> reports,
  List<DateTime> dateRange,
  List<String> timeColumns,
  pw.Font font,
  pw.Font boldFont,
) {
  List<List<String>> tableData = [];
  List<String> headers = [];

  // Date column for Multi type
  if (checklist.checklistDateType == 'Multi' && dateRange.isNotEmpty) {
    headers.add('Ngày');
  }

  // Time columns based on checklistTimeType
  if (checklist.checklistTimeType == 'InOut') {
    headers.addAll(['Giờ vào', 'Giờ ra']);
  } else if (checklist.checklistTimeType == 'PeriodicOut') {
    headers.addAll(timeColumns);
  } else {
    headers.add('Giờ');
  }

  // Task columns
  for (final item in items) {
    headers.add(item.itemName ?? item.itemId);
  }

  // Standard columns
  headers.addAll(['Nhân viên trực', 'Giám sát trực']);

  tableData.add(headers);

  // Filter reports by type (exclude 'customer' reports from display)
  final relevantReports = reports.where((r) => 
    r.reportType == 'staff' || r.reportType == 'sup'
  ).toList();

  print('DEBUG PDF: Total relevant reports: ${relevantReports.length}');
  print('DEBUG PDF: Date range: $dateRange');
  print('DEBUG PDF: Use blank date: $_useBlankDate'); // Fixed: use _useBlankDate

  if (dateRange.isEmpty || _useBlankDate) { // Fixed: use _useBlankDate
    // Create empty rows for blank date scenario
    for (int i = 0; i < 15; i++) {
      List<String> row = [];
      
      // Date column for Multi type
      if (checklist.checklistDateType == 'Multi' && !_useBlankDate) { // Fixed: use _useBlankDate
        row.add('');
      }
      
      // Time columns
      if (checklist.checklistTimeType == 'InOut') {
        row.addAll(['', '']);
      } else if (checklist.checklistTimeType == 'PeriodicOut') {
        row.addAll(List.filled(timeColumns.length, ''));
      } else {
        row.add('');
      }

      // Task columns
      for (final item in items) {
        row.add('');
      }

      // Standard columns
      row.addAll(['', '']);
      tableData.add(row);
    }
  } else {
    // Generate rows for each date
    for (final date in dateRange) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // Find reports for this specific date - extract date part from reportDate
      final dayReports = relevantReports.where((r) {
        try {
          String reportDateOnly;
          if (r.reportDate.contains('T')) {
            reportDateOnly = r.reportDate.split('T')[0];
          } else if (r.reportDate.contains(' ')) {
            reportDateOnly = r.reportDate.split(' ')[0];
          } else {
            reportDateOnly = r.reportDate;
          }
          return reportDateOnly == dateStr;
        } catch (e) {
          print('Error parsing report date: ${r.reportDate}');
          return false;
        }
      }).toList();
      
      print('DEBUG PDF: Date $dateStr has ${dayReports.length} reports');
      
      // Group reports by time for InOut handling
      if (checklist.checklistTimeType == 'InOut') {
        final reportsByTime = <String, Map<String, ChecklistReportModel>>{};
        
        for (final report in dayReports) {
          final timeKey = report.reportTime ?? '';
          if (!reportsByTime.containsKey(timeKey)) {
            reportsByTime[timeKey] = <String, ChecklistReportModel>{};
          }
          if (report.reportInOut != null) {
            reportsByTime[timeKey]![report.reportInOut!] = report;
          }
        }
        
        // Create rows for each unique time
        final uniqueTimes = reportsByTime.keys.toSet();
        if (uniqueTimes.isEmpty) {
          uniqueTimes.add(''); // Add empty time slot
        }
        
        for (final timeSlot in uniqueTimes) {
          List<String> row = [];
          
          // Date column
          if (checklist.checklistDateType == 'Multi') {
            row.add('${date.day}/${date.month}');
          }
          
          // In/Out time columns
          final inReport = reportsByTime[timeSlot]?['In'];
          final outReport = reportsByTime[timeSlot]?['Out'];
          row.add(inReport?.reportTime ?? '');
          row.add(outReport?.reportTime ?? '');
          
          // Task columns
          for (final item in items) {
            String cellValue = '';
            
            if (checklist.checklistCompletionType == 'State') {
              // Show note from staff report
              ChecklistReportModel? staffReport;
              for (final report in [inReport, outReport]) {
                if (report?.reportType == 'staff' && 
                    (report?.reportTaskList?.contains(item.itemId) ?? false)) {
                  staffReport = report;
                  break;
                }
              }
              cellValue = staffReport?.reportNote ?? '';
            } else {
              // Show 'X' if task is completed by staff
              bool hasTask = false;
              for (final report in [inReport, outReport]) {
                if (report?.reportType == 'staff' && 
                    (report?.reportTaskList?.contains(item.itemId) ?? false)) {
                  hasTask = true;
                  break;
                }
              }
              cellValue = hasTask ? 'X' : '';
            }
            
            row.add(cellValue);
          }
          
          // Standard columns
          ChecklistReportModel? staffReport;
          ChecklistReportModel? supReport;
          
          for (final report in [inReport, outReport]) {
            if (report?.reportType == 'staff' && staffReport == null) {
              staffReport = report;
            }
            if (report?.reportType == 'sup' && supReport == null) {
              supReport = report;
            }
          }
          
          row.add(staffReport?.userId ?? '');
          row.add(supReport?.userId ?? '');
          
          tableData.add(row);
        }
      } else {
        // Handle Out and PeriodicOut types
        final uniqueTimes = dayReports.map((r) => r.reportTime ?? '').toSet();
        if (uniqueTimes.isEmpty) {
          uniqueTimes.add(''); // Add empty time slot
        }
        
        for (final timeSlot in uniqueTimes) {
          List<String> row = [];
          
          // Date column
          if (checklist.checklistDateType == 'Multi') {
            row.add('${date.day}/${date.month}');
          }
          
          // Time column(s)
          if (checklist.checklistTimeType == 'PeriodicOut') {
            // Fill periodic time columns
            for (final periodTime in timeColumns) {
              final hasReportAtTime = dayReports.any((r) => 
                r.reportTime == periodTime && r.reportType == 'staff'
              );
              row.add(hasReportAtTime ? 'X' : '');
            }
          } else {
            row.add(timeSlot);
          }
          
          // Task columns
          for (final item in items) {
            String cellValue = '';
            
            if (checklist.checklistCompletionType == 'State') {
              ChecklistReportModel? staffReport;
              for (final report in dayReports) {
                if (report.reportType == 'staff' && 
                    report.reportTime == timeSlot &&
                    (report.reportTaskList?.contains(item.itemId) ?? false)) {
                  staffReport = report;
                  break;
                }
              }
              cellValue = staffReport?.reportNote ?? '';
            } else {
              final hasTask = dayReports.any((r) => 
                r.reportType == 'staff' && 
                r.reportTime == timeSlot &&
                (r.reportTaskList?.contains(item.itemId) ?? false)
              );
              cellValue = hasTask ? 'X' : '';
            }
            
            print('DEBUG PDF: Item ${item.itemId} for date $dateStr time $timeSlot: "$cellValue"');
            row.add(cellValue);
          }
          
          // Standard columns
          ChecklistReportModel? staffReport;
          ChecklistReportModel? supReport;
          
          for (final report in dayReports) {
            if (report.reportType == 'staff' && 
                report.reportTime == timeSlot && 
                staffReport == null) {
              staffReport = report;
            }
            if (report.reportType == 'sup' && 
                report.reportTime == timeSlot && 
                supReport == null) {
              supReport = report;
            }
          }
          
          row.add(staffReport?.userId ?? '');
          row.add(supReport?.userId ?? '');
          
          tableData.add(row);
        }
      }
    }
  }

  print('DEBUG PDF: Final table data rows: ${tableData.length}');
  print('DEBUG PDF: Sample row: ${tableData.length > 1 ? tableData[1] : 'No data rows'}');

  return pw.Table(
    border: pw.TableBorder.all(),
    children: tableData.map((row) => 
      pw.TableRow(
        children: row.map((cell) => 
          pw.Padding(
            padding: pw.EdgeInsets.all(4),
            child: pw.Text(
              cell,
              style: pw.TextStyle(
                font: font, 
                fontSize: 10,
                fontWeight: cell == 'X' ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ).toList(),
      ),
    ).toList(),
  );
}
  pw.Widget _buildPDFFooter(ChecklistListModel checklist, pw.Font font) {
    return pw.Column(
      children: [
        if (checklist.checklistSubtext != null && checklist.checklistSubtext!.isNotEmpty)
          pw.Text(
            checklist.checklistSubtext!,
            style: pw.TextStyle(font: font, fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Tạo bởi: ${widget.username} - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: pw.TextStyle(font: font, fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  List<String> _generatePeriodicTimeColumns(String startTime, String endTime, int intervalMinutes) {
    List<String> columns = [];
    
    final start = TimeOfDay(
      hour: int.parse(startTime.split(':')[0]),
      minute: int.parse(startTime.split(':')[1]),
    );
    final end = TimeOfDay(
      hour: int.parse(endTime.split(':')[0]),
      minute: int.parse(endTime.split(':')[1]),
    );
    
    int currentMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    while (currentMinutes <= endMinutes) {
      final hour = currentMinutes ~/ 60;
      final minute = currentMinutes % 60;
      columns.add('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      currentMinutes += intervalMinutes;
    }
    
    return columns;
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 156, 39, 176),
            Color.fromARGB(255, 186, 104, 200),
            Color.fromARGB(255, 171, 71, 188),
            Color.fromARGB(255, 206, 147, 216),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: isMobile ? 20 : 24),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Text(
                  'Checklist Lists',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          if (!_isLoading)
            Container(
              margin: EdgeInsets.only(top: isMobile ? 12 : 16),
              height: isMobile ? 36 : 40,
              child: ElevatedButton.icon(
                onPressed: () => _syncAllData(),
                icon: Icon(Icons.sync, size: isMobile ? 16 : 18),
                label: Text('Đồng bộ', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple[700],
                  elevation: 2,
                ),
              ),
            ),
          if (_isLoading && _syncStatus.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 8),
              child: Text(
                _syncStatus,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isMobile ? 12 : 14),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm checklist...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 8),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Text(
                  '${_filteredChecklists.length} lists',
                  style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w500, color: Colors.purple[700]),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedProject,
            hint: Text('Chọn dự án'),
            isExpanded: true,
            items: _projectOptions.map((project) => DropdownMenuItem(value: project, child: Text(project))).toList(),
            onChanged: (value) {
              setState(() {
                _selectedProject = value;
                _filterChecklists();
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(ChecklistListModel checklist) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final items = _getItemsForChecklist(checklist);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 6),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.list_alt, color: Colors.purple[600], size: isMobile ? 20 : 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checklist.checklistTitle ?? 'Unnamed Checklist',
                        style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${checklist.projectName ?? ''} - ${checklist.areaName ?? ''}',
                        style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showDateRangePicker(checklist),
                      icon: Icon(Icons.visibility, size: 14),
                      label: Text('Xem', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                                               backgroundColor: Colors.blue[600],
                       foregroundColor: Colors.white,
                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                       minimumSize: Size(0, 32),
                     ),
                   ),
                   SizedBox(width: 8),
                   ElevatedButton.icon(
                     onPressed: () => _showDateRangePicker(checklist),
                     icon: Icon(Icons.picture_as_pdf, size: 14),
                     label: Text('PDF', style: TextStyle(fontSize: 11)),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.purple[600],
                       foregroundColor: Colors.white,
                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                       minimumSize: Size(0, 32),
                     ),
                   ),
                 ],
               ),
             ],
           ),
           SizedBox(height: 12),
           _buildChecklistInfo(checklist, items, isMobile),
           SizedBox(height: 12),
           _buildItemsList(items, isMobile),
         ],
       ),
     ),
   );
 }

 Widget _buildChecklistInfo(ChecklistListModel checklist, List<ChecklistItemModel> items, bool isMobile) {
   return Wrap(
     spacing: 8,
     runSpacing: 4,
     children: [
       _buildInfoChip('ID: ${checklist.checklistId}', Colors.grey),
       _buildInfoChip('${checklist.checklistDateType}', Colors.blue),
       _buildInfoChip('${checklist.checklistTimeType}', Colors.green),
       _buildInfoChip('${checklist.checklistCompletionType}', Colors.orange),
       _buildInfoChip('${items.length} items', Colors.purple),
       if (checklist.versionNumber != null)
         _buildInfoChip('v${checklist.versionNumber}', Colors.teal),
       if (checklist.checklistNoteEnabled == 'true' || checklist.checklistNoteEnabled == '1')
         _buildInfoChip('Note enabled', Colors.indigo),
     ],
   );
 }

 Widget _buildInfoChip(String label, Color color) {
   return Container(
     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
     decoration: BoxDecoration(
       color: color.withOpacity(0.1),
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: color.withOpacity(0.3)),
     ),
     child: Text(
       label,
       style: TextStyle(
         fontSize: 11,
         color: Color.fromARGB(255, color.red ~/ 3, color.green ~/ 3, color.blue ~/ 3),
         fontWeight: FontWeight.w500
       ),
     ),
   );
 }

 Widget _buildItemsList(List<ChecklistItemModel> items, bool isMobile) {
   if (items.isEmpty) {
     return Container(
       padding: EdgeInsets.all(8),
       decoration: BoxDecoration(
         color: Colors.grey[100],
         borderRadius: BorderRadius.circular(8),
       ),
       child: Text(
         'Không có items nào',
         style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
       ),
     );
   }

   return Container(
     padding: EdgeInsets.all(8),
     decoration: BoxDecoration(
       color: Colors.purple[50],
       borderRadius: BorderRadius.circular(8),
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           'Items trong checklist:',
           style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.purple[700]),
         ),
         SizedBox(height: 4),
         Wrap(
           spacing: 4,
           runSpacing: 2,
           children: items.map((item) => Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               if (item.itemIcon != null && item.itemIcon!.isNotEmpty)
                 Icon(
                   _iconMap[item.itemIcon] ?? Icons.help_outline,
                   size: 14,
                   color: Colors.purple[600],
                 ),
               SizedBox(width: 4),
               Text(
                 item.itemName ?? item.itemId,
                 style: TextStyle(fontSize: 11, color: Colors.purple[600]),
               ),
             ],
           )).toList(),
         ),
       ],
     ),
   );
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     backgroundColor: Colors.grey[50],
     body: SafeArea(
       child: Column(
         children: [
           _buildHeader(),
           _buildFilterBar(),
           Expanded(
             child: _filteredChecklists.isEmpty
                 ? Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.list_alt_outlined, size: 64, color: Colors.grey[400]),
                         SizedBox(height: 16),
                         Text(
                           _isLoading ? 'Đang tải...' : 'Không có checklist nào',
                           style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                         ),
                       ],
                     ),
                   )
                 : ListView.builder(
                     itemCount: _filteredChecklists.length,
                     itemBuilder: (context, index) => _buildChecklistCard(_filteredChecklists[index]),
                   ),
           ),
         ],
       ),
     ),
   );
 }
}

// In-app Checklist Preview Screen
class ChecklistPreviewScreen extends StatelessWidget {
  final ChecklistListModel checklist;
  final List<ChecklistItemModel> items;
  final List<ChecklistReportModel> reports;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final bool useBlankDate;
  final Map<String, IconData> iconMap;
  final VoidCallback onGeneratePDF;

  const ChecklistPreviewScreen({
    Key? key,
    required this.checklist,
    required this.items,
    required this.reports,
    this.selectedStartDate,
    this.selectedEndDate,
    required this.useBlankDate,
    required this.iconMap,
    required this.onGeneratePDF,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Xem trước Checklist'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: onGeneratePDF,
            tooltip: 'Tạo PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            _buildPreviewHeader(isMobile),
            SizedBox(height: 20),
            _buildPreviewTable(isMobile),
            SizedBox(height: 20),
            // Debug info
            _buildDebugInfo(),
          ],
        ),
      ),
    );
  }

Widget _buildDebugInfo() {
  return Container(
    padding: EdgeInsets.all(16),
    margin: EdgeInsets.only(top: 16),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Total Reports: ${reports.length}'),
        Text('Selected Start Date: ${selectedStartDate?.toString() ?? 'None'}'),
        Text('Selected End Date: ${selectedEndDate?.toString() ?? 'None'}'),
        Text('Use Blank Date: $useBlankDate'),
        Text('Checklist ID: ${checklist.checklistId}'),
        Text('Checklist Time Type: ${checklist.checklistTimeType}'),
        Text('Checklist Completion Type: ${checklist.checklistCompletionType}'),
        SizedBox(height: 8),
        Text('Reports by Date:'),
        ...reports.take(5).map((report) {
          // Extract date part for display
          String reportDateOnly;
          try {
            if (report.reportDate.contains('T')) {
              reportDateOnly = report.reportDate.split('T')[0];
            } else if (report.reportDate.contains(' ')) {
              reportDateOnly = report.reportDate.split(' ')[0];
            } else {
              reportDateOnly = report.reportDate;
            }
          } catch (e) {
            reportDateOnly = report.reportDate;
          }
          
          return Text(
            '  $reportDateOnly - ${report.reportType} - Time: ${report.reportTime} - InOut: ${report.reportInOut ?? 'N/A'} - Tasks: ${report.reportTaskList ?? 'none'}'
          );
        }),
        if (reports.length > 5) Text('  ... and ${reports.length - 5} more'),
      ],
    ),
  );
}

  Widget _buildPreviewHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Main Logo
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: checklist.logoMain != null && checklist.logoMain!.isNotEmpty
                    ? Image.asset(
                        checklist.logoMain!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => 
                            Center(child: Text('LOGO', style: TextStyle(fontSize: 10))),
                      )
                    : Center(child: Text('LOGO', style: TextStyle(fontSize: 10))),
              ),
              // Title Section
              Expanded(
                child: Column(
                  children: [
                    Text(
                      checklist.checklistTitle ?? '',
                      style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (checklist.checklistPretext != null && checklist.checklistPretext!.isNotEmpty)
                      Text(
                        checklist.checklistPretext!,
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              // Secondary Logo
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: checklist.logoSecondary != null && checklist.logoSecondary!.isNotEmpty
                    ? Image.asset(
                        checklist.logoSecondary!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => 
                            Center(child: Text('LOGO2', style: TextStyle(fontSize: 10))),
                      )
                    : Center(child: Text('LOGO2', style: TextStyle(fontSize: 10))),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dự án: ${checklist.projectName ?? ''}', style: TextStyle(fontSize: 12)),
              Text('Khu vực: ${checklist.areaName ?? ''}', style: TextStyle(fontSize: 12)),
              Text('Tầng: ${checklist.floorName ?? ''}', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

 Widget _buildPreviewTable(bool isMobile) {
  List<DateTime> dateRange = [];
  if (checklist.checklistDateType == 'Multi') {
    if (!useBlankDate && selectedStartDate != null && selectedEndDate != null) {
      for (DateTime date = selectedStartDate!; 
           date.isBefore(selectedEndDate!.add(Duration(days: 1))); 
           date = date.add(Duration(days: 1))) {
        dateRange.add(date);
      }
    } else if (!useBlankDate && selectedStartDate != null) {
      dateRange = [selectedStartDate!];
    }
  } else {
    dateRange = !useBlankDate && selectedStartDate != null ? [selectedStartDate!] : [DateTime.now()];
  }

  List<String> timeColumns = [];
  if (checklist.checklistTimeType == 'PeriodicOut' && 
      checklist.checklistPeriodicStart != null && 
      checklist.checklistPeriodicEnd != null &&
      checklist.checklistPeriodInterval != null) {
    timeColumns = _generatePeriodicTimeColumns(
      checklist.checklistPeriodicStart!,
      checklist.checklistPeriodicEnd!,
      checklist.checklistPeriodInterval!,
    );
  }

  List<String> headers = [];
  
  // Date column for Multi type
  if (checklist.checklistDateType == 'Multi' && dateRange.isNotEmpty) {
    headers.add('Ngày');
  }

  // Time columns based on checklistTimeType
  if (checklist.checklistTimeType == 'InOut') {
    headers.addAll(['Giờ vào', 'Giờ ra']);
  } else if (checklist.checklistTimeType == 'PeriodicOut') {
    headers.addAll(timeColumns);
  } else {
    headers.add('Giờ');
  }

  // Task columns with icons
for (final item in items) {
  headers.add('${item.itemName ?? item.itemId}${item.itemIcon != null ? ' 🔧' : ''}'); // Add emoji as placeholder for icon
}

  // Standard columns
  headers.addAll(['Nhân viên trực', 'Giám sát trực']);

  // Filter reports by type and integrate with table data
  final relevantReports = reports.where((r) => 
    r.reportType == 'staff' || r.reportType == 'sup'
  ).toList();

  print('DEBUG: Total relevant reports: ${relevantReports.length}');
  print('DEBUG: Date range: $dateRange');
  print('DEBUG: Use blank date: $useBlankDate');

  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey[300]!),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        // Header row
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: headers.map((header) => Expanded(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Text(
                  header,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            )).toList(),
          ),
        ),
        // Data rows
        ...List.generate(useBlankDate || dateRange.isEmpty ? 15 : dateRange.length, (index) {
          if (useBlankDate || dateRange.isEmpty) {
            // Empty rows for blank date scenario
            return _buildTableRow(headers, List.filled(headers.length, ''));
          } else {
            // Populated rows with report data
            final date = dateRange[index];
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            
            // Find reports for this specific date - extract date part from reportDate
            final dayReports = relevantReports.where((r) {
              try {
                // Handle both date-only and datetime formats
                String reportDateOnly;
                if (r.reportDate.contains('T')) {
                  // Full datetime format like "2025-08-12T17:00:00.000Z"
                  reportDateOnly = r.reportDate.split('T')[0];
                } else if (r.reportDate.contains(' ')) {
                  // Format like "2025-08-12 17:00:00"
                  reportDateOnly = r.reportDate.split(' ')[0];
                } else {
                  // Already date-only format
                  reportDateOnly = r.reportDate;
                }
                return reportDateOnly == dateStr;
              } catch (e) {
                print('Error parsing report date: ${r.reportDate}');
                return false;
              }
            }).toList();
            
            print('DEBUG: Date $dateStr has ${dayReports.length} reports');
            if (dayReports.isNotEmpty) {
              print('DEBUG: Report times for $dateStr: ${dayReports.map((r) => '${r.reportTime} (${r.reportInOut})').toList()}');
            }
            
            List<String> row = [];
            
            // Date column
            if (checklist.checklistDateType == 'Multi') {
              row.add('${date.day}/${date.month}');
            }
            
            // Time columns based on checklistTimeType
            if (checklist.checklistTimeType == 'InOut') {
              // For InOut type, show In and Out times
              final inReports = dayReports.where((r) => r.reportInOut == 'In').toList();
              final outReports = dayReports.where((r) => r.reportInOut == 'Out').toList();
              
              // Giờ vào column
              if (inReports.isNotEmpty) {
                final inTimes = inReports.map((r) => r.reportTime ?? '').where((t) => t.isNotEmpty).toSet().toList();
                row.add(inTimes.join(', '));
              } else {
                row.add('');
              }
              
              // Giờ ra column
              if (outReports.isNotEmpty) {
                final outTimes = outReports.map((r) => r.reportTime ?? '').where((t) => t.isNotEmpty).toSet().toList();
                row.add(outTimes.join(', '));
              } else {
                row.add('');
              }
              
            } else if (checklist.checklistTimeType == 'PeriodicOut') {
              // Fill periodic time columns with 'X' if there's a report at that time
              for (final periodTime in timeColumns) {
                final hasReportAtTime = dayReports.any((r) => 
                  r.reportTime == periodTime && r.reportType == 'staff'
                );
                row.add(hasReportAtTime ? 'X' : '');
              }
            } else {
              // For 'Out' type, show the actual time from staff reports
              final staffReports = dayReports.where((r) => r.reportType == 'staff').toList();
              if (staffReports.isNotEmpty) {
                // Show times separated by comma if multiple
                final times = staffReports.map((r) => r.reportTime ?? '').where((t) => t.isNotEmpty).toSet().toList();
                row.add(times.join(', '));
              } else {
                row.add('');
              }
            }
            
            // Task columns with completion status
            for (final item in items) {
              String cellValue = '';
              
              if (checklist.checklistCompletionType == 'State') {
                // Show note from staff report
                final staffReport = dayReports.where((r) => 
                  r.reportType == 'staff' && 
                  (r.reportTaskList?.contains(item.itemId) ?? false)
                ).firstOrNull;
                cellValue = staffReport?.reportNote ?? '';
              } else {
                // Show 'X' if task is completed by staff
                final hasTask = dayReports.any((r) => 
                  r.reportType == 'staff' && 
                  (r.reportTaskList?.contains(item.itemId) ?? false)
                );
                cellValue = hasTask ? 'X' : '';
              }
              
              print('DEBUG: Item ${item.itemId} has task: ${cellValue != ''} for date $dateStr');
              row.add(cellValue);
            }
            
            // Standard columns
            final staffReport = dayReports.where((r) => r.reportType == 'staff').firstOrNull;
            final supReport = dayReports.where((r) => r.reportType == 'sup').firstOrNull;
            
            row.add(staffReport?.userId ?? '');
            row.add(supReport?.userId ?? '');
            
            return _buildTableRow(headers, row);
          }
        }),
      ],
    ),
  );
}

  Widget _buildTableRow(List<String> headers, List<String> row) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: List.generate(headers.length, (index) => Expanded(
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Text(
              index < row.length ? row[index] : '',
              style: TextStyle(
                fontSize: 11,
                color: row[index] == 'X' ? Colors.green[700] : Colors.black,
                fontWeight: row[index] == 'X' ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        )),
      ),
    );
  }

  List<String> _generatePeriodicTimeColumns(String startTime, String endTime, int intervalMinutes) {
    List<String> columns = [];
    
    final start = TimeOfDay(
      hour: int.parse(startTime.split(':')[0]),
      minute: int.parse(startTime.split(':')[1]),
    );
    final end = TimeOfDay(
      hour: int.parse(endTime.split(':')[0]),
      minute: int.parse(endTime.split(':')[1]),
    );
    
    int currentMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    while (currentMinutes <= endMinutes) {
      final hour = currentMinutes ~/ 60;
      final minute = currentMinutes % 60;
      columns.add('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      currentMinutes += intervalMinutes;
    }
    
    return columns;
  }
}

class ChecklistListModel {
 final String checklistId;
 final String? userId;
 final String date;
 final String time;
 final int? versionNumber;
 final String? projectName;
 final String? areaName;
 final String? floorName;
 final String? checklistTitle;
 final String? checklistPretext;
 final String? checklistSubtext;
 final String? logoMain;
 final String? logoSecondary;
 final String? checklistTaskList;
 final String? checklistDateType;
 final String? checklistTimeType;
 final String? checklistPeriodicStart;
 final String? checklistPeriodicEnd;
 final int? checklistPeriodInterval;
 final String? checklistCompletionType;
 final String? checklistNoteEnabled;
 final String? cloudUrl;

 ChecklistListModel({
   required this.checklistId,
   this.userId,
   required this.date,
   required this.time,
   this.versionNumber,
   this.projectName,
   this.areaName,
   this.floorName,
   this.checklistTitle,
   this.checklistPretext,
   this.checklistSubtext,
   this.logoMain,
   this.logoSecondary,
   this.checklistTaskList,
   this.checklistDateType,
   this.checklistTimeType,
   this.checklistPeriodicStart,
   this.checklistPeriodicEnd,
   this.checklistPeriodInterval,
   this.checklistCompletionType,
   this.checklistNoteEnabled,
   this.cloudUrl,
 });

 Map<String, dynamic> toMap() {
   return {
     'checklistId': checklistId,
     'userId': userId,
     'date': date,
     'time': time,
     'versionNumber': versionNumber,
     'projectName': projectName,
     'areaName': areaName,
     'floorName': floorName,
     'checklistTitle': checklistTitle,
     'checklistPretext': checklistPretext,
     'checklistSubtext': checklistSubtext,
     'logoMain': logoMain,
     'logoSecondary': logoSecondary,
     'checklistTaskList': checklistTaskList,
     'checklistDateType': checklistDateType,
     'checklistTimeType': checklistTimeType,
     'checklistPeriodicStart': checklistPeriodicStart,
     'checklistPeriodicEnd': checklistPeriodicEnd,
     'checklistPeriodInterval': checklistPeriodInterval,
     'checklistCompletionType': checklistCompletionType,
     'checklistNoteEnabled': checklistNoteEnabled,
     'cloudUrl': cloudUrl,
   };
 }

 factory ChecklistListModel.fromMap(Map<String, dynamic> map) {
   return ChecklistListModel(
     checklistId: map['checklistId'] ?? '',
     userId: map['userId'],
     date: map['date'] ?? '',
     time: map['time'] ?? '',
     versionNumber: map['versionNumber'],
     projectName: map['projectName'],
     areaName: map['areaName'],
     floorName: map['floorName'],
     checklistTitle: map['checklistTitle'],
     checklistPretext: map['checklistPretext'],
     checklistSubtext: map['checklistSubtext'],
     logoMain: map['logoMain'],
     logoSecondary: map['logoSecondary'],
     checklistTaskList: map['checklistTaskList'],
     checklistDateType: map['checklistDateType'],
     checklistTimeType: map['checklistTimeType'],
     checklistPeriodicStart: map['checklistPeriodicStart'],
     checklistPeriodicEnd: map['checklistPeriodicEnd'],
     checklistPeriodInterval: map['checklistPeriodInterval'],
     checklistCompletionType: map['checklistCompletionType'],
     checklistNoteEnabled: map['checklistNoteEnabled'],
     cloudUrl: map['cloudUrl'],
   );
 }
}

class ChecklistItemModel {
 final String itemId;
 final String? itemName;
 final String? itemImage;
 final String? itemIcon;

 ChecklistItemModel({
   required this.itemId,
   this.itemName,
   this.itemImage,
   this.itemIcon,
 });

 Map<String, dynamic> toMap() {
   return {
     'itemId': itemId,
     'itemName': itemName,
     'itemImage': itemImage,
     'itemIcon': itemIcon,
   };
 }

 factory ChecklistItemModel.fromMap(Map<String, dynamic> map) {
   return ChecklistItemModel(
     itemId: map['itemId'] ?? '',
     itemName: map['itemName'],
     itemImage: map['itemImage'],
     itemIcon: map['itemIcon'],
   );
 }
}

class ChecklistReportModel {
 final String reportId;
 final String? checklistId;
 final String? projectName;
 final String? reportType;
 final String reportDate;
 final String reportTime;
 final String? userId;
 final String? reportTaskList;
 final String? reportNote;
 final String? reportImage;
 final String? reportInOut;

 ChecklistReportModel({
   required this.reportId,
   this.checklistId,
   this.projectName,
   this.reportType,
   required this.reportDate,
   required this.reportTime,
   this.userId,
   this.reportTaskList,
   this.reportNote,
   this.reportImage,
   this.reportInOut,
 });

 Map<String, dynamic> toMap() {
   return {
     'reportId': reportId,
     'checklistId': checklistId,
     'projectName': projectName,
     'reportType': reportType,
     'reportDate': reportDate,
     'reportTime': reportTime,
     'userId': userId,
     'reportTaskList': reportTaskList,
     'reportNote': reportNote,
     'reportImage': reportImage,
     'reportInOut': reportInOut,
   };
 }

 factory ChecklistReportModel.fromMap(Map<String, dynamic> map) {
   return ChecklistReportModel(
     reportId: map['reportId'] ?? '',
     checklistId: map['checklistId'],
     projectName: map['projectName'],
     reportType: map['reportType'],
     reportDate: map['reportDate'] ?? '',
     reportTime: map['reportTime'] ?? '',
     userId: map['userId'],
     reportTaskList: map['reportTaskList'],
     reportNote: map['reportNote'],
     reportImage: map['reportImage'],
     reportInOut: map['reportInOut'],
   );
 }
}