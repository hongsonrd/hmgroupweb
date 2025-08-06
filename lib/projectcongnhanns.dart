// projectcongnhanns.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'table_models.dart';
import 'projectcongnhanllv.dart';

class ProjectCongNhanNS extends StatefulWidget {
  final String username;
  final List<TaskScheduleModel> taskSchedules;
  final List<QRLookupModel> qrLookups;

  const ProjectCongNhanNS({
    Key? key,
    required this.username,
    required this.taskSchedules,
    required this.qrLookups,
  }) : super(key: key);

  @override
  _ProjectCongNhanNSState createState() => _ProjectCongNhanNSState();
}

class _ProjectCongNhanNSState extends State<ProjectCongNhanNS> {
  bool _isLoading = false;
  String _syncStatus = '';
  
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
    _extractProjectPositions();
    await _checkAndSyncHistory();
    _startAutoSync();
    setState(() {});
  }

  void _extractProjectPositions() {
    _projectPositions.clear();
    
    for (final task in widget.taskSchedules) {
      final userMapping = TaskScheduleManager.getUserProjectAndPosition(
        task.username, 
        widget.qrLookups
      );
      
      final projectName = userMapping['projectName'];
      final positionName = userMapping['positionName'];
      
      if (projectName?.isNotEmpty == true && positionName?.isNotEmpty == true) {
        _projectPositions.putIfAbsent(projectName!, () => <String>[]);
        if (!_projectPositions[projectName]!.contains(positionName)) {
          _projectPositions[projectName]!.add(positionName!);
        }
      }
    }
    
    // Sort project names and positions
    _projectOptions = _projectPositions.keys.toList()..sort();
    for (final positions in _projectPositions.values) {
      positions.sort();
    }
    
    // Auto-select first project
    if (_projectOptions.isNotEmpty) {
      _selectedProject = _projectOptions.first;
    }
  }

  void _startAutoSync() {
    // Sync history once a day
    Timer.periodic(Duration(hours: 24), (timer) {
      _syncEvaluationHistory();
    });
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
        Uri.parse('$baseUrl/duanlichsudanhgia'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Convert to model list
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

        // Save to SharedPreferences as JSON
        await _saveEvaluationHistoryLocally(evaluations);
        
        // Update sync time
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
      await _loadLocalEvaluationHistory(); // Load local data if sync fails
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

      // Sort by date and time (newest first)
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
        
        // Add to local history immediately
        final newEvaluation = DepartmentEvaluationModel.fromMap(requestBody);
        setState(() {
          _evaluationHistory.insert(0, newEvaluation); // Add to beginning
        });
        
        // Save updated history locally
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
    showDialog(
      context: context,
      builder: (context) => EvaluationDialog(
        projectName: projectName,
        positionName: positionName,
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 16),
          Text(
            'Đánh giá bộ phận',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Spacer(),
          if (!_isLoading)
            ElevatedButton.icon(
              onPressed: () => _syncEvaluationHistory(),
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Đồng bộ lịch sử'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 2,
              ),
            ),
          if (_isLoading) ...[
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
              ),
            ),
            SizedBox(width: 8),
            Text(
              _syncStatus,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectFilter() {
    return Container(
      padding: EdgeInsets.all(16),
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
          Text(
            'Chọn dự án',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
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
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionsList() {
    if (_selectedProject == null || _projectPositions[_selectedProject] == null) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.work_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'Vui lòng chọn dự án để xem danh sách vị trí',
                style: TextStyle(
                  fontSize: 16,
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
      margin: EdgeInsets.all(16),
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: Colors.indigo[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Danh sách vị trí - $_selectedProject',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[800],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEvaluationHistory(_selectedProject!),
                  icon: Icon(Icons.history, size: 16),
                  label: Text('Xem lịch sử'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: positions.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final position = positions[index];
              
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.indigo[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.work,
                    color: Colors.indigo[600],
                    size: 24,
                  ),
                ),
                title: Text(
                  position,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Vị trí trong dự án $_selectedProject',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: _isLoading 
                      ? null 
                      : () => _showEvaluationDialog(_selectedProject!, position),
                  child: Text('Đánh giá'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
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
      body: Column(
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

class EvaluationDialog extends StatefulWidget {
  final String projectName;
  final String positionName;
  final Function(String, String, String) onSubmit;

  const EvaluationDialog({
    Key? key,
    required this.projectName,
    required this.positionName,
    required this.onSubmit,
  }) : super(key: key);

  @override
  _EvaluationDialogState createState() => _EvaluationDialogState();
}
class _EvaluationDialogState extends State<EvaluationDialog> {
  String? _selectedRating;
  final _descriptionController = TextEditingController();
  final _solutionController = TextEditingController();

  // Add suggestion options for description
  final List<String> _descriptionSuggestions = [
    'Tăng ca',
    'Ôm việc', 
    'Hỗ trợ',
  ];

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
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _solutionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng chọn mức đánh giá'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập mô tả'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onSubmit(
      _selectedRating!,
      _descriptionController.text.trim(),
      _solutionController.text.trim(), // This can be empty now
    );
    
    Navigator.of(context).pop();
  }

  void _addSuggestionToDescription(String suggestion) {
    final currentText = _descriptionController.text;
    String newText;
    
    if (currentText.isEmpty) {
      newText = suggestion;
    } else if (currentText.endsWith(' ') || currentText.endsWith(',') || currentText.endsWith(';')) {
      newText = currentText + suggestion;
    } else {
      newText = currentText + ', ' + suggestion;
    }
    
    _descriptionController.text = newText;
    _descriptionController.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    
    return Dialog(
      child: Container(
        width: isDesktop ? 600 : MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - same as before
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[600],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.rate_review, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đánh giá vị trí',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.positionName} - ${widget.projectName}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating selection - same as before
                    Text(
                      'Chất lượng công việc',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 12),
                    ...(_ratingOptions.map((option) {
                      final isSelected = _selectedRating == option['value'];
                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedRating = option['value'];
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
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
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  option['label'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                                    color: isSelected 
                                        ? option['color']
                                        : Colors.grey[800],
                                  ),
                                ),
                                Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: option['color'],
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList()),
                    SizedBox(height: 24),
                    
                    // Description with suggestions
                    Text(
                      'Mô tả chi tiết *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    // Suggestion chips
                    Text(
                      'Gợi ý:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _descriptionSuggestions.map((suggestion) {
                        return InkWell(
                          onTap: () => _addSuggestionToDescription(suggestion),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 8),
                    
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Nhập mô tả về chất lượng công việc của vị trí này...\nVí dụ: Tăng ca, Ôm việc, Hỗ trợ tốt...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Solution (now optional)
                    Row(
                      children: [
                        Text(
                          'Giải pháp cải thiện',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tùy chọn',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _solutionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Đề xuất giải pháp cải thiện (không bắt buộc)...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    SizedBox(height: 24),
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(
                          'Gửi đánh giá',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
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


// Evaluation History Dialog
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
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    
    return Dialog(
      child: Container(
        width: isDesktop ? 800 : MediaQuery.of(context).size.width * 0.9,
        height: isDesktop ? 700 : MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lịch sử đánh giá',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$projectName (${evaluations.length} bản ghi)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
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
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Chưa có đánh giá nào cho dự án này',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: evaluations.length,
                      itemBuilder: (context, index) {
                        final evaluation = evaluations[index];
                        final ratingColor = _getRatingColor(evaluation.rating);
                        final ratingIcon = _getRatingIcon(evaluation.rating);
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                            size: 16,
                                            color: ratingColor,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            evaluation.rating,
                                            style: TextStyle(
                                              fontSize: 12,
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
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // Position
                                Row(
                                  children: [
                                    Icon(Icons.work, size: 16, color: Colors.grey[600]),
                                    SizedBox(width: 4),
                                    Text(
                                      evaluation.positionName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // Description
                                Text(
                                  'Mô tả:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  evaluation.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                // Solution (if available)
                                if (evaluation.solution.isNotEmpty) ...[
                                  SizedBox(height: 8),
                                  Text(
                                    'Giải pháp:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    evaluation.solution,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                                // Evaluator
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.person, size: 14, color: Colors.grey[500]),
                                    SizedBox(width: 4),
                                    Text(
                                      'Đánh giá bởi: ${evaluation.username}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                        fontStyle: FontStyle.italic,
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