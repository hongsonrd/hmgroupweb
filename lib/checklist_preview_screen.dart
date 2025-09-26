import 'package:flutter/material.dart';
import 'checklist_models.dart';
import 'db_helper.dart';
import 'table_models.dart';

class ChecklistPreviewScreen extends StatelessWidget {
  final ChecklistListModel checklist;
  final List<ChecklistItemModel> items;
  final List<ChecklistReportModel> reports;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final bool useBlankDate;
  final Map<String, IconData> iconMap;
  final VoidCallback onGeneratePDF;
  final VoidCallback onGenerateExcel;

  const ChecklistPreviewScreen({
    Key? key,
    required this.checklist,
    required this.items,
    required this.reports,
    this.selectedStartDate,
    this.selectedEndDate,
    required this.useBlankDate,
    required this.iconMap,
    required this.onGeneratePDF,
    required this.onGenerateExcel,
  }) : super(key: key);

  Future<Map<String, String>> _getStaffNameMap() async {
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

  Widget _thumbFor(BuildContext context, ChecklistItemModel item, {double size = 18}) {
    final has = (item.itemImage != null && item.itemImage!.isNotEmpty);
    final path = 'assets/checklist/${item.itemImage ?? ''}';
    final child = has ? Image.asset(path, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
      return Icon(iconMap[item.itemIcon ?? ''] ?? Icons.help_outline, size: size, color: Colors.purple[600]);
    }) : Icon(iconMap[item.itemIcon ?? ''] ?? Icons.help_outline, size: size, color: Colors.purple[600]);
    return ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(width: size, height: size, child: child));
  }

  List<String> _generatePeriodicTimeColumns(String start, String end, int interval) {
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

  List<String> _sortTimes(List<String> times) {
    if (times.isEmpty) {
      return [''];
    }
    
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
    
    return times;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getStaffNameMap(),
      builder: (context, snapshot) {
        final staffNameMap = snapshot.data ?? {};
        final isMobile = MediaQuery.of(context).size.width < 600;
        
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Xem trước Checklist'),
            backgroundColor: Colors.purple[600],
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.table_view),
                onPressed: onGenerateExcel,
                tooltip: 'Tạo Excel',
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: onGeneratePDF,
                tooltip: 'Tạo PDF',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                _buildPreviewHeader(isMobile),
                const SizedBox(height: 20),
                _buildPreviewTable(context, isMobile, staffNameMap),
                const SizedBox(height: 20),
                _buildDebugInfo(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebugInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Số báo cáo: ${reports.length}',style: TextStyle(fontSize: 5),),
          Text('Ngày bắt đầu: ${selectedStartDate?.toString() ?? 'Không có'}',style: TextStyle(fontSize: 5),),
          Text('Ngày kết thúc: ${selectedEndDate?.toString() ?? 'Không có'}',style: TextStyle(fontSize: 5),),
          Text('Dùng ngày trống: $useBlankDate',style: TextStyle(fontSize: 5),),
          Text('Checklist ID: ${checklist.checklistId}',style: TextStyle(fontSize: 5),),
          Text('Loại thời gian: ${checklist.checklistTimeType}',style: TextStyle(fontSize: 5),),
          Text('Loại hoàn thành: ${checklist.checklistCompletionType}',style: TextStyle(fontSize: 5),),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: checklist.logoMain != null && checklist.logoMain!.isNotEmpty
                    ? Image.asset(checklist.logoMain!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('LOGO', style: TextStyle(fontSize: 10))))
                    : const Center(child: Text('LOGO', style: TextStyle(fontSize: 10))),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(checklist.checklistTitle ?? '', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    if (checklist.checklistPretext != null && checklist.checklistPretext!.isNotEmpty)
                      Text(checklist.checklistPretext!, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)
                  ],
                ),
              ),
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: checklist.logoSecondary != null && checklist.logoSecondary!.isNotEmpty
                    ? Image.asset(checklist.logoSecondary!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('LOGO2', style: TextStyle(fontSize: 10))))
                    : const Center(child: Text('LOGO2', style: TextStyle(fontSize: 10))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Dự án: ${checklist.projectName ?? ''}', style: const TextStyle(fontSize: 12)),
              Text('Khu vực: ${checklist.areaName ?? ''}', style: const TextStyle(fontSize: 12)),
              Text('Tầng: ${checklist.floorName ?? ''}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable(BuildContext context, bool isMobile, Map<String, String> staffNameMap) {
    List<DateTime> dateRange = [];
    if (checklist.checklistDateType == 'Multi') {
      if (!useBlankDate && selectedStartDate != null && selectedEndDate != null) {
        for (DateTime d = selectedStartDate!; d.isBefore(selectedEndDate!.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
          dateRange.add(d);
        }
      } else if (!useBlankDate && selectedStartDate != null) {
        dateRange = [selectedStartDate!];
      }
    } else {
      dateRange = !useBlankDate && selectedStartDate != null ? [selectedStartDate!] : [DateTime.now()];
    }

    List<String> timeColumns = [];
    if (checklist.checklistTimeType == 'PeriodicOut' && checklist.checklistPeriodicStart != null && checklist.checklistPeriodicEnd != null && checklist.checklistPeriodInterval != null) {
      timeColumns = _generatePeriodicTimeColumns(checklist.checklistPeriodicStart!, checklist.checklistPeriodicEnd!, checklist.checklistPeriodInterval!);
    }

    final List<Widget> headerCells = [];
    if (checklist.checklistDateType == 'Multi' && dateRange.isNotEmpty) {
      headerCells.add(_hcell('Ngày'));
    }
    if (checklist.checklistTimeType == 'InOut') {
      headerCells.addAll([_hcell('Giờ vào'), _hcell('Giờ ra')]);
    } else if (checklist.checklistTimeType == 'PeriodicOut') {
      headerCells.addAll(timeColumns.map(_hcell));
    } else {
      headerCells.add(_hcell('Giờ'));
    }
    for (final it in items) {
      headerCells.add(Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _thumbFor(context, it, size: 18),
            const SizedBox(height: 4),
            Text(it.itemName ?? it.itemId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ));
    }
    headerCells.addAll([_hcell('Nhân viên'), _hcell('Giám sát')]);

    final headerCount = headerCells.length;
    final relevant = reports.where((r) => r.reportType == 'staff' || r.reportType == 'sup').toList();
    List<Widget> rows = [];
    rows.add(Container(
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))),
      child: Row(children: headerCells.map((w) => Expanded(child: w)).toList()),
    ));

    if (useBlankDate || dateRange.isEmpty) {
      for (int i = 0; i < 15; i++) {
        rows.add(_buildTableRow(headerCount, List.filled(headerCount, '')));
      }
    } else {
      for (int index = 0; index < dateRange.length; index++) {
        final date = dateRange[index];
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
          
          final times = _sortTimes(byTime.keys.toList());
          
          for (final t in times) {
            final inRs = dayReports.where((r) => r.reportInOut == 'In' && r.reportTime == t).toList();
            final outRs = dayReports.where((r) => r.reportInOut == 'Out' && r.reportTime == t).toList();
            
            List<String> row = [];
            if (checklist.checklistDateType == 'Multi') {
              row.add('${date.day}/${date.month}');
            }
            row.add(inRs.isNotEmpty ? inRs.first.reportTime : '');
            row.add(outRs.isNotEmpty ? outRs.first.reportTime : '');
            
            for (final it in items) {
              String v = '';
              if (checklist.checklistCompletionType == 'State') {
                final timeReports = dayReports.where((r) => r.reportTime == t).toList();
                final sp = timeReports.where((r) => r.reportType == 'sup' && (r.reportTaskList?.contains(it.itemId) ?? false)).firstOrNull;
                final s = timeReports.where((r) => r.reportType == 'staff' && (r.reportTaskList?.contains(it.itemId) ?? false)).firstOrNull;
                
                if (sp != null) {
                  v = 'O';
                } else if (s != null) {
                  v = s.reportNote ?? '';
                }
              } else {
                final timeReports = dayReports.where((r) => r.reportTime == t).toList();
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
            
            final timeReports = dayReports.where((r) => r.reportTime == t).toList();
            final s = timeReports.where((r) => r.reportType == 'staff').firstOrNull;
            final sp = timeReports.where((r) => r.reportType == 'sup').firstOrNull;
            
            final staffName = s?.userId != null ? (staffNameMap[s!.userId!.toUpperCase()] ?? s.userId!) : '';
            final supName = sp?.userId != null ? (staffNameMap[sp!.userId!.toUpperCase()] ?? sp.userId!) : '';
            
            row.add(staffName);
            row.add(supName);
            rows.add(_buildTableRow(headerCount, row));
          }
        } else {
          final times = _sortTimes(dayReports.map((r) => r.reportTime).toSet().toList());
          
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
            rows.add(_buildTableRow(headerCount, row));
          }
        }
      }
    }
    
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
      child: Column(children: rows),
    );
  }

  Widget _hcell(String t) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!))),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
  );

  Widget _buildTableRow(int colCount, List<String> row) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
      child: Row(
        children: List.generate(colCount, (i) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!))),
            child: Text(
              i < row.length ? row[i] : '',
              style: TextStyle(
                fontSize: 11,
                color: (i < row.length && row[i] == 'O') ? Colors.red[700] :
                       (i < row.length && row[i] == 'X') ? Colors.green[700] : Colors.black,
                fontWeight: (i < row.length && (row[i] == 'X' || row[i] == 'O')) ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        )),
      ),
    );
  }
}