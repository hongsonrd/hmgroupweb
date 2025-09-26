import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:barcode/barcode.dart';
import 'package:excel/excel.dart' hide Border;
import 'checklist_models.dart';
import 'checklist_preview_screen.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'dart:core';

class ChecklistPreviewService {
  static const Map<String, IconData> _iconMap = {
    'Icons.wallpaper': Icons.wallpaper,
    'Icons.receipt_long': Icons.receipt_long,
    'Icons.blender': Icons.blender,
    'Icons.ad_units': Icons.ad_units,
    'Icons.grid_view': Icons.grid_view,
    'Icons.miscellaneous_services': Icons.miscellaneous_services,
    'Icons.plumbing': Icons.plumbing,
    'Icons.inventory_2': Icons.inventory_2,
    'Icons.countertops': Icons.countertops,
    'Icons.dry': Icons.dry,
    'Icons.soap': Icons.soap,
    'Icons.roofing': Icons.roofing,
    'Icons.view_week': Icons.view_week,
    'Icons.lightbulb': Icons.lightbulb,
    'Icons.label': Icons.label,
    'Icons.delete': Icons.delete,
    'Icons.water_damage': Icons.water_damage,
    'Icons.filter_alt': Icons.filter_alt,
    'Icons.water_drop': Icons.water_drop,
    'Icons.meeting_room': Icons.meeting_room,
    'Icons.shower': Icons.shower,
    'Icons.water_drop_outlined': Icons.water_drop_outlined,
    'Icons.texture': Icons.texture,
    'Icons.airplay': Icons.airplay,
    'Icons.handyman': Icons.handyman,
    'Icons.air': Icons.air,
    'Icons.blur_on': Icons.blur_on,
    'Icons.verified': Icons.verified,
    'Icons.build': Icons.build,
    'Icons.security': Icons.security,
    'Icons.description': Icons.description,
    'Icons.assignment': Icons.assignment,
    'Icons.check_circle': Icons.check_circle,
    'Icons.warning': Icons.warning,
    'Icons.info': Icons.info,
    'Icons.settings': Icons.settings,
    'Icons.home': Icons.home,
    'Icons.work': Icons.work,
    'Icons.cleaning_services': Icons.cleaning_services,
    'Icons.electrical_services': Icons.electrical_services,
    'Icons.schedule': Icons.schedule,
    'Icons.task_alt': Icons.task_alt,
    'Icons.checklist': Icons.checklist,
    'Icons.list_alt': Icons.list_alt,
    'Icons.fact_check': Icons.fact_check,
    'Icons.rule': Icons.rule,
    'Icons.inventory': Icons.inventory,
    'Icons.construction': Icons.construction,
    'Icons.engineering': Icons.engineering,
  };

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
      print('Error loading staff names: $e');
      return {};
    }
  }

  static Future<void> generateAndSharePDF({
    required ChecklistListModel checklist,
    required List<ChecklistItemModel> items,
    required List<ChecklistReportModel> reports,
    required String username,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    bool useBlankDate = false,
    required BuildContext context,
  }) async {
    try {
      final pdf = await _createPDF(
        checklist: checklist,
        items: items,
        reports: reports,
        username: username,
        selectedStartDate: selectedStartDate,
        selectedEndDate: selectedEndDate,
        useBlankDate: useBlankDate,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/checklist_${checklist.checklistId}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Checklist: ${checklist.checklistTitle}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> generateAndShareExcel({
    required ChecklistListModel checklist,
    required List<ChecklistItemModel> items,
    required List<ChecklistReportModel> reports,
    required String username,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    bool useBlankDate = false,
    required BuildContext context,
  }) async {
    try {
      final excel = await _createExcel(
        checklist: checklist,
        items: items,
        reports: reports,
        username: username,
        selectedStartDate: selectedStartDate,
        selectedEndDate: selectedEndDate,
        useBlankDate: useBlankDate,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/checklist_${checklist.checklistId}.xlsx');
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Checklist Excel: ${checklist.checklistTitle}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo Excel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> shareChecklistQr({
    required String checklistId,
    required BuildContext context,
  }) async {
    try {
      final qrPainter = QrPainter(
        data: checklistId,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final image = await qrPainter.toImage(512);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) throw Exception('Không thể tạo hình ảnh QR code');

      final bytes = byteData.buffer.asUint8List();
      if (bytes.isEmpty) throw Exception('Dữ liệu hình ảnh trống');

      final tempDir = await getTemporaryDirectory();
      final fileName = 'qr_checklist_${checklistId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsBytes(bytes);
      
      if (!await file.exists()) throw Exception('Không thể tạo file');

      if (context.mounted) {
        _showQrSharingOptions(context, file, checklistId);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo mã QR: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static void showChecklistPreview({
  required BuildContext context,
  required ChecklistListModel checklist,
  required List<ChecklistItemModel> items,
  required List<ChecklistReportModel> reports,
  DateTime? selectedStartDate,
  DateTime? selectedEndDate,
  bool useBlankDate = false,
  required String username,
}) {
  showDialog(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: ChecklistPreviewScreen(
        checklist: checklist,
        items: items,
        reports: reports,
        selectedStartDate: selectedStartDate,
        selectedEndDate: selectedEndDate,
        useBlankDate: useBlankDate,
        iconMap: _iconMap,
        onGeneratePDF: () {
          Navigator.pop(context);
          generateAndSharePDF(
            checklist: checklist,
            items: items,
            reports: reports,
            username: username,
            selectedStartDate: selectedStartDate,
            selectedEndDate: selectedEndDate,
            useBlankDate: useBlankDate,
            context: context,
          );
        },
        onGenerateExcel: () {
          Navigator.pop(context);
          generateAndShareExcel(
            checklist: checklist,
            items: items,
            reports: reports,
            username: username,
            selectedStartDate: selectedStartDate,
            selectedEndDate: selectedEndDate,
            useBlankDate: useBlankDate,
            context: context,
          );
        },
      ),
    ),
  );
}

  static void _showQrSharingOptions(BuildContext context, File qrFile, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code, color: Colors.purple[600]),
            const SizedBox(width: 8),
            const Text('Mã QR Checklist'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              height: 180,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.file(
                qrFile, 
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red[400]),
                        const Text('Lỗi hiển thị QR', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ID: $id',
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w500,
                  color: Colors.purple[700],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _shareQrFile(qrFile, id, context);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Chia sẻ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _saveQrToAppFolder(qrFile, id, context);
            },
            icon: const Icon(Icons.save_alt, size: 16),
            label: const Text('Lưu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _shareQrFile(File qrFile, String id, BuildContext context) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(qrFile.path)],
        text: 'Mã QR Checklist: $id',
        subject: 'Checklist QR Code - $id',
      );
      
      if (result.status == ShareResultStatus.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chia sẻ mã QR thành công'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chia sẻ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<void> _saveQrToAppFolder(File qrFile, String id, BuildContext context) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedFile = File('${appDocDir.path}/QR_Checklist_${id}_$timestamp.png');
      
      await qrFile.copy(savedFile.path);
      
      if (await savedFile.exists() && context.mounted) {
        final fileSize = await savedFile.length();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu QR code (${(fileSize / 1024).toStringAsFixed(1)} KB)\nTại: ${savedFile.path}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('File không được tạo');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<Excel> _createExcel({
    required ChecklistListModel checklist,
    required List<ChecklistItemModel> items,
    required List<ChecklistReportModel> reports,
    required String username,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    bool useBlankDate = false,
  }) async {
    final staffNameMap = await _getStaffNameMap();
    final excel = Excel.createExcel();
    final sheet = excel['Checklist'];
    
    List<DateTime> dateRange = [];
    if (checklist.checklistDateType == 'Multi') {
      if (useBlankDate) {
        dateRange = [];
      } else if (selectedStartDate != null && selectedEndDate != null) {
        for (DateTime d = selectedStartDate!; d.isBefore(selectedEndDate!.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
          dateRange.add(d);
        }
      } else if (selectedStartDate != null) {
        dateRange = [selectedStartDate!];
      }
    } else {
      dateRange = selectedStartDate != null ? [selectedStartDate!] : [DateTime.now()];
    }

    List<String> timeColumns = [];
    if (checklist.checklistTimeType == 'PeriodicOut' && checklist.checklistPeriodicStart != null && checklist.checklistPeriodicEnd != null && checklist.checklistPeriodInterval != null) {
      timeColumns = _generatePeriodicTimeColumns(checklist.checklistPeriodicStart!, checklist.checklistPeriodicEnd!, checklist.checklistPeriodInterval!);
    }

    int row = 0;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = checklist.checklistTitle ?? '';
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row));
    row++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'Dự án: ${checklist.projectName ?? ''}';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = 'Khu vực: ${checklist.areaName ?? ''}';
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = 'Tầng: ${checklist.floorName ?? ''}';
    row += 2;

    List<String> headers = [];
    if (checklist.checklistDateType == 'Multi' && dateRange.isNotEmpty) {
      headers.add('Ngày');
    }
    if (checklist.checklistTimeType == 'InOut') {
      headers.addAll(['Giờ vào', 'Giờ ra']);
    } else if (checklist.checklistTimeType == 'PeriodicOut') {
      headers.addAll(timeColumns);
    } else {
      headers.add('Giờ');
    }
    for (final it in items) {
      headers.add(it.itemName ?? it.itemId);
    }
    headers.addAll(['Nhân viên', 'Giám sát']);

    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).value = headers[i];
    }
    row++;

    final relevant = reports.where((r) => r.reportType == 'staff' || r.reportType == 'sup').toList();
    
    if (dateRange.isEmpty || useBlankDate) {
      for (int i = 0; i < 15; i++) {
        List<String> rowData = [];
        if (checklist.checklistDateType == 'Multi' && !useBlankDate) {
          rowData.add('');
        }
        if (checklist.checklistTimeType == 'InOut') {
          rowData.addAll(['', '']);
        } else if (checklist.checklistTimeType == 'PeriodicOut') {
          rowData.addAll(List.filled(timeColumns.length, ''));
        } else {
          rowData.add('');
        }
        for (final _ in items) {
          rowData.add('');
        }
        rowData.addAll(['', '']);
        
        for (int j = 0; j < rowData.length; j++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row)).value = rowData[j];
        }
        row++;
      }
    } else {
      for (final date in dateRange) {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final dayReports = relevant.where((r) {
          try {
            String d;
            if (r.reportDate.contains('T')) {
              d = r.reportDate.split('T')[0];
            } else if (r.reportDate.contains(' ')) {
              d = r.reportDate.split(' ')[0];
            } else {
              d = r.reportDate;
            }
            return d == dateStr;
          } catch (_) {
            return false;
          }
        }).toList();

        if (checklist.checklistTimeType == 'InOut') {
          final Map<String, Map<String, ChecklistReportModel>> byTime = {};
          for (final r in dayReports) {
            final k = r.reportTime;
            byTime.putIfAbsent(k, () => {});
            if (r.reportInOut != null) {
              byTime[k]![r.reportInOut!] = r;
            }
          }
          
          final times = byTime.keys.toList();
          if (times.isEmpty) {
            times.add('');
          } else {
            times.sort((a, b) {
              if (a.isEmpty) return 1;
              if (b.isEmpty) return -1;
              try {
                final timeA = TimeOfDay(hour: int.parse(a.split(':')[0]), minute: int.parse(a.split(':')[1]));
                final timeB = TimeOfDay(hour: int.parse(b.split(':')[0]), minute: int.parse(b.split(':')[1]));
                final minutesA = timeA.hour * 60 + timeA.minute;
                final minutesB = timeB.hour * 60 + timeB.minute;
                return minutesA.compareTo(minutesB);
              } catch (_) {
                return a.compareTo(b);
              }
            });
          }
          
          for (final t in times) {
            final inR = byTime[t]?['In'];
            final outR = byTime[t]?['Out'];
            List<String> rowData = [];
            if (checklist.checklistDateType == 'Multi') {
              rowData.add('${date.day}/${date.month}');
            }
            rowData.add(inR?.reportTime ?? '');
            rowData.add(outR?.reportTime ?? '');
            
            for (final it in items) {
              String v = '';
              if (checklist.checklistCompletionType == 'State') {
                ChecklistReportModel? sp;
                ChecklistReportModel? s;
                for (final r in [inR, outR]) {
                  if (r?.reportType == 'sup' && (r?.reportTaskList?.contains(it.itemId) ?? false) && sp == null) {
                    sp = r;
                  }
                  if (r?.reportType == 'staff' && (r?.reportTaskList?.contains(it.itemId) ?? false) && s == null) {
                    s = r;
                  }
                }
                
                if (sp != null) {
                  v = 'O';
                } else if (s != null) {
                  v = s.reportNote ?? '';
                }
              } else {
                bool supHas = false;
                bool staffHas = false;
                for (final r in [inR, outR]) {
                  if (r?.reportType == 'sup' && (r?.reportTaskList?.contains(it.itemId) ?? false)) {
                    supHas = true;
                  }
                  if (r?.reportType == 'staff' && (r?.reportTaskList?.contains(it.itemId) ?? false)) {
                    staffHas = true;
                  }
                }
                
                if (supHas) {
                  v = 'O';
                } else if (staffHas) {
                  v = 'X';
                }
              }
              rowData.add(v);
            }
            
            ChecklistReportModel? s;
            ChecklistReportModel? sp;
            for (final r in [inR, outR]) {
              if (r?.reportType == 'staff' && s == null) s = r;
              if (r?.reportType == 'sup' && sp == null) sp = r;
            }
            
            final staffName = s?.userId != null ? (staffNameMap[s!.userId!.toUpperCase()] ?? s.userId!) : '';
            final supName = sp?.userId != null ? (staffNameMap[sp!.userId!.toUpperCase()] ?? sp.userId!) : '';
            
            rowData.add(staffName);
            rowData.add(supName);
            
            for (int j = 0; j < rowData.length; j++) {
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row)).value = rowData[j];
            }
            row++;
          }
        } else {
          final times = dayReports.map((r) => r.reportTime).toSet().toList();
          if (times.isEmpty) {
            times.add('');
          } else {
            times.sort((a, b) {
              if (a.isEmpty) return 1;
              if (b.isEmpty) return -1;
              try {
                final timeA = TimeOfDay(hour: int.parse(a.split(':')[0]), minute: int.parse(a.split(':')[1]));
                final timeB = TimeOfDay(hour: int.parse(b.split(':')[0]), minute: int.parse(b.split(':')[1]));
                final minutesA = timeA.hour * 60 + timeA.minute;
                final minutesB = timeB.hour * 60 + timeB.minute;
                return minutesA.compareTo(minutesB);
              } catch (_) {
                return a.compareTo(b);
              }
            });
          }
          
          for (final t in times) {
            final timeReports = dayReports.where((r) => r.reportTime == t).toList();
            List<String> rowData = [];
            
            if (checklist.checklistDateType == 'Multi') {
              rowData.add('${date.day}/${date.month}');
            }
            
            if (checklist.checklistTimeType == 'PeriodicOut') {
              for (final per in timeColumns) {
                final supHas = timeReports.any((r) => r.reportTime == per && r.reportType == 'sup');
                final staffHas = timeReports.any((r) => r.reportTime == per && r.reportType == 'staff');
                
                if (supHas) {
                  rowData.add('O');
                } else if (staffHas) {
                  rowData.add('X');
                } else {
                  rowData.add('');
                }
              }
            } else {
              rowData.add(t);
            }
            
            for (final it in items) {
              String v = '';
              if (checklist.checklistCompletionType == 'State') {
                final sp = timeReports.where((r) => r.reportType == 'sup' && (r.reportTaskList?.contains(it.itemId) ?? false)).firstOrNull;
                final s = timeReports.where((r) => r.reportType == 'staff' && (r.reportTaskList?.contains(it.itemId) ?? false)).firstOrNull;
                
                if (sp != null) {
                  v = 'O';
                } else if (s != null) {
                  v = s.reportNote ?? '';
                }
              } else {
                final supHas = timeReports.any((r) => r.reportType == 'sup' && (r.reportTaskList?.contains(it.itemId) ?? false));
                final staffHas = timeReports.any((r) => r.reportType == 'staff' && (r.reportTaskList?.contains(it.itemId) ?? false));
                
                if (supHas) {
                  v = 'O';
                } else if (staffHas) {
                  v = 'X';
                }
              }
              rowData.add(v);
            }
            
            final s = timeReports.where((r) => r.reportType == 'staff').firstOrNull;
            final sp = timeReports.where((r) => r.reportType == 'sup').firstOrNull;
            
            final staffName = s?.userId != null ? (staffNameMap[s!.userId!.toUpperCase()] ?? s.userId!) : '';
            final supName = sp?.userId != null ? (staffNameMap[sp!.userId!.toUpperCase()] ?? sp.userId!) : '';
            
            rowData.add(staffName);
            rowData.add(supName);
            
            for (int j = 0; j < rowData.length; j++) {
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row)).value = rowData[j];
            }
            row++;
          }
        }
      }
    }

    row += 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'Tạo bởi: $username - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    row++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'ID: ${checklist.checklistId}';

    return excel;
  }

  static Future<pw.Document> _createPDF({
  required ChecklistListModel checklist,
  required List<ChecklistItemModel> items,
  required List<ChecklistReportModel> reports,
  required String username,
  DateTime? selectedStartDate,
  DateTime? selectedEndDate,
  bool useBlankDate = false,
}) async {
  final staffNameMap = await _getStaffNameMap();
  final pdf = pw.Document();
  final font = await PdfGoogleFonts.robotoRegular();
  final boldFont = await PdfGoogleFonts.robotoBold();
  
  final useHorizontal = items.length > 6;
  final pageFormat = useHorizontal ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
  final headerFontSize = useHorizontal ? 9.0 : 8.0;
  final cellFontSize = useHorizontal ? 8.0 : 7.0;
  final itemNameFontSize = useHorizontal ? 7.0 : 6.0;
  
  pw.ImageProvider? logoMain;
  pw.ImageProvider? logoSecondary;
  if (checklist.logoMain != null && checklist.logoMain!.isNotEmpty) {
    try {
      final b = await rootBundle.load(checklist.logoMain!);
      logoMain = pw.MemoryImage(b.buffer.asUint8List());
    } catch (_) {}
  }
  if (checklist.logoSecondary != null && checklist.logoSecondary!.isNotEmpty) {
    try {
      final b = await rootBundle.load(checklist.logoSecondary!);
      logoSecondary = pw.MemoryImage(b.buffer.asUint8List());
    } catch (_) {}
  }

  final Map<String, pw.MemoryImage> cache = {};
  Future<pw.MemoryImage?> loadItemImg(String? f) async {
    if (f== null || f.isEmpty) return null;
    final path = 'assets/checklist/$f';
    if (cache.containsKey(path)) return cache[path];
    try {
      final b = await rootBundle.load(path);
      final img = pw.MemoryImage(b.buffer.asUint8List());
      cache[path] = img;
      return img;
    } catch (_) {
      return null;
    }
  }

  List<DateTime> dateRange = [];
  if (checklist.checklistDateType == 'Multi') {
    if (useBlankDate) {
      dateRange = [];
    } else if (selectedStartDate != null && selectedEndDate != null) {
      for (DateTime d = selectedStartDate!; d.isBefore(selectedEndDate!.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
        dateRange.add(d);
      }
    } else if (selectedStartDate != null) {
      dateRange = [selectedStartDate!];
    }
  } else {
    dateRange = selectedStartDate != null ? [selectedStartDate!] : [DateTime.now()];
  }

  List<String> timeColumns = [];
  if (checklist.checklistTimeType == 'PeriodicOut' && checklist.checklistPeriodicStart != null && checklist.checklistPeriodicEnd != null && checklist.checklistPeriodInterval != null) {
    timeColumns = _generatePeriodicTimeColumns(checklist.checklistPeriodicStart!, checklist.checklistPeriodicEnd!, checklist.checklistPeriodInterval!);
  }

  List<List<String>> tableData = [];
  List<String> headers = [];
  if (checklist.checklistDateType == 'Multi' && dateRange.isNotEmpty) {
    headers.add('Ngày');
  }
  if (checklist.checklistTimeType == 'InOut') {
    headers.addAll(['Giờ vào', 'Giờ ra']);
  } else if (checklist.checklistTimeType == 'PeriodicOut') {
    headers.addAll(timeColumns);
  } else {
    headers.add('Giờ');
  }
  for (final it in items) {
    headers.add(it.itemName ?? it.itemId);
  }
  headers.addAll(['Nhân viên', 'Giám sát']);
  tableData.add(headers);

  final relevant = reports.where((r) => r.reportType == 'staff' || r.reportType == 'sup').toList();
  if (dateRange.isEmpty || useBlankDate) {
    for (int i = 0; i < 15; i++) {
      List<String> row = [];
      if (checklist.checklistDateType == 'Multi' && !useBlankDate) {
        row.add('');
      }
      if (checklist.checklistTimeType == 'InOut') {
        row.addAll(['', '']);
      } else if (checklist.checklistTimeType == 'PeriodicOut') {
        row.addAll(List.filled(timeColumns.length, ''));
      } else {
        row.add('');
      }
      for (final _ in items) {
        row.add('');
      }
      row.addAll(['', '']);
      tableData.add(row);
    }
  } else {
    for (final date in dateRange) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dayReports = relevant.where((r) {
        try {
          String d;
          if (r.reportDate.contains('T')) {
            d = r.reportDate.split('T')[0];
          } else if (r.reportDate.contains(' ')) {
            d = r.reportDate.split(' ')[0];
          } else {
            d = r.reportDate;
          }
          return d == dateStr;
        } catch (_) {
          return false;
        }
      }).toList();

      if (checklist.checklistTimeType == 'InOut') {
        final Map<String, Map<String, ChecklistReportModel>> byTime = {};
        for (final r in dayReports) {
          final k = r.reportTime;
          byTime.putIfAbsent(k, () => {});
          if (r.reportInOut != null) {
            byTime[k]![r.reportInOut!] = r;
          }
        }
        
        final times = byTime.keys.toList();
        if (times.isEmpty) {
          times.add('');
        } else {
          times.sort((a, b) {
            if (a.isEmpty) return 1;
            if (b.isEmpty) return -1;
            try {
              final timeA = TimeOfDay(
                hour: int.parse(a.split(':')[0]), 
                minute: int.parse(a.split(':')[1])
              );
              final timeB = TimeOfDay(
                hour: int.parse(b.split(':')[0]), 
                minute: int.parse(b.split(':')[1])
              );
              final minutesA = timeA.hour * 60 + timeA.minute;
              final minutesB = timeB.hour * 60 + timeB.minute;
              return minutesA.compareTo(minutesB);
            } catch (_) {
              return a.compareTo(b);
            }
          });
        }
        
        for (final t in times) {
          final inR = byTime[t]?['In'];
          final outR = byTime[t]?['Out'];
          List<String> row = [];
          if (checklist.checklistDateType == 'Multi') {
            row.add('${date.day}/${date.month}');
          }
          row.add(inR?.reportTime ?? '');
          row.add(outR?.reportTime ?? '');
          
          for (final it in items) {
            String v = '';
            if (checklist.checklistCompletionType == 'State') {
              ChecklistReportModel? sp;
              ChecklistReportModel? s;
              for (final r in [inR, outR]) {
                if (r?.reportType == 'sup' && (r?.reportTaskList?.contains(it.itemId) ?? false) && sp == null) {
                  sp = r;
                }
                if (r?.reportType == 'staff' && (r?.reportTaskList?.contains(it.itemId) ?? false) && s == null) {
                  s = r;
                }
              }
              
              if (sp != null) {
                v = 'O';
              } else if (s != null) {
                v = s.reportNote ?? '';
              }
            } else {
              bool supHas = false;
              bool staffHas = false;
              for (final r in [inR, outR]) {
                if (r?.reportType == 'sup' && (r?.reportTaskList?.contains(it.itemId) ?? false)) {
                  supHas = true;
                }
                if (r?.reportType == 'staff' && (r?.reportTaskList?.contains(it.itemId) ?? false)) {
                  staffHas = true;
                }
              }
              
              if (supHas) {
                v = 'O';
              } else if (staffHas) {
                v = 'X';
              }
            }
            row.add(v);
          }
          
          ChecklistReportModel? s;
          ChecklistReportModel? sp;
          for (final r in [inR, outR]) {
            if (r?.reportType == 'staff' && s == null) s = r;
            if (r?.reportType == 'sup' && sp == null) sp = r;
          }
          
          final staffName = s?.userId != null ? (staffNameMap[s!.userId!.toUpperCase()] ?? s.userId!) : '';
          final supName = sp?.userId != null ? (staffNameMap[sp!.userId!.toUpperCase()] ?? sp.userId!) : '';
          
          row.add(staffName);
          row.add(supName);
          tableData.add(row);
        }
      } else {
        final times = dayReports.map((r) => r.reportTime).toSet().toList();
        if (times.isEmpty) {
          times.add('');
        } else {
          times.sort((a, b) {
            if (a.isEmpty) return 1;
            if (b.isEmpty) return -1;
            try {
              final timeA = TimeOfDay(
                hour: int.parse(a.split(':')[0]), 
                minute: int.parse(a.split(':')[1])
              );
              final timeB = TimeOfDay(
                hour: int.parse(b.split(':')[0]), 
                minute: int.parse(b.split(':')[1])
              );
              final minutesA = timeA.hour * 60 + timeA.minute;
              final minutesB = timeB.hour * 60 + timeB.minute;
              return minutesA.compareTo(minutesB);
            } catch (_) {
              return a.compareTo(b); 
            }
          });
        }
        
        for (final t in times) {
          final timeReports = dayReports.where((r) => r.reportTime == t).toList();
          List<String> row = [];
          
          if (checklist.checklistDateType == 'Multi') {
            row.add('${date.day}/${date.month}');
          }
          
          if (checklist.checklistTimeType == 'PeriodicOut') {
            for (final per in timeColumns) {
              final supHas = timeReports.any((r) => r.reportTime == per && r.reportType == 'sup');
              final staffHas = timeReports.any((r) => r.reportTime == per && r.reportType == 'staff');
              
              if (supHas) {
                row.add('O');
              } else if (staffHas) {
                row.add('X');
              } else {
                row.add('');
              }
            }
          } else {
            row.add(t);
          }
          
          for (final it in items) {
            String v = '';
            if (checklist.checklistCompletionType == 'State') {
              final sp = timeReports.where((r) => r.reportType == 'sup' && (r.reportTaskList?.contains(it.itemId) ?? false)).firstOrNull;
              final s = timeReports.where((r) => r.reportType == 'staff' && (r.reportTaskList?.contains(it.itemId) ?? false)).firstOrNull;
              
              if (sp != null) {
                v = 'O';
              } else if (s != null) {
                v = s.reportNote ?? '';
              }
            } else {
              final supHas = timeReports.any((r) => r.reportType == 'sup' && (r.reportTaskList?.contains(it.itemId) ?? false));
              final staffHas = timeReports.any((r) => r.reportType == 'staff' && (r.reportTaskList?.contains(it.itemId) ?? false));
              
              if (supHas) {
                v = 'O';
              } else if (staffHas) {
                v = 'X';
              }
            }
            row.add(v);
          }
          
          final s = timeReports.where((r) => r.reportType == 'staff').firstOrNull;
          final sp = timeReports.where((r) => r.reportType == 'sup').firstOrNull;
          
          final staffName = s?.userId != null ? (staffNameMap[s!.userId!.toUpperCase()] ?? s.userId!) : '';
          final supName = sp?.userId != null ? (staffNameMap[sp!.userId!.toUpperCase()] ?? sp.userId!) : '';
          
          row.add(staffName);
          row.add(supName);
          tableData.add(row);
        }
      }
    }
  }

  pw.Widget header = pw.Column(children: [
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      logoMain != null ? pw.Container(width: 80, height: 60, child: pw.Image(logoMain!)) : pw.Container(width: 80, height: 60),
      pw.Expanded(child: pw.Column(children: [
        pw.Text(checklist.checklistTitle ?? '', style: pw.TextStyle(font: boldFont, fontSize: 16), textAlign: pw.TextAlign.center),
        if (checklist.checklistPretext != null && checklist.checklistPretext!.isNotEmpty)
          pw.Text(checklist.checklistPretext!, style: pw.TextStyle(font: font, fontSize: 7), textAlign: pw.TextAlign.center)
      ])),
      logoSecondary != null ? pw.Container(width: 80, height: 60, child: pw.Image(logoSecondary!)) : pw.Container(width: 80, height: 60),
    ]),
    pw.SizedBox(height: 10),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Dự án: ${checklist.projectName ?? ''}', style: pw.TextStyle(font: boldFont, fontSize: cellFontSize+1)),
      pw.Text('Khu vực: ${checklist.areaName ?? ''}', style: pw.TextStyle(font: font, fontSize: cellFontSize)),
      pw.Text('Tầng: ${checklist.floorName ?? ''}', style: pw.TextStyle(font: font, fontSize: cellFontSize)),
    ]),
  ]);

  final timeColumns1 = checklist.checklistDateType == 'Multi' && dateRange.isNotEmpty ? 1 : 0;
  final timeColumns2 = checklist.checklistTimeType == 'InOut' ? 2 : (checklist.checklistTimeType == 'PeriodicOut' ? timeColumns.length : 1);
  final staffColumns = 2;
  final itemColumns = items.length;
  
  final timeWidth = (timeColumns1 + timeColumns2) * 1.1;
  final staffWidth = staffColumns * 1.3;
  final itemWidth = itemColumns * 0.9;
  final totalWidth = timeWidth + staffWidth + itemWidth;
  
  final timeColWidth = timeWidth / totalWidth / (timeColumns1 + timeColumns2);
  final itemColWidth = itemWidth / totalWidth / itemColumns;
  final staffColWidth = staffWidth / totalWidth / staffColumns;

  Map<int, pw.TableColumnWidth> columnWidths = {};
  int colIndex = 0;
  
  if (checklist.checklistDateType == 'Multi' && dateRange.isNotEmpty) {
    columnWidths[colIndex] = pw.FractionColumnWidth(timeColWidth);
    colIndex++;
  }
  
  if (checklist.checklistTimeType == 'InOut') {
    columnWidths[colIndex] = pw.FractionColumnWidth(timeColWidth);
    columnWidths[colIndex + 1] = pw.FractionColumnWidth(timeColWidth);
    colIndex += 2;
  } else if (checklist.checklistTimeType == 'PeriodicOut') {
    for (int i = 0; i < timeColumns.length; i++) {
      columnWidths[colIndex + i] = pw.FractionColumnWidth(timeColWidth);
    }
    colIndex += timeColumns.length;
  } else {
    columnWidths[colIndex] = pw.FractionColumnWidth(timeColWidth);
    colIndex++;
  }
  
  for (int i = 0; i < items.length; i++) {
    columnWidths[colIndex + i] = pw.FractionColumnWidth(itemColWidth);
  }
  colIndex += items.length;
  
  columnWidths[colIndex] = pw.FractionColumnWidth(staffColWidth);
  columnWidths[colIndex + 1] = pw.FractionColumnWidth(staffColWidth);

  List<pw.Widget> headerCells = [];
  if (checklist.checklistDateType == 'Multi' && dateRange.isNotEmpty) {
    headerCells.add(_pdfHeaderCell(pw.Text('Ngày', style: pw.TextStyle(font: boldFont, fontSize: headerFontSize))));
  }
  if (checklist.checklistTimeType == 'InOut') {
    headerCells.addAll([
      _pdfHeaderCell(pw.Text('Giờ vào', style: pw.TextStyle(font: boldFont, fontSize: headerFontSize))),
      _pdfHeaderCell(pw.Text('Giờ ra', style: pw.TextStyle(font: boldFont, fontSize: headerFontSize)))
    ]);
  } else if (checklist.checklistTimeType == 'PeriodicOut') {
    headerCells.addAll(timeColumns.map((t) => _pdfHeaderCell(pw.Text(t, style: pw.TextStyle(font: boldFont, fontSize: headerFontSize)))));
  } else {
    headerCells.add(_pdfHeaderCell(pw.Text('Giờ', style: pw.TextStyle(font: boldFont, fontSize: headerFontSize))));
  }
  for (final it in items) {
    final img = await loadItemImg(it.itemImage);
    headerCells.add(_pdfHeaderCell(pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
      if (img != null) pw.Container(width: 12, height: 12, child: pw.Image(img, fit: pw.BoxFit.cover)),
      pw.SizedBox(height: 2),
      pw.Text(it.itemName ?? it.itemId, style: pw.TextStyle(font: boldFont, fontSize: itemNameFontSize), textAlign: pw.TextAlign.center, maxLines: 2),
    ])));
  }
  headerCells.addAll([
    _pdfHeaderCell(pw.Text('Nhân viên', style: pw.TextStyle(font: boldFont, fontSize: headerFontSize))),
    _pdfHeaderCell(pw.Text('Giám sát', style: pw.TextStyle(font: boldFont, fontSize: headerFontSize)))
  ]);

  pw.Widget table = pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: columnWidths,
    children: [
      pw.TableRow(children: headerCells.map((w) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: w)).toList()),
      ...tableData.skip(1).map((row) => pw.TableRow(children: row.map((cell) => pw.Padding(
        padding: const pw.EdgeInsets.all(3), 
        child: pw.Text(
          cell, 
          style: pw.TextStyle(
            font: font, 
            fontSize: cellFontSize, 
            fontWeight: (cell == 'X' || cell == 'O') ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: cell == 'O' ? PdfColors.red700 : (cell == 'X' ? PdfColors.green700 : PdfColors.black)
          ), 
          textAlign: pw.TextAlign.center
        )
      )).toList())),
    ]
  );

  pw.Widget footer = pw.Column(children: [
    if (checklist.checklistSubtext != null && checklist.checklistSubtext!.isNotEmpty)
      pw.Text(checklist.checklistSubtext!, style: pw.TextStyle(font: font, fontSize: 7), textAlign: pw.TextAlign.center),
    pw.SizedBox(height: 10),
    pw.Text('Tạo bởi: $username - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: pw.TextStyle(font: font, fontSize: 3), textAlign: pw.TextAlign.center),
    pw.SizedBox(height: 12),
    pw.Center(child: pw.BarcodeWidget(barcode: Barcode.qrCode(), data: checklist.checklistId, width: 35, height: 35, drawText: false)),
    pw.SizedBox(height: 4),
    pw.Text('ID: ${checklist.checklistId}', style: pw.TextStyle(font: font, fontSize: 6), textAlign: pw.TextAlign.center),
  ]);

  pdf.addPage(pw.MultiPage(pageFormat: pageFormat, build: (_) => [header, pw.SizedBox(height: 20), table, pw.SizedBox(height: 20), footer]));
  return pdf;
}

  static pw.Widget _pdfHeaderCell(pw.Widget child) => pw.Container(color: PdfColors.grey200, padding: const pw.EdgeInsets.all(4), alignment: pw.Alignment.center, child: child);

  static List<String> _generatePeriodicTimeColumns(String start, String end, int interval) {
    List<String> cols = [];
    final s = TimeOfDay(hour: int.parse(start.split(':')[0]), minute: int.parse(start.split(':')[1]));
    final e = TimeOfDay(hour: int.parse(end.split(':')[0]), minute: int.parse(end.split(':')[1]));
    int cur = s.hour * 60 + s.minute;
    final endMin = e.hour * 60 + e.minute;
    while (cur <= endMin) {
      final h = cur ~/ 60;
      final m = cur % 60;
      cols.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      cur += interval;
    }
    return cols;
  }
}