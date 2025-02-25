import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';
import 'http_client.dart';

class ProjectDailyView extends StatefulWidget {
  final String? startDate;
  final String? endDate;
  final String? selectedBoPhan;

  ProjectDailyView({
    this.startDate,
    this.endDate,
    this.selectedBoPhan,
  });

  @override
  _ProjectDailyViewState createState() => _ProjectDailyViewState();
}

class _ProjectDailyViewState extends State<ProjectDailyView> {
  final dbHelper = DBHelper();
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _personnelStats = [];
  List<String> _dateRange = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadDateRange();
    await Future.wait([
      _loadDailyStats(),
      _loadPersonnelStats(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadDateRange() async {
    _dateRange = [];
    DateTime startDate = DateTime.parse(widget.startDate!);
    DateTime endDate = DateTime.parse(widget.endDate!);
    
    for (var date = startDate;
         date.isBefore(endDate.add(Duration(days: 1)));
         date = date.add(Duration(days: 1))) {
      _dateRange.add(DateFormat('yyyy-MM-dd').format(date));
    }
  }

  Future<void> _loadDailyStats() async {
    try {
      final db = await dbHelper.database;
      String query = '''
        SELECT 
          date(Ngay) as date,
          BoPhan,
          COUNT(*) as report_count,
          SUM(CASE WHEN KetQua != '✔️' THEN 1 ELSE 0 END) as issue_count,
          SUM(CASE 
            WHEN KetQua != '✔️' AND (GiaiPhap IS NULL OR trim(GiaiPhap) = '') 
            THEN 1 
            ELSE 0 
          END) as unresolved_count
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE date(Ngay) BETWEEN ? AND ?
      ''';
      
      List<dynamic> args = [widget.startDate, widget.endDate];

      if (widget.selectedBoPhan != 'Tất cả') {
        query += ' AND BoPhan = ?';
        args.add(widget.selectedBoPhan);
      }

      query += ' GROUP BY date(Ngay), BoPhan ORDER BY date DESC, BoPhan';

      _dailyStats = await db.rawQuery(query, args);
    } catch (e) {
      print('Error loading daily stats: $e');
    }
  }

  Future<void> _loadPersonnelStats() async {
    try {
      final db = await dbHelper.database;
      
      // Get unique boPhan and viTri combinations
      String vtQuery = '''
        SELECT DISTINCT BoPhan, ViTri
        FROM ${DatabaseTables.vtHistoryTable}
        WHERE date(Ngay) BETWEEN ? AND ?
      ''';
      
      List<dynamic> vtArgs = [widget.startDate, widget.endDate];
      if (widget.selectedBoPhan != 'Tất cả') {
        vtQuery += ' AND BoPhan = ?';
        vtArgs.add(widget.selectedBoPhan);
      }
      vtQuery += ' ORDER BY BoPhan, ViTri';

      final locations = await db.rawQuery(vtQuery, vtArgs);
      
      List<Map<String, dynamic>> stats = [];
      
      for (var location in locations) {
        final boPhan = location['BoPhan'];
        final viTri = location['ViTri'];
        Map<String, dynamic> row = {
          'BoPhan': boPhan,
          'ViTri': viTri,
        };
        
        String? lastStatus;
        for (String date in _dateRange) {
          final statusQuery = '''
            SELECT TrangThai, PhuongAn, HoTro
            FROM ${DatabaseTables.vtHistoryTable}
            WHERE date(Ngay) = ? AND BoPhan = ? AND ViTri = ?
            ORDER BY Gio DESC
            LIMIT 1
          ''';

          final statusResult = await db.rawQuery(
            statusQuery, 
            [date, boPhan, viTri]
          );

          if (statusResult.isNotEmpty) {
            final entry = statusResult.first;
            lastStatus = _formatStatus(
              entry['TrangThai']?.toString(),
              entry['PhuongAn']?.toString(),
              entry['HoTro']?.toString()
            );
          }
          
          row[date] = lastStatus ?? '';
        }
        
        stats.add(row);
      }
      
      _personnelStats = stats;
    } catch (e) {
      print('Error loading personnel stats: $e');
    }
  }

  String _formatStatus(String? trangThai, String? phuongAn, String? hoTro) {
    List<String> parts = [];
    
    if (trangThai != null && trangThai.isNotEmpty) {
      parts.add(trangThai);
    }
    
    if (phuongAn != null && phuongAn.isNotEmpty) {
      parts.add(phuongAn);
    }

    String status = parts.join(' / ');
    
    if (hoTro != null && hoTro.isNotEmpty) {
      status += ' + $hoTro';
    }
    
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Tổng hợp theo ngày'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Báo cáo'),
              Tab(text: 'Nhân sự'),
            ],
          ),
        ),
        body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildDailyStatsTab(),
                _buildPersonnelStatsTab(),
              ],
            ),
      ),
    );
  }

  Widget _buildDailyStatsTab() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
          columns: [
            DataColumn(label: Text('Ngày')),
DataColumn(
  label: Container(
    width: 300,
    child: Text(
      'Bộ phận',
      softWrap: true,
    ),
  ),
),            DataColumn(label: Text('Số báo cáo')),
            DataColumn(label: Text('Số vấn đề')),
            DataColumn(label: Text('Vấn đề chưa giải quyết')),
          ],
          rows: _dailyStats.map((stat) {
            return DataRow(
              cells: [
                DataCell(Text(stat['date'])),
DataCell(
  Container(
    width: 300,
    child: Text(
      stat['BoPhan'],
      softWrap: true,
      overflow: TextOverflow.visible,
    ),
  ),
),                DataCell(Text(stat['report_count'].toString())),
                DataCell(Text(stat['issue_count'].toString())),
                DataCell(Text(stat['unresolved_count'].toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPersonnelStatsTab() {
    List<DataColumn> columns = [
DataColumn(
  label: Container(
    width: 300,
    child: Text(
      'Bộ phận',
      softWrap: true,
    ),
  ),
),      DataColumn(label: Text('Vị trí')),
      ..._dateRange.map((date) => DataColumn(label: Text(date))),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
          columns: columns,
          rows: _personnelStats.map((stat) {
            return DataRow(
              cells: [
DataCell(
  Container(
    width: 300,
    child: Text(
      stat['BoPhan'],
      softWrap: true,
      overflow: TextOverflow.visible,
    ),
  ),
),                DataCell(Text(stat['ViTri'])),
                ..._dateRange.map((date) => 
                  DataCell(Text(stat[date] ?? ''))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}