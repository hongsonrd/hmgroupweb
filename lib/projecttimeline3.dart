import 'package:flutter/material.dart';
import 'dart:async';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:intl/intl.dart';

class ProjectProgressDashboard extends StatefulWidget {
  final String username;

  const ProjectProgressDashboard({Key? key, required this.username}) : super(key: key);

  @override
  _ProjectProgressDashboardState createState() => _ProjectProgressDashboardState();
}

class _ProjectProgressDashboardState extends State<ProjectProgressDashboard> {
  bool _isLoading = false;
  List<ProjectProgress> _projectsData = [];
  List<ProjectProgress> _filteredProjectsData = [];
  final dbHelper = DBHelper();
  
  // Timer configuration
  Timer? _reloadTimer;
  final Duration _reloadInterval = Duration(minutes: 15); 
  DateTime? _lastUpdate;
  
  // Filter dropdown
  String? _selectedChiTiet2;
  List<String> _chiTiet2Options = [];
  
  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    await _loadChiTiet2Options();
    await _loadProjectsData();
    _startReloadTimer();
  }

  void _startReloadTimer() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer.periodic(_reloadInterval, (timer) {
      _loadProjectsData();
    });
  }

  Future<void> _loadChiTiet2Options() async {
    try {
      final db = await dbHelper.database;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT DISTINCT ChiTiet2
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE Ngay >= ? AND Ngay < ?
        AND ChiTiet2 IS NOT NULL AND ChiTiet2 != ''
        ORDER BY ChiTiet2
      ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

      setState(() {
        _chiTiet2Options = results.map((item) => item['ChiTiet2'] as String).toList();
        _chiTiet2Options.insert(0, 'Tất cả'); // Add "All" option at the beginning
      });
    } catch (e) {
      print('Error loading ChiTiet2 options: $e');
    }
  }

  bool _shouldFilterProject(String projectName) {
    if (projectName.length < 10) return true;
    if (projectName.toLowerCase().startsWith('hm') && 
        RegExp(r'^hm\d+').hasMatch(projectName.toLowerCase())) return true;
    if (projectName.toLowerCase() == 'unknown') return true;
    if (projectName == projectName.toUpperCase() && !projectName.contains(' ')) return true;
    
    // Filter out project names that start with "http:" or "https:"
    if (projectName.toLowerCase().startsWith('http:') || 
        projectName.toLowerCase().startsWith('https:')) return true;
    
    return false;
  }

  Future<void> _loadProjectsData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final db = await dbHelper.database;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      // Build the query with optional ChiTiet2 filter
      String whereClause = 'WHERE Ngay >= ? AND Ngay < ?';
      List<String> queryParams = [startOfDay.toIso8601String(), endOfDay.toIso8601String()];
      
      if (_selectedChiTiet2 != null && _selectedChiTiet2 != 'Tất cả') {
        whereClause += ' AND ChiTiet2 = ?';
        queryParams.add(_selectedChiTiet2!);
      }

      // Load data for today grouped by project (BoPhan)
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT 
          BoPhan as project_name,
          COUNT(*) as total_reports,
          COUNT(CASE WHEN HinhAnh IS NOT NULL AND HinhAnh != '' THEN 1 END) as images_submitted
        FROM ${DatabaseTables.taskHistoryTable}
        $whereClause
        GROUP BY BoPhan
        HAVING BoPhan IS NOT NULL AND BoPhan != ''
        ORDER BY BoPhan
      ''', queryParams);

      final projectsData = results
    .where((item) => !_shouldFilterProject(item['project_name'] as String))
    .map((item) {
      final projectName = item['project_name'] as String;
      final targetImages = projectName.startsWith('Bệnh viện') ? 10 : 15;
      
      return ProjectProgress(
        projectName: projectName,
        totalReports: item['total_reports'] as int,
        imagesSubmitted: item['images_submitted'] as int,
        targetImages: targetImages,
      );
    })
    .toList()
    ..sort((a, b) {
      // Calculate percentage for both projects
      final percentageA = (a.imagesSubmitted / a.targetImages * 100);
      final percentageB = (b.imagesSubmitted / b.targetImages * 100);
      // Sort from lowest to highest percentage
      return percentageA.compareTo(percentageB);
    });

      setState(() {
        _projectsData = projectsData;
        _filteredProjectsData = projectsData;
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      print('Error loading projects data: $e');
      _showError('Lỗi tải dữ liệu dự án: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onChiTiet2FilterChanged(String? value) {
    setState(() {
      _selectedChiTiet2 = value;
    });
    _loadProjectsData();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 90) return Colors.tealAccent[400]!;
    if (percentage >= 70) return Colors.blue[600]!;
    if (percentage >= 50) return Colors.yellow[600]!;
    if (percentage >= 30) return Colors.deepOrange[600]!;
    return Colors.red[600]!;
  }

  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= 1920) {
      return 6;
    } else if (screenWidth >= 1600) {
      return 6; 
    } else if (screenWidth >= 1400) {
      return 5; 
    } else if (screenWidth >= 1200) {
      return 4; 
    } else if (screenWidth >= 900) {
      return 3; 
    } else if (screenWidth >= 600) {
      return 2; 
    } else {
      return 1; // Mobile phones
    }
  }

  Widget _buildProjectCard(ProjectProgress project) {
    final percentage = (project.imagesSubmitted / project.targetImages * 100).clamp(0.0, 100.0);
    final progressColor = _getProgressColor(percentage);

    return Container(
      height: 120, // Increased height to accommodate 2 lines
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: progressColor,
          width: 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            // Background
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
            ),
            // Progress fill - back to solid color
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: progressColor,
                ),
              ),
            ),
            // Content overlay
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Project name with more space
                  Expanded(
                    flex: 3, 
                    child: Center(
                      child: Text(
                        project.projectName,
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2, 
                          shadows: [
                            Shadow(offset: Offset(-1.5, -1.5), color: progressColor),
                            Shadow(offset: Offset(1.5, -1.5), color: progressColor),
                            Shadow(offset: Offset(1.5, 1.5), color: progressColor),
                            Shadow(offset: Offset(-1.5, 1.5), color: progressColor),
                            Shadow(offset: Offset(-1.5, 0), color: progressColor),
                            Shadow(offset: Offset(1.5, 0), color: progressColor),
                            Shadow(offset: Offset(0, -1.5), color: progressColor),
                            Shadow(offset: Offset(0, 1.5), color: progressColor),
                          ],
                        ),
                        maxLines: 3, // Allow up to 3 lines
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Count and percentage section
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${project.imagesSubmitted}/${project.targetImages}',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            shadows: [
                              Shadow(offset: Offset(-1.5, -1.5), color: progressColor),
                              Shadow(offset: Offset(1.5, -1.5), color: progressColor),
                              Shadow(offset: Offset(1.5, 1.5), color: progressColor),
                              Shadow(offset: Offset(-1.5, 1.5), color: progressColor),
                              Shadow(offset: Offset(-1.5, 0), color: progressColor),
                              Shadow(offset: Offset(1.5, 0), color: progressColor),
                              Shadow(offset: Offset(0, -1.5), color: progressColor),
                              Shadow(offset: Offset(0, 1.5), color: progressColor),
                            ],
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(offset: Offset(-1.5, -1.5), color: progressColor),
                              Shadow(offset: Offset(1.5, -1.5), color: progressColor),
                              Shadow(offset: Offset(1.5, 1.5), color: progressColor),
                              Shadow(offset: Offset(-1.5, 1.5), color: progressColor),
                              Shadow(offset: Offset(-1.5, 0), color: progressColor),
                              Shadow(offset: Offset(1.5, 0), color: progressColor),
                              Shadow(offset: Offset(0, -1.5), color: progressColor),
                              Shadow(offset: Offset(0, 1.5), color: progressColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      constraints: BoxConstraints(maxWidth: 150), 
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: DropdownButton<String>(
        value: _selectedChiTiet2 ?? 'Tất cả',
        hint: Text('Filter', style: TextStyle(fontSize: 12)),
        underline: Container(), 
        isExpanded: true,
        icon: Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(fontSize: 12, color: Colors.black87),
        items: _chiTiet2Options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: _onChiTiet2FilterChanged,
      ),
    );
  }

  Widget _buildHeader() {
    return AppBar(
      elevation: 0,
      backgroundColor: Color.fromARGB(255, 79, 255, 214),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Icon(
            Icons.dashboard,
            size: 24, 
            color: Colors.black87,
          ),
          SizedBox(width: 8),
          Text(
            'Tiến độ dự án',
            style: TextStyle(
              fontSize: 20, // Slightly smaller to fit better
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 12),
          // Filter dropdown in app bar
          if (_chiTiet2Options.isNotEmpty) ...[
            _buildFilterDropdown(),
            SizedBox(width: 8),
          ],
          Text(
            DateFormat('dd/MM').format(DateTime.now()),
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      actions: [
        if (_projectsData.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                '${_projectsData.length}/${_projectsData.where((p) => p.imagesSubmitted >= p.targetImages).length}',
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        if (_isLoading)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
              ),
            ),
          ),
        if (!_isLoading && _lastUpdate != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.black54,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: _buildHeader(),
      ),
      body: _projectsData.isEmpty && !_isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 72,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Không có dự án hôm nay',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadProjectsData,
                    icon: Icon(Icons.refresh, size: 24),
                    label: Text(
                      'Tải lại',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(8),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.5, 
                ),
                itemCount: _projectsData.length,
                itemBuilder: (context, index) {
                  return _buildProjectCard(_projectsData[index]);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _loadProjectsData,
        child: Icon(Icons.refresh, size: 27), 
        backgroundColor: Color.fromARGB(255, 79, 255, 214),
        tooltip: 'Tải lại',
      ),
    );
  }
}

// Model class for project progress data
class ProjectProgress {
  final String projectName;
  final int totalReports;
  final int imagesSubmitted;
  final int targetImages;

  ProjectProgress({
    required this.projectName,
    required this.totalReports,
    required this.imagesSubmitted,
    required this.targetImages,
  });
}