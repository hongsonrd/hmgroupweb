import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'checklist_item.dart';
import 'checklist_list.dart';
import 'checklist_report.dart';

class ChecklistManager extends StatefulWidget {
  final String username;
  const ChecklistManager({Key? key, required this.username}) : super(key: key);
  @override
  _ChecklistManagerState createState() => _ChecklistManagerState();
}

class _ChecklistManagerState extends State<ChecklistManager> {
  bool _isLoading = false;
  String _syncStatus = '';
  List<ChecklistItemModel> _checklistItems = [];
  List<ChecklistReportModel> _checklistReports = [];
  List<ChecklistListModel> _checklistLists = [];
  Map<String, int> _recordCounts = {'items': 0, 'reports': 0, 'lists': 0};
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  static const String _itemsKey = 'checklist_items_v1';
  static const String _reportsKey = 'checklist_reports_v1';
  static const String _listsKey = 'checklist_lists_v1';
  static const String _lastSyncKey = 'checklist_last_sync';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _checkAndSyncData();
  }

  Future<void> _checkAndSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final today = DateTime.now();
    final isNewDay = lastSyncDate.day != today.day || lastSyncDate.month != today.month || lastSyncDate.year != today.year;
    if (lastSync == 0 || isNewDay) {
      await _syncAllTables();
    } else {
      await _loadLocalData();
    }
  }

  Future<void> _syncAllTables() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ dữ liệu checklist...';
    });
    try {
      await Future.wait([_syncChecklistItems(), _syncChecklistReports(), _syncChecklistLists()]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      _showSuccess('Đồng bộ thành công - Items: ${_recordCounts['items']}, Reports: ${_recordCounts['reports']}, Lists: ${_recordCounts['lists']}');
    } catch (e) {
      print('Error syncing checklist data: $e');
      _showError('Không thể đồng bộ dữ liệu: ${e.toString()}');
      await _loadLocalData();
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _syncChecklistItems() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/checklistitem/${widget.username}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final items = data.map((item) => ChecklistItemModel.fromMap(item)).toList();
        await _saveChecklistItemsLocally(items);
        setState(() {
          _checklistItems = items;
          _recordCounts['items'] = items.length;
        });
      } else {
        throw Exception('Failed to sync checklist items: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing checklist items: $e');
      await _loadLocalChecklistItems();
      rethrow;
    }
  }

  Future<void> _syncChecklistReports() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/checklistreport/${widget.username}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final reports = data.map((report) => ChecklistReportModel.fromMap(report)).toList();
        await _saveChecklistReportsLocally(reports);
        setState(() {
          _checklistReports = reports;
          _recordCounts['reports'] = reports.length;
        });
      } else {
        throw Exception('Failed to sync checklist reports: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing checklist reports: $e');
      await _loadLocalChecklistReports();
      rethrow;
    }
  }

  Future<void> _syncChecklistLists() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/checklistlist/${widget.username}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final lists = data.map((list) => ChecklistListModel.fromMap(list)).toList();
        await _saveChecklistListsLocally(lists);
        setState(() {
          _checklistLists = lists;
          _recordCounts['lists'] = lists.length;
        });
      } else {
        throw Exception('Failed to sync checklist lists: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing checklist lists: $e');
      await _loadLocalChecklistLists();
      rethrow;
    }
  }

  Future<void> _saveChecklistItemsLocally(List<ChecklistItemModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.map((item) => json.encode(item.toMap())).toList();
      await prefs.setStringList(_itemsKey, jsonList);
    } catch (e) {
      print('Error saving checklist items locally: $e');
    }
  }

  Future<void> _saveChecklistReportsLocally(List<ChecklistReportModel> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reports.map((report) => json.encode(report.toMap())).toList();
      await prefs.setStringList(_reportsKey, jsonList);
    } catch (e) {
      print('Error saving checklist reports locally: $e');
    }
  }

  Future<void> _saveChecklistListsLocally(List<ChecklistListModel> lists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = lists.map((list) => json.encode(list.toMap())).toList();
      await prefs.setStringList(_listsKey, jsonList);
    } catch (e) {
      print('Error saving checklist lists locally: $e');
    }
  }

  Future<void> _loadLocalData() async {
    await Future.wait([_loadLocalChecklistItems(), _loadLocalChecklistReports(), _loadLocalChecklistLists()]);
  }

  Future<void> _loadLocalChecklistItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_itemsKey) ?? [];
      final items = jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistItemModel.fromMap(map);
      }).toList();
      setState(() {
        _checklistItems = items;
        _recordCounts['items'] = items.length;
      });
    } catch (e) {
      print('Error loading local checklist items: $e');
      setState(() {
        _checklistItems = [];
        _recordCounts['items'] = 0;
      });
    }
  }

  Future<void> _loadLocalChecklistReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_reportsKey) ?? [];
      final reports = jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistReportModel.fromMap(map);
      }).toList();
      reports.sort((a, b) {
        final dateTimeA = '${a.reportDate} ${a.reportTime}';
        final dateTimeB = '${b.reportDate} ${b.reportTime}';
        return dateTimeB.compareTo(dateTimeA);
      });
      setState(() {
        _checklistReports = reports;
        _recordCounts['reports'] = reports.length;
      });
    } catch (e) {
      print('Error loading local checklist reports: $e');
      setState(() {
        _checklistReports = [];
        _recordCounts['reports'] = 0;
      });
    }
  }

  Future<void> _loadLocalChecklistLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_listsKey) ?? [];
      final lists = jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistListModel.fromMap(map);
      }).toList();
      lists.sort((a, b) {
        final dateTimeA = '${a.date} ${a.time}';
        final dateTimeB = '${b.date} ${b.time}';
        return dateTimeB.compareTo(dateTimeA);
      });
      setState(() {
        _checklistLists = lists;
        _recordCounts['lists'] = lists.length;
      });
    } catch (e) {
      print('Error loading local checklist lists: $e');
      setState(() {
        _checklistLists = [];
        _recordCounts['lists'] = 0;
      });
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, duration: Duration(seconds: 3)));
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
    }
  }

  Map<String, Map<String, int>> _getReportCountsByChecklistAndDay() {
    final Map<String, Map<String, int>> result = {};
    for (var report in _checklistReports) {
      final checklistId = report.checklistId ?? 'N/A';
      final date = report.reportDate;
      if (!result.containsKey(checklistId)) {
        result[checklistId] = {};
      }
      result[checklistId]![date] = (result[checklistId]![date] ?? 0) + 1;
    }
    return result;
  }

  Map<String, Map<String, int>> _getReportCountsByProjectAndDay() {
    final Map<String, Map<String, int>> result = {};
    for (var report in _checklistReports) {
      final projectName = report.projectName ?? 'N/A';
      final date = report.reportDate;
      if (!result.containsKey(projectName)) {
        result[projectName] = {};
      }
      result[projectName]![date] = (result[projectName]![date] ?? 0) + 1;
    }
    return result;
  }

  Map<String, Map<String, int>> _getReportCountsByProjectChecklistUserAndDay() {
    final Map<String, Map<String, int>> result = {};
    for (var report in _checklistReports) {
      final projectName = report.projectName ?? 'N/A';
      final checklistId = report.checklistId ?? 'N/A';
      final userId = report.userId ?? 'N/A';
      final date = report.reportDate;
      final key = '$projectName|$checklistId|$userId';
      if (!result.containsKey(key)) {
        result[key] = {};
      }
      result[key]![date] = (result[key]![date] ?? 0) + 1;
    }
    return result;
  }

  List<String> _getRecentDays(int days) {
    final now = DateTime.now();
    final List<String> dates = [];
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      dates.add(DateFormat('yyyy-MM-dd').format(date));
    }
    return dates;
  }

  Future<void> _generateReportExcel() async {
    try {
      final excelDoc = excel_pkg.Excel.createExcel();
      final sheet = excelDoc['Báo cáo checklist'];
      final countDataByChecklist = _getReportCountsByChecklistAndDay();
      final countDataByProject = _getReportCountsByProjectAndDay();
      final recentDays = _getRecentDays(45);
      final checklistIds = countDataByChecklist.keys.toList()..sort();
      
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'BÁO CÁO SỐ LƯỢNG CHECKLIST THEO NGÀY (45 NGÀY)';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 'Người tạo: ${widget.username}';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = 'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';
      
      int headerRow = 4;
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow)).value = 'Checklist ID';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#4CAF50', fontColorHex: '#FFFFFF');
      
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow)).value = 'Dự án';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#4CAF50', fontColorHex: '#FFFFFF');
      
      for (int i = 0; i < recentDays.length; i++) {
        final date = recentDays[i];
        final displayDate = DateFormat('dd/MM').format(DateTime.parse(date));
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 2, rowIndex: headerRow)).value = displayDate;
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 2, rowIndex: headerRow)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#4CAF50', fontColorHex: '#FFFFFF');
      }
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 2, rowIndex: headerRow)).value = 'Tổng';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 2, rowIndex: headerRow)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#2196F3', fontColorHex: '#FFFFFF');
      
      int currentRow = headerRow + 1;
      for (var checklistId in checklistIds) {
        final projectName = _checklistReports.firstWhere((r) => r.checklistId == checklistId, orElse: () => ChecklistReportModel(reportId: '', reportDate: '', reportTime: '')).projectName ?? 'N/A';
        
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = checklistId;
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = projectName;
        
        int rowTotal = 0;
        for (int i = 0; i < recentDays.length; i++) {
          final date = recentDays[i];
          final count = countDataByChecklist[checklistId]?[date] ?? 0;
          rowTotal += count;
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 2, rowIndex: currentRow)).value = count > 0 ? count : '';
        }
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 2, rowIndex: currentRow)).value = rowTotal;
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 2, rowIndex: currentRow)).cellStyle = excel_pkg.CellStyle(bold: true);
        currentRow++;
      }
      
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = 'TỔNG';
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FFC107');
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FFC107');
      
      int grandTotal = 0;
      for (int i = 0; i < recentDays.length; i++) {
        final date = recentDays[i];
        int dayTotal = 0;
        for (var checklistId in checklistIds) {
          dayTotal += countDataByChecklist[checklistId]?[date] ?? 0;
        }
        grandTotal += dayTotal;
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 2, rowIndex: currentRow)).value = dayTotal;
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 2, rowIndex: currentRow)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FFC107');
      }
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 2, rowIndex: currentRow)).value = grandTotal;
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 2, rowIndex: currentRow)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FF5722', fontColorHex: '#FFFFFF');
      
      final sheet2 = excelDoc['Chi tiết theo user'];
      final countDataByUser = _getReportCountsByProjectChecklistUserAndDay();
      final userKeys = countDataByUser.keys.toList()..sort();
      
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'BÁO CÁO CHI TIẾT THEO USER (45 NGÀY)';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 'Người tạo: ${widget.username}';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = 'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}';
      
      int headerRow2 = 4;
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow2)).value = 'Dự án';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#4CAF50', fontColorHex: '#FFFFFF');
      
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow2)).value = 'Checklist ID';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#4CAF50', fontColorHex: '#FFFFFF');
      
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: headerRow2)).value = 'User ID';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: headerRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#4CAF50', fontColorHex: '#FFFFFF');
      
      for (int i = 0; i < recentDays.length; i++) {
        final date = recentDays[i];
        final displayDate = DateFormat('dd/MM').format(DateTime.parse(date));
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: headerRow2)).value = displayDate;
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: headerRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#4CAF50', fontColorHex: '#FFFFFF');
      }
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 3, rowIndex: headerRow2)).value = 'Tổng';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 3, rowIndex: headerRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#2196F3', fontColorHex: '#FFFFFF');
      
      int currentRow2 = headerRow2 + 1;
      for (var key in userKeys) {
        final parts = key.split('|');
        final projectName = parts[0];
        final checklistId = parts[1];
        final userId = parts[2];
        
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow2)).value = projectName;
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow2)).value = checklistId;
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow2)).value = userId;
        
        int rowTotal = 0;
        for (int i = 0; i < recentDays.length; i++) {
          final date = recentDays[i];
          final count = countDataByUser[key]?[date] ?? 0;
          rowTotal += count;
          sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: currentRow2)).value = count > 0 ? count : '';
        }
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 3, rowIndex: currentRow2)).value = rowTotal;
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 3, rowIndex: currentRow2)).cellStyle = excel_pkg.CellStyle(bold: true);
        currentRow2++;
      }
      
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow2)).value = 'TỔNG';
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FFC107');
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FFC107');
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FFC107');
      
      int grandTotal2 = 0;
      for (int i = 0; i < recentDays.length; i++) {
        final date = recentDays[i];
        int dayTotal = 0;
        for (var key in userKeys) {
          dayTotal += countDataByUser[key]?[date] ?? 0;
        }
        grandTotal2 += dayTotal;
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: currentRow2)).value = dayTotal;
        sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: currentRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FFC107');
      }
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 3, rowIndex: currentRow2)).value = grandTotal2;
      sheet2.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: recentDays.length + 3, rowIndex: currentRow2)).cellStyle = excel_pkg.CellStyle(bold: true, backgroundColorHex: '#FF5722', fontColorHex: '#FFFFFF');
      
      final excelBytes = excelDoc.encode()!;
      final dir = await getApplicationDocumentsDirectory();
      final reportDir = Directory('${dir.path}/ChecklistReports');
      if (!await reportDir.exists()) {
        await reportDir.create(recursive: true);
      }
      final now = DateTime.now();
      final ts = DateFormat('yyyyMMddHHmmss').format(now);
      final rand = 1000000 + Random().nextInt(9000000);
      final fileName = '${ts}_checklist_report_$rand.xlsx';
      final file = File('${reportDir.path}/$fileName');
      await file.writeAsBytes(excelBytes, flush: true);
      
      if (mounted) {
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 12), Text('Đã tạo Excel')]),
            content: Text('File đã được lưu tại:\n${file.path}\n\nBạn muốn làm gì?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, 'share'), child: Text('Chia sẻ')),
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                TextButton(onPressed: () => Navigator.pop(context, 'open'), child: Text('Mở file')),
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                TextButton(onPressed: () => Navigator.pop(context, 'folder'), child: Text('Mở thư mục')),
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng'))
            ]
          )
        );
        if (result == 'share') {
          await Share.shareXFiles([XFile(file.path)], text: 'Báo cáo checklist');
        } else if (result == 'open') {
          await _openFile(file.path);
        } else if (result == 'folder') {
          await _openFolder(reportDir.path);
        }
      }
    } catch (e) {
      print('Error generating Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tạo Excel: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      print('Error opening file: $e');
    }
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

  Widget _buildRecentReportsCard() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final recentDays = _getRecentDays(7);
    final countData = _getReportCountsByProjectAndDay();
    
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Báo cáo 7 ngày gần nhất (theo dự án)', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(width: 280, child: Text('Dự án', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    ...recentDays.map((date) {
                      final displayDate = DateFormat('dd/MM').format(DateTime.parse(date));
                      return SizedBox(width: 45, child: Text(displayDate, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)));
                    }).toList(),
                    SizedBox(width: 50, child: Text('Tổng', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
                Divider(thickness: 2),
                ...countData.entries.map((entry) {
                  int rowTotal = 0;
                  for (var date in recentDays) {
                    rowTotal += entry.value[date] ?? 0;
                  }
                  
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 280,
                          child: Text(entry.key, style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        ...recentDays.map((date) {
                          final count = entry.value[date] ?? 0;
                          return SizedBox(
                            width: 45,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                count > 0 ? count.toString() : '-',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                                  color: count > 0 ? Colors.blue[700] : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        SizedBox(
                          width: 50,
                          child: Text(
                            rowTotal.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[700]),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                Divider(thickness: 2),
                Row(
                  children: [
                    SizedBox(width: 280, child: Text('TỔNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    ...recentDays.map((date) {
                      int dayTotal = 0;
                      for (var entry in countData.entries) {
                        dayTotal += entry.value[date] ?? 0;
                      }
                      return SizedBox(
                        width: 45,
                        child: Text(
                          dayTotal.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange[700]),
                        ),
                      );
                    }).toList(),
                    SizedBox(
                      width: 50,
                      child: Text(
                        countData.values.fold<int>(0, (sum, map) => sum + map.values.fold<int>(0, (s, v) => s + v)).toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.apps, color: Colors.green[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Quản lý dữ liệu', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.green[800])),
                ),
                TextButton.icon(
                  onPressed: _generateReportExcel,
                  icon: Icon(Icons.table_chart, color: Colors.green[700]),
                  label: Text('Xuất Excel', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                )
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                _buildActionButton(
                  icon: Icons.check_box_outlined,
                  title: 'Hạng mục Checklist',
                  subtitle: '${_recordCounts['items']} items',
                  color: Colors.blue,
                  onTap: () => _navigateToItems(),
                  isMobile: isMobile,
                ),
                SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.assignment_outlined,
                  title: 'Báo cáo Checklist',
                  subtitle: '${_recordCounts['reports']} reports',
                  color: Colors.orange,
                  onTap: () => _navigateToReports(),
                  isMobile: isMobile,
                ),
                SizedBox(height: 12),
                _buildActionButton(
                  icon: Icons.list_alt_outlined,
                  title: 'Danh sách Checklist',
                  subtitle: '${_recordCounts['lists']} lists',
                  color: Colors.purple,
                  onTap: () => _navigateToLists(),
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: isMobile ? 20 : 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                  Text(subtitle, style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: isMobile ? 20 : 24),
          ],
        ),
      ),
    );
  }

  void _navigateToItems() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChecklistItemScreen(username: widget.username)));
  }

  void _navigateToReports() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChecklistReportScreen(username: widget.username)));
  }

  void _navigateToLists() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChecklistListScreen(username: widget.username)));
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.fromARGB(255, 76, 175, 80), Color.fromARGB(255, 129, 199, 132), Color.fromARGB(255, 102, 187, 106), Color.fromARGB(255, 165, 214, 167)],
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
              Expanded(child: Text('Quản lý Checklist', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: Colors.white))),
              if (_isLoading)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
            ],
          ),
          if (!_isLoading)
            Container(
              margin: EdgeInsets.only(top: isMobile ? 12 : 16),
              height: isMobile ? 36 : 40,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _syncAllTables(),
                      icon: Icon(Icons.sync, size: isMobile ? 16 : 18),
                      label: Text('Đồng bộ dữ liệu', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green[700],
                        elevation: 2,
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isLoading && _syncStatus.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 8),
              child: Text(_syncStatus, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isMobile ? 12 : 14), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncStatus() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.assessment_outlined, color: Colors.green[600]),
                SizedBox(width: 8),
                Text('Trạng thái dữ liệu', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.green[800])),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                _buildDataCountRow(icon: Icons.check_box_outlined, label: 'Checklist Items', count: _recordCounts['items']!, color: Colors.blue, isMobile: isMobile),
                SizedBox(height: 12),
                _buildDataCountRow(icon: Icons.assignment_outlined, label: 'Checklist Reports', count: _recordCounts['reports']!, color: Colors.orange, isMobile: isMobile),
                SizedBox(height: 12),
                _buildDataCountRow(icon: Icons.list_alt_outlined, label: 'Checklist Lists', count: _recordCounts['lists']!, color: Colors.purple, isMobile: isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCountRow({required IconData icon, required String label, required int count, required Color color, required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 24),
          SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w500, color: Colors.grey[800]))),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 4 : 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            child: Text(count.toString(), style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLastSyncInfo() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        final prefs = snapshot.data!;
        final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
        if (lastSync == 0) return SizedBox.shrink();
        final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(lastSyncDate);
        return Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(Icons.schedule, size: isMobile ? 16 : 18, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text('Đồng bộ lần cuối: $formattedDate', style: TextStyle(fontSize: isMobile ? 12 : 14, color: Colors.grey[600])),
            ],
          ),
        );
      },
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildLastSyncInfo(),
                    _buildQuickActions(),
                    SizedBox(height: 8),
                    _buildRecentReportsCard(),
                    SizedBox(height: 8),
                    _buildSyncStatus(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChecklistItemModel {
  final String itemId;
  final String? itemName;
  final String? itemImage;
  final String? itemIcon;
  ChecklistItemModel({required this.itemId, this.itemName, this.itemImage, this.itemIcon});
  Map<String, dynamic> toMap() => {'itemId': itemId, 'itemName': itemName, 'itemImage': itemImage, 'itemIcon': itemIcon};
  factory ChecklistItemModel.fromMap(Map<String, dynamic> map) => ChecklistItemModel(itemId: map['itemId'] ?? '', itemName: map['itemName'], itemImage: map['itemImage'], itemIcon: map['itemIcon']);
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
  ChecklistReportModel({required this.reportId, this.checklistId, this.projectName, this.reportType, required this.reportDate, required this.reportTime, this.userId, this.reportTaskList, this.reportNote, this.reportImage});
  Map<String, dynamic> toMap() => {'reportId': reportId, 'checklistId': checklistId, 'projectName': projectName, 'reportType': reportType, 'reportDate': reportDate, 'reportTime': reportTime, 'userId': userId, 'reportTaskList': reportTaskList, 'reportNote': reportNote, 'reportImage': reportImage};
  factory ChecklistReportModel.fromMap(Map<String, dynamic> map) => ChecklistReportModel(reportId: map['reportId'] ?? '', checklistId: map['checklistId'], projectName: map['projectName'], reportType: map['reportType'], reportDate: map['reportDate'] ?? '', reportTime: map['reportTime'] ?? '', userId: map['userId'], reportTaskList: map['reportTaskList'], reportNote: map['reportNote'], reportImage: map['reportImage']);
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
  ChecklistListModel({required this.checklistId, this.userId, required this.date, required this.time, this.versionNumber, this.projectName, this.areaName, this.floorName, this.checklistTitle, this.checklistPretext, this.checklistSubtext, this.logoMain, this.logoSecondary, this.checklistTaskList, this.checklistDateType, this.checklistTimeType, this.checklistPeriodicStart, this.checklistPeriodicEnd, this.checklistPeriodInterval, this.checklistCompletionType, this.checklistNoteEnabled, this.cloudUrl});
  Map<String, dynamic> toMap() => {'checklistId': checklistId, 'userId': userId, 'date': date, 'time': time, 'versionNumber': versionNumber, 'projectName': projectName, 'areaName': areaName, 'floorName': floorName, 'checklistTitle': checklistTitle, 'checklistPretext': checklistPretext, 'checklistSubtext': checklistSubtext, 'logoMain': logoMain, 'logoSecondary': logoSecondary, 'checklistTaskList': checklistTaskList, 'checklistDateType': checklistDateType, 'checklistTimeType': checklistTimeType, 'checklistPeriodicStart': checklistPeriodicStart, 'checklistPeriodicEnd': checklistPeriodicEnd, 'checklistPeriodInterval': checklistPeriodInterval, 'checklistCompletionType': checklistCompletionType, 'checklistNoteEnabled': checklistNoteEnabled, 'cloudUrl': cloudUrl};
  factory ChecklistListModel.fromMap(Map<String, dynamic> map) => ChecklistListModel(checklistId: map['checklistId'] ?? '', userId: map['userId'], date: map['date'] ?? '', time: map['time'] ?? '', versionNumber: map['versionNumber'], projectName: map['projectName'], areaName: map['areaName'], floorName: map['floorName'], checklistTitle: map['checklistTitle'], checklistPretext: map['checklistPretext'], checklistSubtext: map['checklistSubtext'], logoMain: map['logoMain'], logoSecondary: map['logoSecondary'], checklistTaskList: map['checklistTaskList'], checklistDateType: map['checklistDateType'], checklistTimeType: map['checklistTimeType'], checklistPeriodicStart: map['checklistPeriodicStart'], checklistPeriodicEnd: map['checklistPeriodicEnd'], checklistPeriodInterval: map['checklistPeriodInterval'], checklistCompletionType: map['checklistCompletionType'], checklistNoteEnabled: map['checklistNoteEnabled'], cloudUrl: map['cloudUrl']);
}