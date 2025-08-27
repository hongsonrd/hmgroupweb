import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'table_models.dart';
import 'db_helper.dart'; // Add this import

class ProjectCongNhanExcel {
  static Future<void> exportToExcel({
  required List<TaskHistoryModel> allData,
  required List<String> projectOptions,
  required BuildContext context,
}) async {
  // Apply BoPhan correction before export
  final correctedData = _applyCorrectionToData(allData);
  
  // Get staff name mapping
  final staffNameMap = await _getStaffNameMap();
  
  final excel = Excel.createExcel();
  
  // Remove default sheet
  excel.delete('Sheet1');
  
  // Create TongHop sheet
  await _createTongHopSheet(excel, correctedData, projectOptions, staffNameMap);
  
  // Create ChiTiet sheet
  await _createChiTietSheet(excel, correctedData, staffNameMap);
  
  // ADD: Create daily matrix sheet
  //await _createDailyMatrixSheet(excel, correctedData, staffNameMap);
  
  // Save and share/save file based on platform
  final fileName = 'DuAn_CongNhan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
  await _saveAndHandleFile(excel, fileName, context);
}

static Future<void> exportToExcelMonth({
  required List<TaskHistoryModel> allData,
  required List<String> projectOptions,
  required DateTime selectedMonth,
  required BuildContext context,
}) async {
  // Filter data for the selected month
  final monthData = allData.where((record) {
    return record.ngay.year == selectedMonth.year && 
           record.ngay.month == selectedMonth.month;
  }).toList();

  // Apply BoPhan correction before export
  final correctedData = _applyCorrectionToData(monthData);

  // Get staff name mapping
  final staffNameMap = await _getStaffNameMap();

  final excel = Excel.createExcel();
  
  // Remove default sheet
  excel.delete('Sheet1');
  
  // Create TongHop sheet for the month
  await _createTongHopSheet(excel, correctedData, projectOptions, staffNameMap);
  
  // Create ChiTiet sheet for the month
  await _createChiTietSheet(excel, correctedData, staffNameMap);
  
  // ADD: Create daily matrix sheet
  //await _createDailyMatrixSheet(excel, correctedData, staffNameMap);
  
  // Save and share/save file based on platform
  final monthName = DateFormat('yyyy_MM').format(selectedMonth);
  final fileName = 'DuAn_CongNhan_Thang_${monthName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
  await _saveAndHandleFile(excel, fileName, context);
}

  // Add this new method to get staff names
  static Future<Map<String, String>> _getStaffNameMap() async {
    try {
      final dbHelper = DBHelper();
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> staffbioResults = await db.query(DatabaseTables.staffbioTable);
      
      final Map<String, String> nameMap = {};
      for (final staff in staffbioResults) {
        if (staff['MaNV'] != null && staff['Ho_ten'] != null) {
          // Store both lowercase and uppercase versions for lookup
          final maNV = staff['MaNV'].toString();
          final hoTen = staff['Ho_ten'].toString();
          nameMap[maNV.toLowerCase()] = hoTen;
          nameMap[maNV.toUpperCase()] = hoTen;
          nameMap[maNV] = hoTen; // Original case
        }
      }
      return nameMap;
    } catch (e) {
      print('Error loading staff names for Excel: $e');
      return {};
    }
  }

  static List<TaskHistoryModel> _applyCorrectionToData(List<TaskHistoryModel> data) {
    // Create a copy of all data for processing
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

    // Group records by worker and date
    final workerDateGroups = <String, List<TaskHistoryModel>>{};
    
    for (final record in processedData) {
      if (record.nguoiDung?.isNotEmpty == true) {
        final key = '${record.nguoiDung}_${DateFormat('yyyy-MM-dd').format(record.ngay)}';
        workerDateGroups.putIfAbsent(key, () => []).add(record);
      }
    }

    // Process each worker-date group
    for (final group in workerDateGroups.values) {
      if (group.length <= 1) continue; // Skip if only one record
      
      // Find valid BoPhan projects in this group
      final validProjects = <String, int>{};
      for (final record in group) {
        if (record.boPhan != null && !_shouldFilterProject(record.boPhan!)) {
          validProjects[record.boPhan!] = (validProjects[record.boPhan!] ?? 0) + 1;
        }
      }
      
      // Determine the most common valid project for this worker-date
      String? correctProject;
      if (validProjects.isNotEmpty) {
        correctProject = validProjects.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }
      
      // Apply correction to records with invalid BoPhan
      if (correctProject != null) {
        for (final record in group) {
          if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) {
            record.boPhan = correctProject; // Correct the BoPhan
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
        // Mobile/Web: Use share_plus
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Báo cáo dự án - công nhân',
        );
      } else {
        // Desktop: Save to app folder and show dialog
        final directory = await getApplicationDocumentsDirectory();
        final appFolder = Directory('${directory.path}/ProjectCongNhan');
        
        // Create app folder if it doesn't exist
        if (!await appFolder.exists()) {
          await appFolder.create(recursive: true);
        }
        
        final filePath = '${appFolder.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        
        // Show success dialog with options
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
                    // Fallback: try to open with system default
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
                    // Fallback: try to open with system default
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

  static Future<void> _createTongHopSheet(
    Excel excel, 
    List<TaskHistoryModel> data, 
    List<String> projectOptions,
    Map<String, String> staffNameMap, // Add this parameter
  ) async {
    final tongHopSheet = excel['TongHop'];
    
    // Updated headers to include staff name
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
    
    // Set headers
    for (int i = 0; i < headers.length; i++) {
      final cell = tongHopSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '#4472C4',
        fontColorHex: '#FFFFFF',
      );
    }

    // Process data by worker and project (only valid projects after correction)
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

    // Write data rows
    int rowIndex = 1;
    int stt = 1;
    
    final sortedWorkerNames = workerProjectMap.keys.toList()..sort();
    
    for (final workerName in sortedWorkerNames) {
      final sortedProjectNames = workerProjectMap[workerName]!.keys.toList()..sort();
      
      for (final projectName in sortedProjectNames) {
        final summary = workerProjectMap[workerName]![projectName]!;
        
        // Get staff name, capitalize workerName for lookup
        final capitalizedWorkerName = workerName.toUpperCase();
        final staffName = staffNameMap[capitalizedWorkerName] ?? '❓❓❓';
        
        final rowData = [
          stt.toString(),
          summary.workerName, // Employee ID
          staffName, // Employee Name
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
static Future<void> _createDailyMatrixSheet(
  Excel excel,
  List<TaskHistoryModel> data,
  Map<String, String> staffNameMap,
) async {
  final matrixSheet = excel['Ma_tran_bao_cao_hang_ngay'];
  
  // Get unique dates and workers
  final dateSet = <String>{};
  final workerSet = <String>{};
  
  for (final record in data) {
    if (record.boPhan != null && !_shouldFilterProject(record.boPhan!)) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.ngay);
      dateSet.add(dateStr);
      if (record.nguoiDung?.isNotEmpty == true) {
        workerSet.add(record.nguoiDung!);
      }
    }
  }
  
  final sortedDates = dateSet.toList()..sort((a, b) => b.compareTo(a));
  final sortedWorkers = workerSet.toList()..sort();
  
  // ADD: Safety check to prevent Excel from freezing with too much data
  if (sortedDates.length > 366 || sortedWorkers.length > 1000) {
    print('Warning: Too much data for matrix sheet. Dates: ${sortedDates.length}, Workers: ${sortedWorkers.length}');
    // Create a simple info sheet instead
    matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Dữ liệu quá lớn để tạo ma trận';
    return;
  }
  
  // Create headers
  final headers = ['Mã NV', 'Tên công nhân', ...sortedDates.map((d) => DateFormat('dd/MM').format(DateTime.parse(d)))];
  
  for (int i = 0; i < headers.length; i++) {
    final cell = matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
    cell.value = headers[i];
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#70AD47',
      fontColorHex: '#FFFFFF',
    );
  }
  
  // Fill data
  int rowIndex = 1;
  for (final worker in sortedWorkers) {
    final capitalizedWorker = worker.toUpperCase();
    final staffName = staffNameMap[capitalizedWorker] ?? '❓❓❓';
    
    matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = worker;
    matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = staffName;
    
    for (int dateIndex = 0; dateIndex < sortedDates.length; dateIndex++) {
      final dateStr = sortedDates[dateIndex];
      final reportCount = data.where((record) =>
        DateFormat('yyyy-MM-dd').format(record.ngay) == dateStr &&
        record.nguoiDung == worker &&
        record.boPhan != null &&
        !_shouldFilterProject(record.boPhan!)
      ).length;
      
      final cell = matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: dateIndex + 2, rowIndex: rowIndex));
      cell.value = reportCount > 0 ? reportCount.toString() : '';
    }
    rowIndex++;
  }
}
  static Future<void> _createChiTietSheet(
    Excel excel, 
    List<TaskHistoryModel> data,
    Map<String, String> staffNameMap, // Add this parameter
  ) async {
    final chiTietSheet = excel['ChiTiet'];
    
    // Updated headers to include staff name
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
    
    // Set headers
    for (int i = 0; i < headers.length; i++) {
      final cell = chiTietSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '#70AD47',
        fontColorHex: '#FFFFFF',
      );
    }

    // Sort data by date and time
    final sortedData = List<TaskHistoryModel>.from(data);
    sortedData.sort((a, b) {
      final dateCompare = a.ngay.compareTo(b.ngay);
      if (dateCompare != 0) return dateCompare;
      return (a.gio ?? '').compareTo(b.gio ?? '');
    });

    // Write data rows (only include records with valid projects after correction)
    int excelRowIndex = 1;
    for (int i = 0; i < sortedData.length; i++) {
      final record = sortedData[i];
      
      // Skip records with invalid projects (they should be corrected by now, but double-check)
      if (record.boPhan == null || _shouldFilterProject(record.boPhan!)) {
        continue;
      }
      
      // Get staff name, capitalize nguoiDung for lookup
      final capitalizedNguoiDung = (record.nguoiDung ?? '').toUpperCase();
      final staffName = staffNameMap[capitalizedNguoiDung] ?? '❓❓❓';
      
      final rowData = [
        excelRowIndex.toString(),
        DateFormat('dd/MM/yyyy').format(record.ngay),
        record.gio ?? '',
        record.nguoiDung ?? '', // Employee ID
        staffName, // Employee Name
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
    
    // 1. Filter out "unknown"
    if (name == 'unknown') return true;
    
    // 2. Filter out "hm" + numbers (e.g., "hm123", "hm45")
    if (name.length >= 3 && name.startsWith('hm')) {
      if (RegExp(r'^hm\d').hasMatch(name)) return true;
    }
    
    // 3. Filter out "tv" + numbers (e.g., "tv123", "tv45")
    if (name.length >= 3 && name.startsWith('tv')) {
      if (RegExp(r'^tv\d').hasMatch(name)) return true;
    }
    
    // 4. Filter out "tvn" + numbers (e.g., "tvn123", "tvn45")
    if (name.length >= 4 && name.startsWith('tvn')) {
      if (RegExp(r'^tvn\d').hasMatch(name)) return true;
    }
    
    // 5. Filter out "nvhm" + numbers (e.g., "nvhm123", "nvhm45")
    if (name.length >= 5 && name.startsWith('nvhm')) {
      if (RegExp(r'^nvhm\d').hasMatch(name)) return true;
    }
    
    // 6. Filter out URLs starting with "http:" or "https:"
    if (name.startsWith('http:') || name.startsWith('https:')) return true;
    
    // 7. Filter out pattern: 2-5 characters + "-" + numbers (e.g., "ab-123", "xyz-45")
    if (RegExp(r'^[a-z]{2,5}-\d+$').hasMatch(name)) return true;
    
    // 8. Filter out full capitalized text with no spaces (e.g., "ABCDEF", "XYZ123")
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
        // Handle time parsing errors
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