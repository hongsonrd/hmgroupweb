// lib/export_all_projects_helper.dart
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'db_helper.dart';

class ExportAllProjectsHelper {
  static Future<void> exportAllProjectsToSingleSheet({
    required List<String> projects,
    required String selectedMonth,
    required BuildContext context,
    required Future<void> Function(String project) loadProjectData,
    required List<String> Function() getUniqueEmployees,
    required Map<String, String> Function() getStaffNames,
    required List<String> Function(String columnType) getEmployeesWithValueInColumn,
    required List<int> Function() getDaysInMonth,
    required String? Function(String empId, int day, String columnType) getAttendanceForDay,
    required Map<String, dynamic> Function(String empId) calculateSummary,
  }) async {
    try {
      // Show progress dialog with project counter
      int currentProjectIndex = 0;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Đang xuất Excel tất cả dự án'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang xử lý dự án ${currentProjectIndex + 1}/${projects.length}'),
                    if (currentProjectIndex < projects.length)
                      Text('${projects[currentProjectIndex]}', 
                           style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            },
          );
        },
      );

      final excelFile = excel.Excel.createExcel();
      
      // Remove default sheet
      excelFile.delete('Sheet1');
      
      // Create main sheet
      final sheet = excelFile['Tổng hợp tất cả dự án'];
      
      // Create headers first
      _createHeaders(sheet, selectedMonth);
      
      int currentRow = 3; // Start from row 4 (after title and headers)
      
      // Process each project ONE BY ONE to avoid memory issues
      for (int i = 0; i < projects.length; i++) {
        final project = projects[i];
        currentProjectIndex = i;
        
        print('Processing project ${i + 1}/${projects.length}: $project');
        
        try {
          // Load data for this project
          await loadProjectData(project);
          
          final employees = getUniqueEmployees();
          final staffNames = getStaffNames();
          
          if (employees.isEmpty) {
            print('No employees found for project: $project');
            continue;
          }
          
          // Process each employee and immediately write to Excel
          for (final empId in employees) {
            final summary = calculateSummary(empId);
            final staffName = staffNames[empId] ?? '';
            
            _writeEmployeeRow(sheet, currentRow, project, empId, staffName, summary);
            currentRow++;
          }
          
          // Clear data after processing each project to free memory
          // This should be handled in the loadProjectData function
          
        } catch (e) {
          print('Error processing project $project: $e');
          // Continue with next project instead of failing completely
          continue;
        }
      }
      
      // Close progress dialog
      Navigator.of(context).pop();
      
      if (currentRow <= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không có dữ liệu để xuất'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Style the sheet
      _styleSheet(sheet, currentRow - 1);
      
      // Save and share the file
      await _saveAndShareFile(excelFile, selectedMonth, context);
      
    } catch (e) {
      // Close progress dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xuất Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  static void _createHeaders(excel.Sheet sheet, String selectedMonth) {
    final headers = [
      'Dự án',
      'Mã NV',
      'Họ tên',
      'Tuần 1+2',
      'P1+2',
      'HT1+2',
      'Tuần 3+4',
      'P3+4',
      'HT3+4',
      'Công',
      'Phép',
      'Lễ',
      'HV',
      'Đêm',
      'CĐ',
      'HT',
      'NG thường',
      'Hỗ trợ',
      'Part time',
      'PT sáng',
      'PT chiều',
      'NG khác',
      'NG x1.5',
      'NG x2',
      'Công lễ',
    ];
    
    // Add title row
    final titleCell = sheet.cell(excel.CellIndex.indexByString('A1'));
    titleCell.value = 'BÁO CÁO TỔNG HỢP TẤT CẢ DỰ ÁN - THÁNG ${DateFormat('MM/yyyy').format(DateTime.parse('$selectedMonth-01'))}';
    titleCell.cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 16,
    );
    
    // Merge title cells
    sheet.merge(excel.CellIndex.indexByString('A1'), excel.CellIndex.indexByString('${_getColumnLetter(headers.length)}1'));
    
    // Add headers in row 3
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = headers[i];
      cell.cellStyle = excel.CellStyle(
        bold: true,
      );
    }
  }
  
  static void _writeEmployeeRow(
    excel.Sheet sheet, 
    int rowIndex, 
    String project, 
    String empId, 
    String staffName, 
    Map<String, dynamic> summary
  ) {
    final rowData = [
      project,
      empId,
      staffName,
      summary['tuan12'] ?? '',
      summary['p12'] ?? '',
      summary['ht12'] ?? '',
      summary['tuan34'] ?? '',
      summary['p34'] ?? '',
      summary['ht34'] ?? '',
      summary['cong'] ?? '',
      summary['phep'] ?? '',
      summary['le'] ?? '',
      summary['hv'] ?? '',
      summary['dem'] ?? '',
      summary['cd'] ?? '',
      summary['ht'] ?? '',
      summary['ng_total'] ?? '',
      summary['hotro_total'] ?? '',
      summary['pt_total'] ?? '',
      summary['pts_total'] ?? '',
      summary['ptc_total'] ?? '',
      summary['ngk_total'] ?? '',
      summary['ng15_total'] ?? '',
      summary['ng2_total'] ?? '',
      summary['congle_total'] ?? '',
    ];
    
    for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
      cell.value = rowData[colIndex].toString();
      
      // Style based on column
      if (colIndex == 0) { // Project column
        cell.cellStyle = excel.CellStyle(bold: true);
      } else if (colIndex == 1) { // Employee ID column
        cell.cellStyle = excel.CellStyle(bold: true);
      }
    }
  }
  
  static void _styleSheet(excel.Sheet sheet, int lastRow) {
    // Set column widths
    sheet.setColWidth(0, 20); // Project
    sheet.setColWidth(1, 12); // Employee ID
    sheet.setColWidth(2, 25); // Staff Name
    
    // Set standard width for other columns
    for (int i = 3; i < 25; i++) {
      sheet.setColWidth(i, 10);
    }
  }
  
  static Future<void> _saveAndShareFile(excel.Excel excelFile, String selectedMonth, BuildContext context) async {
    final bytes = excelFile.encode()!;
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'TongHop_TatCaDuAn_${selectedMonth}_$timestamp.xlsx';
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsBytes(bytes);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Báo cáo tổng hợp tất cả dự án tháng ${DateFormat('MM/yyyy').format(DateTime.parse('$selectedMonth-01'))}',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xuất Excel thành công: $fileName'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  static String _getColumnLetter(int columnIndex) {
    String result = '';
    while (columnIndex > 0) {
      columnIndex--;
      result = String.fromCharCode(65 + (columnIndex % 26)) + result;
      columnIndex ~/= 26;
    }
    return result;
  }
  
  // Helper method to get all projects with data for a specific month
  static Future<List<String>> getAllProjectsWithData(String selectedMonth) async {
    final dbHelper = DBHelper();
    final projectsWithData = await dbHelper.rawQuery('''
      SELECT DISTINCT BoPhan FROM chamcongcn 
      WHERE strftime('%Y-%m', Ngay) = ?
      ORDER BY BoPhan
    ''', [selectedMonth]);
    
    return projectsWithData.map((p) => p['BoPhan'] as String).toList();
  }
}