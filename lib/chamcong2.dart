import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:core';
import 'table_models.dart';
import 'chamlaixe.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'location_provider.dart';
import 'db_helper.dart';
import 'chamcongvang.dart';
import 'chamcongnghi.dart';
import 'chamcongtca.dart';
import 'chamcongduyet.dart';
import 'chamcongthang.dart';
import 'http_client.dart';

class ChamCong2Screen extends StatefulWidget {
  final String username;
  final String userRole;
  final String approverUsername;

  const ChamCong2Screen({
    Key? key, 
    required this.username, 
    this.userRole = '', 
    this.approverUsername = '',
  }) : super(key: key);

  @override
  _ChamCong2ScreenState createState() => _ChamCong2ScreenState();
}

class _ChamCong2ScreenState extends State<ChamCong2Screen> {
  bool _isLoading = true;
  String _message = '';
  bool _canAccessLaiXeScreen = false;
  bool _canAccessTongHopScreen = false;
  // Stats variables
  double _totalCong = 0.0;
  int _totalWorkDays = 0;
  int _totalLateMinutes = 0;
    DateTime? _lastRefreshDate;
   int _pendingVangToApprove = 0;
  int _pendingNghiToApprove = 0;
  int _pendingTcaToApprove = 0;
  int _pendingVangAwaitingApproval = 0;
  int _pendingNghiAwaitingApproval = 0;
  int _pendingTcaAwaitingApproval = 0;
  int _unapprovedChamCongLSCount = 0;

  @override
  void initState() {
    super.initState();
    _checkUserPermissions();
    _checkAndLoadData();
  }
    final List<String> _laiXeAuthorizedUsers = [
  'hm.tason', 
  'hm.duongloan', 
  'hm.daotan', 
  'hm.quanganh', 
];
  final List<String> _tongHopAuthorizedUsers = [
  'hm.tason', 
  'hm.quanganh', 
  'hm.nguyenthu', 
  'hm.nguyengiang',
  'hm.lethihoa',
  'hm.vovy',
  'hm.nguyenlua', 
  'hm.nguyentoan2', 
  'hm.anhmanh', 
  'hm.doannga', 
  'hm.damlinh', 
  'hm.ngochuyen', 
];
void _checkUserPermissions() {
  setState(() {
    _canAccessLaiXeScreen = _laiXeAuthorizedUsers.contains(widget.username);
    _canAccessTongHopScreen = _tongHopAuthorizedUsers.contains(widget.username);
  });
}

Future<void> _checkAndLoadData() async {
  // Get the last refresh date from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final lastRefreshStr = prefs.getString('lastRefresh_${widget.username}');
  
  if (lastRefreshStr != null) {
    _lastRefreshDate = DateTime.parse(lastRefreshStr);
  }
  
  // Check if we need to load data (first time or new day)
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final lastRefreshDay = _lastRefreshDate != null 
      ? DateTime(_lastRefreshDate!.year, _lastRefreshDate!.month, _lastRefreshDate!.day)
      : null;
  
  if (lastRefreshDay == null || lastRefreshDay != today) {
    await _loadUserStats();
  } else {
    // Load cached stats
    _loadCachedStats();
  }
}
  Future<void> _loadUnapprovedChamCongLS() async {
  try {
    final dbHelper = DBHelper();
    final count = await dbHelper.getUnapprovedChamCongLSCount(widget.username);
    
    setState(() {
      _unapprovedChamCongLSCount = count;
    });
  } catch (e) {
    print('Error loading unapproved ChamCongLS: $e');
  }
}
  Future<void> _loadPendingCounts() async {
  try {
    final dbHelper = DBHelper();
    
    // Get records where current user needs to approve (as NguoiDuyet)
    final toApprove = await dbHelper.getChamCongVangNghiTcaByNguoiDuyet(widget.username);
    
    // Get records from current user waiting for approval (as NguoiDung)
    final awaitingApproval = await dbHelper.getChamCongVangNghiTcaByNguoiDung(widget.username);
    
    // Count records by PhanLoai and TrangThai
    setState(() {
      // Records that need approval (as approver)
      _pendingVangToApprove = toApprove.where((record) => 
          record.phanLoai == 'Vắng' && record.trangThai == 'Chưa xem').length;
          
      _pendingNghiToApprove = toApprove.where((record) => 
          record.phanLoai == 'Nghỉ' && record.trangThai == 'Chưa xem').length;
          
      _pendingTcaToApprove = toApprove.where((record) => 
          record.phanLoai == 'Tăng ca' && record.trangThai == 'Chưa xem').length;
      
      // User's records awaiting approval
      _pendingVangAwaitingApproval = awaitingApproval.where((record) => 
          record.phanLoai == 'Vắng' && record.trangThai == 'Chưa xem').length;
          
      _pendingNghiAwaitingApproval = awaitingApproval.where((record) => 
          record.phanLoai == 'Nghỉ' && record.trangThai == 'Chưa xem').length;
          
      _pendingTcaAwaitingApproval = awaitingApproval.where((record) => 
          record.phanLoai == 'Tăng ca' && record.trangThai == 'Chưa xem').length;
    });
  } catch (e) {
    print('Error loading pending counts: $e');
  }
}
  Future<void> _loadCachedStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalCong = prefs.getDouble('totalCong_${widget.username}') ?? 0.0;
      _totalWorkDays = prefs.getInt('totalWorkDays_${widget.username}') ?? 0;
      _totalLateMinutes = prefs.getInt('totalLateMinutes_${widget.username}') ?? 0;
      _isLoading = false;
    });
  }
  Future<void> _loadUserStats() async {
  setState(() {
    _isLoading = true;
    _message = 'Đang tải thông tin...';
  });
  
  try {
    // Get current month in format YYYY-MM
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now);
    
    // STEP 1: Load check-in history for current month
    final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamcongls/${widget.username}');
    final response = await AuthenticatedHttpClient.get(url);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      
      // Filter check-ins for current month AND where NguoiDung equals username
      final currentMonthCheckIns = data.where((item) {
        final checkInDate = item['Ngay'] as String?;
        final nguoiDung = item['NguoiDung'] as String?;
        return checkInDate != null && 
               checkInDate.startsWith(currentMonth) && 
               nguoiDung == widget.username;
      }).toList();
      
      // Calculate stats
      double totalCong = 0.0;
      int totalLateMinutes = 0;
      
      for (var checkIn in currentMonthCheckIns) {
        // Sum up TongCongNgay
        if (checkIn['TongCongNgay'] != null) {
          try {
            totalCong += double.parse(checkIn['TongCongNgay'].toString());
          } catch (e) {
            print('Error parsing TongCongNgay: $e');
          }
        }
        
        // Sum up TongDiMuonNgay
        if (checkIn['TongDiMuonNgay'] != null) {
          try {
            totalLateMinutes += int.parse(checkIn['TongDiMuonNgay'].toString());
          } catch (e) {
            print('Error parsing TongDiMuonNgay: $e');
          }
        }
      }
      
      // STEP 2: Load additional data from /chamconglsphep endpoint
      await _loadAdditionalUserData();
      // STEP 3: Load pending counts
      await _loadPendingCounts();
      // STEP 4: Load unapproved ChamCongLS
      await _loadUnapprovedChamCongLS();
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('lastRefresh_${widget.username}', DateTime.now().toIso8601String());
      prefs.setDouble('totalCong_${widget.username}', totalCong);
      prefs.setInt('totalWorkDays_${widget.username}', currentMonthCheckIns.length);
      prefs.setInt('totalLateMinutes_${widget.username}', totalLateMinutes);
      
      setState(() {
        _totalCong = totalCong;
        _totalWorkDays = currentMonthCheckIns.length;
        _totalLateMinutes = totalLateMinutes;
        _isLoading = false;
        _message = '';
        _lastRefreshDate = DateTime.now();
      });
    } else {
      setState(() {
        _isLoading = false;
        _message = 'Lỗi tải dữ liệu: ${response.statusCode}';
      });
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
      _message = 'Lỗi: $e';
    });
    print('Error loading user stats: $e');
  }
}
Future<void> _loadAdditionalUserData() async {
  try {
    // Get data from /chamconglsphep endpoint
    final url = Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/chamconglsphep/${widget.username}');
    final response = await AuthenticatedHttpClient.get(url);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      
      // First, clear existing records to prevent duplication
      final dbHelper = DBHelper();
      
      // Option 1: Clear all records for this user
      // This assumes you want to completely refresh the data
      final existingRecords = await dbHelper.getChamCongVangNghiTcaByNguoiDung(widget.username);
      for (var record in existingRecords) {
        if (record.uid != null) {
          await dbHelper.deleteChamCongVangNghiTca(record.uid!);
        }
      }
      
      // Convert the data to ChamCongVangNghiTcaModel objects
      List<ChamCongVangNghiTcaModel> chamCongItems = [];
      
      for (var item in data) {
        try {
          chamCongItems.add(ChamCongVangNghiTcaModel.fromMap(item));
        } catch (e) {
          print('Error converting item to ChamCongVangNghiTcaModel: $e');
        }
      }
      
      // Use the DB helper to batch insert the items
      if (chamCongItems.isNotEmpty) {
        await dbHelper.batchInsertChamCongVangNghiTca(chamCongItems);
        print('Successfully loaded and saved ${chamCongItems.length} items from /chamconglsphep endpoint');
      } else {
        print('No valid items found to save from /chamconglsphep endpoint');
      }
    } else {
      print('Error loading data from /chamconglsphep endpoint: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in _loadAdditionalUserData: $e');
  }
}

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.username),
      backgroundColor: const Color.fromARGB(255, 190, 226, 255),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Làm mới',
          onPressed: _loadUserStats,
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _loadUserStats,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 32.0, // More padding on sides for desktop
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Role and approver info card (if available)
                if (widget.userRole.isNotEmpty || widget.approverUsername.isNotEmpty)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.userRole.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.business, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Phòng ban: ${widget.userRole}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          if (widget.userRole.isNotEmpty && widget.approverUsername.isNotEmpty)
                            const SizedBox(height: 8),
                          if (widget.approverUsername.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.supervisor_account, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Quản lý: ${widget.approverUsername}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                
                if (widget.userRole.isNotEmpty || widget.approverUsername.isNotEmpty)
                  const SizedBox(height: 16),
                
                // Monthly stats card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thống kê tháng này',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  icon: Icons.work,
                                  label: 'Tổng công',
                                  value: _totalCong.toStringAsFixed(1),
                                  color: Colors.blue,
                                ),
                                _buildStatItem(
                                  icon: Icons.calendar_today,
                                  label: 'Ngày làm',
                                  value: _totalWorkDays.toString(),
                                  color: Colors.green,
                                ),
                                _buildStatItem(
                                  icon: Icons.timer_off,
                                  label: 'Phút muộn',
                                  value: _totalLateMinutes.toString(),
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Function buttons section
                const Text(
                  'Chức năng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 24),

// Pending approvals section
if (_pendingVangToApprove > 0 || _pendingNghiToApprove > 0 || 
    _pendingTcaToApprove > 0 || _pendingVangAwaitingApproval > 0 || 
    _pendingNghiAwaitingApproval > 0 || _pendingTcaAwaitingApproval > 0)
  Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông báo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          // Records needing your approval
          if (_pendingVangToApprove > 0)
            _buildWarningItem(
              text: '$_pendingVangToApprove lượt báo vắng cần bạn duyệt',
              color: Colors.red.shade400,
              icon: Icons.warning,
            ),
          if (_pendingNghiToApprove > 0)
            _buildWarningItem(
              text: '$_pendingNghiToApprove lượt báo nghỉ cần bạn duyệt',
              color: Colors.amber.shade700,
              icon: Icons.warning,
            ),
          if (_pendingTcaToApprove > 0)
            _buildWarningItem(
              text: '$_pendingTcaToApprove lượt báo tăng ca cần bạn duyệt',
              color: Colors.green.shade600,
              icon: Icons.warning,
            ),
          
          // Your records awaiting approval
          if (_pendingVangAwaitingApproval > 0)
            _buildWarningItem(
              text: '$_pendingVangAwaitingApproval lượt báo vắng của bạn chưa duyệt',
              color: Colors.red.shade400,
              icon: Icons.hourglass_empty,
            ),
          if (_pendingNghiAwaitingApproval > 0)
            _buildWarningItem(
              text: '$_pendingNghiAwaitingApproval lượt báo nghỉ của bạn chưa duyệt',
              color: Colors.amber.shade700,
              icon: Icons.hourglass_empty,
            ),
          if (_pendingTcaAwaitingApproval > 0)
            _buildWarningItem(
              text: '$_pendingTcaAwaitingApproval lượt báo tăng ca của bạn chưa duyệt',
              color: Colors.green.shade600,
              icon: Icons.hourglass_empty,
            ),
          if (_unapprovedChamCongLSCount > 0)
  _buildWarningItem(
    text: '$_unapprovedChamCongLSCount lượt chấm bất thường chưa duyệt',
    color: Colors.purple.shade600,
    icon: Icons.warning,
  ),
        ],
      ),
    ),
  ),

const SizedBox(height: 24),
                
                // Grid of function buttons
                GridView.count(
  crossAxisCount: 4, // Changed from 2 to 4 columns
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  mainAxisSpacing: 8, // Reduced from 16
  crossAxisSpacing: 8, // Reduced from 16
  childAspectRatio: 1.2, // Changed from 1.5 to make more square-shaped
  children: [
                    _buildFunctionButton(
  icon: Icons.person_off,
  label: 'Báo/duyệt\nVắng',
  color: Colors.red.shade400,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChamCongVangScreen(
          username: widget.username,
          userRole: widget.userRole,
          approverUsername: widget.approverUsername,
        ),
      ),
    );
  },
),
                    _buildFunctionButton(
                      icon: Icons.beach_access,
                      label: 'Báo/duyệt\nNghỉ',
                      color: Colors.amber.shade700,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChamCongNghiScreen(
                              username: widget.username,
                              userRole: widget.userRole,
                              approverUsername: widget.approverUsername,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildFunctionButton(
                      icon: Icons.access_time_filled,
                      label: 'Báo/duyệt\nTăng ca',
                      color: Colors.green.shade600,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChamCongTcaScreen(
                              username: widget.username,
                              userRole: widget.userRole,
                              approverUsername: widget.approverUsername,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildFunctionButton(
                      icon: Icons.approval,
                      label: 'Duyệt chấm\nBất thường',
                      color: Colors.purple.shade600,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChamCongDuyetScreen(
                              username: widget.username,
                              userRole: widget.userRole,
                              approverUsername: widget.approverUsername,
                            ),
                          ),
                        );
                      },
                    ),
                    // Add the conditional Lái xe button
                    if (_canAccessLaiXeScreen)
                      _buildFunctionButton(
                        icon: Icons.drive_eta,
                        label: 'Lái xe/ Kỹ thuật',
                        color: Colors.blue.shade600,
                        onTap: () {
                          Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ChamLaiXeScreen(
      username: widget.username,
      userRole: widget.userRole,
      approverUsername: widget.approverUsername,
    ),
  ),
);},),
                          if (_canAccessTongHopScreen)
  _buildFunctionButton(
    icon: Icons.star,
    label: 'Tổng hợp tháng',
    color: Colors.blue.shade600,
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChamCongThangScreen(
            username: widget.username,
            userRole: widget.userRole,
            approverUsername: widget.approverUsername,
          ),
        ),
      );
    },
  ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _message.contains('Lỗi') ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildWarningItem({
  required String text,
  required Color color,
  required IconData icon,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.0), // Reduced from 4.0
    child: Row(
      children: [
        Icon(icon, color: color, size: 16), // Reduced from 18
        const SizedBox(width: 6), // Reduced from 8
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13, // Added smaller font size
            ),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildStatItem({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Column(
    children: [
      Icon(icon, color: color, size: 20), // Reduced from 28
      const SizedBox(height: 4), // Reduced from 8
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16, // Reduced from 18
          color: color,
        ),
      ),
      const SizedBox(height: 2), // Reduced from 4
      Text(
        label,
        style: TextStyle(
          fontSize: 10, // Reduced from 12
          color: Colors.grey[600],
        ),
      ),
    ],
  );
}
  
  Widget _buildFunctionButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return Card(
    elevation: 2, // Reduced from 3
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8), // Reduced from 12
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8), // Reduced from 16
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24), // Reduced from 32
            const SizedBox(height: 6), // Reduced from 12
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 12, // Added smaller font size
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
}