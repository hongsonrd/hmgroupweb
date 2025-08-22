// projecttimelinemayexcel.dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'table_models.dart';

class MachineryCsvExporter {
  /// Export records to a UTF-8 CSV (Excel-compatible).
  /// Returns the saved file path.
  static Future<String> exportCsv({
    required List<TaskHistoryModel> records,
    required String selectedPeriod, // yyyy-MM
    String subfolderName = 'BaoCao_DuAn',
    String filePrefix = 'machinery_report',
  }) async {
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
    final sb = StringBuffer();

    // Header row
    sb.writeln(headers.map(_csvEscape).join(','));

    // Data rows
    for (final r in records) {
      final row = <String>[
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
      sb.writeln(row.map(_csvEscape).join(','));
    }

    // Save with UTF-8 BOM to render Vietnamese correctly in Excel on Windows
    final bytes = <int>[0xEF, 0xBB, 0xBF] + utf8.encode(sb.toString());

    final dir = await getApplicationDocumentsDirectory();
    final reportDir = Directory('${dir.path}/$subfolderName');
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }

    // Filename: YYYYMMDDHHMMSS + baocao + random + .csv
    final now = DateTime.now();
    final ts = DateFormat('yyyyMMddHHmmss').format(now);
    final rand = 1000000 + Random().nextInt(9000000);
    final file = File('${reportDir.path}/${ts}baocao$rand.csv');
    await file.writeAsBytes(bytes, flush: true);
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

  /// Wrap in quotes if needed; escape inner quotes by doubling them.
  static String _csvEscape(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    var v = value.replaceAll('"', '""');
    return needsQuotes ? '"$v"' : v;
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
