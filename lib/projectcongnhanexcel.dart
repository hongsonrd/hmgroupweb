import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'table_models.dart';
import 'db_helper.dart';

class ProjectCongNhanExcel {
 static Future<void> exportToExcel({
 required List<TaskHistoryModel> allData,
 required List<String> projectOptions,
 required BuildContext context,
}) async {
 final correctedData = _applyCorrectionToData(allData);
 final staffNameMap = await _getStaffNameMap();
 final excel = Excel.createExcel();
 excel.delete('Sheet1');
 await _createTongHopSheet(excel, correctedData, projectOptions, staffNameMap);
 await _createChiTietSheet(excel, correctedData, staffNameMap);
 await _createDailyMatrixSheet(excel, correctedData, staffNameMap);
 final fileName = 'DuAn_CongNhan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
 await _saveAndHandleFile(excel, fileName, context);
}

static Future<void> exportToExcelMonth({
 required List<TaskHistoryModel> allData,
 required List<String> projectOptions,
 required DateTime selectedMonth,
 required BuildContext context,
}) async {
 final monthData = allData.where((record) {
   return record.ngay.year == selectedMonth.year && 
          record.ngay.month == selectedMonth.month;
 }).toList();
 final correctedData = _applyCorrectionToData(monthData);
 final staffNameMap = await _getStaffNameMap();
 final excel = Excel.createExcel();
 excel.delete('Sheet1');
 await _createTongHopSheet(excel, correctedData, projectOptions, staffNameMap);
 await _createChiTietSheet(excel, correctedData, staffNameMap);
 await _createDailyMatrixSheet(excel, correctedData, staffNameMap);
 final monthName = DateFormat('yyyy_MM').format(selectedMonth);
 final fileName = 'DuAn_CongNhan_Thang_${monthName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
 await _saveAndHandleFile(excel, fileName, context);
}

 static Future<Map<String, String>> _getStaffNameMap() async {
   try {
     final dbHelper = DBHelper();
     final db = await dbHelper.database;
     final List<Map<String, dynamic>> staffbioResults = await db.query(DatabaseTables.staffbioTable);
     final Map<String, String> nameMap = {};
     for (final staff in staffbioResults) {
       if (staff['MaNV'] != null && staff['Ho_ten'] != null) {
         final maNV = staff['MaNV'].toString();
         final hoTen = staff['Ho_ten'].toString();
         nameMap[maNV.toLowerCase()] = hoTen;
         nameMap[maNV.toUpperCase()] = hoTen;
         nameMap[maNV] = hoTen;
       }
     }
     return nameMap;
   } catch (e) {
     print('Error loading staff names for Excel: $e');
     return {};
   }
 }

 static List<TaskHistoryModel> _applyCorrectionToData(List<TaskHistoryModel> data) {
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
   final workerDateGroups = <String, List<TaskHistoryModel>>{};
   for (final record in processedData) {
     if (record.nguoiDung?.isNotEmpty == true) {
       final key = '${record.nguoiDung}_${DateFormat('yyyy-MM-dd').format(record.ngay)}';
       workerDateGroups.putIfAbsent(key, () => []).add(record);
     }
   }
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
   return processedData;
 }

 static Future<void> _saveAndHandleFile(Excel excel, String fileName, BuildContext context) async {
   try {
     final fileBytes = excel.save();
     if (fileBytes == null) {
       throw Exception('Failed to generate Excel file');
     }
     if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
       final directory = await getTemporaryDirectory();
       final filePath = '${directory.path}/$fileName';
       final file = File(filePath);
       await file.writeAsBytes(fileBytes);
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
static Future<void> _createDailyMatrixSheet(
  Excel excel,
  List<TaskHistoryModel> data,
  Map<String, String> staffNameMap,
) async {
  print('Starting matrix creation');
  print('Total input data: ${data.length}');
  final matrixSheet = excel['Ma_tran_bao_cao_hang_ngay'];
  final dateSet = <String>{};
  final workerSet = <String>{};
  final validRecords = <TaskHistoryModel>[];
  for (final record in data) {
    if (record.boPhan != null && 
        !_shouldFilterProject(record.boPhan!) && 
        record.nguoiDung?.isNotEmpty == true) {
      validRecords.add(record);
      dateSet.add(DateFormat('yyyy-MM-dd').format(record.ngay));
      workerSet.add(record.nguoiDung!);
    }
  }
  final sortedDates = dateSet.toList()..sort((a, b) => b.compareTo(a));
  final sortedWorkers = workerSet.toList()..sort();
  print('Valid records: ${validRecords.length}');
  print('Unique dates: ${sortedDates.length}');
  print('Unique workers: ${sortedWorkers.length}');
  const maxDates = 366; // 1 year max
  const maxWorkers = 2000; // Increased worker limit
  const maxCells = 200000; // Increased cell limit to 200k
  final totalCells = sortedDates.length * sortedWorkers.length;
  print('Matrix size check: ${sortedDates.length} dates × ${sortedWorkers.length} workers = $totalCells cells');
  if (sortedDates.length > maxDates || 
      sortedWorkers.length > maxWorkers || 
      totalCells > maxCells) {
    print('Matrix too large: Creating summary instead');
    await _createMatrixSummary(excel, validRecords, staffNameMap, sortedDates, sortedWorkers);
    return;
  }
  print('Matrix size OK: Creating full matrix');
  await _createMatrixHeaders(matrixSheet, sortedDates);
  const batchSize = 100; // Increased batch size for better performance
  final totalWorkers = sortedWorkers.length;
  for (int batchStart = 0; batchStart < totalWorkers; batchStart += batchSize) {
    final batchEnd = (batchStart + batchSize).clamp(0, totalWorkers);
    final workerBatch = sortedWorkers.sublist(batchStart, batchEnd);
    print('Processing worker batch ${(batchStart / batchSize).floor() + 1}/${(totalWorkers / batchSize).ceil()}');
    await _processWorkerBatch(
      matrixSheet, 
      workerBatch, 
      sortedDates, 
      validRecords, 
      staffNameMap, 
      batchStart + 1
    );
    await Future.delayed(Duration(milliseconds: 5)); // Reduced delay
  }
  print('Matrix creation completed: ${sortedWorkers.length} workers × ${sortedDates.length} dates');
}

static Future<void> _createMatrixHeaders(Sheet matrixSheet, List<String> sortedDates) async {
 final headers = [
   'Mã NV', 
   'Tên công nhân', 
   ...sortedDates.map((d) => DateFormat('dd/MM').format(DateTime.parse(d)))
 ];
 print('Creating headers: ${headers.length} columns');
 for (int i = 0; i < headers.length; i++) {
   final cell = matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
   cell.value = headers[i];
   cell.cellStyle = CellStyle(
     bold: true,
     backgroundColorHex: '#70AD47',
     fontColorHex: '#FFFFFF',
   );
 }
 print('Headers created successfully');
}

static Future<void> _processWorkerBatch(
 Sheet matrixSheet,
 List<String> workerBatch,
 List<String> sortedDates,
 List<TaskHistoryModel> validRecords,
 Map<String, String> staffNameMap,
 int startRowIndex,
) async {
 print('Processing batch: ${workerBatch.length} workers, starting at row $startRowIndex');
 final workerDateCounts = <String, Map<String, int>>{};
 for (final worker in workerBatch) {
   workerDateCounts[worker] = <String, int>{};
   for (final date in sortedDates) {
     workerDateCounts[worker]![date] = 0;
   }
 }
 for (final record in validRecords) {
   final worker = record.nguoiDung!;
   if (workerDateCounts.containsKey(worker)) {
     final dateStr = DateFormat('yyyy-MM-dd').format(record.ngay);
     if (workerDateCounts[worker]!.containsKey(dateStr)) {
       workerDateCounts[worker]![dateStr] = workerDateCounts[worker]![dateStr]! + 1;
     }
   }
 }
 for (int i = 0; i < workerBatch.length; i++) {
   final worker = workerBatch[i];
   final rowIndex = startRowIndex + i;
   print('Writing worker $worker to row $rowIndex');
   final capitalizedWorker = worker.toUpperCase();
   final staffName = staffNameMap[capitalizedWorker] ?? '❓❓❓';
   matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = worker;
   matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = staffName;
   for (int dateIndex = 0; dateIndex < sortedDates.length; dateIndex++) {
     final dateStr = sortedDates[dateIndex];
     final reportCount = workerDateCounts[worker]![dateStr]!;
     final cell = matrixSheet.cell(CellIndex.indexByColumnRow(
       columnIndex: dateIndex + 2, 
       rowIndex: rowIndex
     ));
     if (reportCount > 0) {
       cell.value = reportCount.toString();
       final color = _getReportCountColorHex(reportCount);
       cell.cellStyle = CellStyle(backgroundColorHex: color);
     } else {
       cell.value = '';
     }
   }
 }
 print('Batch processing completed');
}

static String _getReportCountColorHex(int count) {
 if (count <= 2) return '#E3F2FD';
 if (count <= 5) return '#E8F5E8';
 if (count <= 10) return '#FFF3E0';
 return '#FFEBEE';
}

static Future<void> _createMatrixSummary(
 Excel excel,
 List<TaskHistoryModel> validRecords,
 Map<String, String> staffNameMap,
 List<String> sortedDates,
 List<String> sortedWorkers,
) async {
 final summarySheet = excel['Thong_ke_tong_hop'];
 final headers = [
   'Thông tin',
   'Giá trị',
   'Ghi chú'
 ];
 for (int i = 0; i < headers.length; i++) {
   final cell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
   cell.value = headers[i];
   cell.cellStyle = CellStyle(
     bold: true,
     backgroundColorHex: '#FF6B6B',
     fontColorHex: '#FFFFFF',
   );
 }
 final summaryData = [
   ['Tổng số công nhân', sortedWorkers.length.toString(), 'Số công nhân có báo cáo'],
   ['Tổng số ngày', sortedDates.length.toString(), 'Khoảng thời gian có dữ liệu'],
   ['Tổng số báo cáo', validRecords.length.toString(), 'Tổng báo cáo hợp lệ'],
   ['Ma trận sẽ có', '${sortedWorkers.length} × ${sortedDates.length} ô', 'Quá lớn để hiển thị'],
   ['Khuyến nghị', 'Lọc theo tháng', 'Để tạo ma trận chi tiết'],
 ];
 for (int i = 0; i < summaryData.length; i++) {
   for (int j = 0; j < summaryData[i].length; j++) {
     final cell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
     cell.value = summaryData[i][j];
   }
 }
}

 static Future<void> _createTongHopSheet(
   Excel excel, 
   List<TaskHistoryModel> data, 
   List<String> projectOptions,
   Map<String, String> staffNameMap,
 ) async {
   final tongHopSheet = excel['TongHop'];
   final headers = [
     'STT',
     'Mã công nhân',
     'Tên công nhân', 
     'Dự án',
     'Số ngày làm việc',
     'Tổng báo cáo',
     'Báo cáo có hình ảnh',
     'Số chủ đề khác nhau',
     'Số giờ làm việc khác nhau',
     'Ngày đầu tiên',
     'Ngày cuối cùng',
   ];
   for (int i = 0; i < headers.length; i++) {
     final cell = tongHopSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
     cell.value = headers[i];
     cell.cellStyle = CellStyle(
       bold: true,
       backgroundColorHex: '#4472C4',
       fontColorHex: '#FFFFFF',
     );
   }
   final workerProjectMap = <String, Map<String, WorkerProjectSummary>>{};
   for (final record in data) {
     if (record.nguoiDung == null || record.nguoiDung!.trim().isEmpty) continue;
     if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) continue;
     final workerName = record.nguoiDung!;
     final projectName = record.boPhan!;
     workerProjectMap.putIfAbsent(workerName, () => {});
     workerProjectMap[workerName]!.putIfAbsent(projectName, () => WorkerProjectSummary(
       workerName: workerName,
       projectName: projectName,
     ));
     final summary = workerProjectMap[workerName]![projectName]!;
     summary.addRecord(record);
   }
   int rowIndex = 1;
   int stt = 1;
   final sortedWorkerNames = workerProjectMap.keys.toList()..sort();
   for (final workerName in sortedWorkerNames) {
     final sortedProjectNames = workerProjectMap[workerName]!.keys.toList()..sort();
     for (final projectName in sortedProjectNames) {
       final summary = workerProjectMap[workerName]![projectName]!;
       final capitalizedWorkerName = workerName.toUpperCase();
       final staffName = staffNameMap[capitalizedWorkerName] ?? '❓❓❓';
       final rowData = [
         stt.toString(),
         summary.workerName,
         staffName,
         summary.projectName,
         summary.workDays.toString(),
         summary.totalReports.toString(),
         summary.reportsWithImages.toString(),
         summary.uniqueTopics.toString(),
         summary.uniqueHours.toString(),
         DateFormat('dd/MM/yyyy').format(summary.firstDate!),
         DateFormat('dd/MM/yyyy').format(summary.lastDate!),
       ];
       for (int i = 0; i < rowData.length; i++) {
         final cell = tongHopSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
         cell.value = rowData[i];
       }
       rowIndex++;
       stt++;
     }
   }
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
     'Chi tiết',
     'Chi tiết 2',
     'Vị trí',
     'Phân loại',
     'Giải pháp',
     'Có hình ảnh',
   ];
   for (int i = 0; i < headers.length; i++) {
     final cell = chiTietSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
     cell.value = headers[i];
     cell.cellStyle = CellStyle(
       bold: true,
       backgroundColorHex: '#70AD47',
       fontColorHex: '#FFFFFF',
     );
   }
   final sortedData = List<TaskHistoryModel>.from(data);
   sortedData.sort((a, b) {
     final dateCompare = a.ngay.compareTo(b.ngay);
     if (dateCompare != 0) return dateCompare;
     return (a.gio ?? '').compareTo(b.gio ?? '');
   });
   int excelRowIndex = 1;
   for (int i = 0; i < sortedData.length; i++) {
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
       record.chiTiet ?? '',
       record.chiTiet2 ?? '',
       record.viTri ?? '',
       record.phanLoai ?? '',
       record.giaiPhap ?? '',
       (record.hinhAnh?.isNotEmpty == true) ? 'Có' : 'Không',
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

class WorkerProjectSummary {
 final String workerName;
 final String projectName;
 int totalReports = 0;
 int reportsWithImages = 0;
 final Set<String> topics = <String>{};
 final Set<String> hours = <String>{};
 final Set<String> dates = <String>{};
 DateTime? firstDate;
 DateTime? lastDate;

 WorkerProjectSummary({
   required this.workerName,
   required this.projectName,
 });

 void addRecord(TaskHistoryModel record) {
   totalReports++;
   if (record.hinhAnh?.isNotEmpty == true) {
     reportsWithImages++;
   }
   if (record.phanLoai?.isNotEmpty == true) {
     topics.add(record.phanLoai!);
   }
   if (record.gio?.isNotEmpty == true) {
     try {
       final timeParts = record.gio!.split(':');
       if (timeParts.isNotEmpty) {
         hours.add(timeParts[0]);
       }
     } catch (e) {
     }
   }
   final dateStr = DateFormat('yyyy-MM-dd').format(record.ngay);
   dates.add(dateStr);
   if (firstDate == null || record.ngay.isBefore(firstDate!)) {
     firstDate = record.ngay;
   }
   if (lastDate == null || record.ngay.isAfter(lastDate!)) {
     lastDate = record.ngay;
   }
 }

 int get workDays => dates.length;
 int get uniqueTopics => topics.length;
 int get uniqueHours => hours.length;
}