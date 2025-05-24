import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'user_credentials.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'projectmanagement4moi.dart';
import 'package:intl/intl.dart';
class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({Key? key}) : super(key: key);

  @override
  _CustomerDashboardState createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  String _username = '';
  GoCleanTaiKhoanModel? _userProfile;
  final DBHelper _dbHelper = DBHelper();
  bool _isLoading = true;
  final Random _random = Random();
  int _avatarIndex = 0;
  bool _showAllUsers = false;
  List<GoCleanTaiKhoanModel> _allUsers = [];
  List<GoCleanYeuCauModel> _workRequests = [];
  
  // Track selected work request for showing child tasks
  GoCleanYeuCauModel? _selectedWorkRequest;
  List<GoCleanCongViecModel> _relatedTasks = [];
  bool _isLoadingTasks = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _avatarIndex = _random.nextInt(21); // Generate random number 0-20 for avatar
  }
Map<String, List<GoCleanYeuCauModel>> _groupWorkRequestsByWeek() {
    Map<String, List<GoCleanYeuCauModel>> weekGroups = {};
    
    for (var request in _workRequests) {
      if (request.ngayBatDau != null) {
        String weekKey = _getWeekKey(request.ngayBatDau!);
        if (!weekGroups.containsKey(weekKey)) {
          weekGroups[weekKey] = [];
        }
        weekGroups[weekKey]!.add(request);
      }
    }
    
    return weekGroups;
  }
   String _getWeekKey(DateTime date) {
    // Find the start of the week (Monday)
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    
    return '${DateFormat('dd/MM').format(startOfWeek)} - ${DateFormat('dd/MM/yyyy').format(endOfWeek)}';
  }
  
  // Get job statistics for a work request
  Map<String, int> _getJobStats(String giaoViecID) {
    int totalJobs = 0;
    int inProgressJobs = 0;
    int completedJobs = 0;
    
    // Find all tasks related to this work request
    for (var task in _allTasks) {
      if (task.giaoViecID == giaoViecID) {
        totalJobs++;
        
        // Check if job is in progress (has before image)
        if (task.hinhAnhTruoc != null && task.hinhAnhTruoc!.isNotEmpty) {
          inProgressJobs++;
          
          // Check if job is completed (has after image)
          if (task.hinhAnhSau != null && task.hinhAnhSau!.isNotEmpty) {
            completedJobs++;
          }
        }
      }
    }
    
    return {
      'total': totalJobs,
      'inProgress': inProgressJobs,
      'completed': completedJobs,
    };
  }
  
  // Add this variable to store all tasks
  List<GoCleanCongViecModel> _allTasks = [];
  
  // Load all tasks for statistics
  Future<void> _loadAllTasks() async {
    try {
      final allTasks = await _dbHelper.getAllGoCleanCongViec();
      setState(() {
        _allTasks = allTasks;
      });
    } catch (e) {
      print('Error loading all tasks: $e');
    }
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
      // Get all users from the table
      final users = await _dbHelper.getAllGoCleanTaiKhoan();
      print('Loaded ${users.length} users from database');
      
      // Find the user with matching TaiKhoan field
      final matchingUser = users.firstWhere(
        (user) => user.taiKhoan == _username,
        orElse: () => GoCleanTaiKhoanModel(), // Return empty model if not found
      );
      
      print('Found matching user: ${matchingUser.taiKhoan}, role: ${matchingUser.phanLoai}, location: ${matchingUser.diaDiem}');

      setState(() {
        _userProfile = matchingUser;
        _allUsers = users;
      });

      // After loading user profile, load work requests
      await _loadWorkRequests();
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWorkRequests() async {
  try {
    print('Loading work requests...');
    // Get all work requests
    final allRequests = await _dbHelper.getAllGoCleanYeuCau();
    print('Loaded ${allRequests.length} total work requests from database');
    
    // Load all tasks for statistics
    await _loadAllTasks();
    
    List<GoCleanYeuCauModel> filteredRequests = [];
    
    if (_userProfile != null) {
      print('Current user: ${_username}, PhanLoai: ${_userProfile!.phanLoai}, DiaDiem: ${_userProfile!.diaDiem}');
      
      // Filter based on user role
      if (_userProfile!.phanLoai == 'Admin') {
        // Admin sees all requests
        filteredRequests = allRequests;
        print('User is Admin, showing all ${allRequests.length} requests');
      } else if (_userProfile!.phanLoai == 'Kỹ thuật') {
        // Technical staff only sees requests where they are listed in ListNguoiThucHien
        filteredRequests = allRequests.where((request) {
          final listUsers = request.listNguoiThucHien ?? '';
          return listUsers.contains(_username);
        }).toList();
        print('User is Kỹ thuật, filtered to ${filteredRequests.length} requests where they are assigned');
      } else {
        // Regular users see records matching their location
        final userLocation = _userProfile!.diaDiem;
        if (userLocation != null && userLocation.isNotEmpty) {
          filteredRequests = allRequests.where((request) => 
            request.diaDiem == userLocation
          ).toList();
          print('Regular user, filtered to ${filteredRequests.length} requests matching location: $userLocation');
        }
      }
    }
    
    // Sort by most recent requests first (using ngayBatDau)
    filteredRequests.sort((a, b) {
      final dateA = a.ngayBatDau;
      final dateB = b.ngayBatDau;
      
      if (dateA == null) return 1; // Null dates go to the end
      if (dateB == null) return -1;
      
      return dateB.compareTo(dateA); // Descending order (newest first)
    });
    
    setState(() {
      _workRequests = filteredRequests;
      _isLoading = false;
    });
    
    // For debugging
    print('Filtered to ${_workRequests.length} work requests for display');
  } catch (e) {
    print('Error loading work requests: $e');
    setState(() {
      _isLoading = false;
    });
  }
}
  // New week-grouped layout for work requests
Widget _buildWorkRequestsGrid(double screenWidth) {
  final weekGroups = _groupWorkRequestsByWeek();
  
  return Column(
    children: [
      // Add new button
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Yêu cầu công việc theo tuần',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateWorkRequestScreen()),
                );
                
                if (result == true) {
                  await _loadWorkRequests();
                }
              },
              icon: Icon(Icons.add, size: 16, color: Colors.white),
              label: Text(
                'Thêm mới',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Week-grouped work requests
      Expanded(
        child: weekGroups.isEmpty
            ? _buildEmptyWorkRequestsMessage()
            : ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: weekGroups.keys.length,
                itemBuilder: (context, index) {
                  final weekKey = weekGroups.keys.toList()[index];
                  final weekRequests = weekGroups[weekKey]!;
                  
                  return _buildWeekSection(weekKey, weekRequests);
                },
              ),
      ),
    ],
  );
}

// Build week section with requests
Widget _buildWeekSection(String weekKey, List<GoCleanYeuCauModel> requests) {
  // Calculate total jobs stats for the week
  int totalJobs = 0;
  int inProgressJobs = 0;
  int completedJobs = 0;
  
  for (var request in requests) {
    final stats = _getJobStats(request.giaoViecID ?? '');
    totalJobs += stats['total']!;
    inProgressJobs += stats['inProgress']!;
    completedJobs += stats['completed']!;
  }
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Week header with stats
      Container(
        margin: EdgeInsets.only(bottom: 12, top: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tuần $weekKey',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            Row(
              children: [
                _buildStatChip('Tổng', totalJobs.toString(), Colors.grey),
                SizedBox(width: 8),
                _buildStatChip('Đang làm', inProgressJobs.toString(), Colors.orange),
                SizedBox(width: 8),
                _buildStatChip('Hoàn thành', completedJobs.toString(), Colors.green),
              ],
            ),
          ],
        ),
      ),
      
      // Requests for this week
      GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(MediaQuery.of(context).size.width),
          childAspectRatio: 1.8, // Reduced height
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _buildCompactWorkRequestCard(requests[index]);
        },
      ),
      
      SizedBox(height: 16),
    ],
  );
}
// Show work request details with jobs
void _showWorkRequestDetails(GoCleanYeuCauModel request) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return DefaultTabController(
            length: 2,
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
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
                  
                  // Title and status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.moTaCongViec ?? 'Chi tiết yêu cầu công việc',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(request.xacNhan).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          request.xacNhan ?? 'Chưa xác nhận',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(request.xacNhan),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      labelColor: Colors.blue[800],
                      unselectedLabelColor: Colors.grey[600],
                      indicator: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tabs: [
                        Tab(text: 'Thông tin yêu cầu'),
                        Tab(text: 'Danh sách công việc'),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Request details tab
                        _buildRequestDetailsTab(request, scrollController),
                        
                        // Jobs list tab
                        _buildJobsListTab(request, scrollController),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// Request details tab
Widget _buildRequestDetailsTab(GoCleanYeuCauModel request, ScrollController scrollController) {
  return ListView(
    controller: scrollController,
    children: [
      // Basic info
      _buildDetailSection(
        'Thông tin cơ bản',
        [
          _buildDetailItem('ID yêu cầu', request.giaoViecID),
          _buildDetailItem('Mô tả công việc', request.moTaCongViec),
          _buildDetailItem('Yêu cầu công việc', request.yeuCauCongViec),
        ],
      ),
      
      // Location and time
      _buildDetailSection(
        'Địa điểm và thời gian',
        [
          _buildDetailItem('Địa điểm', request.diaDiem),
          _buildDetailItem('Địa chỉ', request.diaChi),
          _buildDetailItem('Khu vực thực hiện', request.khuVucThucHien),
          _buildDetailItem('Ngày bắt đầu', request.ngayBatDau?.toString().split(' ')[0]),
          _buildDetailItem('Ngày kết thúc', request.ngayKetThuc?.toString().split(' ')[0]),
          _buildDetailItem('Thời gian bắt đầu', request.thoiGianBatDau),
          _buildDetailItem('Thời gian kết thúc', request.thoiGianKetThuc),
        ],
      ),
      
      // Execution details
      _buildDetailSection(
        'Chi tiết thực hiện',
        [
          _buildDetailItem('Số người thực hiện', request.soNguoiThucHien?.toString()),
          _buildDetailItem('Cá nhân thực hiện', request.caNhanThucHien),
          _buildDetailItem('Nhóm thực hiện', request.nhomThucHien),
          _buildDetailItem('Danh sách người thực hiện', request.listNguoiThucHien),
          _buildDetailItem('Khối lượng công việc', request.khoiLuongCongViec?.toString()),
        ],
      ),
      
      // Tools and equipment
      _buildDetailSection(
        'Công cụ và thiết bị',
        [
          _buildDetailItem('Loại máy sử dụng', request.loaiMaySuDung),
          _buildDetailItem('Công cụ sử dụng', request.congCuSuDung),
          _buildDetailItem('Hóa chất sử dụng', request.hoaChatSuDung),
        ],
      ),
      
      // Notes
      _buildDetailSection(
        'Hướng dẫn và ghi chú',
        [
          _buildDetailItem('Hướng dẫn', request.huongDan),
          _buildDetailItem('Ghi chú', request.ghiChu),
        ],
      ),
    ],
  );
}

// Jobs list tab
Widget _buildJobsListTab(GoCleanYeuCauModel request, ScrollController scrollController) {
  // Get related tasks
  final relatedTasks = _allTasks.where((task) => task.giaoViecID == request.giaoViecID).toList();
  
  if (relatedTasks.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Chưa có công việc nào được tạo',
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
  
  return ListView.builder(
    controller: scrollController,
    padding: EdgeInsets.all(8),
    itemCount: relatedTasks.length,
    itemBuilder: (context, index) {
      return _buildJobCard(relatedTasks[index]);
    },
  );
}

// Job card for the list
Widget _buildJobCard(GoCleanCongViecModel task) {
  // Determine job status based on images
  String jobStatus = 'Chưa bắt đầu';
  Color statusColor = Colors.grey;
  
  if (task.hinhAnhSau != null && task.hinhAnhSau!.isNotEmpty) {
    jobStatus = 'Đã hoàn thành';
    statusColor = Colors.green;
  } else if (task.hinhAnhTruoc != null && task.hinhAnhTruoc!.isNotEmpty) {
    jobStatus = 'Đang thực hiện';
    statusColor = Colors.orange;
  }
  
  final taskDate = task.ngay != null 
      ? DateFormat('dd/MM/yyyy').format(task.ngay!)
      : 'N/A';
  
  return Card(
    margin: EdgeInsets.symmetric(vertical: 4),
    elevation: 1,
    child: InkWell(
      onTap: () {
        // Close current modal and show task details
        Navigator.pop(context);
        _showTaskDetailsFromAdmin(task);
      },
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${task.lichLamViecID ?? "N/A"}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    jobStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Details
            if (task.nguoiThucHien != null)
              _buildJobInfoRow(Icons.person, 'Người thực hiện', task.nguoiThucHien!),
            
            _buildJobInfoRow(Icons.calendar_today, 'Ngày', taskDate),
            
            if (task.mocBatDau != null)
              _buildJobInfoRow(Icons.play_arrow, 'Bắt đầu', _formatDateTime(task.mocBatDau)),
            
            if (task.mocKetThuc != null)
              _buildJobInfoRow(Icons.stop, 'Kết thúc', _formatDateTime(task.mocKetThuc)),
          ],
        ),
      ),
    ),
  );
}

Widget _buildJobInfoRow(IconData icon, String label, String? value) {
  if (value == null) return SizedBox();
  
  return Padding(
    padding: const EdgeInsets.only(bottom: 4.0),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

// Show task details similar to worker screen
void _showTaskDetailsFromAdmin(GoCleanCongViecModel task) {
  // Get the related work request
  final workRequest = _workRequests.firstWhere(
    (request) => request.giaoViecID == task.giaoViecID,
    orElse: () => GoCleanYeuCauModel(),
  );
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
       expand: false,
       builder: (context, scrollController) {
         return DefaultTabController(
           length: 2,
           child: Container(
             padding: EdgeInsets.all(16),
             child: Column(
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
                 
                 // Title and task status
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
                         color: _getTaskStatusColor(task).withOpacity(0.2),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                         _getTaskStatusText(task),
                         style: TextStyle(
                           fontSize: 12,
                           color: _getTaskStatusColor(task),
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                   ],
                 ),
                 
                 SizedBox(height: 16),
                 
                 // Tab bar
                 Container(
                   decoration: BoxDecoration(
                     color: Colors.grey[100],
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: TabBar(
                     labelColor: Colors.blue[800],
                     unselectedLabelColor: Colors.grey[600],
                     indicator: BoxDecoration(
                       color: Colors.blue[50],
                       borderRadius: BorderRadius.circular(8),
                     ),
                     tabs: [
                       Tab(text: 'Thông tin công việc'),
                       Tab(text: 'Kết quả thực hiện'),
                     ],
                   ),
                 ),
                 
                 SizedBox(height: 16),
                 
                 // Tab content
                 Expanded(
                   child: TabBarView(
                     children: [
                       // Job details tab
                       _buildTaskJobDetailsTab(task, workRequest, scrollController),
                       
                       // Submission results tab
                       _buildTaskSubmissionResultsTab(task, workRequest, scrollController),
                     ],
                   ),
                 ),
                 
                 SizedBox(height: 16),
                 
                 // Close button
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
               ],
             ),
           ),
         );
       },
     );
   },
 );
}

// Task job details tab content
Widget _buildTaskJobDetailsTab(GoCleanCongViecModel task, GoCleanYeuCauModel workRequest, ScrollController scrollController) {
 return ListView(
   controller: scrollController,
   children: [
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
   ],
 );
}

// Task submission results tab content
Widget _buildTaskSubmissionResultsTab(GoCleanCongViecModel task, GoCleanYeuCauModel workRequest, ScrollController scrollController) {
 final hasSubmission = task.mocBatDau != null || task.mocKetThuc != null;
 
 if (!hasSubmission) {
   return Center(
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
         SizedBox(height: 16),
         Text(
           'Chưa có kết quả thực hiện',
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
   controller: scrollController,
   children: [
     // Execution timeline
     _buildDetailSection(
       'Thời gian thực hiện',
       [
         _buildDetailItem('Thời điểm bắt đầu', _formatDateTime(task.mocBatDau)),
         _buildDetailItem('Thời điểm kết thúc', _formatDateTime(task.mocKetThuc)),
         _buildDetailItem('QR Code', task.qrCode),
         if (task.mocBatDau != null && task.mocKetThuc != null)
           _buildDetailItem('Thời gian làm việc', _calculateWorkDuration(task.mocBatDau!, task.mocKetThuc!)),
       ],
     ),
     
     // Worker evaluation
     if (task.thucHienDanhGia != null || task.moTaThucHien != null)
       _buildDetailSection(
         'Đánh giá của nhân viên',
         [
           if (task.thucHienDanhGia != null)
             _buildRatingItem('Đánh giá chất lượng', task.thucHienDanhGia!),
           _buildDetailItem('Ghi chú thực hiện', task.moTaThucHien),
         ],
       ),
     
     // Before and after images
     _buildImageSection(task),
     
     SizedBox(height: 16),
   ],
 );
}

// Helper methods for task status
String _getTaskStatusText(GoCleanCongViecModel task) {
 if (task.hinhAnhSau != null && task.hinhAnhSau!.isNotEmpty) {
   return 'Đã hoàn thành';
 } else if (task.hinhAnhTruoc != null && task.hinhAnhTruoc!.isNotEmpty) {
   return 'Đang thực hiện';
 } else {
   return 'Chưa bắt đầu';
 }
}

Color _getTaskStatusColor(GoCleanCongViecModel task) {
 if (task.hinhAnhSau != null && task.hinhAnhSau!.isNotEmpty) {
   return Colors.green;
 } else if (task.hinhAnhTruoc != null && task.hinhAnhTruoc!.isNotEmpty) {
   return Colors.orange;
 } else {
   return Colors.grey;
 }
}

// Build rating display item
Widget _buildRatingItem(String label, int rating) {
 return Padding(
   padding: const EdgeInsets.only(bottom: 16.0),
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
       SizedBox(height: 4),
       Row(
         children: [
           ...List.generate(5, (index) {
             return Icon(
               Icons.star,
               size: 20,
               color: index < rating ? Colors.amber : Colors.grey[300],
             );
           }),
           SizedBox(width: 8),
           Text(
             '$rating/5 sao',
             style: TextStyle(
               fontSize: 14,
               fontWeight: FontWeight.w500,
             ),
           ),
         ],
       ),
     ],
   ),
 );
}

// Build image section
Widget _buildImageSection(GoCleanCongViecModel task) {
 final hasBeforeImage = task.hinhAnhTruoc != null && task.hinhAnhTruoc!.isNotEmpty;
 final hasAfterImage = task.hinhAnhSau != null && task.hinhAnhSau!.isNotEmpty;
 
 if (!hasBeforeImage && !hasAfterImage) {
   return SizedBox.shrink();
 }
 
 return Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
     Text(
       'Hình ảnh thực hiện',
       style: TextStyle(
         fontSize: 16,
         fontWeight: FontWeight.bold,
         color: Colors.blue[800],
       ),
     ),
     SizedBox(height: 12),
     
     Row(
       children: [
         // Before image
         if (hasBeforeImage)
           Expanded(
             child: _buildImageCard('Trước khi làm', task.hinhAnhTruoc!),
           ),
         
         if (hasBeforeImage && hasAfterImage)
           SizedBox(width: 12),
         
         // After image
         if (hasAfterImage)
           Expanded(
             child: _buildImageCard('Sau khi làm', task.hinhAnhSau!),
           ),
       ],
     ),
     
     SizedBox(height: 16),
   ],
 );
}

// Build individual image card
Widget _buildImageCard(String title, String imageUrl) {
 return GestureDetector(
   onTap: () => _showFullScreenImage(imageUrl, title),
   child: Container(
     decoration: BoxDecoration(
       borderRadius: BorderRadius.circular(8),
       border: Border.all(color: Colors.grey[300]!),
     ),
     child: Column(
       children: [
         Container(
           padding: EdgeInsets.symmetric(vertical: 8),
           decoration: BoxDecoration(
             color: Colors.grey[100],
             borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
           ),
           child: Center(
             child: Text(
               title,
               style: TextStyle(
                 fontSize: 12,
                 fontWeight: FontWeight.w500,
               ),
             ),
           ),
         ),
         Container(
           height: 120,
           width: double.infinity,
           child: ClipRRect(
             borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
             child: Image.network(
               imageUrl,
               fit: BoxFit.cover,
               loadingBuilder: (context, child, loadingProgress) {
                 if (loadingProgress == null) return child;
                 return Center(
                   child: CircularProgressIndicator(
                     value: loadingProgress.expectedTotalBytes != null
                         ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                         : null,
                   ),
                 );
               },
               errorBuilder: (context, error, stackTrace) {
                 return Container(
                   color: Colors.grey[200],
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.error_outline, color: Colors.grey[400]),
                       Text(
                         'Lỗi tải ảnh',
                         style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                       ),
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
 );
}

// Helper methods from worker screen
String? _formatDateTime(String? dateTimeString) {
 if (dateTimeString == null || dateTimeString.isEmpty) {
   return null;
 }
 
 try {
   final dateTime = DateTime.parse(dateTimeString);
   return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
 } catch (e) {
   return dateTimeString; // Return original if parsing fails
 }
}

String? _calculateWorkDuration(String startTime, String endTime) {
 try {
   final start = DateTime.parse(startTime);
   final end = DateTime.parse(endTime);
   final duration = end.difference(start);
   
   final hours = duration.inHours;
   final minutes = duration.inMinutes % 60;
   
   if (hours > 0) {
     return '${hours}h ${minutes}m';
   } else {
     return '${minutes}m';
   }
 } catch (e) {
   return null;
 }
}

// Show full screen image
void _showFullScreenImage(String imageUrl, String title) {
 showDialog(
   context: context,
   builder: (context) => Dialog(
     backgroundColor: Colors.black,
     child: Stack(
       children: [
         Center(
           child: InteractiveViewer(
             child: Image.network(
               imageUrl,
               fit: BoxFit.contain,
               loadingBuilder: (context, child, loadingProgress) {
                 if (loadingProgress == null) return child;
                 return Center(
                   child: CircularProgressIndicator(
                     value: loadingProgress.expectedTotalBytes != null
                         ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                         : null,
                     color: Colors.white,
                   ),
                 );
               },
               errorBuilder: (context, error, stackTrace) {
                 return Container(
                   color: Colors.grey[800],
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.error_outline, color: Colors.white, size: 48),
                       SizedBox(height: 16),
                       Text(
                         'Không thể tải ảnh',
                         style: TextStyle(color: Colors.white),
                       ),
                     ],
                   ),
                 );
               },
             ),
           ),
         ),
         Positioned(
           top: 40,
           left: 16,
           child: Text(
             title,
             style: TextStyle(
               color: Colors.white,
               fontSize: 18,
               fontWeight: FontWeight.bold,
             ),
           ),
         ),
         Positioned(
           top: 40,
           right: 16,
           child: IconButton(
             icon: Icon(Icons.close, color: Colors.white, size: 28),
             onPressed: () => Navigator.pop(context),
           ),
         ),
       ],
     ),
   ),
 );
}
// Compact card for work request in grid view
Widget _buildCompactWorkRequestCard(GoCleanYeuCauModel request) {
  // Format dates for display
  final startDate = request.ngayBatDau != null 
      ? '${request.ngayBatDau!.day}/${request.ngayBatDau!.month}'
      : 'N/A';
  
  final endDate = request.ngayKetThuc != null
      ? '${request.ngayKetThuc!.day}/${request.ngayKetThuc!.month}'
      : 'N/A';
  
  // Get job statistics
  final jobStats = _getJobStats(request.giaoViecID ?? '');
  final totalJobs = jobStats['total']!;
  final inProgressJobs = jobStats['inProgress']!;
  final completedJobs = jobStats['completed']!;
  
  // Get days remaining or overdue
  String timeStatus = '';
  Color timeStatusColor = Colors.green;
  if (request.ngayKetThuc != null) {
    final now = DateTime.now();
    final daysRemaining = request.ngayKetThuc!.difference(now).inDays;
    
    if (daysRemaining < 0) {
      timeStatus = 'Quá hạn ${daysRemaining.abs()}d';
      timeStatusColor = Colors.red;
    } else if (daysRemaining == 0) {
      timeStatus = 'Hôm nay';
      timeStatusColor = Colors.orange;
    } else {
      timeStatus = 'Còn ${daysRemaining}d';
      timeStatusColor = Colors.green;
    }
  }
  
  // Card color based on status
  Color cardColor = Colors.white;
  if (request.xacNhan == 'Đã hoàn thành') {
    cardColor = Colors.green[50]!;
  } else if (request.ngayKetThuc != null && request.ngayKetThuc!.isBefore(DateTime.now())) {
    cardColor = Colors.red[50]!;
  } else if (request.xacNhan == 'Đang thực hiện') {
    cardColor = Colors.amber[50]!;
  } else if (request.xacNhan == 'Chờ xác nhận') {
    cardColor = Colors.purple[50]!;
  }
  
  return Card(
    elevation: 2,
    color: cardColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    child: InkWell(
      onTap: () {
        _showWorkRequestDetails(request);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    request.moTaCongViec ?? 'Không có mô tả',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(request.xacNhan).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request.xacNhan ?? 'Chưa xác nhận',
                    style: TextStyle(
                      fontSize: 9,
                      color: _getStatusColor(request.xacNhan),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 6),
            
            // Job statistics
            Row(
              children: [
                Icon(Icons.assignment, size: 12, color: Colors.blue[700]),
                SizedBox(width: 4),
                Text(
                  'Công việc: $completedJobs/$totalJobs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (inProgressJobs > 0) ...[
                  Text(
                    ' ($inProgressJobs đang làm)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ],
            ),
            
            SizedBox(height: 4),
            
            // Location
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: Colors.blue[700]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.diaDiem ?? 'N/A',
                    style: TextStyle(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 4),
            
            // Date range
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.blue[700]),
                SizedBox(width: 4),
                Text(
                  '$startDate - $endDate',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
            
            Spacer(),
            
            // Bottom row with status and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  SizedBox(),
                
                // Time status
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: timeStatusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    timeStatus,
                    style: TextStyle(
                      fontSize: 9,
                      color: timeStatusColor,
                      fontWeight: FontWeight.w500,
                    ),
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
// Helper method to determine grid columns
int _getCrossAxisCount(double screenWidth) {
  if (screenWidth > 1200) {
    return 4;
  } else if (screenWidth > 900) {
    return 3;
  } else if (screenWidth > 600) {
    return 2;
  }
  return 1;
}

// Build small stat chip
Widget _buildStatChip(String label, String value, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
  // Load individual tasks related to a specific work request
  Future<void> _loadRelatedTasks(String giaoViecID) async {
    setState(() {
      _isLoadingTasks = true;
    });
    
    try {
      print('Loading tasks for GiaoViecID: $giaoViecID');
      
      // Get all tasks
      final allTasks = await _dbHelper.getAllGoCleanCongViec();
      print('Loaded ${allTasks.length} total tasks from database');
      
      // Filter tasks by GiaoViecID
      final relatedTasks = allTasks.where((task) => 
        task.giaoViecID == giaoViecID
      ).toList();
      
      print('Found ${relatedTasks.length} tasks related to GiaoViecID: $giaoViecID');
      
      // Sort tasks by date if available
      relatedTasks.sort((a, b) {
        final dateA = a.ngay;
        final dateB = b.ngay;
        
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        
        return dateB.compareTo(dateA); // Newest first
      });
      
      setState(() {
        _relatedTasks = relatedTasks;
        _isLoadingTasks = false;
      });
      
      // For debugging
      for (var i = 0; i < _relatedTasks.length; i++) {
        print('Task #$i: ID=${_relatedTasks[i].lichLamViecID}, Date=${_relatedTasks[i].ngay}');
      }
    } catch (e) {
      print('Error loading related tasks: $e');
      setState(() {
        _isLoadingTasks = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70), // Much smaller AppBar
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
                    // User info card
                    IntrinsicHeight(
                      child: _buildCompactUserInfoCard(),
                    ),
                    
                    // Toggle between users list and work requests
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAllUsers = false;
                              _selectedWorkRequest = null; // Clear selection when switching views
                            });
                          },
                          icon: Icon(
                            Icons.assignment, 
                            size: 16, 
                            color: !_showAllUsers ? Colors.blue : Colors.grey,
                          ),
                          label: Text(
                            "Yêu cầu công việc", 
                            style: TextStyle(
                              fontSize: 12, 
                              color: !_showAllUsers ? Colors.blue : Colors.grey,
                              fontWeight: !_showAllUsers ? FontWeight.bold : FontWeight.normal,
                            )
                          ),
                        ),
                        SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAllUsers = true;
                              _selectedWorkRequest = null; // Clear selection when switching views
                            });
                          },
                          icon: Icon(
                            Icons.people, 
                            size: 16, 
                            color: _showAllUsers ? Colors.blue : Colors.grey,
                          ),
                          label: Text(
                            "Người dùng khác", 
                            style: TextStyle(
                              fontSize: 12, 
                              color: _showAllUsers ? Colors.blue : Colors.grey,
                              fontWeight: _showAllUsers ? FontWeight.bold : FontWeight.normal,
                            )
                          ),
                        ),
                      ],
                    ),
                    
                    // Content area
                    Expanded(
                      child: _showAllUsers 
                          ? _buildRelatedUsersList()
                          : _selectedWorkRequest != null
                              ? _buildTasksForSelectedRequest()
                              : _buildWorkRequestsGrid(screenWidth),
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
                if (_selectedWorkRequest != null) {
                  // If viewing tasks, go back to work requests list
                  setState(() {
                    _selectedWorkRequest = null;
                  });
                } else {
                  // Otherwise, navigate back to previous screen
                  Navigator.pop(context);
                }
              },
            ),
            
            // Avatar
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
                          _userProfile?.nhom ?? 'Chưa phân nhóm',
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
            
            // Refresh button
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.blue, size: 22),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                await _loadUserProfile();
              },
            ),
            
            // Database check button (for debugging)
            IconButton(
              icon: Icon(Icons.storage, color: Colors.grey[600], size: 20),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () async {
                final congViecCount = await _dbHelper.getGoCleanCongViecCount();
                final yeuCauCount = await _dbHelper.getGoCleanYeuCauCount();
                final taiKhoanCount = await _dbHelper.getGoCleanTaiKhoanCount();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Database: CongViec($congViecCount), YeuCau($yeuCauCount), TaiKhoan($taiKhoanCount)'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactUserInfoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left half of the card
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCompactInfoRow(Icons.phone, 'SĐT', _userProfile?.sdt ?? 'N/A'),
                      _buildCompactInfoRow(Icons.email, 'Email', _userProfile?.email ?? 'N/A'),
                      _buildCompactInfoRow(Icons.verified_user, 'Trạng thái', _userProfile?.trangThai ?? 'N/A'),
                    ],
                  ),
                ),
                // Right half of the card
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCompactInfoRow(Icons.location_city, 'Địa điểm', _userProfile?.diaDiem ?? 'N/A'),
                      _buildCompactInfoRow(Icons.home, 'Địa chỉ', _userProfile?.diaChi ?? 'N/A'),
                      _buildCompactInfoRow(Icons.assignment_ind, 'Phân loại', _userProfile?.phanLoai ?? 'N/A'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: Colors.blue),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: $value',
                  style: TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkRequestsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Không có yêu cầu công việc nào phù hợp',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _userProfile?.phanLoai == 'Admin' 
                  ? 'Tất cả yêu cầu sẽ hiển thị ở đây' 
                  : _userProfile?.phanLoai == 'Kỹ thuật'
                      ? 'Chỉ hiển thị yêu cầu có bạn trong danh sách thực hiện'
                      : 'Chỉ hiển thị yêu cầu tại ${_userProfile?.diaDiem ?? "địa điểm của bạn"}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // Card for work request in grid view
  Widget _buildWorkRequestCard(GoCleanYeuCauModel request) {
    // Format dates for display
    final startDate = request.ngayBatDau != null 
        ? '${request.ngayBatDau!.day}/${request.ngayBatDau!.month}/${request.ngayBatDau!.year}'
        : 'N/A';
    
    final endDate = request.ngayKetThuc != null
        ? '${request.ngayKetThuc!.day}/${request.ngayKetThuc!.month}/${request.ngayKetThuc!.year}'
        : 'N/A';
    
    // Get days remaining or overdue
    String timeStatus = '';
    Color timeStatusColor = Colors.green;
    if (request.ngayKetThuc != null) {
      final now = DateTime.now();
      final daysRemaining = request.ngayKetThuc!.difference(now).inDays;
      
      if (daysRemaining < 0) {
        timeStatus = 'Quá hạn ${daysRemaining.abs()} ngày';
        timeStatusColor = Colors.red;
      } else if (daysRemaining == 0) {
        timeStatus = 'Hết hạn hôm nay';
        timeStatusColor = Colors.orange;
      } else {
        timeStatus = 'Còn $daysRemaining ngày';
        timeStatusColor = Colors.green;
      }
    }
    
    // Card color based on status
    Color cardColor = Colors.white;
if (request.xacNhan == 'Đã hoàn thành') {
  cardColor = Colors.green[50]!;
} else if (request.ngayKetThuc != null && request.ngayKetThuc!.isBefore(DateTime.now())) {
  cardColor = Colors.red[50]!;
} else if (request.xacNhan == 'Đang thực hiện') {
  cardColor = Colors.amber[50]!;
} else if (request.xacNhan == 'Chờ xác nhận') {
  cardColor = Colors.purple[50]!;
}
    
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          // When card is tapped, load and show related tasks
          if (request.giaoViecID != null) {
            setState(() {
              _selectedWorkRequest = request;
            });
            _loadRelatedTasks(request.giaoViecID!);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      request.moTaCongViec ?? 'Không có mô tả',
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
                      color: _getStatusColor(request.xacNhan).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      request.xacNhan ?? 'Chưa xác nhận',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getStatusColor(request.xacNhan),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // ID
              Text(
                'ID: ${request.giaoViecID ?? "N/A"}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              
              Divider(height: 12),
              
              // Location
              _buildCardInfoRow(
                Icons.location_on, 
                'Địa điểm', 
                request.diaDiem ?? 'N/A',
              ),
              
              // Date range
              _buildCardInfoRow(
                Icons.calendar_today, 
                'Thời gian', 
                '$startDate - $endDate',
              ),
              
              // Working hours
              _buildCardInfoRow(
                Icons.access_time, 
                'Giờ làm việc', 
                '${request.thoiGianBatDau ?? "N/A"} - ${request.thoiGianKetThuc ?? "N/A"}',
              ),
              
              // Performers
              _buildCardInfoRow(
                Icons.person, 
                'Người thực hiện', 
                request.caNhanThucHien != null && request.caNhanThucHien!.isNotEmpty 
                    ? request.caNhanThucHien!
                    : request.nhomThucHien ?? 'N/A',
              ),
              
              Spacer(),
              
              // Bottom row with time status and confirm button
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [    
    Align(
      alignment: Alignment.bottomRight,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: timeStatusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          timeStatus,
          style: TextStyle(
            fontSize: 10,
            color: timeStatusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
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
  
  Widget _buildCardInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: Colors.blue[700]),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Display tasks for a selected work request
  Widget _buildTasksForSelectedRequest() {
    if (_selectedWorkRequest == null) {
      return Center(child: Text('Không có yêu cầu công việc được chọn'));
    }
    
    return Column(
      children: [
        // Header with selected request info
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedWorkRequest!.moTaCongViec ?? 'Chi tiết công việc',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_selectedWorkRequest!.xacNhan).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _selectedWorkRequest!.xacNhan ?? 'Chưa xác nhận',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(_selectedWorkRequest!.xacNhan),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'ID: ${_selectedWorkRequest!.giaoViecID ?? "N/A"}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Địa điểm: ${_selectedWorkRequest!.diaDiem ?? "N/A"}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  children: [
                    TextSpan(text: 'Thời gian: '),
                    TextSpan(
                      text: _selectedWorkRequest!.ngayBatDau != null 
                          ? '${_selectedWorkRequest!.ngayBatDau!.day}/${_selectedWorkRequest!.ngayBatDau!.month}/${_selectedWorkRequest!.ngayBatDau!.year}'
                          : 'N/A',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    TextSpan(text: ' - '),
                    TextSpan(
                      text: _selectedWorkRequest!.ngayKetThuc != null 
                          ? '${_selectedWorkRequest!.ngayKetThuc!.day}/${_selectedWorkRequest!.ngayKetThuc!.month}/${_selectedWorkRequest!.ngayKetThuc!.year}'
                          : 'N/A',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Tasks list header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Danh sách công việc',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Add task button (if needed)
              ElevatedButton.icon(
                onPressed: () {
                  // Add new task functionality (will implement later)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tính năng đang phát triển'))
                  );
                },
                icon: Icon(Icons.add, size: 12),
                label: Text('Thêm công việc'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: Colors.deepOrange,
                  textStyle: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        
        // Tasks list
        Expanded(
          child: _isLoadingTasks
              ? Center(child: CircularProgressIndicator())
              : _relatedTasks.isEmpty
                  ? _buildEmptyTasksMessage()
                  : ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: _relatedTasks.length,
                      itemBuilder: (context, index) {
                        return _buildTaskCard(_relatedTasks[index]);
                      },
                    ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyTasksMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Không có công việc nào cho yêu cầu này',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Công việc cụ thể sẽ hiển thị ở đây, bạn có thể thêm mới hoặc đợi phân công',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // Card for individual task
  Widget _buildTaskCard(GoCleanCongViecModel task) {
    // Format date for display
    final taskDate = task.ngay != null 
        ? '${task.ngay!.day}/${task.ngay!.month}/${task.ngay!.year}'
        : 'N/A';
    
    // Card color based on status
    Color cardColor = Colors.white;
    if (task.xacNhan == 'Đã hoàn thành') {
      cardColor = Colors.green[50]!;
    } else if (task.xacNhan == 'Đang thực hiện') {
      cardColor = Colors.amber[50]!;
    } else if (task.xacNhan == 'Chưa bắt đầu') {
      cardColor = Colors.blue[50]!;
    }
    
    return Card(
      elevation: 1,
      color: cardColor,
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task ID and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${task.lichLamViecID ?? "N/A"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      taskDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            Divider(height: 16),
            
            // Executor
            if (task.nguoiThucHien != null && task.nguoiThucHien!.isNotEmpty)
              _buildTaskInfoRow(
                Icons.person,
                'Người thực hiện:',
                task.nguoiThucHien!,
              ),
            
            // Status
            _buildTaskInfoRow(
              Icons.check_circle,
              'Trạng thái:',
              task.xacNhan ?? 'Chưa xác nhận',
              valueColor: _getStatusColor(task.xacNhan),
            ),
            
            // Start time
            if (task.mocBatDau != null && task.mocBatDau!.isNotEmpty)
              _buildTaskInfoRow(
                Icons.play_circle_outline,
                'Bắt đầu:',
                task.mocBatDau!,
              ),
            
            // End time
            if (task.mocKetThuc != null && task.mocKetThuc!.isNotEmpty)
              _buildTaskInfoRow(
                Icons.stop_circle_outlined,
                'Kết thúc:',
                task.mocKetThuc!,
              ),
            
            // Description
            if (task.moTaThucHien != null && task.moTaThucHien!.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mô tả thực hiện:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      task.moTaThucHien!,
                      style: TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            
            SizedBox(height: 8),
            
            // Action buttons based on status
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View details button
                OutlinedButton(
                  onPressed: () {
                    _showTaskDetails(task);
                  },
                  child: Text(
                    'Chi tiết',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                
                SizedBox(width: 8),
                
                // Update status button (only show if applicable)
                if (task.xacNhan != 'Đã hoàn thành' && 
                    (_userProfile?.phanLoai == 'Kỹ thuật' || _userProfile?.phanLoai == 'Admin'))
                  ElevatedButton(
                    onPressed: () {
                      _showUpdateStatusDialog(task);
                    },
                    child: Text(
                      task.xacNhan == 'Đang thực hiện' ? 'Hoàn thành' : 'Bắt đầu',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      backgroundColor: task.xacNhan == 'Đang thực hiện' ? Colors.green : Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTaskInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Show task details in bottom sheet
  void _showTaskDetails(GoCleanCongViecModel task) {
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
                          'Chi tiết công việc',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ID: ${task.lichLamViecID ?? "N/A"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  Divider(height: 24),
                  
                  // Basic info section
                  _buildDetailSection(
                    'Thông tin cơ bản',
                    [
                      _buildDetailItem('Ngày', task.ngay?.toString().split(' ')[0]),
                      _buildDetailItem('Người thực hiện', task.nguoiThucHien),
                      _buildDetailItem('Trạng thái', task.xacNhan),
                      _buildDetailItem('Mã QR', task.qrCode),
                    ],
                  ),
                  
                  // Timestamps section
                  _buildDetailSection(
                    'Thời gian thực hiện',
                    [
                      _buildDetailItem('Thời điểm bắt đầu', task.mocBatDau),
                      _buildDetailItem('Thời điểm kết thúc', task.mocKetThuc),
                    ],
                  ),
                  
                  // Images section
                  _buildDetailSection(
                    'Hình ảnh',
                    [
                      _buildDetailItem('Hình ảnh trước', task.hinhAnhTruoc),
                      _buildDetailItem('Hình ảnh sau', task.hinhAnhSau),
                    ],
                  ),
                  
                  // Evaluation section
                  _buildDetailSection(
                    'Đánh giá',
                    [
                      _buildDetailItem('Đánh giá thực hiện', task.thucHienDanhGia?.toString()),
                      _buildDetailItem('Mô tả thực hiện', task.moTaThucHien),
                      _buildDetailItem('Khách hàng', task.khachHang),
                      _buildDetailItem('Đánh giá của khách hàng', task.khachHangDanhGia?.toString()),
                      _buildDetailItem('Thời gian đánh giá', task.thoiGianDanhGia),
                      _buildDetailItem('Mô tả của khách hàng', task.khachHangMoTa),
                      _buildDetailItem('Hình ảnh khách hàng', task.khachHangChupAnh),
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
                      
                      // Update status button (if applicable)
                      if (task.xacNhan != 'Đã hoàn thành' && 
                          (_userProfile?.phanLoai == 'Kỹ thuật' || _userProfile?.phanLoai == 'Admin'))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showUpdateStatusDialog(task);
                          },
                          icon: Icon(
                            task.xacNhan == 'Đang thực hiện' 
                                ? Icons.check_circle 
                                : Icons.play_circle_filled,
                            size: 16
                          ),
                          label: Text(
                            task.xacNhan == 'Đang thực hiện' ? 'Hoàn thành' : 'Bắt đầu',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: task.xacNhan == 'Đang thực hiện' ? Colors.green : Colors.blue,
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
  
  // Dialog to update task status
  void _showUpdateStatusDialog(GoCleanCongViecModel task) {
    final bool isStarting = task.xacNhan != 'Đang thực hiện';
    final TextEditingController _noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isStarting ? 'Bắt đầu công việc' : 'Hoàn thành công việc',
          style: TextStyle(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStarting 
                  ? 'Bạn đang bắt đầu thực hiện công việc này?' 
                  : 'Bạn đã hoàn thành công việc này?',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            onPressed: () async {
              // Update the task status
              final updatedTask = GoCleanCongViecModel(
                lichLamViecID: task.lichLamViecID,
                giaoViecID: task.giaoViecID,
                ngay: task.ngay,
                nguoiThucHien: _username, // Set current user as executor
                xacNhan: isStarting ? 'Đang thực hiện' : 'Đã hoàn thành',
                qrCode: task.qrCode,
                mocBatDau: isStarting ? DateTime.now().toString() : task.mocBatDau,
                hinhAnhTruoc: task.hinhAnhTruoc,
                mocKetThuc: isStarting ? null : DateTime.now().toString(),
                hinhAnhSau: task.hinhAnhSau,
                thucHienDanhGia: task.thucHienDanhGia,
                moTaThucHien: _noteController.text.isNotEmpty 
                    ? _noteController.text 
                    : task.moTaThucHien,
                khachHang: task.khachHang,
                khachHangDanhGia: task.khachHangDanhGia,
                thoiGianDanhGia: task.thoiGianDanhGia,
                khachHangMoTa: task.khachHangMoTa,
                khachHangChupAnh: task.khachHangChupAnh,
                trangThai: task.trangThai,
              );
              
              try {
                // Update in database
                await _dbHelper.updateGoCleanCongViec(updatedTask);
                
                // Close dialog
                Navigator.pop(context);
                
                // Reload tasks to show updated status
                if (_selectedWorkRequest?.giaoViecID != null) {
                  _loadRelatedTasks(_selectedWorkRequest!.giaoViecID!);
                }
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isStarting
                          ? 'Đã bắt đầu công việc thành công'
                          : 'Đã hoàn thành công việc thành công'
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                print('Error updating task status: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi cập nhật trạng thái: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isStarting ? Colors.blue : Colors.green,
            ),
            child: Text(
              isStarting ? 'Bắt đầu' : 'Hoàn thành',
            ),
          ),
        ],
      ),
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

  Widget _buildRelatedUsersList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      itemCount: _allUsers.length,
      itemBuilder: (context, index) {
        final user = _allUsers[index];
        // Skip current user
        if (user.taiKhoan == _username) return SizedBox.shrink();
        
        return Card(
          margin: EdgeInsets.only(bottom: 6.0),
          elevation: 1,
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('assets/avatar/avatar_${index % 21}.png'),
              backgroundColor: Colors.grey[300],
            ),
            title: Text(
              user.taiKhoan ?? 'Không có tên',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              user.phanLoai ?? 'Chưa phân loại',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Text(
              user.nhom ?? 'Chưa có nhóm',
              style: TextStyle(fontSize: 12),
            ),
            dense: true,
            onTap: () {
              // Show compact dialog about the selected user
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  titlePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  title: Text(
                    'Thông tin: ${user.taiKhoan}',
                    style: TextStyle(fontSize: 16),
                  ),
                  content: Container(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Two columns of information
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDialogInfoRow('Phân loại', user.phanLoai ?? 'N/A'),
                                  _buildDialogInfoRow('SĐT', user.sdt ?? 'N/A'),
                                  _buildDialogInfoRow('Email', user.email ?? 'N/A'),
                                ],
                              ),
                            ),
                            // Right column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDialogInfoRow('Địa điểm', user.diaDiem ?? 'N/A'),
                                  _buildDialogInfoRow('Nhóm', user.nhom ?? 'N/A'),
                                  _buildDialogInfoRow('Trạng thái', user.trangThai ?? 'N/A'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Đóng'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String? status) {
  if (status == null) return Colors.grey;
  
  switch (status.toLowerCase()) {
    case 'đã hoàn thành':
      return Colors.green;
    case 'đang thực hiện':
      return Colors.orange;
    case 'chưa bắt đầu':
      return Colors.blue;
    case 'chờ xác nhận':
      return Colors.purple;
    case 'hủy bỏ':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
}