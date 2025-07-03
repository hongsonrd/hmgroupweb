import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class AllProjectsExcelGenerator {
  static Future<void> generateComprehensiveExcelReport({
    required String selectedMonth,
    required BuildContext context,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
    bool isPeriodMode = false,
  }) async {
    try {
      // Create new Excel workbook
      var excelWorkbook = Excel.createExcel();
      
      // Remove default sheet
      excelWorkbook.delete('Sheet1');
      
      // Get all projects with data
      final allProjectsWithData = await _fetchAllProjectsWithAttendanceData(
        selectedMonth: selectedMonth,
        periodStartDate: periodStartDate,
        periodEndDate: periodEndDate,
        isPeriodMode: isPeriodMode,
      );
      
      if (allProjectsWithData.isEmpty) {
        _showMessage(context, 'Không tìm thấy dự án nào có dữ liệu', Colors.orange);
        return;
      }
      
      // Create summary sheet first
      await _createComprehensiveSummarySheet(
        excelWorkbook: excelWorkbook,
        projectsList: allProjectsWithData,
        selectedMonth: selectedMonth,
        periodStartDate: periodStartDate,
        periodEndDate: periodEndDate,
        isPeriodMode: isPeriodMode,
      );
      
      // Create individual project sheets
      for (String projectName in allProjectsWithData) {
        await _createIndividualProjectSheet(
          excelWorkbook: excelWorkbook,
          projectName: projectName,
          selectedMonth: selectedMonth,
          periodStartDate: periodStartDate,
          periodEndDate: periodEndDate,
          isPeriodMode: isPeriodMode,
        );
      }
      
      // Save and share the file
      await _saveAndShareComprehensiveExcel(
        excelWorkbook: excelWorkbook,
        selectedMonth: selectedMonth,
        context: context,
        isPeriodMode: isPeriodMode,
        periodStartDate: periodStartDate,
        periodEndDate: periodEndDate,
      );
      
    } catch (e) {
      print('Error in generateComprehensiveExcelReport: $e');
      _showMessage(context, 'Lỗi khi tạo báo cáo Excel: $e', Colors.red);
    }
  }
  
  static Future<List<String>> _fetchAllProjectsWithAttendanceData({
    required String selectedMonth,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
    bool isPeriodMode = false,
  }) async {
    final dbHelper = DBHelper();
    List<Map<String, Object?>> projectsQueryResult;
    
    if (isPeriodMode && periodStartDate != null && periodEndDate != null) {
      projectsQueryResult = await dbHelper.rawQuery('''
        SELECT DISTINCT BoPhan FROM chamcongcn 
        WHERE date(Ngay) BETWEEN date(?) AND date(?)
        ORDER BY BoPhan
      ''', [
        DateFormat('yyyy-MM-dd').format(periodStartDate),
        DateFormat('yyyy-MM-dd').format(periodEndDate)
      ]);
    } else {
      projectsQueryResult = await dbHelper.rawQuery('''
        SELECT DISTINCT BoPhan FROM chamcongcn 
        WHERE strftime('%Y-%m', Ngay) = ?
        ORDER BY BoPhan
      ''', [selectedMonth]);
    }
    
    return projectsQueryResult.map((p) => p['BoPhan'] as String).toList();
  }
  
  static Future<void> _createComprehensiveSummarySheet({
    required Excel excelWorkbook,
    required List<String> projectsList,
    required String selectedMonth,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
    bool isPeriodMode = false,
  }) async {
    // Create summary sheet
    Sheet summarySheet = excelWorkbook['Tổng hợp tất cả dự án'];
    
    // Set up headers
    summarySheet.cell(CellIndex.indexByString('A1')).value = 
        'BÁO CÁO TỔNG HỢP TẤT CẢ DỰ ÁN';
    summarySheet.cell(CellIndex.indexByString('A2')).value = 
        isPeriodMode 
          ? 'Giai đoạn: ${DateFormat('dd/MM/yyyy').format(periodStartDate!)} - ${DateFormat('dd/MM/yyyy').format(periodEndDate!)}'
          : 'Tháng: ${DateFormat('MM/yyyy').format(DateTime.parse('$selectedMonth-01'))}';
    
    // Headers for summary
    int currentRow = 4;
    List<String> summaryHeaders = [
      'STT', 'Tên dự án', 'Số nhân viên', 'Tổng công thường', 
      'Tổng phép', 'Tổng HT', 'Tổng NG thường', 'Tổng HV', 'Tổng đêm', 'Tổng CĐ'
    ];
    
    for (int i = 0; i < summaryHeaders.length; i++) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow - 1)).value = 
          summaryHeaders[i];
    }
    
    // Process each project for summary
    for (int projectIndex = 0; projectIndex < projectsList.length; projectIndex++) {
      String projectName = projectsList[projectIndex];
      
      final projectSummaryData = await _calculateProjectComprehensiveSummary(
        projectName: projectName,
        selectedMonth: selectedMonth,
        periodStartDate: periodStartDate,
        periodEndDate: periodEndDate,
        isPeriodMode: isPeriodMode,
      );
      
      // Add project summary row
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).value = 
          projectIndex + 1;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).value = 
          projectName;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow)).value = 
          projectSummaryData['employeeCount'];
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow)).value = 
          projectSummaryData['totalCongThuong'];
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow)).value = 
          projectSummaryData['totalPhep'];
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).value = 
          projectSummaryData['totalHT'];
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).value = 
          projectSummaryData['totalNGThuong'];
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow)).value = 
          projectSummaryData['totalHV'];
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow)).value = 
          projectSummaryData['totalDem'];
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: currentRow)).value = 
          projectSummaryData['totalCD'];
      
      currentRow++;
    }
  }
  
  static Future<Map<String, dynamic>> _calculateProjectComprehensiveSummary({
    required String projectName,
    required String selectedMonth,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
    bool isPeriodMode = false,
  }) async {
    final dbHelper = DBHelper();
    String query;
    List<dynamic> params;
    
    if (isPeriodMode && periodStartDate != null && periodEndDate != null) {
      query = '''
        SELECT * FROM chamcongcn 
        WHERE BoPhan = ? AND date(Ngay) BETWEEN date(?) AND date(?)
        ORDER BY MaNV, Ngay
      ''';
      params = [
        projectName, 
        DateFormat('yyyy-MM-dd').format(periodStartDate),
        DateFormat('yyyy-MM-dd').format(periodEndDate)
      ];
    } else {
      query = '''
        SELECT * FROM chamcongcn 
        WHERE BoPhan = ? AND strftime('%Y-%m', Ngay) = ?
        ORDER BY MaNV, Ngay
      ''';
      params = [projectName, selectedMonth];
    }
    
    final attendanceData = await dbHelper.rawQuery(query, params);
    
    // Get unique employees
    final uniqueEmployees = attendanceData
        .map((record) => record['MaNV'] as String)
        .toSet()
        .toList();
    
    // Calculate totals
    double totalCongThuong = 0;
    double totalPhep = 0;
    double totalHT = 0;
    double totalNGThuong = 0;
    double totalHV = 0;
    double totalDem = 0;
    double totalCD = 0;
    
    for (String empId in uniqueEmployees) {
      final empSummary = _calculateEmployeeComprehensiveSummary(
        empId: empId,
        attendanceData: attendanceData,
        isPeriodMode: isPeriodMode,
        periodStartDate: periodStartDate,
        periodEndDate: periodEndDate,
        selectedMonth: selectedMonth,
      );
      
      totalCongThuong += _parseDouble(empSummary['cong']);
      totalPhep += _parseDouble(empSummary['phep']);
      totalHT += _parseDouble(empSummary['ht']);
      totalNGThuong += _parseDouble(empSummary['ng_total']);
      totalHV += _parseDouble(empSummary['hv']);
      totalDem += _parseDouble(empSummary['dem']);
      totalCD += _parseDouble(empSummary['cd']);
    }
    
    return {
      'employeeCount': uniqueEmployees.length,
      'totalCongThuong': totalCongThuong,
      'totalPhep': totalPhep,
      'totalHT': totalHT,
      'totalNGThuong': totalNGThuong,
      'totalHV': totalHV,
      'totalDem': totalDem,
      'totalCD': totalCD,
    };
  }
  
  static Future<void> _createIndividualProjectSheet({
    required Excel excelWorkbook,
    required String projectName,
    required String selectedMonth,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
    bool isPeriodMode = false,
  }) async {
    // Create sheet for this project
    String safeSheetName = _createSafeSheetName(projectName);
    Sheet projectSheet = excelWorkbook[safeSheetName];
    
    // Get attendance data for this project
    final dbHelper = DBHelper();
    String query;
    List<dynamic> params;
    
    if (isPeriodMode && periodStartDate != null && periodEndDate != null) {
      query = '''
        SELECT * FROM chamcongcn 
        WHERE BoPhan = ? AND date(Ngay) BETWEEN date(?) AND date(?)
        ORDER BY MaNV, Ngay
      ''';
      params = [
        projectName, 
        DateFormat('yyyy-MM-dd').format(periodStartDate),
        DateFormat('yyyy-MM-dd').format(periodEndDate)
      ];
    } else {
      query = '''
        SELECT * FROM chamcongcn 
        WHERE BoPhan = ? AND strftime('%Y-%m', Ngay) = ?
        ORDER BY MaNV, Ngay
      ''';
      params = [projectName, selectedMonth];
    }
    
    final attendanceData = await dbHelper.rawQuery(query, params);
    
    if (attendanceData.isEmpty) return;
    
    // Get unique employees
    final uniqueEmployees = attendanceData
        .map((record) => record['MaNV'] as String)
        .toSet()
        .toList()..sort();
    
    // Get staff names
    final staffNames = await _getStaffNamesForEmployees(uniqueEmployees);
    
    // Get days in period
    final daysInPeriod = _getDaysInPeriodForExcel(
      selectedMonth: selectedMonth,
      isPeriodMode: isPeriodMode,
      periodStartDate: periodStartDate,
      periodEndDate: periodEndDate,
    );
    
    // Set up sheet headers
    projectSheet.cell(CellIndex.indexByString('A1')).value = 
        'DỰ ÁN: $projectName';
    projectSheet.cell(CellIndex.indexByString('A2')).value = 
        isPeriodMode 
          ? 'Giai đoạn: ${DateFormat('dd/MM/yyyy').format(periodStartDate!)} - ${DateFormat('dd/MM/yyyy').format(periodEndDate!)}'
          : 'Tháng: ${DateFormat('MM/yyyy').format(DateTime.parse('$selectedMonth-01'))}';
    
    // Create detailed table
    int currentRow = 4;
    
    // Headers
    List<String> detailedHeaders = [
      'Mã NV', 'Họ tên', 'Tuần 1+2', 'P1+2', 'HT1+2', 'Tuần 3+4', 'P3+4', 'HT3+4',
      'Công', 'Phép', 'Lễ', 'HV', 'Đêm', 'CĐ', 'HT', 'NG thường'
    ];
    
    // Add day headers
    for (int day in daysInPeriod) {
      detailedHeaders.add('Ngày $day');
    }
    
    for (int i = 0; i < detailedHeaders.length; i++) {
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow - 1)).value = 
          detailedHeaders[i];
    }
    
    // Add employee data
    for (String empId in uniqueEmployees) {
      final empSummary = _calculateEmployeeComprehensiveSummary(
        empId: empId,
        attendanceData: attendanceData,
        isPeriodMode: isPeriodMode,
        periodStartDate: periodStartDate,
        periodEndDate: periodEndDate,
        selectedMonth: selectedMonth,
      );
      
      int colIndex = 0;
      
      // Employee ID
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empId;
      
      // Employee name
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          staffNames[empId] ?? '';
      
      // Summary data
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['tuan12'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['p12'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['ht12'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['tuan34'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['p34'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['ht34'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['cong'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['phep'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['le'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['hv'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['dem'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['cd'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['ht'] ?? '';
      projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
          empSummary['ng_total'] ?? '';
      
      // Daily attendance data
      for (int day in daysInPeriod) {
        final dailyValue = _getAttendanceForDayFromData(
          empId: empId,
          day: day,
          columnType: 'CongThuongChu',
          attendanceData: attendanceData,
          selectedMonth: selectedMonth,
          isPeriodMode: isPeriodMode,
          periodStartDate: periodStartDate,
          periodEndDate: periodEndDate,
        );
        
        final displayValue = (dailyValue == 'Ro') ? '' : dailyValue;
        projectSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: currentRow)).value = 
            displayValue ?? '';
      }
      
      currentRow++;
    }
  }
  
  static Map<String, dynamic> _calculateEmployeeComprehensiveSummary({
    required String empId,
    required List<Map<String, Object?>> attendanceData,
    required bool isPeriodMode,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
    required String selectedMonth,
  }) {
    final daysInPeriod = _getDaysInPeriodForExcel(
      selectedMonth: selectedMonth,
      isPeriodMode: isPeriodMode,
      periodStartDate: periodStartDate,
      periodEndDate: periodEndDate,
    );
    
    double tongHV = 0;
    double tongDem = 0;
    double tongCD = 0;
    
    // Initialize period-based calculations
    double congChu_regularDays12 = 0;
    double congChu_permissionDays12 = 0;
    double congChu_htDays12 = 0;
    
    double congChu_regularDays34 = 0;
    double congChu_permissionDays34 = 0;
    double congChu_htDays34 = 0;
    
    double congChu_regularDays5plus = 0;
    double congChu_permissionDays5plus = 0;
    double congChu_htDays5plus = 0;
    
    double ngThuong_days12 = 0;
    double ngThuong_days34 = 0;
    double ngThuong_days5plus = 0;
    
    // Process each day
    for (int dayIndex = 0; dayIndex < daysInPeriod.length; dayIndex++) {
      int day = daysInPeriod[dayIndex];
      String dateStr;
      
      if (isPeriodMode && periodStartDate != null && periodEndDate != null) {
        final targetDate = periodStartDate.add(Duration(days: dayIndex));
        if (targetDate.isAfter(periodEndDate)) continue;
        dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      } else {
        dateStr = '$selectedMonth-${day.toString().padLeft(2, '0')}';
      }
      
      final recordList = attendanceData.where(
        (record) => 
          record['MaNV'] == empId && 
          record['Ngay'].toString().split('T')[0] == dateStr
      ).toList();
      
      if (recordList.isEmpty) continue;
      final record = recordList.first;
      
      // Get values from record
      final congThuongChu = record['CongThuongChu'] ?? 'Ro';
      final phanLoai = record['PhanLoai']?.toString() ?? '';
      final ngoaiGioThuong = double.tryParse(record['NgoaiGioThuong']?.toString() ?? '0') ?? 0;
      
      // Process base CongThuongChu value
      final baseCongThuongChu = _extractCongThuongChuBase(congThuongChu.toString());
      
      // Calculate HV, Đêm, CĐ
      double hvValue = 0;
      if (baseCongThuongChu == 'HV') {
        hvValue = 1.0;
      } else if (baseCongThuongChu == '2HV') {
        hvValue = 2.0;
      } else if (baseCongThuongChu == '3HV') {
        hvValue = 3.0;
      }
      tongHV += hvValue;
      
      if (baseCongThuongChu == 'CĐ') {
        tongCD += 1.0;
      }
      
      if (baseCongThuongChu == 'XĐ' || baseCongThuongChu == '2XĐ') {
        tongDem += baseCongThuongChu.startsWith('2') ? 2.0 : 1.0;
      }
      
      // Check if it has +P or +P/2 suffix
      final bool hasFullPermission = congThuongChu.toString().endsWith('+P');
      final bool hasHalfPermission = congThuongChu.toString().endsWith('+P/2');
      
      // Get PhanLoai value for regular days calculation
      double phanLoaiValue = 0;
      if (phanLoai.isNotEmpty) {
        try {
          phanLoaiValue = double.parse(phanLoai);
        } catch (e) {
          print("Error parsing PhanLoai: $e");
        }
      }
      
      // Calculate values for each day based on day group
      if (dayIndex < 15) {
        // Days 1-15
        if (phanLoaiValue > 0) {
          congChu_regularDays12 += phanLoaiValue;
        }
        
        if (baseCongThuongChu == 'P') {
          congChu_permissionDays12 += 1.0;
        } else if (baseCongThuongChu == 'P/2') {
          congChu_permissionDays12 += 0.5;
        }
        
        if (hasFullPermission) {
          congChu_permissionDays12 += 1.0;
        } else if (hasHalfPermission) {
          congChu_permissionDays12 += 0.5;
        }
        
        if (baseCongThuongChu == 'HT') {
          congChu_htDays12 += 1.0;
        }
        
        if (ngoaiGioThuong > 0) {
          ngThuong_days12 += ngoaiGioThuong;
        }
        
      } else if (dayIndex < 25) {
        // Days 16-25
        if (phanLoaiValue > 0) {
          congChu_regularDays34 += phanLoaiValue;
        }
        
        if (baseCongThuongChu == 'P') {
          congChu_permissionDays34 += 1.0;
        } else if (baseCongThuongChu == 'P/2') {
          congChu_permissionDays34 += 0.5;
        }
        
        if (hasFullPermission) {
          congChu_permissionDays34 += 1.0;
        } else if (hasHalfPermission) {
          congChu_permissionDays34 += 0.5;
        }
        
        if (baseCongThuongChu == 'HT') {
          congChu_htDays34 += 1.0;
        }
        
        if (ngoaiGioThuong > 0) {
          ngThuong_days34 += ngoaiGioThuong;
        }
        
      } else {
        // Days 26+
        if (phanLoaiValue > 0) {
          congChu_regularDays5plus += phanLoaiValue;
        }
        
        if (baseCongThuongChu == 'P') {
          congChu_permissionDays5plus += 1.0;
        } else if (baseCongThuongChu == 'P/2') {
          congChu_permissionDays5plus += 0.5;
        }
        
        if (hasFullPermission) {
          congChu_permissionDays5plus += 1.0;
        } else if (hasHalfPermission) {
          congChu_permissionDays5plus += 0.5;
        }
        
        if (baseCongThuongChu == 'HT') {
          congChu_htDays5plus += 1.0;
        }
        
        if (ngoaiGioThuong > 0) {
          ngThuong_days5plus += ngoaiGioThuong;
        }
      }
    }
    
    // Reduce regular days by permission days
    congChu_regularDays12 = congChu_regularDays12 - congChu_permissionDays12;
    if (congChu_regularDays12 < 0) congChu_regularDays12 = 0;
    
    congChu_regularDays34 = congChu_regularDays34 - congChu_permissionDays34;
    if (congChu_regularDays34 < 0) congChu_regularDays34 = 0;
    
    // Calculate totals
    final double congChu_totalPermission = congChu_permissionDays12 + congChu_permissionDays34 + congChu_permissionDays5plus;
    final double congChu_totalRegular = congChu_regularDays12 + congChu_regularDays34 + congChu_regularDays5plus;
    final double congChu_totalHT = congChu_htDays12 + congChu_htDays34 + congChu_htDays5plus;
    final double ngThuong_total = ngThuong_days12 + ngThuong_days34 + ngThuong_days5plus;
    
    return {
      'tuan12': _formatNumberValue(congChu_regularDays12),
      'p12': _formatNumberValue(congChu_permissionDays12),
      'ht12': _formatNumberValue(congChu_htDays12),
      'tuan34': _formatNumberValue(congChu_regularDays34),
      'p34': _formatNumberValue(congChu_permissionDays34),
      'ht34': _formatNumberValue(congChu_htDays34),
      'cong': _formatNumberValue(congChu_totalRegular),
      'phep': _formatNumberValue(congChu_totalPermission),
      'ht': _formatNumberValue(congChu_totalHT),
      'ng_total': _formatNumberValue(ngThuong_total),
      'le': _formatNumberValue(0), // Placeholder
      'hv': _formatNumberValue(tongHV),
      'dem': _formatNumberValue(tongDem),
      'cd': _formatNumberValue(tongCD),
    };
  }
  
  static String? _getAttendanceForDayFromData({
    required String empId,
    required int day,
    required String columnType,
    required List<Map<String, Object?>> attendanceData,
    required String selectedMonth,
    required bool isPeriodMode,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
  }) {
    String dateStr;
    
    if (isPeriodMode && periodStartDate != null && periodEndDate != null) {
      // In period mode, find the date that matches the day number
      DateTime current = periodStartDate;
      DateTime? foundDate;
      
      while (current.isBefore(periodEndDate) || current.isAtSameMomentAs(periodEndDate)) {
        if (current.day == day) {
          foundDate = current;
          break;
        }
        current = current.add(Duration(days: 1));
      }
      
      if (foundDate == null) {
        return columnType == 'CongThuongChu' ? 'Ro' : '0';
      }
      
      dateStr = DateFormat('yyyy-MM-dd').format(foundDate);
    } else {
      // Original logic
      dateStr = '$selectedMonth-${day.toString().padLeft(2, '0')}';
    }
    
    final record = attendanceData.firstWhere(
      (record) => 
        record['MaNV'] == empId && 
        record['Ngay'].toString().split('T')[0] == dateStr,
      orElse: () => <String, Object?>{},
    );
    
    if (record.isEmpty) {
      return columnType == 'CongThuongChu' ? 'Ro' : '0';
    }
    
    return record[columnType]?.toString() ?? (columnType == 'CongThuongChu' ? 'Ro' : '0');
  }
  
  static List<int> _getDaysInPeriodForExcel({
    required String selectedMonth,
    required bool isPeriodMode,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
  }) {
    if (isPeriodMode && periodStartDate != null && periodEndDate != null) {
      List<int> days = [];
      DateTime current = periodStartDate;
      
      while (current.isBefore(periodEndDate) || current.isAtSameMomentAs(periodEndDate)) {
        days.add(current.day);
        current = current.add(Duration(days: 1));
      }
      
      return days;
    } else {
      final parts = selectedMonth.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final daysInMonth = DateTime(year, month + 1, 0).day;
      return List.generate(daysInMonth, (i) => i + 1);
    }
  }
 
 static Future<Map<String, String>> _getStaffNamesForEmployees(List<String> employeeIds) async {
   if (employeeIds.isEmpty) return {};
   
   final dbHelper = DBHelper();
   final placeholders = List.filled(employeeIds.length, '?').join(',');
   final result = await dbHelper.rawQuery(
     'SELECT MaNV, Ho_ten FROM staffbio WHERE MaNV IN ($placeholders)',
     employeeIds,
   );

   // Convert database results to a Map
   final Map<String, String> fetchedNames = {
     for (var row in result) row['MaNV'] as String: row['Ho_ten'] as String
   };

   // Assign "???" to unmatched IDs
   final Map<String, String> staffNames = {
     for (var id in employeeIds) id: fetchedNames[id] ?? "???"
   };

   return staffNames;
 }
 
 static String _extractCongThuongChuBase(String? value) {
   if (value == null) return 'Ro';
   if (value.endsWith('+P')) {
     return value.substring(0, value.length - 2);
   } else if (value.endsWith('+P/2')) {
     return value.substring(0, value.length - 4);
   }
   return value;
 }
 
 static String _formatNumberValue(double value) {
   if (value == value.toInt()) {
     return value.toInt().toString();
   } else {
     return value.toStringAsFixed(1);
   }
 }
 
 static double _parseDouble(String? value) {
   if (value == null || value.isEmpty) return 0.0;
   return double.tryParse(value) ?? 0.0;
 }
 
 static String _createSafeSheetName(String originalName) {
   // Excel sheet names have character limitations
   String safeName = originalName
       .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') // Replace invalid characters
       .substring(0, originalName.length > 31 ? 31 : originalName.length); // Limit to 31 chars
   
   return safeName;
 }
 
 static Future<void> _saveAndShareComprehensiveExcel({
  required Excel excelWorkbook,
  required String selectedMonth,
  required BuildContext context,
  required bool isPeriodMode,
  DateTime? periodStartDate,
  DateTime? periodEndDate,
}) async {
  try {
    // Generate filename
    String fileName;
    if (isPeriodMode && periodStartDate != null && periodEndDate != null) {
      fileName = 'TongHop_TatCaDuAn_${DateFormat('ddMMyyyy').format(periodStartDate)}_${DateFormat('ddMMyyyy').format(periodEndDate)}.xlsx';
    } else {
      final monthFormatted = DateFormat('MMyyyy').format(DateTime.parse('$selectedMonth-01'));
      fileName = 'TongHop_TatCaDuAn_$monthFormatted.xlsx';
    }
    
    // Save the Excel file
    var fileBytes = excelWorkbook.save();
    if (fileBytes != null) {
      // Get the application documents directory (same as other exports)
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      
      // Write the file
      File file = File(path);
      await file.writeAsBytes(fileBytes);
      
      // Share the file (same as other exports)
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Báo cáo tổng hợp tất cả dự án',
      );
      
      _showMessage(context, 'Đã xuất Excel thành công: $fileName', Colors.green);
    } else {
      _showMessage(context, 'Lỗi khi tạo file Excel', Colors.red);
    }
  } catch (e) {
    print('Error saving and sharing Excel: $e');
    _showMessage(context, 'Lỗi khi lưu và chia sẻ file Excel: $e', Colors.red);
  }
}
 
 static void _showMessage(BuildContext context, String message, Color color) {
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       content: Text(message),
       backgroundColor: color,
       duration: Duration(seconds: 3),
     ),
   );
 }
}

// Alternative comprehensive export helper class
class ComprehensiveProjectsExcelExporter {
 static Future<void> exportAllProjectsToComprehensiveExcel({
   required List<String> projectsList,
   required String selectedMonth,
   required BuildContext context,
   DateTime? periodStartDate,
   DateTime? periodEndDate,
   bool isPeriodMode = false,
 }) async {
   try {
     await AllProjectsExcelGenerator.generateComprehensiveExcelReport(
       selectedMonth: selectedMonth,
       context: context,
       periodStartDate: periodStartDate,
       periodEndDate: periodEndDate,
       isPeriodMode: isPeriodMode,
     );
   } catch (e) {
     print('Error in exportAllProjectsToComprehensiveExcel: $e');
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Lỗi khi xuất Excel tổng hợp: $e'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }
 
 static Future<List<String>> getAllProjectsWithComprehensiveData(String selectedMonth) async {
   final dbHelper = DBHelper();
   final projectsWithData = await dbHelper.rawQuery('''
     SELECT DISTINCT BoPhan FROM chamcongcn 
     WHERE strftime('%Y-%m', Ngay) = ?
     ORDER BY BoPhan
   ''', [selectedMonth]);
   
   return projectsWithData.map((p) => p['BoPhan'] as String).toList();
 }
}

// Enhanced Excel formatting utilities
class ExcelFormattingUtilities {
 static void applyHeaderFormatting(Sheet sheet, String cellAddress) {
   var cell = sheet.cell(CellIndex.indexByString(cellAddress));
   // Note: The excel package may have limited formatting options
   // This is a placeholder for potential formatting enhancements
 }
 
 static void applyDataFormatting(Sheet sheet, String cellAddress) {
   var cell = sheet.cell(CellIndex.indexByString(cellAddress));
   // Note: The excel package may have limited formatting options
   // This is a placeholder for potential formatting enhancements
 }
 
 static void setColumnWidth(Sheet sheet, int columnIndex, double width) {
   // Note: Column width setting may not be available in the basic excel package
   // This is a placeholder for potential width setting functionality
 }
}