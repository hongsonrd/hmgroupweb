// checklist_report.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ChecklistReportScreen extends StatefulWidget {
  final String username;

  const ChecklistReportScreen({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  _ChecklistReportScreenState createState() => _ChecklistReportScreenState();
}

class _ChecklistReportScreenState extends State<ChecklistReportScreen> {
  bool _isLoading = false;
  String _syncStatus = '';
  
  List<ChecklistReportModel> _reports = [];
  List<ChecklistReportModel> _filteredReports = [];
  
  final TextEditingController _searchController = TextEditingController();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  static const String _reportsKey = 'checklist_reports_v1';
  static const String _lastSyncKey = 'checklist_reports_last_sync';

  String? _selectedProject;
  List<String> _projectOptions = [];
  Map<String, List<ChecklistReportModel>> _reportsByDate = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_filterReports);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
     await initializeDateFormatting('vi'); // or 'vi_VN'
    await _checkAndSyncReports();
    _extractProjects();
    _groupReportsByDate();
  }

  Future<void> _checkAndSyncReports() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final today = DateTime.now();
    final isNewDay = lastSyncDate.day != today.day || 
                     lastSyncDate.month != today.month || 
                     lastSyncDate.year != today.year;
    
    if (lastSync == 0 || isNewDay) {
      await _syncReports();
    } else {
      await _loadLocalReports();
    }
  }

  Future<void> _syncReports() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ báo cáo checklist...';
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/checklistreport/${widget.username}'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final reports = data.map((item) => ChecklistReportModel.fromMap(item)).toList();
        
        await _saveReportsLocally(reports);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        
        setState(() {
          _reports = reports;
          _filteredReports = reports;
        });
        
        _showSuccess('Đồng bộ thành công - ${reports.length} báo cáo');
        
      } else {
        throw Exception('Failed to sync reports: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing reports: $e');
      _showError('Không thể đồng bộ báo cáo: ${e.toString()}');
      await _loadLocalReports();
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _saveReportsLocally(List<ChecklistReportModel> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reports.map((report) => json.encode(report.toMap())).toList();
      await prefs.setStringList(_reportsKey, jsonList);
    } catch (e) {
      print('Error saving reports locally: $e');
    }
  }

  Future<void> _loadLocalReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_reportsKey) ?? [];
      
      final reports = jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistReportModel.fromMap(map);
      }).toList();

      // Sort by date/time descending
      reports.sort((a, b) {
        final dateTimeA = '${a.reportDate} ${a.reportTime}';
        final dateTimeB = '${b.reportDate} ${b.reportTime}';
        return dateTimeB.compareTo(dateTimeA);
      });

      setState(() {
        _reports = reports;
        _filteredReports = reports;
      });
    } catch (e) {
      print('Error loading local reports: $e');
      setState(() {
        _reports = [];
        _filteredReports = [];
      });
    }
  }

  void _extractProjects() {
    final projects = _reports
        .map((r) => r.projectName)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    
    setState(() {
      _projectOptions = projects;
    });
  }

  void _groupReportsByDate() {
    _reportsByDate.clear();
    for (final report in _filteredReports) {
      final dateKey = report.reportDate;
      if (!_reportsByDate.containsKey(dateKey)) {
        _reportsByDate[dateKey] = [];
      }
      _reportsByDate[dateKey]!.add(report);
    }
  }

  void _filterReports() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReports = _reports.where((report) {
        final matchesSearch = query.isEmpty || 
            (report.reportNote?.toLowerCase().contains(query) ?? false) ||
            (report.userId?.toLowerCase().contains(query) ?? false);
        final matchesProject = _selectedProject == null || report.projectName == _selectedProject;
        return matchesSearch && matchesProject;
      }).toList();
      _groupReportsByDate();
    });
  }

  MaterialColor _getReportTypeColor(String? reportType) {
  switch (reportType) {
    case 'staff':
      return Colors.blue;
    case 'sup':
      return Colors.orange;
    case 'customer':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

  String _getReportTypeLabel(String? reportType) {
    switch (reportType) {
      case 'staff':
        return 'Nhân viên';
      case 'sup':
        return 'Giám sát';
      case 'customer':
        return 'Khách hàng';
      default:
        return 'Khác';
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 255, 152, 0),
            Color.fromARGB(255, 255, 183, 77),
            Color.fromARGB(255, 255, 167, 38),
            Color.fromARGB(255, 255, 204, 128),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: isMobile ? 20 : 24),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Text(
                  'Checklist Reports',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          if (!_isLoading)
            Container(
              margin: EdgeInsets.only(top: isMobile ? 12 : 16),
              height: isMobile ? 36 : 40,
              child: ElevatedButton.icon(
                onPressed: () => _syncReports(),
                icon: Icon(Icons.sync, size: isMobile ? 16 : 18),
                label: Text('Đồng bộ', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange[700],
                  elevation: 2,
                ),
              ),
            ),
          if (_isLoading && _syncStatus.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 8),
              child: Text(
                _syncStatus,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isMobile ? 12 : 14),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm báo cáo...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 8),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Text(
                  '${_filteredReports.length} reports',
                  style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w500, color: Colors.orange[700]),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedProject,
            hint: Text('Chọn dự án'),
            isExpanded: true,
            items: _projectOptions.map((project) => DropdownMenuItem(value: project, child: Text(project))).toList(),
            onChanged: (value) {
              setState(() {
                _selectedProject = value;
                _filterReports();
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 8),
            ),
          ),
        ],
     ),
   );
 }

 Widget _buildDateGroupCard(String date, List<ChecklistReportModel> reports) {
   final isMobile = MediaQuery.of(context).size.width < 600;
   final parsedDate = DateTime.tryParse(date);
   final formattedDate = parsedDate != null 
       ? DateFormat('dd/MM/yyyy - EEEE', 'vi').format(parsedDate)
       : date;
   
   return Card(
     margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 6),
     elevation: 2,
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // Date header
         Container(
           width: double.infinity,
           padding: EdgeInsets.all(isMobile ? 12 : 16),
           decoration: BoxDecoration(
             color: Colors.orange[50],
             borderRadius: BorderRadius.only(
               topLeft: Radius.circular(8),
               topRight: Radius.circular(8),
             ),
           ),
           child: Row(
             children: [
               Icon(Icons.calendar_today, color: Colors.orange[600], size: isMobile ? 18 : 20),
               SizedBox(width: 8),
               Expanded(
                 child: Text(
                   formattedDate,
                   style: TextStyle(
                     fontSize: isMobile ? 14 : 16,
                     fontWeight: FontWeight.bold,
                     color: Colors.orange[800],
                   ),
                 ),
               ),
               Container(
                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.orange[100],
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   '${reports.length} báo cáo',
                   style: TextStyle(
                     fontSize: 11,
                     fontWeight: FontWeight.w500,
                     color: Colors.orange[700],
                   ),
                 ),
               ),
             ],
           ),
         ),
         // Reports list
         ...reports.asMap().entries.map((entry) {
           final index = entry.key;
           final report = entry.value;
           final isLast = index == reports.length - 1;
           
           return Container(
             decoration: BoxDecoration(
               border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey[200]!)),
             ),
             child: _buildReportItem(report, isMobile),
           );
         }).toList(),
       ],
     ),
   );
 }

 Widget _buildReportItem(ChecklistReportModel report, bool isMobile) {
   final reportTypeColor = _getReportTypeColor(report.reportType);
   final reportTypeLabel = _getReportTypeLabel(report.reportType);
   
   return Padding(
     padding: EdgeInsets.all(isMobile ? 12 : 16),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // Report header
         Row(
           children: [
             Container(
               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: reportTypeColor.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: reportTypeColor.withOpacity(0.3)),
               ),
               child: Text(
                 reportTypeLabel,
                 style: TextStyle(
                   fontSize: 11,
                   fontWeight: FontWeight.w500,
                   color: reportTypeColor[700],
                 ),
               ),
             ),
             SizedBox(width: 8),
             if (report.reportInOut != null && report.reportInOut!.isNotEmpty)
               Container(
                 padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                   color: report.reportInOut == 'In' ? Colors.green[100] : Colors.red[100],
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text(
                   report.reportInOut!,
                   style: TextStyle(
                     fontSize: 10,
                     fontWeight: FontWeight.bold,
                     color: report.reportInOut == 'In' ? Colors.green[700] : Colors.red[700],
                   ),
                 ),
               ),
             Spacer(),
             Text(
               report.reportTime,
               style: TextStyle(
                 fontSize: 12,
                 color: Colors.grey[600],
                 fontWeight: FontWeight.w500,
               ),
             ),
           ],
         ),
         SizedBox(height: 8),
         
         // Report details
         Row(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Expanded(
               flex: 2,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   if (report.projectName != null && report.projectName!.isNotEmpty)
                     _buildDetailRow('Dự án:', report.projectName!, isMobile),
                   if (report.userId != null && report.userId!.isNotEmpty)
                     _buildDetailRow('Người báo cáo:', report.userId!, isMobile),
                   if (report.checklistId != null && report.checklistId!.isNotEmpty)
                     _buildDetailRow('Checklist ID:', report.checklistId!, isMobile),
                 ],
               ),
             ),
             SizedBox(width: 12),
             Expanded(
               flex: 3,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   if (report.reportTaskList != null && report.reportTaskList!.isNotEmpty)
                     _buildDetailRow('Công việc:', report.reportTaskList!, isMobile),
                   if (report.reportNote != null && report.reportNote!.isNotEmpty)
                     _buildDetailRow('Ghi chú:', report.reportNote!, isMobile),
                 ],
               ),
             ),
           ],
         ),
         
         // Report image if available
         if (report.reportImage != null && report.reportImage!.isNotEmpty)
           Container(
             margin: EdgeInsets.only(top: 8),
             padding: EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: Colors.grey[50],
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.grey[200]!),
             ),
             child: Row(
               children: [
                 Icon(Icons.image, size: 16, color: Colors.grey[600]),
                 SizedBox(width: 4),
                 Expanded(
                   child: Text(
                     'Có hình ảnh đính kèm',
                     style: TextStyle(
                       fontSize: 11,
                       color: Colors.grey[600],
                       fontStyle: FontStyle.italic,
                     ),
                   ),
                 ),
               ],
             ),
           ),
       ],
     ),
   );
 }

 Widget _buildDetailRow(String label, String value, bool isMobile) {
   return Padding(
     padding: EdgeInsets.only(bottom: 4),
     child: RichText(
       text: TextSpan(
         style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey[800]),
         children: [
           TextSpan(
             text: '$label ',
             style: TextStyle(fontWeight: FontWeight.w500),
           ),
           TextSpan(text: value),
         ],
       ),
     ),
   );
 }

 @override
 Widget build(BuildContext context) {
   final sortedDates = _reportsByDate.keys.toList()
     ..sort((a, b) => b.compareTo(a)); // Sort dates descending (newest first)
   
   return Scaffold(
     backgroundColor: Colors.grey[50],
     body: SafeArea(
       child: Column(
         children: [
           _buildHeader(),
           _buildFilterBar(),
           Expanded(
             child: sortedDates.isEmpty
                 ? Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                         SizedBox(height: 16),
                         Text(
                           _isLoading ? 'Đang tải...' : 'Không có báo cáo nào',
                           style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                         ),
                       ],
                     ),
                   )
                 : ListView.builder(
                     itemCount: sortedDates.length,
                     itemBuilder: (context, index) {
                       final date = sortedDates[index];
                       final reports = _reportsByDate[date]!;
                       return _buildDateGroupCard(date, reports);
                     },
                   ),
           ),
         ],
       ),
     ),
   );
 }
}

// ChecklistReportModel class (same as in checklist_list.dart)
class ChecklistReportModel {
 final String reportId;
 final String? checklistId;
 final String? projectName;
 final String? reportType;
 final String reportDate;
 final String reportTime;
 final String? userId;
 final String? reportTaskList;
 final String? reportNote;
 final String? reportImage;
 final String? reportInOut;

 ChecklistReportModel({
   required this.reportId,
   this.checklistId,
   this.projectName,
   this.reportType,
   required this.reportDate,
   required this.reportTime,
   this.userId,
   this.reportTaskList,
   this.reportNote,
   this.reportImage,
   this.reportInOut,
 });

 Map<String, dynamic> toMap() {
   return {
     'reportId': reportId,
     'checklistId': checklistId,
     'projectName': projectName,
     'reportType': reportType,
     'reportDate': reportDate,
     'reportTime': reportTime,
     'userId': userId,
     'reportTaskList': reportTaskList,
     'reportNote': reportNote,
     'reportImage': reportImage,
     'reportInOut': reportInOut,
   };
 }

 factory ChecklistReportModel.fromMap(Map<String, dynamic> map) {
   return ChecklistReportModel(
     reportId: map['reportId'] ?? '',
     checklistId: map['checklistId'],
     projectName: map['projectName'],
     reportType: map['reportType'],
     reportDate: map['reportDate'] ?? '',
     reportTime: map['reportTime'] ?? '',
     userId: map['userId'],
     reportTaskList: map['reportTaskList'],
     reportNote: map['reportNote'],
     reportImage: map['reportImage'],
     reportInOut: map['reportInOut'],
   );
 }
}