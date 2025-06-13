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
  final dbHelper = DBHelper();
  
  // Timer configuration
  Timer? _reloadTimer;
  final Duration _reloadInterval = Duration(minutes: 15); 
  DateTime? _lastUpdate;
  
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
    await _loadProjectsData();
    _startReloadTimer();
  }

  void _startReloadTimer() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer.periodic(_reloadInterval, (timer) {
      _loadProjectsData();
    });
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

      // Load data for today grouped by project (BoPhan)
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT 
          BoPhan as project_name,
          COUNT(*) as total_reports,
          COUNT(CASE WHEN HinhAnh IS NOT NULL AND HinhAnh != '' THEN 1 END) as images_submitted
        FROM ${DatabaseTables.taskHistoryTable}
        WHERE Ngay >= ? AND Ngay < ?
        GROUP BY BoPhan
        HAVING BoPhan IS NOT NULL AND BoPhan != ''
        ORDER BY BoPhan
      ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

      final projectsData = results
          .where((item) => !_shouldFilterProject(item['project_name'] as String))
          .map((item) => ProjectProgress(
            projectName: item['project_name'] as String,
            totalReports: item['total_reports'] as int,
            imagesSubmitted: item['images_submitted'] as int,
            targetImages: 15, 
          )).toList();

      setState(() {
        _projectsData = projectsData;
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
  if (percentage >= 90) return Colors.tealAccent;
  if (percentage >= 70) return Colors.blue;
  if (percentage >= 50) return Colors.yellow[400]!;
  if (percentage >= 30) return Colors.deepOrange[400]!;
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
      height: 100, 
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
                  color: progressColor, // Full opacity solid color
                ),
              ),
            ),
            // Content overlay
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        project.projectName,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
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
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center, // Center align for better appearance
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  // Count and percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${project.imagesSubmitted}/${project.targetImages}',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          shadows: [
                            // Multiple shadows to create outline effect
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
                          fontSize: 18, 
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: [
                            // Multiple shadows to create outline effect
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
                ],
              ),
            ),
          ],
        ),
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
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
    Text(
      'Ngày: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      style: TextStyle(
        fontSize: 16,
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
                '${_projectsData.length} dự án • ${_projectsData.where((p) => p.imagesSubmitted >= p.targetImages).length} hoàn thành',
                style: TextStyle(
                  fontSize: 18, 
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
        if (_isLoading)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 24, // Increased size
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
              ),
            ),
          ),
        if (!_isLoading && _lastUpdate != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 21, // Increased from 14 (50% bigger)
                    color: Colors.black54,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18, // Increased from 12 (50% bigger)
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
                    size: 72, // Increased from 48 (50% bigger)
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Không có dự án hôm nay',
                    style: TextStyle(
                      fontSize: 24, // Increased from 16 (50% bigger)
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadProjectsData,
                    icon: Icon(Icons.refresh, size: 24), // Increased from 16
                    label: Text(
                      'Tải lại',
                      style: TextStyle(fontSize: 18), // Increased text size
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
                  childAspectRatio: 3.0,
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