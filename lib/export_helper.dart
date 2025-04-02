// export_helper.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
class ExcelColorHelper {
  final String hexValue;
  
  ExcelColorHelper(this.hexValue);
  
  String get value {
    final buffer = StringBuffer();
    if (hexValue.length == 6 || hexValue.length == 7) buffer.write('FF');
    buffer.write(hexValue.replaceFirst('#', ''));
    return buffer.toString();
  }
}

class ExportHelper {
  // Function to export data to PDF
  static Future<void> exportToPdf({
    required String selectedDepartment,
    required String selectedMonth,
    required List<String> allEmployees,
    required Map<String, String> staffNames,
    required Function getEmployeesWithValueInColumn,
    required Function getDaysInMonth,
    required Function getAttendanceForDay,
    required Function calculateSummary,
    required BuildContext context,
  }) async {
    try {
    final fontData = await rootBundle.load('assets/fonts/RobotoCondensed-Regular.ttf');
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());
    
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: ttf,
        bold: ttf,
      ),
    );
    final days = getDaysInMonth();

      // Add title
       pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,

        build: (pw.Context pdfContext) {
          return [
              pw.Header(
                level: 0,
                child: pw.Text('Báo cáo chấm công - $selectedDepartment - $selectedMonth',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              
              // Add Chữ & Giờ thường section
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'CongThuongChu', 
                sectionTitle: 'Chữ & Giờ thường',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
              
              // Add other sections
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'HoTro', 
                sectionTitle: 'Hỗ trợ',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'PartTime', 
                sectionTitle: 'Part time',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'PartTimeSang', 
                sectionTitle: 'PT sáng',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'PartTimeChieu', 
                sectionTitle: 'PT chiều',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'NgoaiGioKhac', 
                sectionTitle: 'NG khác',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'NgoaiGiox15', 
                sectionTitle: 'NG x1.5',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'NgoaiGiox2', 
                sectionTitle: 'NG x2',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
              _buildPdfSection(
                allEmployees: allEmployees,
                columnType: 'CongLe', 
                sectionTitle: 'Công lễ',
                days: days,
                getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
                staffNames: staffNames,
                getAttendanceForDay: getAttendanceForDay,
                calculateSummary: calculateSummary,
              ),
            ];
          },
        ),
      );
      
      // Save PDF to file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/chamcong_${selectedDepartment.replaceAll(' ', '_')}_$selectedMonth.pdf');
      await file.writeAsBytes(await pdf.save());
      
      final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path)], 
      text: 'Báo cáo chấm công',
      subject: 'Báo cáo chấm công',
      sharePositionOrigin: box != null 
          ? Rect.fromLTWH(
              box.localToGlobal(Offset.zero).dx,
              box.localToGlobal(Offset.zero).dy,
              box.size.width,
              box.size.height / 2,
            )
          : null,
    );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF đã được tạo và chia sẻ thành công'))
      );
    } catch (e) {
      print('PDF export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xuất PDF: $e'), backgroundColor: Colors.red)
      );
    }
  }
  static Future<void> exportAllProjectsToExcel({
  required List<String> projects,
  required String selectedMonth,
  required Function loadProjectData,
  required Function getUniqueEmployees,
  required Function getStaffNames,
  required Function getEmployeesWithValueInColumn,
  required Function getDaysInMonth,
  required Function getAttendanceForDay,
  required Function calculateSummary,
  required BuildContext context,
}) async {
  try {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Đang xuất Excel cho tất cả dự án'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Vui lòng đợi trong giây lát...')
            ],
          ),
        );
      },
    );
    
    // Create a directory for all the Excel files
    final output = await getTemporaryDirectory();
    final batchDir = Directory('${output.path}/batch_excel_${DateTime.now().millisecondsSinceEpoch}');
    if (!await batchDir.exists()) {
      await batchDir.create();
    }
    
    // List to keep track of generated files
    List<File> allFiles = [];
    
    // Process each project
    int processedCount = 0;
    for (var project in projects) {
      // Update dialog progress
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Đang xuất Excel cho tất cả dự án'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: processedCount / projects.length,
                ),
                SizedBox(height: 16),
                Text('Đang xử lý ${processedCount + 1}/${projects.length}: $project')
              ],
            ),
          );
        },
      );
      
      // Load data for this project
      await loadProjectData(project);
      
      // Get the required data for this project
      final employees = getUniqueEmployees();
      final staffNames = getStaffNames();
      
      // Export to Excel in batch mode
      final files = await exportToExcel(
        selectedDepartment: project,
        selectedMonth: selectedMonth,
        allEmployees: employees,
        staffNames: staffNames,
        getEmployeesWithValueInColumn: getEmployeesWithValueInColumn,
        getDaysInMonth: getDaysInMonth,
        getAttendanceForDay: getAttendanceForDay,
        calculateSummary: calculateSummary,
        context: context,
        skipNavigation: true,
        batchMode: true, // Use batch mode to collect files
      );
      
      // Move the file to the batch directory
      for (var file in files) {
        final newPath = '${batchDir.path}/chamcong_${project.replaceAll(' ', '_')}_$selectedMonth.xlsx';
        final newFile = await file.copy(newPath);
        allFiles.add(newFile);
      }
      
      processedCount++;
    }
    
    // Close progress dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
    if (allFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không có dự án nào để xuất Excel'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }
    
    // Show zipping progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Đang nén file'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang nén ${allFiles.length} file Excel...')
            ],
          ),
        );
      },
    );
    
    // Create a ZIP file containing all the Excel files
    final zipFile = File('${output.path}/chamcong_all_projects_$selectedMonth.zip');
    
    // Create a zip encoder
    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    
    // Add each Excel file to the ZIP
    for (var file in allFiles) {
      encoder.addFile(file);
    }
    
    // Close the encoder when done
    encoder.close();
    
    // Close dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
    // Share the ZIP file
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(zipFile.path)],
      text: 'Báo cáo chấm công tất cả dự án $selectedMonth',
      subject: 'Báo cáo chấm công',
      sharePositionOrigin: box != null 
          ? Rect.fromLTWH(
              box.localToGlobal(Offset.zero).dx,
              box.localToGlobal(Offset.zero).dy,
              box.size.width,
              box.size.height / 2,
            )
          : null,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xuất Excel cho ${allFiles.length} dự án thành công'),
        backgroundColor: Colors.green,
      )
    );
  } catch (e) {
    print('Excel all projects export error: $e');
    
    // Close any open dialogs
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi khi xuất Excel cho tất cả dự án: $e'),
        backgroundColor: Colors.red
      )
    );
  }
}
static Future<List<File>> exportToExcel({
  required String selectedDepartment,
  required String selectedMonth,
  required List<String> allEmployees,
  required Map<String, String> staffNames,
  required Function getEmployeesWithValueInColumn,
  required Function getDaysInMonth,
  required Function getAttendanceForDay,
  required Function calculateSummary,
  required BuildContext context,
  bool skipNavigation = false, 
  bool batchMode = false, 
}) async {
  try {
    final excel = Excel.createExcel();
    final String sheetName = 'Báo cáo chấm công';
    final sheet = excel[sheetName];
    
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = 'Báo cáo chấm công - $selectedDepartment - $selectedMonth';
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 14);
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('N1'));
    
    int currentRow = 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'Chữ & Giờ thường', columnType: 'CongThuongChu',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('CongThuongChu'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary,
      includeNgoaiGioThuong: true
    );
    
    currentRow += 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'Hỗ trợ', columnType: 'HoTro',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('HoTro'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary
    );
    
    currentRow += 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'Part time', columnType: 'PartTime',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('PartTime'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary
    );
    
    currentRow += 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'PT sáng', columnType: 'PartTimeSang',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('PartTimeSang'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary
    );
    
    currentRow += 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'PT chiều', columnType: 'PartTimeChieu',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('PartTimeChieu'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary
    );
    
    currentRow += 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'NG khác', columnType: 'NgoaiGioKhac',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('NgoaiGioKhac'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary
    );
    
    currentRow += 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'NG x1.5', columnType: 'NgoaiGiox15',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('NgoaiGiox15'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary
    );
    
    currentRow += 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'NG x2', columnType: 'NgoaiGiox2',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('NgoaiGiox2'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary
    );
    
    currentRow += 3;
    
    currentRow = _addExcelSection(
      excel: excel, sheet: sheet, sheetName: 'Công lễ', columnType: 'CongLe',
      startRow: currentRow, days: getDaysInMonth(), employees: getEmployeesWithValueInColumn('CongLe'),
      staffNames: staffNames, getAttendanceForDay: getAttendanceForDay, calculateSummary: calculateSummary
    );
    
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/chamcong_${selectedDepartment.replaceAll(' ', '_')}_$selectedMonth.xlsx');
    await file.writeAsBytes(excel.encode()!);
    
    if (!batchMode) {  // Fixed missing opening parenthesis
      // Only share the file if not in batch mode
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)], 
        text: 'Báo cáo chấm công $selectedDepartment $selectedMonth',
        subject: 'Báo cáo chấm công',
        sharePositionOrigin: box != null 
            ? Rect.fromLTWH(
                box.localToGlobal(Offset.zero).dx,
                box.localToGlobal(Offset.zero).dy,
                box.size.width,
                box.size.height / 2,
              )
            : null,
      );
      
      if (!skipNavigation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel đã được tạo và chia sẻ thành công'))
        );
      }
    }
    
    return [file]; // Return the file for batch mode
  } catch (e) {
    print('Excel export error: $e');
    if (!skipNavigation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xuất Excel: $e'), backgroundColor: Colors.red)
      );
    }
    return []; // Return empty list on error
  }
}

static int _addExcelSection({
  required Excel excel,
  required Sheet sheet,
  required String sheetName,
  required String columnType,
  required int startRow,
  required List<int> days,
  required List<String> employees,
  required Map<String, String> staffNames,
  required Function getAttendanceForDay,
  required Function calculateSummary,
  bool includeNgoaiGioThuong = false,
}) {
  if (employees.isEmpty) return startRow;
  
  String days12Key, days34Key, totalKey;
  bool showPermissionColumns = false;
  bool showLeColumn = false;
  
  switch (columnType) {
    case 'NgoaiGioThuong':
      days12Key = 'ng_days12';
      days34Key = 'ng_days34';
      totalKey = 'ng_total';
      break;
    case 'HoTro':
      days12Key = 'hotro_days12';
      days34Key = 'hotro_days34';
      totalKey = 'hotro_total';
      break;
    case 'PartTime':
      days12Key = 'pt_days12';
      days34Key = 'pt_days34';
      totalKey = 'pt_total';
      break;
    case 'PartTimeSang':
      days12Key = 'pts_days12';
      days34Key = 'pts_days34';
      totalKey = 'pts_total';
      break;
    case 'PartTimeChieu':
      days12Key = 'ptc_days12';
      days34Key = 'ptc_days34';
      totalKey = 'ptc_total';
      break;
    case 'NgoaiGioKhac':
      days12Key = 'ngk_days12';
      days34Key = 'ngk_days34';
      totalKey = 'ngk_total';
      break;
    case 'NgoaiGiox15':
      days12Key = 'ng15_days12';
      days34Key = 'ng15_days34';
      totalKey = 'ng15_total';
      break;
    case 'NgoaiGiox2':
      days12Key = 'ng2_days12';
      days34Key = 'ng2_days34';
      totalKey = 'ng2_total';
      break;
    case 'CongLe':
      days12Key = 'congle_days12';
      days34Key = 'congle_days34';
      totalKey = 'congle_total';
      break;
    case 'CongThuongChu':
      days12Key = 'tuan12';
      days34Key = 'tuan34';
      totalKey = 'cong';
      showPermissionColumns = true;
      showLeColumn = true;
      break;
    default:
      days12Key = 'tuan12';
      days34Key = 'tuan34';
      totalKey = 'cong';
  }
  
  // Setup colors
  final blueHeaderHex = 'BBDEFB';
  final greenHeaderHex = 'C8E6C9';
  final orangeHeaderHex = 'FFE0B2';
  final blueContentHex = 'E3F2FD';
  final greenContentHex = 'E8F5E9';
  final orangeContentHex = 'FFF3E0';
  
  // Section title
  final sectionTitleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow));
  sectionTitleCell.value = sheetName;
  sectionTitleCell.cellStyle = CellStyle(
    bold: true,
    fontSize: 13,
  );
  
  // Headers (start at startRow + 1)
  final headerRow1 = [
    '', 'Ngày 1-15', '', '', 'Ngày 16+', '', '', 'Tổng tháng', '', '', '', '', '', '',
    ...days.map((day) => ''),
  ];
  
  for (int i = 0; i < headerRow1.length; i++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: startRow + 1));
    cell.value = headerRow1[i];
    
    // Color coding
    if (i >= 1 && i <= 3) {
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: blueHeaderHex,
      );
    } else if (i >= 4 && i <= 6) {
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: greenHeaderHex,
      );
    } else if (i >= 7 && i <= 13) {
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: orangeHeaderHex,
      );
    }
  }
  
  // Header row 2
  final headerRow2 = [
    'Mã NV', 'Tuần 1+2', 'P1+2', 'HT1+2', 'Tuần 3+4', 'P3+4', 'HT3+4',
    'Công', 'Phép', 'Lễ', 'HV', 'Đêm', 'CĐ', 'HT',
    ...days.map((day) => day.toString()),
  ];
  
  for (int i = 0; i < headerRow2.length; i++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: startRow + 2));
    cell.value = headerRow2[i];
    cell.cellStyle = CellStyle(bold: true);
    
    // Color coding
    if (i >= 1 && i <= 3) {
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: blueHeaderHex,
      );
    } else if (i >= 4 && i <= 6) {
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: greenHeaderHex,
      );
    } else if (i >= 7 && i <= 13) {
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: orangeHeaderHex,
      );
    }
  }
  
  // Employee rows
  int currentRow = startRow + 3;
  
  for (int empIndex = 0; empIndex < employees.length; empIndex++) {
    final empId = employees[empIndex];
    final rowIndex = currentRow;
    currentRow++;
    
    // Employee ID and name
    final nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    nameCell.value = '$empId\n${staffNames[empId] ?? ''}';
    
    if (columnType == 'CongThuongChu') {
      // Add "Công chữ" label
      nameCell.value = '$empId\n${staffNames[empId] ?? ''}\nCông chữ';
    }
    
    // Summary data
    final summary = calculateSummary(empId);
    
    // Tuần 1+2
    final tuan12Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    tuan12Cell.value = summary[days12Key] ?? '';
    tuan12Cell.cellStyle = CellStyle(backgroundColorHex: blueContentHex);
    
    // P1+2
    final p12Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
    p12Cell.value = showPermissionColumns ? (summary['p12'] ?? '') : '';
    p12Cell.cellStyle = CellStyle(backgroundColorHex: blueContentHex);
    
    // HT1+2
    final ht12Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
    ht12Cell.value = summary['ht12'] ?? '';
    ht12Cell.cellStyle = CellStyle(backgroundColorHex: blueContentHex);
    
    // Tuần 3+4
    final tuan34Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
    tuan34Cell.value = summary[days34Key] ?? '';
    tuan34Cell.cellStyle = CellStyle(backgroundColorHex: greenContentHex);
    
    // P3+4
    final p34Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
    p34Cell.value = showPermissionColumns ? (summary['p34'] ?? '') : '';
    p34Cell.cellStyle = CellStyle(backgroundColorHex: greenContentHex);
    
    // HT3+4
    final ht34Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
    ht34Cell.value = summary['ht34'] ?? '';
    ht34Cell.cellStyle = CellStyle(backgroundColorHex: greenContentHex);
    
    // Công
    final congCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex));
    congCell.value = summary[totalKey] ?? '';
    congCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
    
    // Phép
    final phepCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex));
    phepCell.value = showPermissionColumns ? (summary['phep'] ?? '') : '';
    phepCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
    
    // Lễ
    final leCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex));
    leCell.value = showLeColumn ? (summary['le'] ?? '') : '';
    leCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
    
    // HV
    final hvCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex));
    hvCell.value = showPermissionColumns ? (summary['hv'] ?? '') : '';
    hvCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
    
    // Đêm
    final demCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex));
    demCell.value = showPermissionColumns ? (summary['dem'] ?? '') : '';
    demCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
    
    // CĐ
    final cdCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex));
    cdCell.value = showPermissionColumns ? (summary['cd'] ?? '') : '';
    cdCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
    
    // HT
    final htCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex));
    htCell.value = summary['ht'] ?? '';
    htCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
    
    // Days
    for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      final value = getAttendanceForDay(empId, day, columnType);
      final displayValue = (value == '0' || value == 'Ro') ? '' : value;
      
      final dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14 + dayIndex, rowIndex: rowIndex));
      dayCell.value = displayValue ?? '';
      
      if (displayValue != null && displayValue.isNotEmpty) {
        dayCell.cellStyle = CellStyle(bold: true);
      }
    }
    
    // If this is the Công chữ section and we need to include NG thường row
    if (columnType == 'CongThuongChu' && includeNgoaiGioThuong) {
      // Add NG thường row
      final ngRowIndex = currentRow;
      currentRow++;
      
      // NG thường label
      final ngLabel = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: ngRowIndex));
      ngLabel.value = 'NG thường';
      
      // Add NG thường summary data
      final ngThuong_days12 = summary['ng_days12'] ?? '';
      final ngThuong_days34 = summary['ng_days34'] ?? '';
      final ngThuong_total = summary['ng_total'] ?? '';
      
      // Tuần 1+2 for NG thường
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: ngRowIndex)).value = ngThuong_days12;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: ngRowIndex))
          .cellStyle = CellStyle(backgroundColorHex: blueContentHex);
      
      // Empty cells for P1+2 and HT1+2
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: ngRowIndex))
          .cellStyle = CellStyle(backgroundColorHex: blueContentHex);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: ngRowIndex))
          .cellStyle = CellStyle(backgroundColorHex: blueContentHex);
      
      // Tuần 3+4 for NG thường
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: ngRowIndex)).value = ngThuong_days34;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: ngRowIndex))
          .cellStyle = CellStyle(backgroundColorHex: greenContentHex);
      
      // Empty cells for P3+4 and HT3+4
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: ngRowIndex))
          .cellStyle = CellStyle(backgroundColorHex: greenContentHex);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: ngRowIndex))
          .cellStyle = CellStyle(backgroundColorHex: greenContentHex);
      
      // Total for NG thường
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: ngRowIndex)).value = ngThuong_total;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: ngRowIndex))
          .cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      
      // Empty cells for other totals
      for (int i = 8; i <= 13; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: ngRowIndex))
            .cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      }
      
      // Add daily values for NG thường
      for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
  final day = days[dayIndex];
  final value = getAttendanceForDay(empId, day, 'NgoaiGioThuong');
  final displayValue = (value == '0') ? '' : value;
  
  final dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14 + dayIndex, rowIndex: ngRowIndex));
  dayCell.value = displayValue ?? '';
  
  if (displayValue != null && displayValue.isNotEmpty) {
    dayCell.cellStyle = CellStyle(bold: true);
  }
}
    }
    
    // Add a small gap between employees
    if (empId != employees.last) {
      currentRow++;
    }
  }
  
  return currentRow;
}
  

  // Helper method to build a section in PDF
  static pw.Widget _buildPdfSection({
    required List<String> allEmployees,
    required String columnType,
    required String sectionTitle,
    required List<int> days,
    required Function getEmployeesWithValueInColumn,
    required Map<String, String> staffNames,
    required Function getAttendanceForDay,
    required Function calculateSummary,
  }) {
    final relevantEmployees = getEmployeesWithValueInColumn(columnType);
    
    if (relevantEmployees.isEmpty) {
      return pw.Container();
    }
    
    String days12Key, days34Key, totalKey;
    bool showPermissionColumns = false;
    bool showLeColumn = false;
    
    switch (columnType) {
      case 'NgoaiGioThuong':
        days12Key = 'ng_days12';
        days34Key = 'ng_days34';
        totalKey = 'ng_total';
        break;
      case 'HoTro':
        days12Key = 'hotro_days12';
        days34Key = 'hotro_days34';
        totalKey = 'hotro_total';
        break;
      case 'PartTime':
        days12Key = 'pt_days12';
        days34Key = 'pt_days34';
        totalKey = 'pt_total';
        break;
      case 'PartTimeSang':
        days12Key = 'pts_days12';
        days34Key = 'pts_days34';
        totalKey = 'pts_total';
        break;
      case 'PartTimeChieu':
        days12Key = 'ptc_days12';
        days34Key = 'ptc_days34';
        totalKey = 'ptc_total';
        break;
      case 'NgoaiGioKhac':
        days12Key = 'ngk_days12';
        days34Key = 'ngk_days34';
        totalKey = 'ngk_total';
        break;
      case 'NgoaiGiox15':
        days12Key = 'ng15_days12';
        days34Key = 'ng15_days34';
        totalKey = 'ng15_total';
        break;
      case 'NgoaiGiox2':
        days12Key = 'ng2_days12';
        days34Key = 'ng2_days34';
        totalKey = 'ng2_total';
        break;
      case 'CongLe':
        days12Key = 'congle_days12';
        days34Key = 'congle_days34';
        totalKey = 'congle_total';
        break;
      case 'CongThuongChu':
        days12Key = 'tuan12';
        days34Key = 'tuan34';
        totalKey = 'cong';
        showPermissionColumns = true;
        showLeColumn = true;
        break;
      default:
        days12Key = 'tuan12';
        days34Key = 'tuan34';
        totalKey = 'cong';
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Text(
          sectionTitle,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FixedColumnWidth(100),
            1: pw.FixedColumnWidth(50),
            2: pw.FixedColumnWidth(50),
            3: pw.FixedColumnWidth(50),
            4: pw.FixedColumnWidth(50),
            5: pw.FixedColumnWidth(50),
            6: pw.FixedColumnWidth(50),
            7: pw.FixedColumnWidth(50),
            8: pw.FixedColumnWidth(50),
            9: pw.FixedColumnWidth(50),
            10: pw.FixedColumnWidth(50),
            11: pw.FixedColumnWidth(50),
            12: pw.FixedColumnWidth(50),
            13: pw.FixedColumnWidth(50),
            for (int i = 0; i < days.length; i++)
              i + 14: pw.FixedColumnWidth(25),
          },
          children: [
            // Header row 1
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Container(child: pw.Text('')),
                pw.Container(
                  color: PdfColors.blue100,
                  child: pw.Center(
                    child: pw.Text('Ngày 1-15', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.Container(color: PdfColors.blue100, child: pw.Text('')),
                pw.Container(color: PdfColors.blue100, child: pw.Text('')),
                pw.Container(
                  color: PdfColors.green100,
                  child: pw.Center(
                    child: pw.Text('Ngày 16+', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.Container(color: PdfColors.green100, child: pw.Text('')),
                pw.Container(color: PdfColors.green100, child: pw.Text('')),
                pw.Container(
                  color: PdfColors.orange100,
                  child: pw.Center(
                    child: pw.Text('Tổng tháng', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ),
                pw.Container(color: PdfColors.orange100, child: pw.Text('')),
                pw.Container(color: PdfColors.orange100, child: pw.Text('')),
                pw.Container(color: PdfColors.orange100, child: pw.Text('')),
                pw.Container(color: PdfColors.orange100, child: pw.Text('')),
                pw.Container(color: PdfColors.orange100, child: pw.Text('')),
                pw.Container(color: PdfColors.orange100, child: pw.Text('')),
                ...List.generate(days.length, (index) => pw.Container(child: pw.Text(''))),
              ],
            ),
            // Header row 2
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Text('Mã NV', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  color: PdfColors.blue100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('Tuần 1+2', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.blue100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('P1+2', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.blue100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('HT1+2', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.green100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('Tuần 3+4', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.green100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('P3+4', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.green100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('HT3+4', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.orange100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('Công', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.orange100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('Phép', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.orange100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('Lễ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.orange100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('HV', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.orange100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('Đêm', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.orange100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('CĐ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                pw.Container(
                  color: PdfColors.orange100,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Center(child: pw.Text('HT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ),
                ...days.map((day) => pw.Padding(
                  padding: pw.EdgeInsets.all(2),
                  child: pw.Center(child: pw.Text(day.toString(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                )),
              ],
            ),
            // Employee rows
            for (var empId in relevantEmployees) 
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(empId, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          staffNames[empId] ?? '',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          columnType == 'CongThuongChu' ? 'Công chữ' : 
                          columnType == 'NgoaiGioThuong' ? 'NG thường' : '',
                          style: pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  ..._buildPdfEmployeeDataCells(
                    empId: empId,
                    calculateSummary: calculateSummary,
                    days12Key: days12Key,
                    days34Key: days34Key,
                    totalKey: totalKey,
                    showPermissionColumns: showPermissionColumns,
                    showLeColumn: showLeColumn,
                  ),
                  ...days.map((day) {
                    final value = getAttendanceForDay(empId, day, columnType);
                    final displayValue = (value == '0' || value == 'Ro') ? '' : value;
                    
                    return pw.Padding(
                      padding: pw.EdgeInsets.all(2),
                      child: pw.Center(
                        child: pw.Text(
                          displayValue ?? '',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: displayValue != null && displayValue.isNotEmpty
                              ? pw.FontWeight.bold
                              : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // Helper method to build employee data cells for PDF
  static List<pw.Widget> _buildPdfEmployeeDataCells({
    required String empId,
    required Function calculateSummary,
    required String days12Key,
    required String days34Key,
    required String totalKey,
    required bool showPermissionColumns,
    required bool showLeColumn,
  }) {
    final summary = calculateSummary(empId);
    
    return [
      // Tuần 1+2
      pw.Container(
        color: PdfColors.blue50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(summary[days12Key] ?? '')),
      ),
      // P1+2
      pw.Container(
        color: PdfColors.blue50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(
          showPermissionColumns ? (summary['p12'] ?? '') : ''
        )),
      ),
      // HT1+2
      pw.Container(
        color: PdfColors.blue50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(summary['ht12'] ?? '')),
      ),
      // Tuần 3+4
      pw.Container(
        color: PdfColors.green50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(summary[days34Key] ?? '')),
      ),
      // P3+4
      pw.Container(
        color: PdfColors.green50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(
          showPermissionColumns ? (summary['p34'] ?? '') : ''
        )),
      ),
      // HT3+4
      pw.Container(
        color: PdfColors.green50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(summary['ht34'] ?? '')),
      ),
      // Công
      pw.Container(
        color: PdfColors.orange50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(summary[totalKey] ?? '')),
      ),
      // Phép
      pw.Container(
        color: PdfColors.orange50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(
          showPermissionColumns ? (summary['phep'] ?? '') : ''
        )),
      ),
      // Lễ
      pw.Container(
        color: PdfColors.orange50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(
          showLeColumn ? (summary['le'] ?? '') : ''
        )),
      ),
      // HV
      pw.Container(
        color: PdfColors.orange50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(
          showPermissionColumns ? (summary['hv'] ?? '') : ''
        )),
      ),
      // Đêm
      pw.Container(
        color: PdfColors.orange50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(
          showPermissionColumns ? (summary['dem'] ?? '') : ''
        )),
      ),
      // CĐ
      pw.Container(
        color: PdfColors.orange50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(
          showPermissionColumns ? (summary['cd'] ?? '') : ''
        )),
      ),
      // HT
      pw.Container(
        color: PdfColors.orange50,
        padding: pw.EdgeInsets.all(5),
        child: pw.Center(child: pw.Text(
          summary['ht'] ?? ''
        )),
      ),
    ];
  }

  // Helper method to add a sheet to Excel
  static void _addExcelSheet({
    required Excel excel,
    required String sheetName,
    required String columnType,
    required List<int> days,
    required List<String> employees,
    required Map<String, String> staffNames,
    required Function getAttendanceForDay,
    required Function calculateSummary,
    required String selectedDepartment,
    required String selectedMonth,
  }) {
    if (employees.isEmpty) return;
    
    String days12Key, days34Key, totalKey;
    bool showPermissionColumns = false;
    bool showLeColumn = false;
    
    switch (columnType) {
      case 'NgoaiGioThuong':
        days12Key = 'ng_days12';
        days34Key = 'ng_days34';
        totalKey = 'ng_total';
        break;
      case 'HoTro':
        days12Key = 'hotro_days12';
        days34Key = 'hotro_days34';
        totalKey = 'hotro_total';
        break;
      case 'PartTime':
        days12Key = 'pt_days12';
        days34Key = 'pt_days34';
        totalKey = 'pt_total';
        break;
      case 'PartTimeSang':
        days12Key = 'pts_days12';
        days34Key = 'pts_days34';
        totalKey = 'pts_total';
        break;
      case 'PartTimeChieu':
        days12Key = 'ptc_days12';
        days34Key = 'ptc_days34';
        totalKey = 'ptc_total';
        break;
      case 'NgoaiGioKhac':
        days12Key = 'ngk_days12';
        days34Key = 'ngk_days34';
        totalKey = 'ngk_total';
        break;
      case 'NgoaiGiox15':
        days12Key = 'ng15_days12';
        days34Key = 'ng15_days34';
        totalKey = 'ng15_total';
        break;
      case 'NgoaiGiox2':
        days12Key = 'ng2_days12';
        days34Key = 'ng2_days34';
        totalKey = 'ng2_total';
        break;
      case 'CongLe':
        days12Key = 'congle_days12';
        days34Key = 'congle_days34';
        totalKey = 'congle_total';
        break;
      case 'CongThuongChu':
        days12Key = 'tuan12';
        days34Key = 'tuan34';
        totalKey = 'cong';
        showPermissionColumns = true;
        showLeColumn = true;
        break;
      default:
        days12Key = 'tuan12';
        days34Key = 'tuan34';
        totalKey = 'cong';
    }
    
    // Create a new sheet
    final sheet = excel[sheetName];
    
    // Set up background colors for the Excel sheet
    final blueHeaderHex = 'BBDEFB'; // Light blue header
    final greenHeaderHex = 'C8E6C9'; // Light green header
    final orangeHeaderHex = 'FFE0B2'; // Light orange header
    final blueContentHex = 'E3F2FD'; // Very light blue content
    final greenContentHex = 'E8F5E9'; // Very light green content
    final orangeContentHex = 'FFF3E0'; // Very light orange content
    
    // Add title
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = '$sheetName - $selectedDepartment - $selectedMonth';
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
    );
    
    // Merge cells for title
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('N1'));
    
    // Add header row 1
    final headerRow1 = [
      '', 'Ngày 1-15', '', '', 'Ngày 16+', '', '', 'Tổng tháng', '', '', '', '', '', '',
      ...days.map((day) => ''),
    ];
    
    for (int i = 0; i < headerRow1.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = headerRow1[i];
      
      // Color coding
      if (i >= 1 && i <= 3) {
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: blueHeaderHex,
        );
      } else if (i >= 4 && i <= 6) {
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: greenHeaderHex,
        );
      } else if (i >= 7 && i <= 13) {
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: orangeHeaderHex,
        );
      }
    }
    
    // Add header row 2
    final headerRow2 = [
      'Mã NV', 'Tuần 1+2', 'P1+2', 'HT1+2', 'Tuần 3+4', 'P3+4', 'HT3+4',
      'Công', 'Phép', 'Lễ', 'HV', 'Đêm', 'CĐ', 'HT',
      ...days.map((day) => day.toString()),
    ];
    
    for (int i = 0; i < headerRow2.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = headerRow2[i];
      cell.cellStyle = CellStyle(bold: true);
      
      // Color coding
      if (i >= 1 && i <= 3) {
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: blueHeaderHex,
        );
      } else if (i >= 4 && i <= 6) {
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: greenHeaderHex,
        );
      } else if (i >= 7 && i <= 13) {
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: orangeHeaderHex,
        );
      }
    }
    
    // Add employee rows
    for (int empIndex = 0; empIndex < employees.length; empIndex++) {
      final empId = employees[empIndex];
      final rowIndex = 4 + empIndex;
      
      // Employee ID and name
      final nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      nameCell.value = '$empId\n${staffNames[empId] ?? ''}';
      
      // Summary data
      final summary = calculateSummary(empId);
      
      // Tuần 1+2
      final tuan12Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      tuan12Cell.value = summary[days12Key] ?? '';
      tuan12Cell.cellStyle = CellStyle(backgroundColorHex: blueContentHex);
      
      // P1+2
      final p12Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      p12Cell.value = showPermissionColumns ? (summary['p12'] ?? '') : '';
      p12Cell.cellStyle = CellStyle(backgroundColorHex: blueContentHex);
      
      // HT1+2
      final ht12Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
      ht12Cell.value = summary['ht12'] ?? '';
      ht12Cell.cellStyle = CellStyle(backgroundColorHex: blueContentHex);
      
      // Tuần 3+4
      final tuan34Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
      tuan34Cell.value = summary[days34Key] ?? '';
      tuan34Cell.cellStyle = CellStyle(backgroundColorHex: greenContentHex);
      
      // P3+4
      final p34Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
      p34Cell.value = showPermissionColumns ? (summary['p34'] ?? '') : '';
      p34Cell.cellStyle = CellStyle(backgroundColorHex: greenContentHex);
      
      // HT3+4
      final ht34Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
      ht34Cell.value = summary['ht34'] ?? '';
      ht34Cell.cellStyle = CellStyle(backgroundColorHex: greenContentHex);
      
      // Công
      final congCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex));
      congCell.value = summary[totalKey] ?? '';
      congCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      
      // Phép
      final phepCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex));
      phepCell.value = showPermissionColumns ? (summary['phep'] ?? '') : '';
      phepCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      
      // Lễ
      final leCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex));
      leCell.value = showLeColumn ? (summary['le'] ?? '') : '';
      leCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      
      // HV
      final hvCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex));
      hvCell.value = showPermissionColumns ? (summary['hv'] ?? '') : '';
      hvCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      
      // Đêm
      final demCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex));
      demCell.value = showPermissionColumns ? (summary['dem'] ?? '') : '';
      demCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      
      // CĐ
      final cdCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex));
      cdCell.value = showPermissionColumns ? (summary['cd'] ?? '') : '';
      cdCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      
      // HT
      final htCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex));
      htCell.value = summary['ht'] ?? '';
      htCell.cellStyle = CellStyle(backgroundColorHex: orangeContentHex);
      
      // Days
      for (int dayIndex = 0; dayIndex < days.length; dayIndex++) {
        final day = days[dayIndex];
        final value = getAttendanceForDay(empId, day, columnType);
        final displayValue = (value == '0' || value == 'Ro') ? '' : value;
        
        final dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14 + dayIndex, rowIndex: rowIndex));
        dayCell.value = displayValue ?? '';
        
        if (displayValue != null && displayValue.isNotEmpty) {
          dayCell.cellStyle = CellStyle(bold: true);
        }
      }
    }
    
    // Set column widths - instead of setColumnWidth which doesn't exist
    // We'll set column auto-fit by adding extra cells with reasonable content
    final maxCols = 14 + days.length;
    final rowForWidths = sheet.maxRows + 1;
    
    // Add a row that helps with column sizing
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowForWidths)).value = 'Employee ID and Name';
    for (int i = 1; i < 14; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowForWidths)).value = 'Value';
    }
    for (int i = 14; i < maxCols; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowForWidths)).value = '99';
    }
    
    // Hide this row later when viewing the spreadsheet
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowForWidths)).value = '';
  }
}