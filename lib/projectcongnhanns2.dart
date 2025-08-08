// projectcongnhanns2.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'projectcongnhanllv2.dart';

class ProjectCongNhanNS extends StatefulWidget {
  final String username;

  const ProjectCongNhanNS({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  _ProjectCongNhanNSState createState() => _ProjectCongNhanNSState();
}

class _ProjectCongNhanNSState extends State<ProjectCongNhanNS> {
  bool _isLoading = false;
  String _syncStatus = '';
  
  // Task schedule data (fetched using TaskScheduleManager)
  List<TaskScheduleModel> _taskSchedules = [];
  List<QRLookupModel> _qrLookups = [];
  
  // Project and position data
  Map<String, List<String>> _projectPositions = {};
  List<String> _projectOptions = [];
  String? _selectedProject;
  
  // Evaluation history - stored locally as JSON strings in SharedPreferences
  List<DepartmentEvaluationModel> _evaluationHistory = [];
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _checkAndSyncTaskSchedules();
    _extractProjectPositions();
    await _checkAndSyncHistory();
    setState(() {});
  }

  Future<void> _checkAndSyncTaskSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('lastTaskScheduleSync_NS') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if it's a new day since last sync
    final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final today = DateTime.now();
    final isNewDay = lastSyncDate.day != today.day || 
                     lastSyncDate.month != today.month || 
                     lastSyncDate.year != today.year;
    
    if (lastSync == 0 || isNewDay) {
      await _syncTaskSchedules();
    } else {
      await _loadLocalTaskSchedules();
    }
  }

  Future<void> _syncTaskSchedules() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ danh sách công việc...';
    });

    try {
      // Use TaskScheduleManager to sync
      await TaskScheduleManager.syncTaskSchedules(baseUrl, widget.username);
      await _loadLocalTaskSchedules();
      
      // Update sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastTaskScheduleSync_NS', DateTime.now().millisecondsSinceEpoch);
      
      _showSuccess('Đồng bộ danh sách công việc thành công - ${_taskSchedules.length} nhiệm vụ, ${_qrLookups.length} ánh xạ');
    } catch (e) {
      print('Error syncing task schedules: $e');
      _showError('Không thể đồng bộ danh sách công việc: ${e.toString()}');
      await _loadLocalTaskSchedules(); // Load local data if sync fails
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _loadLocalTaskSchedules() async {
    try {
      _taskSchedules = await TaskScheduleManager.getTaskSchedules();
      _qrLookups = await TaskScheduleManager.getQRLookups();
    } catch (e) {
      print('Error loading local task schedules: $e');
      _taskSchedules = [];
      _qrLookups = [];
    }
  }

  void _extractProjectPositions() {
    _projectPositions.clear();
    
    // Use TaskScheduleManager to get project names and positions
    _projectOptions = TaskScheduleManager.getAllProjectNames(_qrLookups);
    
    for (final project in _projectOptions) {
      final positions = TaskScheduleManager.getPositionsForProject(project, _qrLookups);
      _projectPositions[project] = positions;
    }
    
    // Auto-select first project
    if (_projectOptions.isNotEmpty) {
      _selectedProject = _projectOptions.first;
    }
  }

  Future<void> _checkAndSyncHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('lastEvaluationHistorySync') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Sync if more than 24 hours since last sync
    if ((now - lastSync) > (24 * 60 * 60 * 1000)) {
      await _syncEvaluationHistory();
    } else {
      await _loadLocalEvaluationHistory();
    }
  }

  Future<void> _syncEvaluationHistory() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ lịch sử đánh giá...';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/duanlichsudanhgia/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final evaluations = data.map((item) => DepartmentEvaluationModel(
          uid: item['UID'] ?? '',
          username: item['Username'] ?? '',
          date: item['Date'] ?? '',
          time: item['Time'] ?? '',
          projectName: item['ProjectName'] ?? '',
          positionName: item['PositionName'] ?? '',
          rating: item['Rating'] ?? '',
          description: item['Description'] ?? '',
          solution: item['Solution'] ?? '',
        )).toList();

        await _saveEvaluationHistoryLocally(evaluations);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastEvaluationHistorySync', DateTime.now().millisecondsSinceEpoch);
        
        setState(() {
          _evaluationHistory = evaluations;
        });
        
        _showSuccess('Đồng bộ lịch sử thành công - ${evaluations.length} bản ghi');
      } else {
        throw Exception('Failed to sync: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing evaluation history: $e');
      _showError('Không thể đồng bộ lịch sử: ${e.toString()}');
      await _loadLocalEvaluationHistory();
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _saveEvaluationHistoryLocally(List<DepartmentEvaluationModel> evaluations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = evaluations.map((e) => json.encode(e.toMap())).toList();
      await prefs.setStringList('departmentEvaluationHistory', jsonList);
    } catch (e) {
      print('Error saving evaluation history locally: $e');
    }
  }

  Future<void> _loadLocalEvaluationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList('departmentEvaluationHistory') ?? [];
      
      final evaluations = jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return DepartmentEvaluationModel.fromMap(map);
      }).toList();

      evaluations.sort((a, b) {
        final dateTimeA = '${a.date} ${a.time}';
        final dateTimeB = '${b.date} ${b.time}';
        return dateTimeB.compareTo(dateTimeA);
      });

      setState(() {
        _evaluationHistory = evaluations;
      });
    } catch (e) {
      print('Error loading local evaluation history: $e');
      setState(() {
        _evaluationHistory = [];
      });
    }
  }

  Future<void> _submitEvaluation({
    required String projectName,
    required String positionName,
    required String rating,
    required String description,
    required String solution,
  }) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang gửi đánh giá...';
   });

   try {
     final now = DateTime.now();
     final uid = 'EVAL_${now.millisecondsSinceEpoch}_${widget.username}';
     
     final requestBody = {
       'UID': uid,
       'Username': widget.username,
       'Date': DateFormat('yyyy-MM-dd').format(now),
       'Time': DateFormat('HH:mm:ss').format(now),
       'ProjectName': projectName,
       'PositionName': positionName,
       'Rating': rating,
       'Description': description,
       'Solution': solution,
     };

     final response = await http.post(
       Uri.parse('$baseUrl/duandanhgia'),
       headers: {'Content-Type': 'application/json'},
       body: json.encode(requestBody),
     );

     if (response.statusCode == 200 || response.statusCode == 201) {
       _showSuccess('Gửi đánh giá thành công');
       
       final newEvaluation = DepartmentEvaluationModel.fromMap(requestBody);
       setState(() {
         _evaluationHistory.insert(0, newEvaluation);
       });
       
       await _saveEvaluationHistoryLocally(_evaluationHistory);
     } else {
       throw Exception('Failed to submit: ${response.statusCode}');
     }
   } catch (e) {
     print('Error submitting evaluation: $e');
     _showError('Không thể gửi đánh giá: ${e.toString()}');
   } finally {
     setState(() {
       _isLoading = false;
       _syncStatus = '';
     });
   }
 }

 void _showEvaluationDialog(String projectName, String positionName) {
   // Get tasks for this specific position
   List<String> positionTasks = _getTasksForPosition(projectName, positionName);
   
   // Get all positions for this project (for the description selection)
   List<String> allPositions = _projectPositions[projectName] ?? [];

   showDialog(
     context: context,
     builder: (context) => EvaluationDialog(
       projectName: projectName,
       positionName: positionName,
       availableTasks: positionTasks,
       allPositions: allPositions,
       onSubmit: (rating, description, solution) {
         _submitEvaluation(
           projectName: projectName,
           positionName: positionName,
           rating: rating,
           description: description,
           solution: solution,
         );
       },
     ),
   );
 }

 List<String> _getTasksForPosition(String projectName, String positionName) {
   List<String> tasks = [];
   
   // Get tasks for this position using the existing TaskScheduleManager functionality
   for (final task in _taskSchedules) {
     final userMapping = TaskScheduleManager.getUserProjectAndPosition(task.username, _qrLookups);
     
     if (userMapping['projectName'] == projectName && 
         userMapping['positionName'] == positionName) {
       tasks.add(task.task); // Use the 'task' property for task name
     }
   }
   
   return tasks.toSet().toList(); // Remove duplicates
 }

 void _showEvaluationHistory(String projectName) {
   final projectHistory = _evaluationHistory
       .where((eval) => eval.projectName == projectName)
       .toList();

   showDialog(
     context: context,
     builder: (context) => EvaluationHistoryDialog(
       projectName: projectName,
       evaluations: projectHistory,
     ),
   );
 }

 void _showPositionTaskList(String projectName, String positionName) {
   showDialog(
     context: context,
     builder: (context) => PositionTaskListDialog(
       projectName: projectName,
       positionName: positionName,
       taskSchedules: _taskSchedules,
       qrLookups: _qrLookups,
     ),
   );
 }

 void _showSuccess(String message) {
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(message),
         backgroundColor: Colors.green,
         duration: Duration(seconds: 2),
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
         duration: Duration(seconds: 3),
       ),
     );
   }
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
           Color.fromARGB(255, 255, 179, 71),
           Color.fromARGB(255, 255, 213, 157),
           Color.fromARGB(255, 255, 165, 79),
           Color.fromARGB(255, 255, 206, 147),
         ],
       ),
     ),
     child: Column(
       children: [
         // Main header row
         Row(
           children: [
             IconButton(
               icon: Icon(Icons.arrow_back, color: Colors.black87, size: isMobile ? 20 : 24),
               onPressed: () => Navigator.of(context).pop(),
               padding: EdgeInsets.zero,
               constraints: BoxConstraints(),
             ),
             SizedBox(width: isMobile ? 12 : 16),
             Expanded(
               child: Text(
                 'Đánh giá các vị trí thiếu',
                 style: TextStyle(
                   fontSize: isMobile ? 20 : 24,
                   fontWeight: FontWeight.bold,
                   color: Colors.black87,
                 ),
               ),
             ),
             if (_isLoading)
               SizedBox(
                 width: 20,
                 height: 20,
                 child: CircularProgressIndicator(
                   strokeWidth: 2,
                   valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                 ),
               ),
           ],
         ),
         // Action buttons row (mobile-optimized)
         if (!_isLoading)
           Container(
             margin: EdgeInsets.only(top: isMobile ? 12 : 16),
             height: isMobile ? 36 : 40,
             child: SingleChildScrollView(
               scrollDirection: Axis.horizontal,
               child: Row(
                 children: [
                   _buildHeaderButton(
                     onPressed: () => _syncTaskSchedules(),
                     icon: Icons.work,
                     label: 'Đồng bộ DS',
                     backgroundColor: Colors.purple[600]!,
                     isMobile: isMobile,
                   ),
                   SizedBox(width: 8),
                   _buildHeaderButton(
                     onPressed: () => _syncEvaluationHistory(),
                     icon: Icons.refresh,
                     label: 'Đồng bộ LS',
                     backgroundColor: Colors.white,
                     textColor: Colors.black87,
                     isMobile: isMobile,
                   ),
                 ],
               ),
             ),
           ),
         // Loading status
         if (_isLoading && _syncStatus.isNotEmpty)
           Container(
             margin: EdgeInsets.only(top: 8),
             child: Text(
               _syncStatus,
               style: TextStyle(
                 color: Colors.black87,
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

 Widget _buildHeaderButton({
   required VoidCallback onPressed,
   required IconData icon,
   required String label,
   required Color backgroundColor,
   Color textColor = Colors.white,
   required bool isMobile,
 }) {
   return ElevatedButton.icon(
     onPressed: onPressed,
     icon: Icon(icon, size: isMobile ? 16 : 18),
     label: Text(
       label,
       style: TextStyle(fontSize: isMobile ? 12 : 14),
     ),
     style: ElevatedButton.styleFrom(
       backgroundColor: backgroundColor,
       foregroundColor: textColor,
       elevation: 2,
       padding: EdgeInsets.symmetric(
         horizontal: isMobile ? 12 : 16,
         vertical: isMobile ? 8 : 12,
       ),
       minimumSize: Size(0, isMobile ? 36 : 40),
     ),
   );
 }

 Widget _buildProjectFilter() {
   final isMobile = MediaQuery.of(context).size.width < 600;
   
   return Container(
     padding: EdgeInsets.all(isMobile ? 12 : 16),
     decoration: BoxDecoration(
       color: Colors.white,
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
         Row(
           children: [
             Expanded(
               child: Text(
                 'Chọn dự án',
                 style: TextStyle(
                   fontSize: isMobile ? 16 : 18,
                   fontWeight: FontWeight.bold,
                   color: Colors.grey[800],
                 ),
               ),
             ),
             if (!isMobile)
               Text(
                 '${_taskSchedules.length} công việc, ${_qrLookups.length} ánh xạ',
                 style: TextStyle(
                   fontSize: 12,
                   color: Colors.grey[600],
                 ),
               ),
           ],
         ),
         if (isMobile) ...[
           SizedBox(height: 4),
           Text(
             '${_taskSchedules.length} công việc, ${_qrLookups.length} ánh xạ',
             style: TextStyle(
               fontSize: 12,
               color: Colors.grey[600],
             ),
           ),
         ],
         SizedBox(height: isMobile ? 12 : 16),
         DropdownButtonFormField<String>(
           value: _selectedProject,
           hint: Text('Chọn dự án để đánh giá'),
           isExpanded: true,
           items: _projectOptions.map((project) {
             return DropdownMenuItem(
               value: project,
               child: Text(
                 project,
                 overflow: TextOverflow.ellipsis,
               ),
             );
           }).toList(),
           onChanged: (value) {
             setState(() {
               _selectedProject = value;
             });
           },
           decoration: InputDecoration(
             border: OutlineInputBorder(
               borderRadius: BorderRadius.circular(8),
             ),
             contentPadding: EdgeInsets.symmetric(
               horizontal: 12,
               vertical: isMobile ? 12 : 8,
             ),
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildPositionsList() {
   final isMobile = MediaQuery.of(context).size.width < 600;
   
   if (_selectedProject == null || _projectPositions[_selectedProject] == null) {
     return Container(
       padding: EdgeInsets.all(32),
       child: Center(
         child: Column(
           children: [
             Icon(
               Icons.work_outline,
               size: isMobile ? 48 : 64,
               color: Colors.grey[400],
             ),
             SizedBox(height: 16),
             Text(
               'Vui lòng chọn dự án để xem danh sách vị trí',
               style: TextStyle(
                 fontSize: isMobile ? 14 : 16,
                 color: Colors.grey[600],
               ),
               textAlign: TextAlign.center,
             ),
           ],
         ),
       ),
     );
   }

   final positions = _projectPositions[_selectedProject]!;
   
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
             color: Colors.indigo[50],
             borderRadius: BorderRadius.only(
               topLeft: Radius.circular(8),
               topRight: Radius.circular(8),
             ),
           ),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 children: [
                   Icon(Icons.people_outline, color: Colors.indigo[600]),
                   SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       'Danh sách vị trí - $_selectedProject',
                       style: TextStyle(
                         fontSize: isMobile ? 16 : 18,
                         fontWeight: FontWeight.bold,
                         color: Colors.indigo[800],
                       ),
                     ),
                   ),
                 ],
               ),
               SizedBox(height: isMobile ? 8 : 12),
               ElevatedButton.icon(
                 onPressed: () => _showEvaluationHistory(_selectedProject!),
                 icon: Icon(Icons.history, size: isMobile ? 14 : 16),
                 label: Text(
                   'Xem lịch sử',
                   style: TextStyle(fontSize: isMobile ? 12 : 14),
                 ),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.blue[600],
                   foregroundColor: Colors.white,
                   padding: EdgeInsets.symmetric(
                     horizontal: isMobile ? 10 : 12,
                     vertical: isMobile ? 6 : 8,
                   ),
                   minimumSize: Size(0, isMobile ? 32 : 36),
                 ),
               ),
             ],
           ),
         ),
         // Positions list
         ListView.separated(
           shrinkWrap: true,
           physics: NeverScrollableScrollPhysics(),
           itemCount: positions.length,
           separatorBuilder: (context, index) => Divider(height: 1),
           itemBuilder: (context, index) {
             final position = positions[index];
             
             return Padding(
               padding: EdgeInsets.all(isMobile ? 12 : 16),
               child: Row(
                 children: [
                   // Position icon and info
                   Container(
                     width: isMobile ? 40 : 48,
                     height: isMobile ? 40 : 48,
                     decoration: BoxDecoration(
                       color: Colors.indigo[100],
                       borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                     ),
                     child: Icon(
                       Icons.work,
                       color: Colors.indigo[600],
                       size: isMobile ? 20 : 24,
                     ),
                   ),
                   SizedBox(width: isMobile ? 12 : 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           position,
                           style: TextStyle(
                             fontSize: isMobile ? 14 : 16,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                         Text(
                           'Vị trí trong dự án $_selectedProject',
                           style: TextStyle(
                             fontSize: isMobile ? 11 : 12,
                             color: Colors.grey[600],
                           ),
                         ),
                       ],
                     ),
                   ),
                   // Action buttons
                   Column(
                     children: [
                       SizedBox(
                         width: isMobile ? 80 : 90,
                         height: isMobile ? 32 : 36,
                         child: ElevatedButton(
                           onPressed: _isLoading 
                               ? null 
                               : () => _showPositionTaskList(_selectedProject!, position),
                           child: Text(
                             'Xem lịch',
                             style: TextStyle(fontSize: isMobile ? 11 : 12),
                           ),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.green[600],
                             foregroundColor: Colors.white,
                             padding: EdgeInsets.symmetric(horizontal: 8),
                           ),
                         ),
                       ),
                       SizedBox(height: 6),
                       SizedBox(
                         width: isMobile ? 80 : 90,
                         height: isMobile ? 32 : 36,
                         child: ElevatedButton(
                           onPressed: _isLoading 
                               ? null 
                               : () => _showEvaluationDialog(_selectedProject!, position),
                           child: Text(
                             'Đánh giá',
                             style: TextStyle(fontSize: isMobile ? 11 : 12),
                           ),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.orange[600],
                             foregroundColor: Colors.white,
                             padding: EdgeInsets.symmetric(horizontal: 8),
                           ),
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
             );
           },
         ),
       ],
     ),
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
           _buildProjectFilter(),
           Expanded(
             child: SingleChildScrollView(
               child: _buildPositionsList(),
             ),
           ),
         ],
       ),
     ),
   );
 }
}

// Department Evaluation Model (local to this file only)
class DepartmentEvaluationModel {
 final String uid;
 final String username;
 final String date;
 final String time;
 final String projectName;
 final String positionName;
 final String rating;
 final String description;
 final String solution;

 DepartmentEvaluationModel({
   required this.uid,
   required this.username,
   required this.date,
   required this.time,
   required this.projectName,
   required this.positionName,
   required this.rating,
   required this.description,
   required this.solution,
 });

 Map<String, dynamic> toMap() {
   return {
     'UID': uid,
     'Username': username,
     'Date': date,
     'Time': time,
     'ProjectName': projectName,
     'PositionName': positionName,
     'Rating': rating,
     'Description': description,
     'Solution': solution,
   };
 }

 factory DepartmentEvaluationModel.fromMap(Map<String, dynamic> map) {
   return DepartmentEvaluationModel(
     uid: map['UID'] ?? '',
     username: map['Username'] ?? '',
     date: map['Date'] ?? '',
     time: map['Time'] ?? '',
     projectName: map['ProjectName'] ?? '',
     positionName: map['PositionName'] ?? '',
     rating: map['Rating'] ?? '',
     description: map['Description'] ?? '',
     solution: map['Solution'] ?? '',
   );
 }
}

// Updated Evaluation Dialog with new requirements
class EvaluationDialog extends StatefulWidget {
 final String projectName;
 final String positionName;
 final List<String> availableTasks;
 final List<String> allPositions;
 final Function(String, String, String) onSubmit;

 const EvaluationDialog({
   Key? key,
   required this.projectName,
   required this.positionName,
   required this.availableTasks,
   required this.allPositions,
   required this.onSubmit,
 }) : super(key: key);

 @override
 _EvaluationDialogState createState() => _EvaluationDialogState();
}

class _EvaluationDialogState extends State<EvaluationDialog> {
 String? _selectedRating;
 String _descriptionText = '';
 String _solutionText = '';
 
 List<String> _selectedTasks = [];
 String? _selectedSolutionType;
 List<String> _selectedPositions = [];

 final List<String> _solutionTypes = ['Tăng ca', 'Ôm việc', 'Hỗ trợ'];

 final List<Map<String, dynamic>> _ratingOptions = [
   {
     'value': 'Đảm bảo',
     'label': 'Đảm bảo',
     'color': Colors.green,
     'icon': Icons.check_circle,
   },
   {
     'value': 'Tạm ổn',
     'label': 'Tạm ổn',
     'color': Colors.orange,
     'icon': Icons.warning,
   },
   {
     'value': 'Không tốt',
     'label': 'Không tốt',
     'color': Colors.red,
     'icon': Icons.error,
   },];

@override
void initState() {
  super.initState();
  _autoSelectRating();
}

void _autoSelectRating() {
  // Auto select rating based on number of unhandled tasks
  if (_selectedTasks.isEmpty) {
    _selectedRating = 'Đảm bảo';
  } else if (_selectedTasks.length < 3) {
    _selectedRating = 'Tạm ổn';
  } else {
    _selectedRating = 'Không tốt';
  }
}

void _updateTaskSelection() {
  _updateSolutionText();
  _autoSelectRating();
  setState(() {});
}

void _updateDescriptionSelection() {
  _updateDescriptionText();
  setState(() {});
}

void _updateSolutionText() {
  if (_selectedTasks.isNotEmpty) {
    _solutionText = _selectedTasks.join(' / ');
  } else {
    _solutionText = '';
  }
}

void _updateDescriptionText() {
  if (_selectedSolutionType != null && _selectedPositions.isNotEmpty) {
    _descriptionText = '$_selectedSolutionType: ${_selectedPositions.join(' / ')}';
  } else {
    _descriptionText = '';
  }
}

void _showTaskSelectionDialog() {
  showDialog(
    context: context,
    builder: (context) => MultiSelectDialog(
      title: 'Chọn những việc chưa xử lý',
      items: widget.availableTasks,
      selectedItems: _selectedTasks,
      onSelectionChanged: (selectedItems) {
        setState(() {
          _selectedTasks = selectedItems;
          _updateTaskSelection();
        });
      },
    ),
  );
}
void _showSolutionTypeDialog() {
  showDialog(
    context: context,
    builder: (context) => SingleSelectDialog(
      title: 'Chọn phương án xử lý',
      items: _solutionTypes,
      selectedItem: _selectedSolutionType,
      onItemSelected: (selectedItem) {
        setState(() {
          _selectedSolutionType = selectedItem;
          _selectedPositions.clear(); // Reset position selection
          _updateDescriptionSelection();
        });
      },
    ),
  ).then((_) {
    // This runs after the solution type dialog is closed
    // Show position selection dialog if a solution type was selected
    if (_selectedSolutionType != null) {
      // Add a small delay to ensure the first dialog is fully closed
      Future.delayed(Duration(milliseconds: 100), () {
        _showPositionSelectionDialog();
      });
    }
  });
}
void _showPositionSelectionDialog() {
  // Create list with "Hỗ trợ" as first option, then all positions
  List<String> positionOptions = ['Hỗ trợ', ...widget.allPositions];
  
  showDialog(
    context: context,
    builder: (context) => MultiSelectDialog(
      title: 'Chọn vị trí $_selectedSolutionType',
      items: positionOptions,
      selectedItems: _selectedPositions,
      onSelectionChanged: (selectedItems) {
        setState(() {
          _selectedPositions = selectedItems;
          _updateDescriptionSelection();
        });
      },
    ),
  );
}

void _submit() {
  if (_selectedRating == null) {
    _showSnackBar('Vui lòng chọn mức đánh giá', Colors.red);
    return;
  }

  if (_descriptionText.trim().isEmpty) {
    _showSnackBar('Vui lòng chọn mô tả vị trí và phương án xử lý', Colors.red);
    return;
  }

  widget.onSubmit(_selectedRating!, _descriptionText, _solutionText);
  Navigator.of(context).pop();
}

void _showSnackBar(String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: Duration(seconds: 2),
    ),
  );
}

@override
Widget build(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 600;
  
  return Dialog(
    child: Container(
      width: isMobile ? MediaQuery.of(context).size.width * 0.95 : 600,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.orange[600],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.rate_review, color: Colors.white, size: isMobile ? 20 : 24),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đánh giá vị trí',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.positionName} - ${widget.projectName}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isMobile ? 12 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: isMobile ? 20 : 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unhandled tasks section
                  Text(
                    'Những việc chưa xử lý của vị trí này hôm nay',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: _showTaskSelectionDialog,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _solutionText.isEmpty 
                                  ? 'Nhấn để chọn các công việc chưa xử lý...' 
                                  : _solutionText,
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: _solutionText.isEmpty 
                                    ? Colors.grey[600] 
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedTasks.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      '${_selectedTasks.length} công việc đã chọn',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  
                  // Description section
                  Text(
                    'Mô tả vị trí, phương án xử lý *',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: _showSolutionTypeDialog,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _descriptionText.isEmpty 
                                  ? 'Nhấn để chọn phương án xử lý và vị trí...' 
                                  : _descriptionText,
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: _descriptionText.isEmpty 
                                    ? Colors.grey[600] 
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedSolutionType != null && _selectedPositions.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      '$_selectedSolutionType: ${_selectedPositions.length} vị trí',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  
                  // Rating selection (auto-selected but user can change)
                  Text(
                    'Chất lượng công việc',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  ...(_ratingOptions.map((option) {
                    final isSelected = _selectedRating == option['value'];
                    return Container(
                      margin: EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedRating = option['value'];
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 8 : 12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? option['color'].withOpacity(0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected 
                                  ? option['color']
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                option['icon'],
                                color: isSelected 
                                    ? option['color']
                                    : Colors.grey[600],
                                size: isMobile ? 20 : 24,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option['label'],
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    fontWeight: isSelected 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                                    color: isSelected 
                                        ? option['color']
                                        : Colors.grey[800],
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: option['color'],
                                  size: isMobile ? 16 : 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList()),
                  
                  SizedBox(height: 20),
                  
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(
                        'Gửi đánh giá',
                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
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

// Multi-select dialog widget
class MultiSelectDialog extends StatefulWidget {
final String title;
final List<String> items;
final List<String> selectedItems;
final Function(List<String>) onSelectionChanged;

const MultiSelectDialog({
  Key? key,
  required this.title,
  required this.items,
  required this.selectedItems,
  required this.onSelectionChanged,
}) : super(key: key);

@override
_MultiSelectDialogState createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
List<String> _tempSelectedItems = [];

@override
void initState() {
  super.initState();
  _tempSelectedItems = List.from(widget.selectedItems);
}

@override
Widget build(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 600;
  
  return AlertDialog(
    title: Text(
      widget.title,
      style: TextStyle(fontSize: isMobile ? 16 : 18),
    ),
    content: Container(
      width: double.maxFinite,
      height: isMobile ? 300 : 400,
      child: widget.items.isEmpty
          ? Center(
              child: Text(
                'Không có mục nào để chọn',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : ListView.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = _tempSelectedItems.contains(item);
                
                return CheckboxListTile(
                  title: Text(
                    item,
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        if (!_tempSelectedItems.contains(item)) {
                          _tempSelectedItems.add(item);
                        }
                      } else {
                        _tempSelectedItems.remove(item);
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: isMobile,
                );
              },
            ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text('Hủy'),
      ),
      ElevatedButton(
        onPressed: () {
          widget.onSelectionChanged(_tempSelectedItems);
          Navigator.of(context).pop();
        },
        child: Text('Xác nhận'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
        ),
      ),
    ],
  );
}
}
// Updated Single-select dialog widget
class SingleSelectDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final Function(String?) onItemSelected;

  const SingleSelectDialog({
    Key? key,
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  _SingleSelectDialogState createState() => _SingleSelectDialogState();
}

class _SingleSelectDialogState extends State<SingleSelectDialog> {
  String? _tempSelectedItem;

  @override
  void initState() {
    super.initState();
    _tempSelectedItem = widget.selectedItem;
  }

  void _selectAndClose(String? value) {
    setState(() {
      _tempSelectedItem = value;
    });
    
    // Small delay to show the selection visually, then close
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        widget.onItemSelected(value);
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return AlertDialog(
      title: Text(
        widget.title,
        style: TextStyle(fontSize: isMobile ? 16 : 18),
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.items.map((item) {
            return RadioListTile<String>(
              title: Text(
                item,
                style: TextStyle(fontSize: isMobile ? 13 : 14),
              ),
              value: item,
              groupValue: _tempSelectedItem,
              onChanged: (value) {
                _selectAndClose(value);
              },
              dense: isMobile,
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Hủy'),
        ),
        if (_tempSelectedItem != null)
          ElevatedButton(
            onPressed: () {
              widget.onItemSelected(_tempSelectedItem);
              Navigator.of(context).pop();
            },
            child: Text('Xác nhận'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}
// Evaluation History Dialog (mobile-optimized)
class EvaluationHistoryDialog extends StatelessWidget {
final String projectName;
final List<DepartmentEvaluationModel> evaluations;

const EvaluationHistoryDialog({
  Key? key,
  required this.projectName,
  required this.evaluations,
}) : super(key: key);

Color _getRatingColor(String rating) {
  switch (rating) {
    case 'Đảm bảo':
      return Colors.green;
    case 'Tạm ổn':
      return Colors.orange;
    case 'Không tốt':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

IconData _getRatingIcon(String rating) {
  switch (rating) {
    case 'Đảm bảo':
      return Icons.check_circle;
    case 'Tạm ổn':
      return Icons.warning;
    case 'Không tốt':
      return Icons.error;
    default:
      return Icons.help;
  }
}

@override
Widget build(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 600;
  
  return Dialog(
    child: Container(
      width: isMobile ? MediaQuery.of(context).size.width * 0.95 : 800,
      height: isMobile ? MediaQuery.of(context).size.height * 0.85 : 700,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.white, size: isMobile ? 20 : 24),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lịch sử đánh giá',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$projectName (${evaluations.length} bản ghi)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isMobile ? 12 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: isMobile ? 20 : 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Evaluations list
          Expanded(
            child: evaluations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: isMobile ? 48 : 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có đánh giá nào cho dự án này',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    itemCount: evaluations.length,
                    itemBuilder: (context, index) {
                      final evaluation = evaluations[index];
                      final ratingColor = _getRatingColor(evaluation.rating);
                      final ratingIcon = _getRatingIcon(evaluation.rating);
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                        elevation: isMobile ? 1 : 2,
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 6 : 8,
                                      vertical: isMobile ? 3 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ratingColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: ratingColor),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          ratingIcon,
                                          size: isMobile ? 14 : 16,
                                          color: ratingColor,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          evaluation.rating,
                                          style: TextStyle(
                                            fontSize: isMobile ? 11 : 12,
                                            fontWeight: FontWeight.bold,
                                            color: ratingColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    '${evaluation.date} ${evaluation.time}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              // Position
                              Row(
                                children: [
                                  Icon(Icons.work, size: isMobile ? 14 : 16, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      evaluation.positionName,
                                      style: TextStyle(
                                        fontSize: isMobile ? 13 : 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              // Description
                              Text(
                                'Mô tả:',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                evaluation.description,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  color: Colors.grey[800],
                                ),
                              ),
                              // Solution (if available)
                              if (evaluation.solution.isNotEmpty) ...[
                                SizedBox(height: 8),
                                Text(
                                  'Việc chưa xử lý:',
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  evaluation.solution,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                              // Evaluator
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.person, size: isMobile ? 12 : 14, color: Colors.grey[500]),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Đánh giá bởi: ${evaluation.username}',
                                      style: TextStyle(
                                        fontSize: isMobile ? 10 : 11,
                                        color: Colors.grey[500],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
}