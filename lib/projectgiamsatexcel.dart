import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
     await _createTheoChuDeSheet(excel, correctedData, staffNameMap);
 
   await _createChiTietSheet(excel, correctedData, staffNameMap);
   
   
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
   
   await _createChiTietSheet(excel, correctedData, staffNameMap);
   
   await _createTheoChuDeSheet(excel, correctedData, staffNameMap);
   
   final monthName = DateFormat('yyyy_MM').format(selectedMonth);
   final fileName = 'DuAn_CongNhan_Thang_${monthName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
   await _saveAndHandleFile(excel, fileName, context);
 }

 // Updated to use stafflistvp data like in the main file
 static Future<Map<String, String>> _getStaffNameMap() async {
   try {
     final prefs = await SharedPreferences.getInstance();
     
     // First try to get from locally saved stafflistvp data
     final String? staffListVPJson = prefs.getString('stafflistvp_data');
     
     if (staffListVPJson != null && staffListVPJson.isNotEmpty) {
       // Use stafflistvp data
       final List<dynamic> staffListVPData = json.decode(staffListVPJson);
       final Map<String, String> nameMap = {};
       
       for (final staff in staffListVPData) {
         if (staff['Username'] != null && staff['Name'] != null) {
           final username = staff['Username'].toString();
           final name = staff['Name'].toString();
           nameMap[username.toLowerCase()] = name;
           nameMap[username.toUpperCase()] = name;
           nameMap[username] = name; // Original case
         }
       }
       return nameMap;
     } else {
       // Return empty map if no stafflistvp data available
       return {};
     }
   } catch (e) {
     print('Error loading staff names for Excel: $e');
     return {};
   }
 }

 // New method to get BP mapping for QLDV column
 static Future<Map<String, String>> _getStaffBPMap() async {
   try {
     final prefs = await SharedPreferences.getInstance();
     
     // Get from locally saved stafflistvp data
     final String? staffListVPJson = prefs.getString('stafflistvp_data');
     
     if (staffListVPJson != null && staffListVPJson.isNotEmpty) {
       // Use stafflistvp data
       final List<dynamic> staffListVPData = json.decode(staffListVPJson);
       final Map<String, String> bpMap = {};
       
       for (final staff in staffListVPData) {
         if (staff['Username'] != null && staff['BP'] != null) {
           final username = staff['Username'].toString();
           final bp = staff['BP'].toString();
           bpMap[username.toLowerCase()] = bp;
           bpMap[username.toUpperCase()] = bp;
           bpMap[username] = bp; // Original case
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

 static Future<void> _createTheoChuDeSheet(
  Excel excel,
  List<TaskHistoryModel> data,
  Map<String, String> staffNameMap,
) async {
  final theoChuDeSheet = excel['TheoChuDe'];
  final staffBPMap = await _getStaffBPMap();
  
  final headers = [
    'STT',
    'Ngày',
    'Mã nhân viên',
    'Tên nhân viên',
    'Dự án',
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
    'Đánh giá',
  ];
  
  for (int i = 0; i < headers.length; i++) {
    final cell = theoChuDeSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
    cell.value = headers[i];
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#FF6B35',
      fontColorHex: '#FFFFFF',
    );
  }

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
  
  for (final key in sortedKeys) {
    final records = groupedData[key]!;
    final firstRecord = records.first;
    
    final capitalizedNguoiDung = (firstRecord.nguoiDung ?? '').toUpperCase();
    final staffName = staffNameMap[capitalizedNguoiDung] ?? '❓❓❓';
    final staffBP = staffBPMap[capitalizedNguoiDung] ?? '';
    
    final summary = _calculateTheoChuDeSummary(records);
    final grading = _calculateGrading(summary);
    
    final rowData = [
      stt.toString(),
      DateFormat('dd/MM/yyyy').format(firstRecord.ngay),
      firstRecord.nguoiDung ?? '',
      staffName,
      firstRecord.boPhan ?? '',
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
      summary.thieuCongGioWithUnit,  // Updated to include unit
      summary.khac.toString(),
      staffBP,
      summary.soBaoCao.toString(),
      summary.soKhungGio.toString(),
      summary.khungGioString,
      grading.toStringAsFixed(1),
    ];
    
    for (int i = 0; i < rowData.length; i++) {
      final cell = theoChuDeSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = rowData[i];
      
      if (i == 24) {
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

 static double _calculateGrading(TheoChuDeSummary summary) {
  double score = 0.0;
  
  // Base score from proper work hours (max 4 points)
  // Expected 8 hours per day, minimum 6 hours acceptable
  if (summary.soKhungGio >= 8) {
    score += 4.0;
  } else if (summary.soKhungGio >= 6) {
    score += 3.0;
  } else if (summary.soKhungGio >= 4) {
    score += 2.0;
  } else if (summary.soKhungGio >= 2) {
    score += 1.0;
  }
  
  // Image documentation score (max 2 points)
  // Should have at least 1 image per 2 hours of work
  double expectedImages = summary.soKhungGio / 2.0;
  if (summary.imageCount >= expectedImages) {
    score += 2.0;
  } else if (summary.imageCount >= expectedImages * 0.7) {
    score += 1.5;
  } else if (summary.imageCount >= expectedImages * 0.5) {
    score += 1.0;
  } else if (summary.imageCount > 0) {
    score += 0.5;
  }
  
  // Quality performance (max 2 points)
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
    score += qualityRate * 2.0;
  }
  
  // Staff management (max 1 point)
  if (summary.nhanSuThieu == 0) {
    score += 1.0;
  } else if (summary.nhanSuDu > summary.nhanSuThieu) {
    score += 0.5;
  }
  
  // Report completeness (max 1 point)
  // Should have at least 1 report per hour worked
  if (summary.soBaoCao >= summary.soKhungGio) {
    score += 1.0;
  } else if (summary.soBaoCao >= summary.soKhungGio * 0.8) {
    score += 0.8;
  } else if (summary.soBaoCao >= summary.soKhungGio * 0.6) {
    score += 0.6;
  } else if (summary.soBaoCao >= summary.soKhungGio * 0.4) {
    score += 0.4;
  } else if (summary.soBaoCao > 0) {
    score += 0.2;
  }
  
  // Deductions for serious issues
  score -= (summary.thieuCongGio * 0.5); // 0.5 points per missing hour
  score -= (summary.khac * 0.2); // 0.2 points per unclassified issue
  
  return score.clamp(0.0, 10.0);
}

 static TheoChuDeSummary _calculateTheoChuDeSummary(List<TaskHistoryModel> records) {
  final summary = TheoChuDeSummary();
  final uniqueHours = <String>{};
  final units = <String>{}; // Collect units
  
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
    
    if (phanLoai == 'Nhân sự') {
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
  
  // Set the most common unit or default to empty
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

 static Map<String, dynamic> _extractThieuNumberAndUnit(String text) {
  try {
    final lowerText = text.toLowerCase();
    final thieuIndex = lowerText.indexOf('thiếu');
    
    if (thieuIndex == -1) return {'number': 0.0, 'unit': ''};
    
    final afterThieu = text.substring(thieuIndex + 5).trim();
    
    // Updated regex to capture number and following text
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
static double _extractThieuNumber(String text) {
  final result = _extractThieuNumberAndUnit(text);
  return result['number'] as double;
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
    'Phân loại',        // Moved before Chi tiết
    'Chi tiết',
    'Ghi chú',          // Changed from 'Chi tiết 2'
    'Vị trí',
    'Giải pháp',
    'Hình ảnh',         // Changed from 'Có hình ảnh'
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
      record.phanLoai ?? '',      // Moved to position 7
      record.chiTiet ?? '',       // Now position 8
      record.chiTiet2 ?? '',      // Now position 9 (Ghi chú)
      record.viTri ?? '',
      record.giaiPhap ?? '',
      record.hinhAnh ?? '',       // Show actual URL instead of Có/Không
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
  String thieuCongUnit = ''; // New field for unit
  int khac = 0;
  int soBaoCao = 0;
  int soKhungGio = 0;
  List<String> khungGio = [];
  
  String get khungGioString => khungGio.join(', ');
  String get thieuCongGioWithUnit => thieuCongGio > 0 
      ? '${thieuCongGio.toStringAsFixed(1)} $thieuCongUnit'.trim()
      : '0';
}
