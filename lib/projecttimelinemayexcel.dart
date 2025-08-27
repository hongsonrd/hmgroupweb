// projecttimelinemayexcel.dart
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'table_models.dart';

class MachineryExcelExporter {
  /// Export records to an Excel file (.xlsx).
  /// Returns the saved file path.
  static Future<String> exportExcel({
    required List<TaskHistoryModel> records,
    required String selectedPeriod, // yyyy-MM
    String subfolderName = 'BaoCao_DuAn',
    String filePrefix = 'machinery_report',
  }) async {
    // Create a new Excel document
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    
    final headers = <String>[
      'UID',
      'TaskID',
      'Ngày',
      'Giờ',
      'Người dùng',
      'Kết quả (raw)',
      'Kết quả (VN)',
      'Chi tiết',
      'Chi tiết 2',
      'Vị trí',
      'Bộ phận',
      'Phân loại',
      'Giải pháp',
      'Hình ảnh',
    ];

    final dfDate = DateFormat('yyyy-MM-dd');

    // Add header row
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
      
      // Optional: Style the header
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '#D3D3D3', // Light gray
      );
    }

    // Add data rows
    for (int rowIndex = 0; rowIndex < records.length; rowIndex++) {
      final r = records[rowIndex];
      final rowData = <String>[
        r.uid ?? '',
        r.taskId ?? '',
        dfDate.format(r.ngay),
        r.gio ?? '',
        r.nguoiDung ?? '',
        r.ketQua ?? '',
        _formatKetQua(r.ketQua),
        r.chiTiet ?? '',
        r.chiTiet2 ?? '',
        r.viTri ?? '',
        r.boPhan ?? '',
        r.phanLoai ?? '',
        r.giaiPhap ?? '',
        r.hinhAnh ?? '',
      ];

      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: colIndex, 
          rowIndex: rowIndex + 1
        ));
        cell.value = rowData[colIndex];
      }
    }

    // Remove the setColumnWidth calls since they don't exist in this version
    // Excel will auto-size columns when opened

    // Get the bytes of the Excel file
    final excelBytes = excel.encode()!;

    // Save to file
    final dir = await getApplicationDocumentsDirectory();
    final reportDir = Directory('${dir.path}/$subfolderName');
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }

    // Filename: YYYYMMDDHHMMSS + baocao + random + .xlsx
    final now = DateTime.now();
    final ts = DateFormat('yyyyMMddHHmmss').format(now);
    final rand = 1000000 + Random().nextInt(9000000);
    final file = File('${reportDir.path}/${ts}baocao$rand.xlsx');
    await file.writeAsBytes(excelBytes, flush: true);
    
    return file.path;
  }

  // === Helpers ===
  static String _formatKetQua(String? ketQua) {
    switch (ketQua) {
      case '✔️':
        return 'Đạt';
      case '❌':
        return 'Không làm';
      case '⚠️':
        return 'Chưa tốt';
      default:
        return ketQua ?? '';
    }
  }

  /// Open a file using OS default apps (desktop platforms).
  static Future<void> openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      } else {
        // On Android/iOS, rely on "Share" to open with external apps.
        print('Open file is not supported on this platform via Process.');
      }
    } catch (e) {
      print('Error opening file: $e');
    }
  }

  /// Open the folder containing the file (desktop platforms).
  static Future<void> openFolder(String folderPath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [folderPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [folderPath]);
      } else {
        print('Open folder is not supported on this platform via Process.');
      }
    } catch (e) {
      print('Error opening folder: $e');
    }
  }
}