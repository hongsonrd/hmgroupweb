// checklist_manager.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'checklist_item.dart';
import 'checklist_list.dart';
import 'checklist_report.dart';

class ChecklistManager extends StatefulWidget {
  final String username;

  const ChecklistManager({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  _ChecklistManagerState createState() => _ChecklistManagerState();
}

class _ChecklistManagerState extends State<ChecklistManager> {
  bool _isLoading = false;
  String _syncStatus = '';
  
  // Data lists for the three tables
  List<ChecklistItemModel> _checklistItems = [];
  List<ChecklistReportModel> _checklistReports = [];
  List<ChecklistListModel> _checklistLists = [];
  
  // Sync tracking
  Map<String, int> _recordCounts = {
    'items': 0,
    'reports': 0,
    'lists': 0,
  };
  
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  
  // SharedPreferences keys
  static const String _itemsKey = 'checklist_items_v1';
  static const String _reportsKey = 'checklist_reports_v1';
  static const String _listsKey = 'checklist_lists_v1';
  static const String _lastSyncKey = 'checklist_last_sync';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _checkAndSyncData();
  }

  Future<void> _checkAndSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if it's a new day since last sync
    final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final today = DateTime.now();
    final isNewDay = lastSyncDate.day != today.day || 
                     lastSyncDate.month != today.month || 
                     lastSyncDate.year != today.year;
    
    if (lastSync == 0 || isNewDay) {
      await _syncAllTables();
    } else {
      await _loadLocalData();
    }
  }

  Future<void> _syncAllTables() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ dữ liệu checklist...';
    });

    try {
      // Sync all three tables concurrently
      await Future.wait([
        _syncChecklistItems(),
        _syncChecklistReports(), 
        _syncChecklistLists(),
      ]);
      
      // Update sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      
      _showSuccess('Đồng bộ thành công - Items: ${_recordCounts['items']}, Reports: ${_recordCounts['reports']}, Lists: ${_recordCounts['lists']}');
      
    } catch (e) {
      print('Error syncing checklist data: $e');
      _showError('Không thể đồng bộ dữ liệu: ${e.toString()}');
      await _loadLocalData(); // Load local data if sync fails
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _syncChecklistItems() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/checklistitem/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final items = data.map((item) => ChecklistItemModel.fromMap(item)).toList();
        
        await _saveChecklistItemsLocally(items);
        
        setState(() {
          _checklistItems = items;
          _recordCounts['items'] = items.length;
        });
      } else {
        throw Exception('Failed to sync checklist items: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing checklist items: $e');
      await _loadLocalChecklistItems();
      rethrow;
    }
  }

  Future<void> _syncChecklistReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/checklistreport/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final reports = data.map((report) => ChecklistReportModel.fromMap(report)).toList();
        
        await _saveChecklistReportsLocally(reports);
        
        setState(() {
          _checklistReports = reports;
          _recordCounts['reports'] = reports.length;
        });
      } else {
        throw Exception('Failed to sync checklist reports: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing checklist reports: $e');
      await _loadLocalChecklistReports();
      rethrow;
    }
  }

  Future<void> _syncChecklistLists() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/checklistlist/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final lists = data.map((list) => ChecklistListModel.fromMap(list)).toList();
        
        await _saveChecklistListsLocally(lists);
        
        setState(() {
          _checklistLists = lists;
          _recordCounts['lists'] = lists.length;
        });
      } else {
        throw Exception('Failed to sync checklist lists: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing checklist lists: $e');
      await _loadLocalChecklistLists();
      rethrow;
    }
  }

  // Local storage methods
  Future<void> _saveChecklistItemsLocally(List<ChecklistItemModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.map((item) => json.encode(item.toMap())).toList();
      await prefs.setStringList(_itemsKey, jsonList);
    } catch (e) {
      print('Error saving checklist items locally: $e');
    }
  }

  Future<void> _saveChecklistReportsLocally(List<ChecklistReportModel> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reports.map((report) => json.encode(report.toMap())).toList();
      await prefs.setStringList(_reportsKey, jsonList);
    } catch (e) {
      print('Error saving checklist reports locally: $e');
    }
  }

  Future<void> _saveChecklistListsLocally(List<ChecklistListModel> lists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = lists.map((list) => json.encode(list.toMap())).toList();
      await prefs.setStringList(_listsKey, jsonList);
    } catch (e) {
      print('Error saving checklist lists locally: $e');
    }
  }

  Future<void> _loadLocalData() async {
    await Future.wait([
      _loadLocalChecklistItems(),
      _loadLocalChecklistReports(),
      _loadLocalChecklistLists(),
    ]);
  }

  Future<void> _loadLocalChecklistItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_itemsKey) ?? [];
      
      final items = jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistItemModel.fromMap(map);
      }).toList();

      setState(() {
        _checklistItems = items;
        _recordCounts['items'] = items.length;
      });
    } catch (e) {
      print('Error loading local checklist items: $e');
      setState(() {
        _checklistItems = [];
        _recordCounts['items'] = 0;
      });
    }
  }

  Future<void> _loadLocalChecklistReports() async {
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
        _checklistReports = reports;
        _recordCounts['reports'] = reports.length;
      });
    } catch (e) {
      print('Error loading local checklist reports: $e');
      setState(() {
        _checklistReports = [];
        _recordCounts['reports'] = 0;
      });
    }
  }

  Future<void> _loadLocalChecklistLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_listsKey) ?? [];
      
      final lists = jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistListModel.fromMap(map);
      }).toList();

      // Sort by date/time descending
      lists.sort((a, b) {
        final dateTimeA = '${a.date} ${a.time}';
        final dateTimeB = '${b.date} ${b.time}';
        return dateTimeB.compareTo(dateTimeA);
      });

      setState(() {
        _checklistLists = lists;
        _recordCounts['lists'] = lists.length;
      });
    } catch (e) {
      print('Error loading local checklist lists: $e');
      setState(() {
        _checklistLists = [];
        _recordCounts['lists'] = 0;
      });
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
Widget _buildQuickActions() {
  final isMobile = MediaQuery.of(context).size.width < 600;
  
  return Container(
    margin: EdgeInsets.all(isMobile ? 12 : 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.apps, color: Colors.green[600]),
              SizedBox(width: 8),
              Text(
                'Quản lý dữ liệu',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            children: [
              _buildActionButton(
                icon: Icons.check_box_outlined,
                title: 'Checklist Items',
                subtitle: '${_recordCounts['items']} items',
                color: Colors.blue,
                onTap: () => _navigateToItems(),
                isMobile: isMobile,
              ),
              SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.assignment_outlined,
                title: 'Checklist Reports',
                subtitle: '${_recordCounts['reports']} reports',
                color: Colors.orange,
                onTap: () => _navigateToReports(),
                isMobile: isMobile,
              ),
              SizedBox(height: 12),
              _buildActionButton(
                icon: Icons.list_alt_outlined,
                title: 'Checklist Lists',
                subtitle: '${_recordCounts['lists']} lists',
                color: Colors.purple,
                onTap: () => _navigateToLists(),
                isMobile: isMobile,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _buildActionButton({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
  required bool isMobile,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: color,
            size: isMobile ? 20 : 24,
          ),
        ],
      ),
    ),
  );
}
void _navigateToItems() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChecklistItemScreen(username: widget.username),
    ),
  );
}

void _navigateToReports() {
 Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChecklistReportScreen(username: widget.username),
    ),
  );
}

void _navigateToLists() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChecklistListScreen(username: widget.username),
    ),
  );
}
  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24, 
        vertical: isMobile ? 12 : 16
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 76, 175, 80),
            Color.fromARGB(255, 129, 199, 132),
            Color.fromARGB(255, 102, 187, 106),
            Color.fromARGB(255, 165, 214, 167),
          ],
        ),
      ),
      child: Column(
        children: [
          // Main header row
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
                  'Quản lý Checklist',
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
          // Action buttons row
          if (!_isLoading)
            Container(
              margin: EdgeInsets.only(top: isMobile ? 12 : 16),
              height: isMobile ? 36 : 40,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _syncAllTables(),
                      icon: Icon(Icons.sync, size: isMobile ? 16 : 18),
                      label: Text(
                        'Đồng bộ dữ liệu',
                        style: TextStyle(fontSize: isMobile ? 12 : 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green[700],
                        elevation: 2,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 16,
                          vertical: isMobile ? 8 : 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Loading status
          if (_isLoading && _syncStatus.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 8),
              child: Text(
                _syncStatus,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: isMobile ? 12 : 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncStatus() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.assessment_outlined, color: Colors.green[600]),
                SizedBox(width: 8),
                Text(
                  'Trạng thái dữ liệu',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
          // Data counts
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                _buildDataCountRow(
                  icon: Icons.check_box_outlined,
                  label: 'Checklist Items',
                  count: _recordCounts['items']!,
                  color: Colors.blue,
                  isMobile: isMobile,
                ),
                SizedBox(height: 12),
                _buildDataCountRow(
                  icon: Icons.assignment_outlined,
                  label: 'Checklist Reports', 
                  count: _recordCounts['reports']!,
                  color: Colors.orange,
                  isMobile: isMobile,
                ),
                SizedBox(height: 12),
                _buildDataCountRow(
                  icon: Icons.list_alt_outlined,
                  label: 'Checklist Lists',
                  count: _recordCounts['lists']!,
                  color: Colors.purple,
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCountRow({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastSyncInfo() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        
        final prefs = snapshot.data!;
        final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
        
        if (lastSync == 0) {
          return SizedBox.shrink();
        }
        
        final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(lastSyncDate);
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: isMobile ? 16 : 18, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text(
                'Đồng bộ lần cuối: $formattedDate',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],
    body: SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSyncStatus(),
                  _buildQuickActions(), 
                  SizedBox(height: 16),
                  _buildLastSyncInfo(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

// Model classes based on the database schemas

class ChecklistItemModel {
  final String itemId;
  final String? itemName;
  final String? itemImage;
  final String? itemIcon;

  ChecklistItemModel({
    required this.itemId,
    this.itemName,
    this.itemImage,
    this.itemIcon,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemImage': itemImage,
      'itemIcon': itemIcon,
    };
  }

  factory ChecklistItemModel.fromMap(Map<String, dynamic> map) {
    return ChecklistItemModel(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'],
      itemImage: map['itemImage'],
      itemIcon: map['itemIcon'],
    );
  }
}

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
    );
  }
}

class ChecklistListModel {
  final String checklistId;
  final String? userId;
  final String date;
  final String time;
  final int? versionNumber;
  final String? projectName;
  final String? areaName;
  final String? floorName;
  final String? checklistTitle;
  final String? checklistPretext;
  final String? checklistSubtext;
  final String? logoMain;
  final String? logoSecondary;
  final String? checklistTaskList;
  final String? checklistDateType;
  final String? checklistTimeType;
  final String? checklistPeriodicStart;
  final String? checklistPeriodicEnd;
  final int? checklistPeriodInterval;
  final String? checklistCompletionType;
  final String? checklistNoteEnabled;
  final String? cloudUrl;

  ChecklistListModel({
    required this.checklistId,
    this.userId,
    required this.date,
    required this.time,
    this.versionNumber,
    this.projectName,
    this.areaName,
    this.floorName,
    this.checklistTitle,
    this.checklistPretext,
    this.checklistSubtext,
    this.logoMain,
    this.logoSecondary,
    this.checklistTaskList,
    this.checklistDateType,
    this.checklistTimeType,
    this.checklistPeriodicStart,
    this.checklistPeriodicEnd,
    this.checklistPeriodInterval,
    this.checklistCompletionType,
    this.checklistNoteEnabled,
    this.cloudUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'checklistId': checklistId,
      'userId': userId,
      'date': date,
      'time': time,
      'versionNumber': versionNumber,
      'projectName': projectName,
      'areaName': areaName,
      'floorName': floorName,
      'checklistTitle': checklistTitle,
      'checklistPretext': checklistPretext,
      'checklistSubtext': checklistSubtext,
      'logoMain': logoMain,
      'logoSecondary': logoSecondary,
      'checklistTaskList': checklistTaskList,
      'checklistDateType': checklistDateType,
      'checklistTimeType': checklistTimeType,
      'checklistPeriodicStart': checklistPeriodicStart,
      'checklistPeriodicEnd': checklistPeriodicEnd,
      'checklistPeriodInterval': checklistPeriodInterval,
      'checklistCompletionType': checklistCompletionType,
      'checklistNoteEnabled': checklistNoteEnabled,
      'cloudUrl': cloudUrl,
    };
  }

  factory ChecklistListModel.fromMap(Map<String, dynamic> map) {
    return ChecklistListModel(
      checklistId: map['checklistId'] ?? '',
      userId: map['userId'],
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      versionNumber: map['versionNumber'],
      projectName: map['projectName'],
      areaName: map['areaName'],
      floorName: map['floorName'],
      checklistTitle: map['checklistTitle'],
      checklistPretext: map['checklistPretext'],
      checklistSubtext: map['checklistSubtext'],
      logoMain: map['logoMain'],
      logoSecondary: map['logoSecondary'],
      checklistTaskList: map['checklistTaskList'],
      checklistDateType: map['checklistDateType'],
      checklistTimeType: map['checklistTimeType'],
      checklistPeriodicStart: map['checklistPeriodicStart'],
      checklistPeriodicEnd: map['checklistPeriodicEnd'],
      checklistPeriodInterval: map['checklistPeriodInterval'],
      checklistCompletionType: map['checklistCompletionType'],
      checklistNoteEnabled: map['checklistNoteEnabled'],
      cloudUrl: map['cloudUrl'],
    );
  }
}