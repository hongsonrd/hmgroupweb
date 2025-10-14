import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'table_models.dart';
import 'db_helper.dart';
import 'projectcongnhanllvgs.dart';
import 'dart:async';
class ProjectCongNhanExcel {
static Future<void> exportToExcel({
required List<TaskHistoryModel> allData,
required List<String> projectOptions,
required BuildContext context,
List<TaskScheduleModel> taskSchedules = const [],
List<QRLookupModel> qrLookups = const [],
}) async {
ProgressDialog.show(context, 'Đang khởi tạo...');
await Future.delayed(Duration(milliseconds: 100));
try {
ProgressDialog.updateMessage('Đang lọc dữ liệu 2 tháng gần nhất...');
await Future.delayed(Duration(milliseconds: 50));
final filteredData = _filterRecentMonths(allData);
ProgressDialog.updateMessage('Đang hiệu chỉnh dữ liệu dự án (${filteredData.length} bản ghi)...');
await Future.delayed(Duration(milliseconds: 50));
final correctedData = await _applyCorrectionToDataAsync(filteredData);
ProgressDialog.updateMessage('Đang tải danh sách nhân viên...');
await Future.delayed(Duration(milliseconds: 50));
final staffNameMap = await _getStaffNameMap();
ProgressDialog.updateMessage('Đang khởi tạo file Excel...');
await Future.delayed(Duration(milliseconds: 50));
final excel = Excel.createExcel();
excel.delete('Sheet1');
ProgressDialog.updateMessage('Đang tạo bảng theo chủ đề...');
await Future.delayed(Duration(milliseconds: 50));
await _createTheoChuDeSheet(
excel, 
correctedData, 
staffNameMap,
taskSchedules: taskSchedules,
qrLookups: qrLookups,
);
ProgressDialog.updateMessage('Đang tạo bảng chi tiết...');
await Future.delayed(Duration(milliseconds: 50));
await _createChiTietSheet(excel, correctedData, staffNameMap);
ProgressDialog.updateMessage('Đang lưu file...');
await Future.delayed(Duration(milliseconds: 50));
final fileName = 'DuAn_CongNhan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
await _saveAndHandleFile(excel, fileName, context);
ProgressDialog.hide();
} catch (e) {
ProgressDialog.hide();
if (context.mounted) {
_showErrorDialog(context, e.toString());
}
rethrow;
}
}
static List<TaskHistoryModel> _filterRecentMonths(List<TaskHistoryModel> allData) {
final now = DateTime.now();
final currentMonth = DateTime(now.year, now.month, 1);
final lastMonth = DateTime(now.year, now.month - 1, 1);
return allData.where((record) {
final recordMonth = DateTime(record.ngay.year, record.ngay.month, 1);
return recordMonth == currentMonth || recordMonth == lastMonth;
}).toList();
}
static void _showErrorDialog(BuildContext context, String error) {
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: Row(
children: [
Icon(Icons.error, color: Colors.red),
SizedBox(width: 8),
Text('Lỗi xuất file'),
],
),
content: Text('Đã xảy ra lỗi: $error'),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: Text('Đóng'),
),
],
);
},
);
}
static Future<void> exportToExcelMonth({
required List<TaskHistoryModel> allData,
required List<String> projectOptions,
required DateTime selectedMonth,
required BuildContext context,
List<TaskScheduleModel> taskSchedules = const [],
List<QRLookupModel> qrLookups = const [],
}) async {
ProgressDialog.show(context, 'Đang khởi tạo...');
await Future.delayed(Duration(milliseconds: 100));
try {
ProgressDialog.updateMessage('Đang lọc dữ liệu tháng ${DateFormat('MM/yyyy').format(selectedMonth)}...');
await Future.delayed(Duration(milliseconds: 50));
final monthData = allData.where((record) {
return record.ngay.year == selectedMonth.year && 
record.ngay.month == selectedMonth.month;
}).toList();
ProgressDialog.updateMessage('Đang hiệu chỉnh dữ liệu dự án (${monthData.length} bản ghi)...');
await Future.delayed(Duration(milliseconds: 50));
final correctedData = await _applyCorrectionToDataAsync(monthData);
ProgressDialog.updateMessage('Đang tải danh sách nhân viên...');
await Future.delayed(Duration(milliseconds: 50));
final staffNameMap = await _getStaffNameMap();
ProgressDialog.updateMessage('Đang khởi tạo file Excel...');
await Future.delayed(Duration(milliseconds: 50));
final excel = Excel.createExcel();
excel.delete('Sheet1');
ProgressDialog.updateMessage('Đang tạo bảng chi tiết tháng...');
await Future.delayed(Duration(milliseconds: 50));
await _createChiTietSheet(excel, correctedData, staffNameMap);
ProgressDialog.updateMessage('Đang tạo bảng theo chủ đề tháng...');
await Future.delayed(Duration(milliseconds: 50));
await _createTheoChuDeSheet(
excel, 
correctedData, 
staffNameMap,
taskSchedules: taskSchedules,
qrLookups: qrLookups,
);
ProgressDialog.updateMessage('Đang lưu file tháng...');
await Future.delayed(Duration(milliseconds: 50));
final monthName = DateFormat('yyyy_MM').format(selectedMonth);
final fileName = 'DuAn_CongNhan_Thang_${monthName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
await _saveAndHandleFile(excel, fileName, context);
ProgressDialog.hide();
} catch (e) {
ProgressDialog.hide();
if (context.mounted) {
_showErrorDialog(context, e.toString());
}
rethrow;
}
}
static Future<void> exportEvaluationOnly({
required List<TaskHistoryModel> allData,
required List<String> projectOptions,
required BuildContext context,
List<TaskScheduleModel> taskSchedules = const [],
List<QRLookupModel> qrLookups = const [],
}) async {
throw Exception('Evaluation export not available for this module');
}
static Future<Map<String, String>> _getStaffNameMap() async {
try {
final prefs = await SharedPreferences.getInstance();
final String? staffListVPJson = prefs.getString('stafflistvp_data');
if (staffListVPJson != null && staffListVPJson.isNotEmpty) {
final List<dynamic> staffListVPData = json.decode(staffListVPJson);
final Map<String, String> nameMap = {};
for (final staff in staffListVPData) {
if (staff['Username'] != null && staff['Name'] != null) {
final username = staff['Username'].toString();
final name = staff['Name'].toString();
nameMap[username.toLowerCase()] = name;
nameMap[username.toUpperCase()] = name;
nameMap[username] = name;
}
}
return nameMap;
} else {
return {};
}
} catch (e) {
print('Error loading staff names for Excel: $e');
return {};
}
}
static Future<Map<String, String>> _getStaffBPMap() async {
try {
final prefs = await SharedPreferences.getInstance();
final String? staffListVPJson = prefs.getString('stafflistvp_data');
if (staffListVPJson != null && staffListVPJson.isNotEmpty) {
final List<dynamic> staffListVPData = json.decode(staffListVPJson);
final Map<String, String> bpMap = {};
for (final staff in staffListVPData) {
if (staff['Username'] != null && staff['BP'] != null) {
final username = staff['Username'].toString();
final bp = staff['BP'].toString();
bpMap[username.toLowerCase()] = bp;
bpMap[username.toUpperCase()] = bp;
bpMap[username] = bp;
}
}
return bpMap;
} else {
return {};
}
} catch (e) {
print('Error loading staff BP for Excel: $e');
return {};
}
}
static Map<String, dynamic> _extractThieuNumberAndUnit(String text) {
try {
final lowerText = text.toLowerCase();
final thieuIndex = lowerText.indexOf('thiếu');
if (thieuIndex == -1) return {'number': 0.0, 'unit': ''};
final afterThieu = text.substring(thieuIndex + 5).trim();
final numberAndUnitRegex = RegExp(r'(\d+[,.]?\d*)\s*([a-zA-ZÀ-ỹ/]+)?');
final match = numberAndUnitRegex.firstMatch(afterThieu);
if (match != null) {
final numberStr = match.group(1)!.replaceAll(',', '.');
final number = double.tryParse(numberStr) ?? 0.0;
final unit = match.group(2)?.trim() ?? '';
return {'number': number, 'unit': unit};
}
return {'number': 0.0, 'unit': ''};
} catch (e) {
return {'number': 0.0, 'unit': ''};
}
}
static TheoChuDeSummary _calculateTheoChuDeSummary(List<TaskHistoryModel> records) {
final summary = TheoChuDeSummary();
final uniqueHours = <String>{};
final units = <String>{};
final uniqueTopics = <String>{};
for (final record in records) {
if (record.hinhAnh?.isNotEmpty == true) {
summary.imageCount++;
}
summary.soBaoCao++;
if (record.gio?.isNotEmpty == true) {
try {
final timeParts = record.gio!.split(':');
if (timeParts.isNotEmpty) {
final hour = timeParts[0].trim();
if (hour.isNotEmpty) {
uniqueHours.add(hour);
}
}
} catch (e) {
}
}
final phanLoai = record.phanLoai?.trim() ?? '';
final ketQua = record.ketQua?.trim() ?? '';
final chiTiet = record.chiTiet?.trim() ?? '';
if (phanLoai.isNotEmpty) {
uniqueTopics.add(phanLoai);
}
if (phanLoai == 'Nhân sự') {
summary.hasNhanSu = true;
if (chiTiet.toLowerCase().contains('thiếu')) {
summary.nhanSuThieu++;
final result = _extractThieuNumberAndUnit(chiTiet);
summary.thieuCongGio += result['number'] as double;
if ((result['unit'] as String).isNotEmpty) {
units.add(result['unit'] as String);
}
} else {
summary.nhanSuDu++;
}
} else if (phanLoai.toLowerCase().contains('chất lượng')) {
summary.hasChatLuong = true;
if (ketQua == '✔️') {
summary.chatLuongDat++;
} else {
summary.chatLuongVanDe++;
}
} else if (phanLoai == 'Vật tư') {
if (ketQua == '✔️') {
summary.vatTuDu++;
} else {
summary.vatTuVanDe++;
}
} else if (phanLoai == 'Máy móc') {
if (ketQua == '✔️') {
summary.mayMocDu++;
} else {
summary.mayMocVanDe++;
}
} else if (phanLoai.toLowerCase().contains('giỏ')) {
if (ketQua == '✔️') {
summary.xeGioDu++;
} else {
summary.xeGioVanDe++;
}
} else if (phanLoai.toLowerCase().contains('ý kiến')) {
if (ketQua == '✔️') {
summary.yKienKHDat++;
} else {
summary.yKienKHVanDe++;
}
} else if (phanLoai.isNotEmpty) {
summary.khac++;
}
}
summary.khungGio = uniqueHours.toList()..sort();
summary.soKhungGio = uniqueHours.length;
summary.soTopics = uniqueTopics.length;
summary.uniqueTopics = uniqueTopics;
if (units.isNotEmpty) {
final unitCounts = <String, int>{};
for (final unit in units) {
unitCounts[unit] = (unitCounts[unit] ?? 0) + 1;
}
summary.thieuCongUnit = unitCounts.entries
.reduce((a, b) => a.value > b.value ? a : b)
.key;
}
return summary;
}
static Map<String, dynamic> _calculateScheduleCompletion(
  String workerUsername,
  String projectName,
  DateTime date,
  List<TaskHistoryModel> workerRecords,
  List<TaskScheduleModel> taskSchedules,
  List<QRLookupModel> qrLookups,
) {
  if (taskSchedules.isEmpty || qrLookups.isEmpty) {
    return {
      'totalTasks': 0,
      'completedTasks': 0,
      'completionRate': 0.0,
      'hasSchedule': false,
      'missedTasks': 0,
      'completedTaskIds': <String>[],
      'missedTaskIds': <String>[],
    };
  }

  // Get tasks for this project and date
  final dayTasks = TaskScheduleManager.getTasksForProjectAndDate(
    taskSchedules,
    projectName,
    date,
    qrLookups,
  );

  if (dayTasks.isEmpty) {
    return {
      'totalTasks': 0,
      'completedTasks': 0,
      'completionRate': 0.0,
      'hasSchedule': false,
      'missedTasks': 0,
      'completedTaskIds': <String>[],
      'missedTaskIds': <String>[],
    };
  }

  // Find worker position from their records
  String? workerPosition;
  final positions = <String, int>{};
  
  for (final record in workerRecords) {
    if (record.viTri != null && record.viTri!.trim().isNotEmpty) {
      positions[record.viTri!] = (positions[record.viTri!] ?? 0) + 1;
    }
  }
  
  if (positions.isEmpty) {
    return {
      'totalTasks': 0,
      'completedTasks': 0,
      'completionRate': 0.0,
      'hasSchedule': false,
      'missedTasks': 0,
      'completedTaskIds': <String>[],
      'missedTaskIds': <String>[],
    };
  }
  
  // Get most frequent position
  workerPosition = positions.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;

  // Get tasks for this position
  final positionTasks = TaskScheduleManager.getTasksForPosition(
    dayTasks,
    workerPosition,
    qrLookups,
  );

  if (positionTasks.isEmpty) {
    return {
      'totalTasks': 0,
      'completedTasks': 0,
      'completionRate': 0.0,
      'hasSchedule': false,
      'missedTasks': 0,
      'completedTaskIds': <String>[],
      'missedTaskIds': <String>[],
    };
  }

  // Analyze task completion
  final analysis = TaskScheduleManager.analyzeTaskCompletion(
    dayTasks,
    workerRecords,
    workerPosition,
    qrLookups,
  );

  return {
    'totalTasks': analysis['totalTasks'] as int,
    'completedTasks': analysis['completedTasks'] as int,
    'completionRate': analysis['completionRate'] as double,
    'hasSchedule': true,
    'missedTasks': analysis['missedTasks'] as int,
    'completedTaskIds': analysis['completedTaskIds'] as List<String>,
    'missedTaskIds': analysis['missedTaskIds'] as List<String>,
    'positionTasks': analysis['positionTasks'] as List<TaskScheduleModel>,
  };
}
static double _calculateGrading(
TheoChuDeSummary summary, {
required double scheduleCompletionRate,
required bool hasSchedule,
}) {
double score = 0.0;
if (summary.soKhungGio >= 8) {
score += 3.0;
} else if (summary.soKhungGio >= 6) {
score += 2.5;
} else if (summary.soKhungGio >= 4) {
score += 2.0;
} else if (summary.soKhungGio >= 2) {
score += 1.0;
}
int minHourCount = summary.soKhungGio < 4 ? 4 : summary.soKhungGio;
double expectedImages = minHourCount * 1.5;
if (summary.imageCount >= expectedImages) {
score += 2.0;
} else if (summary.imageCount >= expectedImages * 0.75) {
score += 1.5;
} else if (summary.imageCount >= expectedImages * 0.5) {
score += 1.0;
} else if (summary.imageCount > 0) {
score += 0.5;
}
int totalQualityIssues = summary.chatLuongVanDe + summary.vatTuVanDe + 
summary.mayMocVanDe + summary.xeGioVanDe + 
summary.yKienKHVanDe;
int totalQualityChecks = summary.chatLuongDat + summary.chatLuongVanDe + 
summary.vatTuDu + summary.vatTuVanDe + 
summary.mayMocDu + summary.mayMocVanDe + 
summary.xeGioDu + summary.xeGioVanDe + 
summary.yKienKHDat + summary.yKienKHVanDe;
if (totalQualityChecks > 0) {
double qualityRate = (totalQualityChecks - totalQualityIssues) / totalQualityChecks;
score += qualityRate * 1.5;
}
if (summary.nhanSuThieu == 0) {
score += 0.5;
} else if (summary.nhanSuDu > summary.nhanSuThieu) {
score += 0.3;
}
if (hasSchedule) {
if (scheduleCompletionRate >= 80.0) {
score += 2.0;
} else if (scheduleCompletionRate >= 70.0) {
score += 1.6;
} else if (scheduleCompletionRate >= 60.0) {
score += 1.2;
} else if (scheduleCompletionRate >= 50.0) {
score += 0.8;
} else if (scheduleCompletionRate >= 40.0) {
score += 0.4;
}
}
bool hasBothRequired = summary.hasNhanSu && summary.hasChatLuong;
if (hasBothRequired && summary.soTopics >= 3) {
score += 2.0;
} else if (hasBothRequired && summary.soTopics == 2) {
score += 1.5;
} else if (hasBothRequired) {
score += 1.0;
} else if (summary.hasNhanSu || summary.hasChatLuong) {
score += 0.5;
}
return score.clamp(0.0, 10.0);
}
static Future<void> _createTheoChuDeSheet(
  Excel excel,
  List<TaskHistoryModel> data,
  Map<String, String> staffNameMap, {
  List<TaskScheduleModel> taskSchedules = const [],
  List<QRLookupModel> qrLookups = const [],
}) async {
  final theoChuDeSheet = excel['TheoChuDe'];
  
  ProgressDialog.updateMessage('Đang tải thông tin QLDV...');
  await Future.delayed(Duration(milliseconds: 50));
  
  final staffBPMap = await _getStaffBPMap();

  final headers = [
    'STT',
    'Ngày',
    'Mã nhân viên',
    'Tên nhân viên',
    'Dự án',
    'Vị trí',  // Add position column
    'Số hình ảnh',
    'Nhân sự đủ',
    'Nhân sự thiếu',
    'Chất lượng đạt',
    'Chất lượng vấn đề',
    'Vật tư đủ',
    'Vật tư vấn đề',
    'Máy móc đủ',
    'Máy móc vấn đề',
    'Xe/giỏ đủ',
    'Xe/giỏ vấn đề',
    'Ý kiến KH đạt',
    'Ý kiến KH vấn đề',
    'Thiếu công/giờ',
    'Khác',
    'QLDV',
    'Số báo cáo',
    'Số khung giờ',
    'Khung giờ',
    'Số chủ đề',
    'Chủ đề',
    'Nhiệm vụ LLV',
    'Hoàn thành LLV',
    'Chưa làm LLV',  // Add missed tasks column
    'Tỷ lệ LLV (%)',
    'Chi tiết LLV',  // Add details column
    'Đánh giá',
  ];

  ProgressDialog.updateMessage('Đang tạo header bảng theo chủ đề...');
  await Future.delayed(Duration(milliseconds: 50));
  
  for (int i = 0; i < headers.length; i++) {
    final cell = theoChuDeSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
    cell.value = headers[i];
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#FF6B35',
      fontColorHex: '#FFFFFF',
    );
  }

  ProgressDialog.updateMessage('Đang nhóm dữ liệu theo nhân viên và ngày...');
  await Future.delayed(Duration(milliseconds: 50));
  
  final groupedData = <String, List<TaskHistoryModel>>{};
  
  for (final record in data) {
    if (record.nguoiDung == null || record.nguoiDung!.trim().isEmpty) continue;
    if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) continue;
    
    final key = '${DateFormat('yyyy-MM-dd').format(record.ngay)}_${record.nguoiDung}_${record.boPhan}';
    groupedData.putIfAbsent(key, () => []).add(record);
  }

  final sortedKeys = groupedData.keys.toList()..sort();
  
  int rowIndex = 1;
  int stt = 1;
  final totalRecords = sortedKeys.length;
  
  for (int keyIndex = 0; keyIndex < sortedKeys.length; keyIndex++) {
    if (keyIndex % 10 == 0) {
      ProgressDialog.updateMessage('Đang xử lý bản ghi ${keyIndex + 1}/$totalRecords...');
      await Future.delayed(Duration(milliseconds: 10));
    }
    
    final key = sortedKeys[keyIndex];
    final records = groupedData[key]!;
    final firstRecord = records.first;
    
    final capitalizedNguoiDung = (firstRecord.nguoiDung ?? '').toUpperCase();
    final staffName = staffNameMap[capitalizedNguoiDung] ?? '❓❓❓';
    final staffBP = staffBPMap[capitalizedNguoiDung] ?? '';
    
    // Get worker position
    final positions = <String, int>{};
    for (final record in records) {
      if (record.viTri != null && record.viTri!.trim().isNotEmpty) {
        positions[record.viTri!] = (positions[record.viTri!] ?? 0) + 1;
      }
    }
    final workerPosition = positions.isEmpty 
        ? '' 
        : positions.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    final summary = _calculateTheoChuDeSummary(records);
    
    final scheduleCompletion = _calculateScheduleCompletion(
      firstRecord.nguoiDung ?? '',
      firstRecord.boPhan ?? '',
      firstRecord.ngay,
      records,
      taskSchedules,
      qrLookups,
    );
    
    final grading = _calculateGrading(
      summary,
      scheduleCompletionRate: scheduleCompletion['completionRate'] as double,
      hasSchedule: scheduleCompletion['hasSchedule'] as bool,
    );

    // Build task completion details
    String llvDetails = '';
    if (scheduleCompletion['hasSchedule'] as bool) {
      final completedTaskIds = scheduleCompletion['completedTaskIds'] as List<String>;
      final missedTaskIds = scheduleCompletion['missedTaskIds'] as List<String>;
      final positionTasks = scheduleCompletion['positionTasks'] as List<TaskScheduleModel>?;
      
      if (positionTasks != null && positionTasks.isNotEmpty) {
        final completedTasks = positionTasks.where((t) => completedTaskIds.contains(t.taskId)).toList();
        final missedTasks = positionTasks.where((t) => missedTaskIds.contains(t.taskId)).toList();
        
        if (completedTasks.isNotEmpty) {
          llvDetails += 'Hoàn thành: ${completedTasks.map((t) => '${TaskScheduleManager.formatScheduleTime(t.start)}-${t.task}').join('; ')}';
        }
        if (missedTasks.isNotEmpty) {
          if (llvDetails.isNotEmpty) llvDetails += ' | ';
          llvDetails += 'Chưa làm: ${missedTasks.map((t) => '${TaskScheduleManager.formatScheduleTime(t.start)}-${t.task}').join('; ')}';
        }
      }
    }

    final rowData = [
      stt.toString(),
      DateFormat('dd/MM/yyyy').format(firstRecord.ngay),
      firstRecord.nguoiDung ?? '',
      staffName,
      firstRecord.boPhan ?? '',
      workerPosition,
      summary.imageCount.toString(),
      summary.nhanSuDu.toString(),
      summary.nhanSuThieu.toString(),
      summary.chatLuongDat.toString(),
      summary.chatLuongVanDe.toString(),
      summary.vatTuDu.toString(),
      summary.vatTuVanDe.toString(),
      summary.mayMocDu.toString(),
      summary.mayMocVanDe.toString(),
      summary.xeGioDu.toString(),
      summary.xeGioVanDe.toString(),
      summary.yKienKHDat.toString(),
      summary.yKienKHVanDe.toString(),
      summary.thieuCongGioWithUnit,
      summary.khac.toString(),
      staffBP,
      summary.soBaoCao.toString(),
      summary.soKhungGio.toString(),
      summary.khungGioString,
      summary.soTopics.toString(),
      summary.topicsString,
      scheduleCompletion['hasSchedule'] as bool 
        ? scheduleCompletion['totalTasks'].toString() 
        : 'N/A',
      scheduleCompletion['hasSchedule'] as bool 
        ? scheduleCompletion['completedTasks'].toString() 
        : 'N/A',
      scheduleCompletion['hasSchedule'] as bool 
        ? scheduleCompletion['missedTasks'].toString() 
        : 'N/A',
      scheduleCompletion['hasSchedule'] as bool 
        ? (scheduleCompletion['completionRate'] as double).toStringAsFixed(1) 
        : 'N/A',
      llvDetails,
      grading.toStringAsFixed(1),
    ];

    for (int i = 0; i < rowData.length; i++) {
      final cell = theoChuDeSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = rowData[i];
      
      // Color coding for topic count (column index 26, was 24)
      if (i == 26) {
        final topicCount = summary.soTopics;
        final hasBothRequired = summary.hasNhanSu && summary.hasChatLuong;
        if (hasBothRequired && topicCount >= 3) {
          cell.cellStyle = CellStyle(backgroundColorHex: '#90EE90');
        } else if (hasBothRequired && topicCount == 2) {
          cell.cellStyle = CellStyle(backgroundColorHex: '#FFD700');
        } else if (hasBothRequired) {
          cell.cellStyle = CellStyle(backgroundColorHex: '#FFA500');
        } else {
          cell.cellStyle = CellStyle(backgroundColorHex: '#FFB6C1');
        }
      }
      
      // Color coding for LLV completion rate (column index 30, was 28)
      if (i == 30 && scheduleCompletion['hasSchedule'] as bool) {
        final completionRate = scheduleCompletion['completionRate'] as double;
        if (completionRate >= 80.0) {
          cell.cellStyle = CellStyle(backgroundColorHex: '#90EE90');
        } else if (completionRate >= 60.0) {
          cell.cellStyle = CellStyle(backgroundColorHex: '#FFD700');
        } else if (completionRate >= 40.0) {
          cell.cellStyle = CellStyle(backgroundColorHex: '#FFA500');
        } else {
          cell.cellStyle = CellStyle(backgroundColorHex: '#FF6B6B');
        }
      }
      
      // Color coding for grading (column index 32, was 29)
      if (i == 32) {
        if (grading >= 8.0) {
          cell.cellStyle = CellStyle(backgroundColorHex: '#90EE90');
        } else if (grading >= 6.0) {
          cell.cellStyle = CellStyle(backgroundColorHex: '#FFD700');
        } else {
          cell.cellStyle = CellStyle(backgroundColorHex: '#FFB6C1');
        }
      }
    }

    rowIndex++;
    stt++;
  }
}
static Future<List<TaskHistoryModel>> _applyCorrectionToDataAsync(List<TaskHistoryModel> data) async {
final processedData = data.map((record) => TaskHistoryModel(
uid: record.uid,
taskId: record.taskId,
ngay: record.ngay,
gio: record.gio,
nguoiDung: record.nguoiDung,
ketQua: record.ketQua,
chiTiet: record.chiTiet,
chiTiet2: record.chiTiet2,
viTri: record.viTri,
boPhan: record.boPhan,
phanLoai: record.phanLoai,
hinhAnh: record.hinhAnh,
giaiPhap: record.giaiPhap,
)).toList();
await Future.delayed(Duration(milliseconds: 50));
final workerDateGroups = <String, List<TaskHistoryModel>>{};
for (final record in processedData) {
if (record.nguoiDung?.isNotEmpty == true) {
final key = '${record.nguoiDung}_${DateFormat('yyyy-MM-dd').format(record.ngay)}';
workerDateGroups.putIfAbsent(key, () => []).add(record);
}
}
await Future.delayed(Duration(milliseconds: 50));
for (final group in workerDateGroups.values) {
if (group.length <= 1) continue;
final validProjects = <String, int>{};
for (final record in group) {
if (record.boPhan != null && !_shouldFilterProject(record.boPhan!)) {
validProjects[record.boPhan!] = (validProjects[record.boPhan!] ?? 0) + 1;
}
}
String? correctProject;
if (validProjects.isNotEmpty) {
correctProject = validProjects.entries
.reduce((a, b) => a.value > b.value ? a : b)
.key;
}
if (correctProject != null) {
for (final record in group) {
if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) {
record.boPhan = correctProject;
}
}
}
}
await Future.delayed(Duration(milliseconds: 50));
return processedData;
}
static Future<void> _saveAndHandleFile(Excel excel, String fileName, BuildContext context) async {
try {
ProgressDialog.updateMessage('Đang tạo file Excel...');
await Future.delayed(Duration(milliseconds: 50));
final fileBytes = excel.save();
if (fileBytes == null) {
throw Exception('Failed to generate Excel file');
}
final fileSizeMB = (fileBytes.length / (1024 * 1024)).toStringAsFixed(1);
ProgressDialog.updateMessage('Đang ghi file ($fileSizeMB MB)...');
await Future.delayed(Duration(milliseconds: 100));
if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
final directory = await getTemporaryDirectory();
final filePath = '${directory.path}/$fileName';
final file = File(filePath);
await file.writeAsBytes(fileBytes);
ProgressDialog.updateMessage('Đang chia sẻ file...');
await Future.delayed(Duration(milliseconds: 50));
await Share.shareXFiles(
[XFile(filePath)],
text: 'Báo cáo dự án - công nhân',
);
} else {
final directory = await getApplicationDocumentsDirectory();
final appFolder = Directory('${directory.path}/ProjectCongNhan');
if (!await appFolder.exists()) {
await appFolder.create(recursive: true);
}
final filePath = '${appFolder.path}/$fileName';
final file = File(filePath);
await file.writeAsBytes(fileBytes);
if (context.mounted) {
_showDesktopSaveDialog(context, filePath, appFolder.path);
}
}
} catch (e) {
print('Error saving Excel file: $e');
if (context.mounted) {
ProgressDialog.hide();
}
rethrow;
}
}
static void _showDesktopSaveDialog(BuildContext context, String filePath, String folderPath) {
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: Row(
children: [
Icon(Icons.check_circle, color: Colors.green),
SizedBox(width: 8),
Text('Xuất file thành công'),
],
),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('File đã được lưu tại:'),
SizedBox(height: 8),
Container(
padding: EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.grey[100],
borderRadius: BorderRadius.circular(8),
),
child: SelectableText(
filePath,
style: TextStyle(
fontSize: 12,
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
static Future<void> _createChiTietSheet(
Excel excel,
List<TaskHistoryModel> data,
Map<String, String> staffNameMap,
) async {
final chiTietSheet = excel['ChiTiet'];
final headers = [
'STT',
'Ngày',
'Giờ',
'Mã người dùng',
'Tên người dùng',
'Dự án',
'Kết quả',
'Phân loại',
'Chi tiết',
'Ghi chú',
'Vị trí',
'Giải pháp',
'Hình ảnh',
];
ProgressDialog.updateMessage('Đang tạo header bảng chi tiết...');
await Future.delayed(Duration(milliseconds: 50));
for (int i = 0; i < headers.length; i++) {
final cell = chiTietSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
cell.value = headers[i];
cell.cellStyle = CellStyle(
bold: true,
backgroundColorHex: '#70AD47',
fontColorHex: '#FFFFFF',
);
}
ProgressDialog.updateMessage('Đang sắp xếp dữ liệu chi tiết...');
await Future.delayed(Duration(milliseconds: 50));
final sortedData = List<TaskHistoryModel>.from(data);
sortedData.sort((a, b) {
final dateCompare = a.ngay.compareTo(b.ngay);
if (dateCompare != 0) return dateCompare;
return (a.gio ?? '').compareTo(b.gio ?? '');
});
int excelRowIndex = 1;
final totalRecords = sortedData.length;
for (int i = 0; i < sortedData.length; i++) {
if (i % 50 == 0) {
ProgressDialog.updateMessage('Đang ghi bản ghi chi tiết ${i + 1}/$totalRecords...');
await Future.delayed(Duration(milliseconds: 10));
}
final record = sortedData[i];
if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) {
continue;
}
final capitalizedNguoiDung = (record.nguoiDung ?? '').toUpperCase();
final staffName = staffNameMap[capitalizedNguoiDung] ?? '❓❓❓';
final rowData = [
excelRowIndex.toString(),
DateFormat('dd/MM/yyyy').format(record.ngay),
record.gio ?? '',
record.nguoiDung ?? '',
staffName,
record.boPhan ?? '',
_formatKetQua(record.ketQua),
record.phanLoai ?? '',
record.chiTiet ?? '',
record.chiTiet2 ?? '',
record.viTri ?? '',
record.giaiPhap ?? '',
record.hinhAnh ?? '',
];
for (int j = 0; j < rowData.length; j++) {
final cell = chiTietSheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: excelRowIndex));
cell.value = rowData[j];
}
excelRowIndex++;
}
}
static String _formatKetQua(String? ketQua) {
if (ketQua == null) return '';
switch (ketQua) {
case '✔️':
return 'Đạt';
case '❌':
return 'Không làm';
case '⚠️':
return 'Chưa tốt';
default:
return ketQua;
}
}
static bool _shouldFilterProject(String? projectName) {
if (projectName == null || projectName.trim().isEmpty) return true;
final name = projectName.toLowerCase();
final originalName = projectName.trim();
if (name == 'unknown') return true;
if (name.length >= 3 && name.startsWith('hm')) {
if (RegExp(r'^hm\d').hasMatch(name)) return true;
}
if (name.length >= 3 && name.startsWith('tv')) {
if (RegExp(r'^tv\d').hasMatch(name)) return true;
}
if (name.length >= 4 && name.startsWith('tvn')) {
if (RegExp(r'^tvn\d').hasMatch(name)) return true;
}
if (name.length >= 5 && name.startsWith('nvhm')) {
if (RegExp(r'^nvhm\d').hasMatch(name)) return true;
}
if (name.startsWith('http:') || name.startsWith('https:')) return true;
if (RegExp(r'^[a-z]{2,5}-\d+$').hasMatch(name)) return true;
if (originalName == originalName.toUpperCase() && 
!originalName.contains(' ') && 
originalName.length > 1) return true;
return false;
}
}
class TheoChuDeSummary {
int imageCount = 0;
int nhanSuDu = 0;
int nhanSuThieu = 0;
int chatLuongDat = 0;
int chatLuongVanDe = 0;
int vatTuDu = 0;
int vatTuVanDe = 0;
int mayMocDu = 0;
int mayMocVanDe = 0;
int xeGioDu = 0;
int xeGioVanDe = 0;
int yKienKHDat = 0;
int yKienKHVanDe = 0;
double thieuCongGio = 0.0;
String thieuCongUnit = '';
int khac = 0;
int soBaoCao = 0;
int soKhungGio = 0;
List<String> khungGio = [];
int soTopics = 0;
Set<String> uniqueTopics = {};
bool hasNhanSu = false;
bool hasChatLuong = false;
String get khungGioString => khungGio.join(', ');
String get topicsString => uniqueTopics.join(', ');
String get thieuCongGioWithUnit => thieuCongGio > 0 
? '${thieuCongGio.toStringAsFixed(1)} $thieuCongUnit'.trim()
: '0';
}
class ProgressDialog {
static OverlayEntry? _overlayEntry;
static ValueNotifier<String>? _messageNotifier;
static void show(BuildContext context, String message) {
hide();
_messageNotifier = ValueNotifier<String>(message);
_overlayEntry = OverlayEntry(
builder: (context) => Material(
color: Colors.black54,
child: Center(
child: Container(
padding: EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(8),
boxShadow: [
BoxShadow(
color: Colors.black26,
blurRadius: 10,
offset: Offset(0, 4),
),
],
),
child: ValueListenableBuilder<String>(
valueListenable: _messageNotifier!,
builder: (context, message, child) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
SizedBox(
width: 40,
height: 40,
child: CircularProgressIndicator(
strokeWidth: 4,
valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
),
),
SizedBox(height: 20),
Container(
constraints: BoxConstraints(maxWidth: 300),
child: Text(
message,
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w500,
color: Colors.black87,
),
textAlign: TextAlign.center,
),
),
],
);
},
),
),
),
),
);
Overlay.of(context).insert(_overlayEntry!);
}
static void updateMessage(String newMessage) {
_messageNotifier?.value = newMessage;
}
static void hide() {
_overlayEntry?.remove();
_overlayEntry = null;
_messageNotifier?.dispose();
_messageNotifier = null;
}
}