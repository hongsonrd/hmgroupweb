import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'db_helper.dart';
import 'table_models.dart';

class ProjectCongNhanBio {
  static Future<void> exportStaffBioToExcel({
    required BuildContext context,
  }) async {
    try {
      final dbHelper = DBHelper();
      final db = await dbHelper.database;
      
      // Get all staff bio data
      final List<Map<String, dynamic>> staffBioResults = await db.query(DatabaseTables.staffbioTable);
      
      if (staffBioResults.isEmpty) {
        throw Exception('Không có dữ liệu hồ sơ nhân sự để xuất');
      }

      // Create Excel workbook
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheet = excelFile['Sheet1'];

      // Define columns in the order you want them to appear
      final List<String> columns = [
        'UID',
        'MaNV', 
        'Ho_ten',
        'Ngay_vao',
        'Thang_vao', 
        'So_thang',
        'Loai_hinh_lao_dong',
        'Chuc_vu',
        'Gioi_tinh',
        'Ngay_sinh',
        'Tuoi',
        'Can_cuoc_cong_dan',
        'Ngay_cap',
        'Noi_cap',
        'Nguyen_quan',
        'Thuong_tru',
        'Dia_chi_lien_lac',
        'SDT',
        'Don_vi',
        'Giam_sat',
      ];

      // Add headers
      for (int i = 0; i < columns.length; i++) {
        var cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = _getColumnDisplayName(columns[i]);
        
        // Apply header styling
        cell.cellStyle = excel.CellStyle(
          bold: true,
          backgroundColorHex: '#4472C4',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int rowIndex = 0; rowIndex < staffBioResults.length; rowIndex++) {
        final staffData = staffBioResults[rowIndex];
        
        for (int colIndex = 0; colIndex < columns.length; colIndex++) {
          var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
            columnIndex: colIndex, 
            rowIndex: rowIndex + 1
          ));
          
          final value = staffData[columns[colIndex]];
          cell.value = value?.toString() ?? '';
        }
      }

      // Save file using the same pattern as ProjectCongNhanExcel
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String fileName = 'HoSoNhanSu_$timestamp.xlsx';
      await _saveAndHandleFile(excelFile, fileName, context, staffBioResults.length);

    } catch (e) {
      print('Error exporting staff bio: $e');
      rethrow;
    }
  }

  static Future<void> _saveAndHandleFile(excel.Excel excelFile, String fileName, BuildContext context, int recordCount) async {
    try {
      final fileBytes = excelFile.save();
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
          text: 'Xuất hồ sơ nhân sự - $recordCount bản ghi',
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
          _showDesktopSaveDialog(context, filePath, appFolder.path, recordCount, fileName);
        }
      }
    } catch (e) {
      print('Error saving Excel file: $e');
      rethrow;
    }
  }

  static void _showDesktopSaveDialog(BuildContext context, String filePath, String folderPath, int recordCount, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('Xuất Excel thành công'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đã xuất thành công hồ sơ nhân sự'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, size: 16, color: Colors.green[700]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Tên file: $fileName',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.green[700]),
                        SizedBox(width: 4),
                        Text(
                          'Số bản ghi: $recordCount',
                          style: TextStyle(
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text('File đã được lưu tại:'),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  filePath,
                  style: TextStyle(
                    fontSize: 11,
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

  static String _getColumnDisplayName(String columnName) {
    final Map<String, String> columnMapping = {
      'UID': 'ID',
      'MaNV': 'Mã nhân viên',
      'Ho_ten': 'Họ và tên',
      'Ngay_vao': 'Ngày vào',
      'Thang_vao': 'Tháng vào',
      'So_thang': 'Số tháng',
      'Loai_hinh_lao_dong': 'Loại hình lao động',
      'Chuc_vu': 'Chức vụ',
      'Gioi_tinh': 'Giới tính',
      'Ngay_sinh': 'Ngày sinh',
      'Tuoi': 'Tuổi',
      'Can_cuoc_cong_dan': 'Căn cước công dân',
      'Ngay_cap': 'Ngày cấp',
      'Noi_cap': 'Nơi cấp',
      'Nguyen_quan': 'Nguyên quán',
      'Thuong_tru': 'Thường trú',
      'Dia_chi_lien_lac': 'Địa chỉ liên lạc',
      'SDT': 'Số điện thoại',
      'Don_vi': 'Đơn vị',
      'Giam_sat': 'Giám sát',
    };
    
    return columnMapping[columnName] ?? columnName;
  }
}