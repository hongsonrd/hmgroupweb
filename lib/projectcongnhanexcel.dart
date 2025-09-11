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
import 'projectcongnhanllv.dart';
import 'dart:async';

class ProjectCongNhanExcel {
static Future<void> exportToExcel({
  required List<TaskHistoryModel> allData,
  required List<String> projectOptions,
  required BuildContext context,
  List<TaskScheduleModel> taskSchedules = const [],
  List<QRLookupModel> qrLookups = const [],
}) async {
  ProgressDialog.show(context, 'Đang chuẩn bị dữ liệu...');
  
  try {
    final correctedData = _applyCorrectionToData(allData);
    final staffNameMap = await _getStaffNameMap();
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    
    ProgressDialog.updateMessage('Đang tạo bảng tổng hợp...');
    await _createTongHopSheet(excel, correctedData, projectOptions, staffNameMap);
    
    ProgressDialog.updateMessage('Đang tạo bảng chi tiết...');
    await _createChiTietSheet(excel, correctedData, staffNameMap);
    
    ProgressDialog.updateMessage('Đang tạo ma trận báo cáo...');
    await _createDailyMatrixSheet(excel, correctedData, staffNameMap);
    
    if (taskSchedules.isNotEmpty && qrLookups.isNotEmpty) {
      ProgressDialog.updateMessage('Đang tạo bảng đánh giá công nhân...');
await _createDanhGiaCongNhanSheet(excel, correctedData, staffNameMap, taskSchedules, qrLookups);
    }
    
    ProgressDialog.updateMessage('Đang lưu file...');
    final fileName = 'DuAn_CongNhan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    await _saveAndHandleFile(excel, fileName, context);
    
    // Success - hide progress dialog
    ProgressDialog.hide();
    
  } catch (e) {
    // Error - hide progress dialog and show error
    ProgressDialog.hide();
    if (context.mounted) {
      _showErrorDialog(context, e.toString());
    }
    rethrow;
  }
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
static Future<void> _createDanhGiaCongNhanSheet(
  Excel excel,
  List<TaskHistoryModel> data,
  Map<String, String> staffNameMap,
  List<TaskScheduleModel> taskSchedules,
  List<QRLookupModel> qrLookups,
) async {
  print('Starting staff evaluation sheet creation');
  final evaluationSheet = excel['DanhGiaCongNhan'];
  
  // Headers...
  final headers = [
    'STT',
    'Ngày',
    'Mã NV',
    'Tên công nhân',
    'Dự án',
    'Số giờ báo cáo',
    'Danh sách giờ',
    'Số báo cáo',
    'Nhiệm vụ theo lịch',
    'Hoàn thành đúng hạn',
    'Điểm giờ (3.0)',
    'Điểm báo cáo (3.5)',
    'Điểm lịch trình (2.0)',
    'Điểm đúng hạn (1.5)',
    'Tổng điểm (10.0)',
  ];
  
  // Create headers with styling
  for (int i = 0; i < headers.length; i++) {
    final cell = evaluationSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
    cell.value = headers[i];
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#8E44AD',
      fontColorHex: '#FFFFFF',
    );
  }
  
  // Group data by worker-date-project
  final workerDayProjectData = <String, WorkerDayEvaluation>{};
  
  for (final record in data) {
    if (record.nguoiDung?.isEmpty != false || 
        record.boPhan == null || 
        _shouldFilterProject(record.boPhan!)) continue;
    
    final key = '${record.nguoiDung}_${DateFormat('yyyy-MM-dd').format(record.ngay)}_${record.boPhan}';
    
    workerDayProjectData.putIfAbsent(key, () => WorkerDayEvaluation(
      workerName: record.nguoiDung!,
      date: record.ngay,
      projectName: record.boPhan!,
    ));
    
    workerDayProjectData[key]!.addRecord(record);
  }
  
  // Sort by date and worker name
  final sortedKeys = workerDayProjectData.keys.toList()..sort();
  
  int rowIndex = 1;
  int stt = 1;
  final totalEvaluations = sortedKeys.length;
  
  for (int i = 0; i < sortedKeys.length; i++) {
    final key = sortedKeys[i];
    final evaluation = workerDayProjectData[key]!;
    
    if (i % 500 == 0 || i == sortedKeys.length - 1) {
      final progressPercent = ((i / totalEvaluations) * 100).round();
      ProgressDialog.updateMessage('Đang đánh giá: ${i + 1}/$totalEvaluations ($progressPercent%)');
    }
    
    // Get scheduled tasks for this worker-date-project
    final scheduledTasks = _getScheduledTasksForWorkerDateProject(
      evaluation.workerName,
      evaluation.date,
      evaluation.projectName,
      taskSchedules,
      qrLookups,
    );
    
    // Calculate scores
    final scores = _calculateWorkerDayScores(evaluation, scheduledTasks);
    
    // Get staff name
    final capitalizedWorkerName = evaluation.workerName.toUpperCase();
    final staffName = staffNameMap[capitalizedWorkerName] ?? '❓❓❓';
    
    // Prepare row data
    final rowData = [
      stt.toString(),
      DateFormat('dd/MM/yyyy').format(evaluation.date),
      evaluation.workerName,
      staffName,
      evaluation.projectName,
      evaluation.uniqueHours.length.toString(),
      evaluation.hoursList.join(', '),
      evaluation.totalReports.toString(),
      scheduledTasks.length.toString(),
      scores['onTimeTasksCount'].toString(),
      scores['hourScore']!.toStringAsFixed(1),
      scores['reportScore']!.toStringAsFixed(1),
      scores['scheduleScore']!.toStringAsFixed(1),
      scores['onTimeScore']!.toStringAsFixed(1),
      scores['totalScore']!.toStringAsFixed(1),
    ];
    
    // Write row data with conditional formatting
    for (int j = 0; j < rowData.length; j++) {
      final cell = evaluationSheet.cell(CellIndex.indexByColumnRow(
        columnIndex: j, 
        rowIndex: rowIndex
      ));
      cell.value = rowData[j];
      
      // Color code the total score
      if (j == rowData.length - 1) {
        final totalScore = scores['totalScore']!;
        cell.cellStyle = CellStyle(
          backgroundColorHex: _getScoreColorHex(totalScore),
        );
      }
    }
    
    rowIndex++;
    stt++;
    
    // Add small delay every 100 rows to prevent UI blocking
    if (i % 100 == 0) {
      await Future.delayed(Duration(milliseconds: 5));
    }
  }
  
  print('Staff evaluation sheet completed: $totalEvaluations evaluations processed');
}

// Helper method to get scheduled tasks for a specific worker-date-project
static List<TaskScheduleModel> _getScheduledTasksForWorkerDateProject(
  String workerName,
  DateTime date,
  String projectName,
  List<TaskScheduleModel> taskSchedules,
  List<QRLookupModel> qrLookups,
) {
  final dayOfWeek = date.weekday % 7; // Convert to 0-6 format
  
  return taskSchedules.where((task) {
    // Check if this task applies to the worker through QR lookup
    final userMapping = qrLookups.firstWhere(
      (lookup) => lookup.qrvalue == task.username, // Fixed: use qrvalue instead of username
      orElse: () => QRLookupModel(id: '', qrvalue: '', bpvalue: '', vtvalue: ''), // Fixed: use correct constructor
    );
    
    if (userMapping.bpvalue != projectName) return false; // Fixed: use bpvalue instead of projectName
    
    // Check if the task applies to this day of week
    if (task.weekday.isNotEmpty) {
      final allowedDays = task.weekday.split(',').map((d) => int.tryParse(d.trim()) ?? -1).toList();
      if (!allowedDays.contains(dayOfWeek)) return false;
    }
    
    return true;
  }).toList();
}

static Map<String, dynamic> _calculateWorkerDayScores(
  WorkerDayEvaluation evaluation,
  List<TaskScheduleModel> scheduledTasks,
) {
  // Updated scoring weights (total = 10.0) - RELAXED CRITERIA
  const hourWeight = 3.0;      // Hours worked (target: 5 unique hours) - RELAXED from 8
  const reportWeight = 3.5;    // Number of reports (target: 40% of scheduled tasks) - RELAXED from 60%
  const scheduleWeight = 2.0;  // Schedule adherence (completed vs scheduled tasks)
  const onTimeWeight = 1.5;    // On-time completion (within 15 minutes)
  
  // Calculate hour score (0-3.0) - RELAXED TARGET
  final uniqueHours = evaluation.uniqueHours.length;
  final hourScore = (uniqueHours / 5.0).clamp(0.0, 1.0) * hourWeight; // Changed from 8.0 to 5.0
  
  // Calculate report score (0-3.5) - RELAXED TARGET
  final expectedReports = (scheduledTasks.length * 0.4).ceil(); // Changed from 0.6 to 0.4 (40%)
  final reportRatio = expectedReports > 0 ? (evaluation.totalReports / expectedReports).clamp(0.0, 1.0) : 0.0;
  final reportScore = reportRatio * reportWeight;
  
  // Calculate schedule adherence score (0-2.0)
  final scheduleRatio = scheduledTasks.isNotEmpty ? 
    (evaluation.getCompletedTasksCount(scheduledTasks) / scheduledTasks.length).clamp(0.0, 1.0) : 0.0;
  final scheduleScore = scheduleRatio * scheduleWeight;
  
  // Calculate on-time score (0-1.5)
  final onTimeTasksCount = evaluation.getOnTimeTasksCount(scheduledTasks);
  final onTimeRatio = scheduledTasks.isNotEmpty ? 
    (onTimeTasksCount / scheduledTasks.length).clamp(0.0, 1.0) : 0.0;
  final onTimeScore = onTimeRatio * onTimeWeight;
  
  // Total score
  final totalScore = hourScore + reportScore + scheduleScore + onTimeScore;
  
  return {
    'hourScore': hourScore,
    'reportScore': reportScore,
    'scheduleScore': scheduleScore,
    'onTimeScore': onTimeScore,
    'totalScore': totalScore,
    'onTimeTasksCount': onTimeTasksCount,
  };
}
static String _getScoreColorHex(double score) {
  if (score >= 8.0) return '#27AE60'; // Green - Excellent
  if (score >= 6.0) return '#F39C12'; // Orange - Good
  if (score >= 4.0) return '#E67E22'; // Dark Orange - Fair
  return '#E74C3C'; // Red - Poor
}

static Future<void> exportToExcelMonth({
  required List<TaskHistoryModel> allData,
  required List<String> projectOptions,
  required DateTime selectedMonth,
  required BuildContext context,
  List<TaskScheduleModel> taskSchedules = const [],
  List<QRLookupModel> qrLookups = const [],
}) async {
  final monthData = allData.where((record) {
    return record.ngay.year == selectedMonth.year && 
           record.ngay.month == selectedMonth.month;
  }).toList();
  
  final correctedData = _applyCorrectionToData(monthData);
  final staffNameMap = await _getStaffNameMap();
  final excel = Excel.createExcel();
  excel.delete('Sheet1');
  
  // Update progress
  ProgressDialog.updateMessage('Đang tạo bảng tổng hợp tháng...');
  await _createTongHopSheet(excel, correctedData, projectOptions, staffNameMap);
  
  // Update progress
  ProgressDialog.updateMessage('Đang tạo bảng chi tiết tháng...');
  await _createChiTietSheet(excel, correctedData, staffNameMap);
  
  // Update progress
  ProgressDialog.updateMessage('Đang tạo ma trận báo cáo tháng...');
  await _createDailyMatrixSheet(excel, correctedData, staffNameMap);
  
  // SKIP the evaluation sheet for month export to keep it fast
  // The evaluation sheet is very computationally expensive and not needed for monthly reports
  
  ProgressDialog.updateMessage('Đang lưu file tháng...');
  final monthName = DateFormat('yyyy_MM').format(selectedMonth);
  final fileName = 'DuAn_CongNhan_Thang_${monthName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
  await _saveAndHandleFile(excel, fileName, context);
}
static Future<void> exportEvaluationOnly({
  required List<TaskHistoryModel> allData,
  required List<String> projectOptions,
  required BuildContext context,
  List<TaskScheduleModel> taskSchedules = const [],
  List<QRLookupModel> qrLookups = const [],
}) async {
  final correctedData = _applyCorrectionToData(allData);
  final staffNameMap = await _getStaffNameMap();
  final excel = Excel.createExcel();
  excel.delete('Sheet1');
  
  if (taskSchedules.isNotEmpty && qrLookups.isNotEmpty) {
    ProgressDialog.updateMessage('Đang tạo bảng đánh giá công nhân...');
    await _createDanhGiaCongNhanSheet(excel, correctedData, staffNameMap, taskSchedules, qrLookups); // Remove context
  } else {
    throw Exception('Không có dữ liệu lịch làm việc để tạo bảng đánh giá');
  }
  
  ProgressDialog.updateMessage('Đang lưu file đánh giá...');
  final fileName = 'DanhGia_CongNhan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
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
    ProgressDialog.updateMessage('Đang tạo file Excel...');
    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    
    final fileSizeMB = (fileBytes.length / (1024 * 1024)).toStringAsFixed(1);
    ProgressDialog.updateMessage('Đang ghi file ($fileSizeMB MB) - Có thể mất vài phút...');
    
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      try {
        // Write file with timeout
        await file.writeAsBytes(fileBytes).timeout(
          Duration(minutes: 2),
          onTimeout: () {
            throw TimeoutException('File writing timed out after 2 minutes', Duration(minutes: 2));
          },
        );
        
        ProgressDialog.updateMessage('Đang chia sẻ file...');
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Báo cáo dự án - công nhân',
        );
      } on TimeoutException catch (e) {
        print('Timeout error: $e');
        // Hide progress dialog before showing error
        if (context.mounted) {
          ProgressDialog.hide();
          _showTimeoutErrorDialog(context, fileName, fileSizeMB);
        }
        return; // Exit early on timeout
      }
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final appFolder = Directory('${directory.path}/ProjectCongNhan');
      if (!await appFolder.exists()) {
        await appFolder.create(recursive: true);
      }
      final filePath = '${appFolder.path}/$fileName';
      final file = File(filePath);
      
      try {
        // Write file with timeout
        await file.writeAsBytes(fileBytes).timeout(
          Duration(minutes: 2),
          onTimeout: () {
            throw TimeoutException('File writing timed out after 2 minutes', Duration(minutes: 2));
          },
        );
        
        if (context.mounted) {
          _showDesktopSaveDialog(context, filePath, appFolder.path);
        }
      } on TimeoutException catch (e) {
        print('Timeout error: $e');
        // Hide progress dialog before showing error
        if (context.mounted) {
          ProgressDialog.hide();
          _showTimeoutErrorDialog(context, fileName, fileSizeMB);
        }
        return; // Exit early on timeout
      }
    }
  } catch (e) {
    print('Error saving Excel file: $e');
    // Hide progress dialog before rethrowing
    if (context.mounted) {
      ProgressDialog.hide();
    }
    rethrow;
  }
}

// Add this helper method to show timeout error dialog
static void _showTimeoutErrorDialog(BuildContext context, String fileName, String fileSizeMB) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Timeout khi ghi file'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Excel ($fileSizeMB MB) quá lớn và việc ghi file đã vượt quá thời gian cho phép (2 phút).'),
            SizedBox(height: 12),
            Text('Khuyến nghị:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Thử xuất dữ liệu theo tháng thay vì toàn bộ'),
            Text('• Giảm phạm vi dữ liệu xuất'),
            Text('• Kiểm tra dung lượng trống trên thiết bị'),
          ],
        ),
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

class WorkerDayEvaluation {
  final String workerName;
  final DateTime date;
  final String projectName;
  int totalReports = 0;
  final Set<String> uniqueHours = <String>{};
  final List<String> hoursList = <String>[];
  final List<TaskHistoryModel> reports = <TaskHistoryModel>[];
  
  WorkerDayEvaluation({
    required this.workerName,
    required this.date,
    required this.projectName,
  });
  
  void addRecord(TaskHistoryModel record) {
    reports.add(record);
    totalReports++;
    
    if (record.gio?.isNotEmpty == true) {
      try {
        final timeParts = record.gio!.split(':');
        if (timeParts.isNotEmpty) {
          final hour = timeParts[0];
          if (uniqueHours.add(hour)) {
            hoursList.add('${hour}h');
          }
        }
      } catch (e) {
        // Handle time parsing errors
      }
    }
  }
  
  int getCompletedTasksCount(List<TaskScheduleModel> scheduledTasks) {
    int completedCount = 0;
    for (final task in scheduledTasks) {
      for (final report in reports) {
        if (report.chiTiet2?.contains(task.task) == true) {
          completedCount++;
          break;
        }
      }
    }
    return completedCount;
  }
  
  int getOnTimeTasksCount(List<TaskScheduleModel> scheduledTasks) {
    int onTimeCount = 0;
    for (final task in scheduledTasks) {
      for (final report in reports) {
        if (report.chiTiet2?.contains(task.task) == true && report.gio != null) {
          final timeDiff = _calculateTimeDifference(report.gio!, task.end);
          if (timeDiff.abs() <= 15) { // Within 15 minutes
            onTimeCount++;
            break;
          }
        }
      }
    }
    return onTimeCount;
  }
  
  static int _calculateTimeDifference(String reportTime, String scheduleTime) {
    try {
      final reportParts = reportTime.split(':');
      final scheduleParts = scheduleTime.split(':');
      
      final reportMinutes = int.parse(reportParts[0]) * 60 + int.parse(reportParts[1]);
      final scheduleMinutes = int.parse(scheduleParts[0]) * 60 + int.parse(scheduleParts[1]);
      
      return reportMinutes - scheduleMinutes;
    } catch (e) {
      return 999; // Large difference for parsing errors
    }
  }
}
class ProgressDialog {
  static OverlayEntry? _overlayEntry;
  static ValueNotifier<String>? _messageNotifier;

  static void show(BuildContext context, String message) {
    hide(); // Ensure no duplicate dialogs
    
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
            ),
            child: ValueListenableBuilder<String>(
              valueListenable: _messageNotifier!,
              builder: (context, message, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Flexible(
                      child: Text(
                        message,
                        style: TextStyle(fontSize: 16),
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

class EvaluationProgressDialog extends StatefulWidget {
  final String initialMessage;
  final Function(_EvaluationProgressDialogState) onStateCreated;

  const EvaluationProgressDialog({
    Key? key, 
    required this.initialMessage,
    required this.onStateCreated,
  }) : super(key: key);

  @override
  _EvaluationProgressDialogState createState() => _EvaluationProgressDialogState();
}

class _EvaluationProgressDialogState extends State<EvaluationProgressDialog> {
  String _currentMessage = '';

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.initialMessage;
    widget.onStateCreated(this);
  }

  // Make this method public (no underscore)
  void updateMessage(String newMessage) {
    if (mounted) {
      setState(() {
        _currentMessage = newMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                _currentMessage,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}