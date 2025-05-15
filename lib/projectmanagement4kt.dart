import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:io';
import 'dart:convert'; // Add this import for jsonEncode and jsonDecode
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({Key? key}) : super(key: key);

  @override
  _WorkerDashboardState createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> with SingleTickerProviderStateMixin {
  String _username = '';
  GoCleanTaiKhoanModel? _userProfile;
  final DBHelper _dbHelper = DBHelper();
  bool _isLoading = true;
  final Random _random = Random();
  int _avatarIndex = 0;
  
  // Task data
  List<GoCleanCongViecModel> _allTasks = [];
  List<GoCleanYeuCauModel> _workRequests = [];
  Map<String, GoCleanYeuCauModel> _requestDetailsMap = {};
  
  // For tab controller
  late TabController _tabController;
  
  // For image picking
  final ImagePicker _picker = ImagePicker();
  File? _beforeImage;
  File? _afterImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsername();
    _avatarIndex = _random.nextInt(21);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    try {
      final userCredentials = Provider.of<UserCredentials>(context, listen: false);
      setState(() {
        _username = userCredentials.username;
      });
      await _loadUserProfile();
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _dbHelper.getAllGoCleanTaiKhoan();
      final matchingUser = users.firstWhere(
        (user) => user.taiKhoan == _username,
        orElse: () => GoCleanTaiKhoanModel(),
      );

      setState(() {
        _userProfile = matchingUser;
      });

      // Load user's tasks
      await _loadWorkerTasks();
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Load all tasks assigned to this worker
  Future<void> _loadWorkerTasks() async {
    try {
      print('Loading tasks for worker: $_username');
      
      // Get all tasks
      final allTasks = await _dbHelper.getAllGoCleanCongViec();
      print('Loaded ${allTasks.length} total tasks from database');
      
      // Filter tasks by NguoiThucHien
      final workerTasks = allTasks.where((task) => 
        task.nguoiThucHien == _username
      ).toList();
      
      print('Found ${workerTasks.length} tasks assigned to $_username');
      
      // Get all work request details to link with tasks
      final allRequests = await _dbHelper.getAllGoCleanYeuCau();
      
      // Create lookup map for easier access
      Map<String, GoCleanYeuCauModel> requestMap = {};
      for (var request in allRequests) {
        if (request.giaoViecID != null) {
          requestMap[request.giaoViecID!] = request;
        }
      }
      
      // Sort tasks by date
      workerTasks.sort((a, b) {
        if (a.ngay == null) return 1;
        if (b.ngay == null) return -1;
        return a.ngay!.compareTo(b.ngay!);
      });
      
      setState(() {
        _allTasks = workerTasks;
        _requestDetailsMap = requestMap;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading worker tasks: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Determine task status
  String getTaskStatus(GoCleanCongViecModel task) {
    if (task.xacNhan == 'Đã hoàn thành') {
      return 'Đã làm';
    } else if (task.mocBatDau != null && task.mocBatDau!.isNotEmpty && task.mocKetThuc == null) {
      return 'Đang làm';
    } else if (task.ngay != null && task.ngay!.isBefore(DateTime.now()) && task.mocBatDau == null) {
      return 'Chưa làm';
    } else {
      return 'Cần làm';
    }
  }
  
  // Group tasks by status for Today tab
  Map<String, List<GoCleanCongViecModel>> getGroupedTodayTasks() {
    final today = DateTime.now();
    today.subtract(Duration(hours: today.hour, minutes: today.minute, seconds: today.second, milliseconds: today.millisecond, microseconds: today.microsecond));
    
    // Filter tasks for today or earlier
    final todayOrEarlierTasks = _allTasks.where((task) => 
      task.ngay != null && 
      (task.ngay!.isAtSameMomentAs(today) || task.ngay!.isBefore(today))
    ).toList();
    
    // Group by status
    Map<String, List<GoCleanCongViecModel>> groupedTasks = {
      'Đang làm': [],
      'Cần làm': [],
      'Đã làm': [],
      'Chưa làm': [],
    };
    
    for (var task in todayOrEarlierTasks) {
      final status = getTaskStatus(task);
      groupedTasks[status]?.add(task);
    }
    
    // Sort each group by ThoiGianBatDau for priority
    for (var status in groupedTasks.keys) {
      groupedTasks[status]?.sort((a, b) {
        // Get the work request details for sorting by ThoiGianBatDau
        final requestA = _requestDetailsMap[a.giaoViecID];
        final requestB = _requestDetailsMap[b.giaoViecID];
        
        final timeA = requestA?.thoiGianBatDau ?? '';
        final timeB = requestB?.thoiGianBatDau ?? '';
        
        return timeA.compareTo(timeB);
      });
    }
    
    return groupedTasks;
  }
  
  // Get upcoming tasks for second tab
  List<GoCleanCongViecModel> getUpcomingTasks() {
    final today = DateTime.now();
    today.subtract(Duration(hours: today.hour, minutes: today.minute, seconds: today.second, milliseconds: today.millisecond, microseconds: today.microsecond));
    
    return _allTasks.where((task) => 
      task.ngay != null && 
      task.ngay!.isAfter(today) &&
      task.mocBatDau == null
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: _buildCompactProfileBar(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _userProfile == null || _userProfile?.taiKhoan == null
              ? Center(
                  child: Text(
                    'Không tìm thấy hồ sơ người dùng',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : Column(
                  children: [
                    // User info card (optional, can be removed for more space)
                    // IntrinsicHeight(
                    //   child: _buildCompactUserInfoCard(),
                    // ),
                    
                    // Tab bar for task categories
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.blue[800],
                        unselectedLabelColor: Colors.grey[600],
                        indicatorColor: Colors.blue,
                        tabs: [
                          Tab(text: 'Công việc hôm nay'),
                          Tab(text: 'Sắp tới'),
                        ],
                      ),
                    ),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Today's tasks
                          _buildTodayTasksList(),
                          
                          // Upcoming tasks
                          _buildUpcomingTasksList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCompactProfileBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black, size: 22),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            
            // Avatar - much smaller
            Container(
              padding: EdgeInsets.all(1),
              margin: EdgeInsets.only(left: 4, right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundImage: AssetImage('assets/avatar/avatar_$_avatarIndex.png'),
                backgroundColor: Colors.grey[300],
              ),
            ),
            
            // User info in appbar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userProfile?.taiKhoan ?? _username,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        _userProfile?.phanLoai ?? 'Chưa xác định',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _userProfile?.diaDiem ?? 'Chưa có địa điểm',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Refresh button to reload data
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.blue, size: 20),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                await _loadWorkerTasks();
              },
              tooltip: 'Refresh data',
            ),
          ],
        ),
      ),
    );
  }

  // Today's tasks list with grouped sections
  Widget _buildTodayTasksList() {
    final groupedTasks = getGroupedTodayTasks();
    
    // All groups empty
    if (groupedTasks.values.every((list) => list.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Không có công việc nào cho hôm nay',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView(
      padding: EdgeInsets.all(8),
      children: [
        // In-progress tasks section
        if (groupedTasks['Đang làm']!.isNotEmpty)
          _buildTaskSection('Đang làm', groupedTasks['Đang làm']!, Colors.orange),
          
        // To-do tasks section (for today)
        if (groupedTasks['Cần làm']!.isNotEmpty)
          _buildTaskSection('Cần làm', groupedTasks['Cần làm']!, Colors.blue),
        
        // Completed tasks section
        if (groupedTasks['Đã làm']!.isNotEmpty)
          _buildTaskSection('Đã làm', groupedTasks['Đã làm']!, Colors.green),
        
        // Missed tasks section
        if (groupedTasks['Chưa làm']!.isNotEmpty)
          _buildTaskSection('Chưa làm', groupedTasks['Chưa làm']!, Colors.red),
      ],
    );
  }
  
  // Upcoming tasks list
  Widget _buildUpcomingTasksList() {
    final upcomingTasks = getUpcomingTasks();
    
    if (upcomingTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Không có công việc nào sắp tới',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Group upcoming tasks by date
    Map<String, List<GoCleanCongViecModel>> tasksByDate = {};
    
    for (var task in upcomingTasks) {
      if (task.ngay != null) {
        final dateKey = '${task.ngay!.day}/${task.ngay!.month}/${task.ngay!.year}';
        if (!tasksByDate.containsKey(dateKey)) {
          tasksByDate[dateKey] = [];
        }
        tasksByDate[dateKey]!.add(task);
      }
    }
    
    // Sort dates chronologically
    final sortedDates = tasksByDate.keys.toList()
      ..sort((a, b) {
        final partsA = a.split('/').map(int.parse).toList();
        final partsB = b.split('/').map(int.parse).toList();
        final dateA = DateTime(partsA[2], partsA[1], partsA[0]);
        final dateB = DateTime(partsB[2], partsB[1], partsB[0]);
        return dateA.compareTo(dateB);
      });
    
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        return _buildTaskSection(
          'Ngày $dateKey', 
          tasksByDate[dateKey]!, 
          Colors.purple,
        );
      },
    );
  }
  
  // Task section with header
  Widget _buildTaskSection(String title, List<GoCleanCongViecModel> tasks, Color headerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          margin: EdgeInsets.only(top: 12, bottom: 4),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: headerColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                title == 'Đang làm' ? Icons.hourglass_top :
                title == 'Cần làm' ? Icons.assignment :
                title == 'Đã làm' ? Icons.check_circle :
                title == 'Chưa làm' ? Icons.warning : 
                Icons.event,
                size: 16,
                color: headerColor,
              ),
              SizedBox(width: 8),
              Text(
                '$title (${tasks.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                ),
              ),
            ],
          ),
        ),
        
        // Tasks list
        ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return _buildTaskCard(tasks[index]);
          },
        ),
      ],
    );
  }
  
  // Task card
  Widget _buildTaskCard(GoCleanCongViecModel task) {
    // Get related work request details
    final workRequest = _requestDetailsMap[task.giaoViecID];
    
    final taskStatus = getTaskStatus(task);
    
    // Card color based on status
    Color cardColor = Colors.white;
    if (taskStatus == 'Đã làm') {
      cardColor = Colors.green[50]!;
    } else if (taskStatus == 'Đang làm') {
      cardColor = Colors.orange[50]!;
    } else if (taskStatus == 'Chưa làm') {
      cardColor = Colors.red[50]!;
    }
    
    // Format date for display
    final taskDate = task.ngay != null 
        ? '${task.ngay!.day}/${task.ngay!.month}/${task.ngay!.year}'
        : 'N/A';
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 1,
      color: cardColor,
      child: InkWell(
        onTap: () {
          _showTaskDetails(task, workRequest);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      workRequest?.moTaCongViec ?? 'Không có mô tả',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      taskDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Area details
              if (workRequest?.khuVucThucHien != null) 
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.blue[700]),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        workRequest!.khuVucThucHien!,
                        style: TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              
              // Location and time
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.business, size: 14, color: Colors.blue[700]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            workRequest?.diaDiem ?? 'N/A',
                            style: TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: 16),
                  
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.blue[700]),
                      SizedBox(width: 4),
                      Text(
                        '${workRequest?.thoiGianBatDau ?? "N/A"} - ${workRequest?.thoiGianKetThuc ?? "N/A"}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Bottom row with status and button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(taskStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      taskStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(taskStatus),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  // Action button based on status
                  if (taskStatus == 'Cần làm' || taskStatus == 'Chưa làm')
                    ElevatedButton(
                      onPressed: () {
                        _startTask(task, workRequest);
                      },
                      child: Text(
                        'Bắt đầu làm',
                        style: TextStyle(fontSize: 12, color: Colors.white,),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size(10, 10),
                        backgroundColor: Colors.blue,
                      ),
                    )
                  else if (taskStatus == 'Đang làm')
                    ElevatedButton(
                      onPressed: () {
                        _finishTask(task, workRequest);
                      },
                      child: Text(
                        'Xong việc',
                        style: TextStyle(fontSize: 12, color: Colors.white,),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size(10, 10),
                        backgroundColor: Colors.green,
                      ),
                    )
                  else
                    OutlinedButton(
                      onPressed: () {
                        _showTaskDetails(task, workRequest);
                      },
                      child: Text(
                        'Chi tiết',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size(10, 10),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Start a task workflow
  Future<void> _startTask(GoCleanCongViecModel task, GoCleanYeuCauModel? workRequest) async {
    // First - scan QR code
    String qrCode = await _scanQRCode();
    
    if (qrCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Code is required to start task'))
      );
      return;
    }
    
    // Then - take before image
    await _takePicture('before');
    
    if (_beforeImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hình ảnh trước khi làm là bắt buộc'))
      );
      return;
    }
    
    // Show loading indicator for upload
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Đang tải lên hình ảnh...'),
              ],
            ),
          ),
        );
      },
    );
    
    try {
      // Upload the before image and get URL
      String? beforeImageUrl;
      if (_beforeImage != null && _beforeImage!.existsSync()) {
        beforeImageUrl = await _uploadImage(
          _beforeImage!, 
          'worker_images', 
          '${task.lichLamViecID}_before'
        );
      }
      
      // Update task with start information
      GoCleanCongViecModel updatedTask = GoCleanCongViecModel(
        lichLamViecID: task.lichLamViecID,
        giaoViecID: task.giaoViecID,
        ngay: task.ngay,
        nguoiThucHien: _username,
        xacNhan: 'Đang thực hiện',
        qrCode: qrCode,
        mocBatDau: DateTime.now().toString(),
        hinhAnhTruoc: beforeImageUrl,
        mocKetThuc: null,
        hinhAnhSau: null,
        thucHienDanhGia: null,
        moTaThucHien: null,
        khachHang: task.khachHang,
        khachHangDanhGia: task.khachHangDanhGia,
        thoiGianDanhGia: task.thoiGianDanhGia,
        khachHangMoTa: task.khachHangMoTa,
        khachHangChupAnh: task.khachHangChupAnh,
        trangThai: task.trangThai,
      );
      
      // Submit to server
      var response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/cleancongviecxong'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lichLamViecID': updatedTask.lichLamViecID ?? '',
          'giaoViecID': updatedTask.giaoViecID ?? '',
          'nguoiThucHien': updatedTask.nguoiThucHien ?? '',
          'qrCode': updatedTask.qrCode ?? '',
          'mocBatDau': updatedTask.mocBatDau ?? '',
          'hinhAnhTruoc': beforeImageUrl,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to submit task start. Status code: ${response.statusCode}');
      }
      
      // Update task in local database
      await _dbHelper.updateGoCleanCongViec(updatedTask);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã bắt đầu công việc thành công'))
      );
      
      // Reload tasks to reflect changes
      _loadWorkerTasks();
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi bắt đầu công việc: ${e.toString()}'),
          duration: Duration(seconds: 5),
        )
      );
      print('Error in _startTask: $e');
    }
  }
  
  // Finish a task workflow
  Future<void> _finishTask(GoCleanCongViecModel task, GoCleanYeuCauModel? workRequest) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Đang xử lý công việc...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Take after image
      await _takePicture('after');
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      if (_afterImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hình ảnh sau khi làm là bắt buộc'))
        );
        return;
      }
      
      // Get worker's rating and description
      final result = await _showRatingDialog();
      
      if (result == null) {
        return; // User cancelled
      }
      // Show loading indicator again for upload process
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Đang tải lên dữ liệu...'),
                ],
              ),
            ),
          );
        },
      );
      
      // Update task with completion information
      GoCleanCongViecModel updatedTask = GoCleanCongViecModel(
        lichLamViecID: task.lichLamViecID,
        giaoViecID: task.giaoViecID,
        ngay: task.ngay,
        nguoiThucHien: _username,
        xacNhan: 'Đã hoàn thành',
        qrCode: task.qrCode,
        mocBatDau: task.mocBatDau,
        hinhAnhTruoc: task.hinhAnhTruoc,
        mocKetThuc: DateTime.now().toString(),
        hinhAnhSau: null, // Will be updated after upload
        thucHienDanhGia: result['rating'],
        moTaThucHien: result['description'],
        khachHang: task.khachHang,
        khachHangDanhGia: task.khachHangDanhGia,
        thoiGianDanhGia: task.thoiGianDanhGia,
        khachHangMoTa: task.khachHangMoTa,
        khachHangChupAnh: task.khachHangChupAnh,
        trangThai: task.trangThai,
      );
      
      // Upload task completion data to server
      await _submitTaskCompletion(updatedTask);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Update task in local database
      await _dbHelper.updateGoCleanCongViec(updatedTask);
      
      // Reload tasks to reflect changes
      _loadWorkerTasks();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã hoàn thành công việc thành công'))
      );
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi dữ liệu: ${e.toString()}'),
          duration: Duration(seconds: 5),
        )
      );
      print('Error in _finishTask: $e');
    }
  }
  
  // Take a picture
  Future<void> _takePicture(String type) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      setState(() {
        if (type == 'before') {
          _beforeImage = File(photo.path);
        } else {
          _afterImage = File(photo.path);
        }
      });
    }
  }
  
  // Show rating dialog
  Future<Map<String, dynamic>?> _showRatingDialog() async {
    int rating = 5;
    final TextEditingController descController = TextEditingController(text: 'Hoàn thành tốt');
    
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đánh giá công việc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chất lượng công việc (1-5 sao)'),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () {
                    rating = index + 1;
                  },
                  icon: Icon(
                    Icons.star,
                    color: index < rating ? Colors.amber : Colors.grey,
                    size: 28,
                  ),
                );
              }),
            ),
            SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Mô tả thực hiện',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'rating': rating,
              'description': descController.text,
            }),
            child: Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
  
  // Submit task completion with separate image uploads
  Future<void> _submitTaskCompletion(GoCleanCongViecModel task) async {
    try {
      // First upload the images and get their URLs
      String? beforeImageUrl;
      String? afterImageUrl;
      
      // Upload before image if available
      if (_beforeImage != null && _beforeImage!.existsSync()) {
        beforeImageUrl = await _uploadImage(
          _beforeImage!, 
          'worker_images', 
          '${task.lichLamViecID}_before'
        );
      }
      
      // Upload after image if available
      if (_afterImage != null && _afterImage!.existsSync()) {
        afterImageUrl = await _uploadImage(
          _afterImage!, 
          'worker_images', 
          '${task.lichLamViecID}_after'
        );
      }
      
      // Now submit the task completion data with image URLs
      var response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/cleancongviecxong'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lichLamViecID': task.lichLamViecID ?? '',
          'giaoViecID': task.giaoViecID ?? '',
          'nguoiThucHien': task.nguoiThucHien ?? '',
          'qrCode': task.qrCode ?? '',
          'mocBatDau': task.mocBatDau ?? '',
          'mocKetThuc': task.mocKetThuc ?? '',
          'thucHienDanhGia': task.thucHienDanhGia?.toString() ?? '',
          'moTaThucHien': task.moTaThucHien ?? '',
          'hinhAnhTruoc': beforeImageUrl,
          'hinhAnhSau': afterImageUrl,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to submit task completion. Status code: ${response.statusCode}');
      }
      
    } catch (e) {
      print('Error submitting task completion: $e');
      throw e;
    }
  }

  // Helper method to upload a single image to the image server
  Future<String> _uploadImage(File imageFile, String folderName, String identifier) async {
    try {
      // Create a multipart request for the image upload
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://dvv-thuyloi1-81200125587.asia-southeast1.run.app/upload-to-folder/$folderName/$identifier'),
      );
      
      // Add the image file to the request
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',  // The field name must be 'image' to match the server's multer configuration
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      );
      
      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to upload image. Status code: ${response.statusCode}, Response: ${response.body}');
      }
      
      // Parse the response to get the image URL
      final responseData = jsonDecode(response.body);
      if (responseData['imageUrl'] == null) {
        throw Exception('Image upload succeeded but no URL was returned');
      }
      
      return responseData['imageUrl'];
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }
  
  // Show task details in bottom sheet
  void _showTaskDetails(GoCleanCongViecModel task, GoCleanYeuCauModel? workRequest) {
    if (workRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy thông tin yêu cầu công việc')),
      );
      return;
    }
    
    final taskStatus = getTaskStatus(task);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  // Header with drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Title and task ID
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          workRequest.moTaCongViec ?? 'Chi tiết công việc',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(taskStatus).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          taskStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(taskStatus),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Task date and IDs
                  Text(
                    'Ngày: ${task.ngay != null ? DateFormat('dd/MM/yyyy').format(task.ngay!) : "N/A"}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  Text(
                    'ID Công việc: ${task.lichLamViecID ?? "N/A"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  Text(
                    'ID Yêu cầu: ${task.giaoViecID ?? "N/A"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  Divider(height: 24),
                  
                  // Location and time section
                  _buildDetailSection(
                    'Địa điểm và thời gian',
                    [
                      _buildDetailItem('Địa điểm', workRequest.diaDiem),
                      _buildDetailItem('Địa chỉ', workRequest.diaChi),
                      _buildDetailItem('Khu vực thực hiện', workRequest.khuVucThucHien),
                      _buildDetailItem('Thời gian bắt đầu', workRequest.thoiGianBatDau),
                      _buildDetailItem('Thời gian kết thúc', workRequest.thoiGianKetThuc),
                    ],
                  ),
                  
                  // Work details section
                  _buildDetailSection(
                    'Chi tiết công việc',
                    [
                      _buildDetailItem('Yêu cầu công việc', workRequest.yeuCauCongViec),
                      _buildDetailItem('Số người thực hiện', workRequest.soNguoiThucHien?.toString()),
                      _buildDetailItem('Khối lượng công việc', workRequest.khoiLuongCongViec?.toString()),
                    ],
                  ),
                  
                  // Tools and equipment section
                  _buildDetailSection(
                    'Công cụ và thiết bị',
                    [
                      _buildDetailItem('Loại máy sử dụng', workRequest.loaiMaySuDung),
                      _buildDetailItem('Công cụ sử dụng', workRequest.congCuSuDung),
                      _buildDetailItem('Hóa chất sử dụng', workRequest.hoaChatSuDung),
                    ],
                  ),
                  
                  // Notes section
                  _buildDetailSection(
                    'Hướng dẫn và ghi chú',
                    [
                      _buildDetailItem('Hướng dẫn', workRequest.huongDan),
                      _buildDetailItem('Ghi chú', workRequest.ghiChu),
                    ],
                  ),
                  
                  // Execution details section (if applicable)
                  if (task.mocBatDau != null || task.mocKetThuc != null)
                    _buildDetailSection(
                      'Thông tin thực hiện',
                      [
                        _buildDetailItem('Thời điểm bắt đầu', task.mocBatDau),
                        _buildDetailItem('Thời điểm kết thúc', task.mocKetThuc),
                        _buildDetailItem('Đánh giá (1-5)', task.thucHienDanhGia?.toString()),
                        _buildDetailItem('Mô tả thực hiện', task.moTaThucHien),
                        _buildDetailItem('QR Code', task.qrCode),
                      ],
                    ),
                  
                  SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.close, size: 16),
                        label: Text('Đóng'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                        ),
                      ),
                      
                      // Action button based on status
                      if (taskStatus == 'Cần làm' || taskStatus == 'Chưa làm')
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _startTask(task, workRequest);
                          },
                          icon: Icon(Icons.play_arrow, size: 16),
                          label: Text('Bắt đầu làm'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        )
                      else if (taskStatus == 'Đang làm')
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _finishTask(task, workRequest);
                          },
                          icon: Icon(Icons.check_circle, size: 16),
                          label: Text('Xong việc'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildDetailSection(String title, List<Widget?> items) {
    // Filter out null items
    final validItems = items.where((item) => item != null).toList();
    
    if (validItems.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        SizedBox(height: 8),
        ...validItems.cast<Widget>(),
        SizedBox(height: 16),
      ],
    );
  }
  
  Widget? _buildDetailItem(String label, String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  // Scan QR code using mobile_scanner
  Future<String> _scanQRCode() async {
    String scannedCode = '';
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.all(0),
        content: Container(
          width: 300,
          height: 300,
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
                    scannedCode = barcodes[0].rawValue!;
                    Navigator.pop(context);
                  }
                },
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // If QR scan was cancelled or failed, show manual input dialog
    if (scannedCode.isEmpty) {
      final TextEditingController qrController = TextEditingController();
      
      scannedCode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Nhập mã QR'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quét không thành công. Vui lòng nhập mã thủ công:'),
              SizedBox(height: 16),
              TextField(
                controller: qrController,
                decoration: InputDecoration(
                  labelText: 'Mã QR',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, qrController.text),
              child: Text('Xác nhận'),
            ),
          ],
        ),
      ) ?? '';
    }
    
    return scannedCode;
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Đã làm':
        return Colors.green;
      case 'Đang làm':
        return Colors.orange;
      case 'Cần làm':
        return Colors.blue;
      case 'Chưa làm':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
     