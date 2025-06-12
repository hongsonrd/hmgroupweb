import 'package:flutter/material.dart';
import 'dart:async';
import 'db_helper.dart';
import 'table_models.dart';

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
  final Duration _reloadInterval = Duration(minutes: 15); // Reload every 15 minutes
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
            targetImages: 15, // Required 15 images per day
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
    if (percentage >= 100) return Colors.green;
    if (percentage >= 80) return Colors.lightGreen;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 40) return Colors.deepOrange;
    return Colors.red;
  }

  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= 1920) {
      return 8; // Ultra wide screens
    } else if (screenWidth >= 1600) {
      return 7; // Large wide screens
    } else if (screenWidth >= 1400) {
      return 6; // Wide screens
    } else if (screenWidth >= 1200) {
      return 5; // Large screens
    } else if (screenWidth >= 900) {
      return 4; // Medium screens
    } else if (screenWidth >= 600) {
      return 3; // Small tablets
    } else {
      return 2; // Mobile phones
    }
  }

  Widget _buildProjectCard(ProjectProgress project) {
    final percentage = (project.imagesSubmitted / project.targetImages * 100).clamp(0.0, 100.0);
    final progressColor = _getProgressColor(percentage);
    final isCompleted = project.imagesSubmitted >= project.targetImages;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Project name with status icon
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      project.projectName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              
              // Images count
              Text(
                '${project.imagesSubmitted}/${project.targetImages}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
              SizedBox(height: 4),
              
              // Progress bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              
              // Percentage
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.fromARGB(255, 114, 255, 217),
            Color.fromARGB(255, 79, 255, 214),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.dashboard,
            size: 20,
            color: Colors.black87,
          ),
          SizedBox(width: 8),
          Text(
            'Tiến độ dự án',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 16),
          if (_projectsData.isNotEmpty) ...[
            Text(
              '${_projectsData.length} dự án',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '${_projectsData.where((p) => p.imagesSubmitted >= p.targetImages).length} hoàn thành',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
          Spacer(),
          if (_isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
              ),
            ),
          if (!_isLoading && _lastUpdate != null) ...[
            Icon(
              Icons.access_time,
              size: 14,
              color: Colors.black54,
            ),
            SizedBox(width: 4),
            Text(
              '${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _projectsData.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Không có dự án hôm nay',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadProjectsData,
                          icon: Icon(Icons.refresh, size: 16),
                          label: Text('Tải lại'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        childAspectRatio: 1.4, // More compact aspect ratio
                      ),
                      itemCount: _projectsData.length,
                      itemBuilder: (context, index) {
                        return _buildProjectCard(_projectsData[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _loadProjectsData,
        child: Icon(Icons.refresh, size: 18),
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