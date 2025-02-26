import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';

class ProjectMachine extends StatefulWidget {
  @override
  _ProjectMachineState createState() => _ProjectMachineState();
}

class _ProjectMachineState extends State<ProjectMachine> with SingleTickerProviderStateMixin {
  final dbHelper = DBHelper();
  List<Map<String, dynamic>> _machineReports = [];
  Map<String, Map<String, int>> _summaryStats = {};
  bool _isLoading = true;
  
  // Date range filter
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMachineReports(),
      _loadSummaryStats(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadMachineReports() async {
    try {
      final db = await dbHelper.database;
      String query = '''
        SELECT 
          UID,
          NguoiDung,
          Ngay,
          Gio,
          BoPhan,
          ViTri,
          ChiTiet as YeuCau,
          KetQua,
          GiaiPhap,
          HinhAnh
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE PhanLoai = 'Máy móc'
          AND date(Ngay) BETWEEN ? AND ?
        ORDER BY date(Ngay) DESC, Gio DESC
      ''';
      
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate);
      
      _machineReports = await db.rawQuery(query, [formattedStartDate, formattedEndDate]);
    } catch (e) {
      print('Error loading machine reports: $e');
    }
  }

  Future<void> _loadSummaryStats() async {
    try {
      final db = await dbHelper.database;
      
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate);
      
      // Get stats by project (BoPhan)
      String projectQuery = '''
        SELECT 
          BoPhan,
          COUNT(*) as total_reports,
          SUM(CASE WHEN KetQua != '✔️' THEN 1 ELSE 0 END) as issue_count,
          SUM(CASE 
            WHEN KetQua != '✔️' AND (GiaiPhap IS NULL OR trim(GiaiPhap) = '') 
            THEN 1 
            ELSE 0 
          END) as unresolved_count
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE PhanLoai = 'Máy móc'
          AND date(Ngay) BETWEEN ? AND ?
        GROUP BY BoPhan
        ORDER BY BoPhan
      ''';
      
      final projectStats = await db.rawQuery(projectQuery, [formattedStartDate, formattedEndDate]);
      
      // Transform the results into a more usable format
      Map<String, Map<String, int>> stats = {};
      
      for (var stat in projectStats) {
        final boPhan = stat['BoPhan'].toString();
        stats[boPhan] = {
          'total_reports': stat['total_reports'] as int,
          'issue_count': stat['issue_count'] as int,
          'unresolved_count': stat['unresolved_count'] as int,
        };
      }
      
      _summaryStats = stats;
    } catch (e) {
      print('Error loading summary stats: $e');
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Color.fromARGB(255, 0, 100, 0),
            colorScheme: ColorScheme.light(
              primary: Color.fromARGB(255, 0, 100, 0),
            ),
            buttonTheme: ButtonThemeData(
              textTheme: ButtonTextTheme.primary
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadAllData();
    }
  }

  Color _getStatusColor(String ketQua) {
    if (ketQua == '✔️') {
      return Colors.green.withOpacity(0.1);
    } else if (ketQua == '⚠️') {
      return Colors.yellow.withOpacity(0.2);
    } else if (ketQua == '❌') {
      return Colors.red.withOpacity(0.1);
    }
    return Colors.transparent;
  }

  void _showDetailsDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with colored background based on status
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report['KetQua'] ?? ''),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Báo cáo máy móc',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text('${report['BoPhan']} - ${report['ViTri']}'),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Text(
                            report['KetQua'] ?? '',
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Date and time
                  _buildDetailRow('Ngày:', DateFormat('dd/MM/yyyy').format(DateTime.parse(report['Ngay']))),
                  _buildDetailRow('Giờ:', report['Gio'] ?? ''),
                  
                  // Image (if available)
                  if (report['HinhAnh'] != null && report['HinhAnh'].toString().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hình ảnh:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: 300,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                report['HinhAnh'],
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('Không thể tải hình ảnh'),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Description and details
                  _buildExpandableDetailRow('Yêu cầu:', report['YeuCau'] ?? ''),
                  _buildExpandableDetailRow('Giải pháp:', report['GiaiPhap'] ?? ''),
                  _buildDetailRow('Người dùng:', report['NguoiDung'] ?? ''),
                  
                  // Close button
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Đóng'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 114, 255, 217),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Quản lý máy móc'),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.date_range, color: Colors.white),
              label: Text(
                '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Color.fromARGB(100, 0, 100, 0),
                ),
              ),
              onPressed: () => _selectDateRange(context),
              style: TextButton.styleFrom(
                backgroundColor: Color.fromARGB(50, 0, 100, 0),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            SizedBox(width: 12),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 114, 255, 217),
                  Color.fromARGB(255, 201, 255, 236),
                  Color.fromARGB(255, 79, 255, 214),
                  Color.fromARGB(255, 188, 255, 235),
                ],
              ),
            ),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Theo dõi máy'),
              Tab(text: 'Tổng hợp'),
            ],
          ),
        ),
        body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildMachineReportsTab(),
                _buildSummaryTab(),
              ],
            ),
        floatingActionButton: FloatingActionButton(
          onPressed: _loadAllData,
          child: Icon(Icons.refresh),
          tooltip: 'Làm mới dữ liệu',
          backgroundColor: Color.fromARGB(255, 0, 154, 225),
        ),
      ),
    );
  }

  Widget _buildMachineReportsTab() {
    double screenWidth = MediaQuery.of(context).size.width;
    double boPhanWidth = screenWidth > 600 ? screenWidth * 0.2 : 200;
    double contentWidth = screenWidth > 600 ? screenWidth * 0.25 : 250;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          dataRowMinHeight: 120, // Increased height for rows
          dataRowMaxHeight: 200, // Maximum height for rows with images
          headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
          columns: [
            DataColumn(label: Text('Ngày')),
            DataColumn(label: Text('Giờ')),
            DataColumn(
              label: Container(
                width: boPhanWidth,
                child: Text(
                  'Bộ phận',
                  softWrap: true,
                ),
              ),
            ),
            DataColumn(label: Text('Vị trí')),
            DataColumn(
              label: Container(
                width: contentWidth,
                child: Text(
                  'Yêu cầu',
                  softWrap: true,
                ),
              ),
            ),
            DataColumn(label: Text('Kết quả')),
            DataColumn(
              label: Container(
                width: contentWidth,
                child: Text(
                  'Giải pháp',
                  softWrap: true,
                ),
              ),
            ),
            DataColumn(label: Text('Hình ảnh')),
            DataColumn(label: Text('Người dùng')),
          ],
          rows: _machineReports.map((report) {
            return DataRow(
              color: MaterialStateProperty.all(_getStatusColor(report['KetQua'] ?? '')),
              onSelectChanged: (_) => _showDetailsDialog(report),
              cells: [
                DataCell(Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(report['Ngay'])))),
                DataCell(Text(report['Gio'] ?? '')),
                DataCell(
                  Container(
                    width: boPhanWidth,
                    child: Text(
                      report['BoPhan'] ?? '',
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
                DataCell(Text(report['ViTri'] ?? '')),
                DataCell(
                  Container(
                    width: contentWidth,
                    height: 80, // Fixed height for 3 lines of text
                    child: Text(
                      report['YeuCau'] ?? '',
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    report['KetQua'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                ),
                DataCell(
                  Container(
                    width: contentWidth,
                    child: Text(
                      report['GiaiPhap'] ?? '',
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
                DataCell(
                  report['HinhAnh'] != null && report['HinhAnh'].toString().isNotEmpty
                      ? Container(
                          width: 100,
                          height: 100,
                          child: Stack(
                            children: [
                              Image.network(
                                report['HinhAnh'],
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.broken_image, color: Colors.grey);
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / 
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                              ),
                              // Semi-transparent overlay with tap hint
                              Positioned.fill(
                                child: Container(
                                  alignment: Alignment.center,
                                  color: Colors.black.withOpacity(0.2),
                                  child: Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text('No image'),
                ),
                DataCell(Text(report['NguoiDung'] ?? '')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    double screenWidth = MediaQuery.of(context).size.width;
    double boPhanWidth = screenWidth > 600 ? screenWidth * 0.3 : 200;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
          columns: [
            DataColumn(
              label: Container(
                width: boPhanWidth,
                child: Text(
                  'Bộ phận',
                  softWrap: true,
                ),
              ),
            ),
            DataColumn(label: Text('Tổng số báo cáo')),
            DataColumn(label: Text('Số vấn đề')),
            DataColumn(label: Text('Vấn đề chưa giải quyết')),
            DataColumn(label: Text('Tỷ lệ giải quyết')),
          ],
          rows: _summaryStats.entries.map((entry) {
            final boPhan = entry.key;
            final stats = entry.value;
            
            // Calculate resolution rate
            final totalIssues = stats['issue_count'] ?? 0;
            final unresolvedIssues = stats['unresolved_count'] ?? 0;
            final resolvedIssues = totalIssues - unresolvedIssues;
            final resolutionRate = totalIssues > 0 
              ? (resolvedIssues / totalIssues * 100).toStringAsFixed(1) + '%'
              : 'N/A';
            
            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: boPhanWidth,
                    child: Text(
                      boPhan,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
                DataCell(Text(stats['total_reports'].toString())),
                DataCell(Text(stats['issue_count'].toString())),
                DataCell(Text(stats['unresolved_count'].toString())),
                DataCell(Text(resolutionRate)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}