// hd_dashboard2.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'table_models.dart';
import 'hd_thang2.dart';

class HDDashboard2 extends StatefulWidget {
  final String currentPeriod;
  final String nextPeriod;
  final String username;
  final String userRole;

  const HDDashboard2({
    Key? key,
    required this.currentPeriod,
    required this.nextPeriod,
    required this.username,
    required this.userRole,
  }) : super(key: key);

  @override
  _HDDashboard2State createState() => _HDDashboard2State();
}

class _HDDashboard2State extends State<HDDashboard2> with TickerProviderStateMixin {
  final DBHelper _dbHelper = DBHelper();
  
  // Data variables
  List<Map<String, dynamic>> _periodStats = [];
  Map<String, int> _tableCounts = {};
  Map<String, dynamic> _currentPeriodSummary = {};
  List<LinkHopDongModel> _recentContracts = [];
  List<LinkHopDongModel> _expiringContracts = [];
  
  // UI state
  bool _isLoading = true;
  String _error = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    print("HD Dashboard initialized with periods:");
    print("Current: ${widget.currentPeriod}");
    print("Next: ${widget.nextPeriod}");
    print("Username: ${widget.username}");
    print("User Role: ${widget.userRole}");
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Load all data in parallel
      await Future.wait([
        _loadContractStats(),
        _loadTableCounts(),
        _loadCurrentPeriodSummary(),
        _loadRecentContracts(),
        _loadExpiringContracts(),
      ]);
      
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadContractStats() async {
    final contracts = await _dbHelper.getAllLinkHopDongs();
    print("Loaded ${contracts.length} contracts from local database");

    // Group contracts by period and calculate basic stats (without financial data)
    Map<String, Map<String, dynamic>> periodData = {};
    
    for (var contract in contracts) {
      // Extract period from Thang field (now string)
      String period = _extractPeriodFromThang(contract.thang);
      print("Processing contract: ${contract.tenHopDong}, Thang: ${contract.thang}, Extracted period: '$period'");
      
      if (period.isNotEmpty) {
        if (!periodData.containsKey(period)) {
          periodData[period] = {
            'period': period,
            'contractCount': 0,
          };
          print("Created new period data for: $period");
        }
        
        periodData[period]!['contractCount']++;
        
        print("Contract ${contract.tenHopDong}: Period=$period");
      } else {
        print("WARNING: Empty period extracted for contract: ${contract.tenHopDong}, Thang: ${contract.thang}");
      }
    }
    
    print("=== PERIOD DATA SUMMARY ===");
    periodData.forEach((period, data) {
      print("Period $period: ${data['contractCount']} contracts");
    });
    
    // Convert to list and sort by period (newest first)
    List<Map<String, dynamic>> sortedStats = periodData.values.toList();
    sortedStats.sort((a, b) => b['period'].toString().compareTo(a['period'].toString()));
    
    print("Period stats calculated: ${sortedStats.length} periods");
    for (var stat in sortedStats) {
      print("Period ${stat['period']}: ${stat['contractCount']} contracts");
    }
    
    setState(() {
      _periodStats = sortedStats;
    });
  }

  Future<void> _loadTableCounts() async {
    final counts = await _dbHelper.getAllLinkTableCounts();
    setState(() {
      _tableCounts = counts;
    });
  }

  Future<void> _loadCurrentPeriodSummary() async {
    try {
      // Use the current period specified in widget parameters
      final summary = await _dbHelper.getMonthlySummary(widget.currentPeriod);
      print("Current period summary loaded: $summary");
      
      setState(() {
        _currentPeriodSummary = summary;
      });
    } catch (e) {
      print('Error loading current period summary: $e');
      // Fallback to latest period from stats if current period has no data
      if (_periodStats.isNotEmpty) {
        final latestPeriodStat = _periodStats.first;
        print("Using latest period as fallback: ${latestPeriodStat['period']}");
        
        setState(() {
          _currentPeriodSummary = latestPeriodStat;
        });
      } else {
        setState(() {
          _currentPeriodSummary = {
            'contractCount': 0,
          };
        });
      }
    }
  }

  Future<void> _loadRecentContracts() async {
    final contracts = await _dbHelper.getAllLinkHopDongs();
    // Sort by Thang (period) safely - since thang is now string, direct comparison works
    contracts.sort((a, b) {
      String thangA = a.thang ?? '';
      String thangB = b.thang ?? '';
      return thangB.compareTo(thangA);
    });
    setState(() {
      _recentContracts = contracts.take(5).toList();
    });
  }

  Future<void> _loadExpiringContracts() async {
    final contracts = await _dbHelper.getExpiringContracts();
    setState(() {
      _expiringContracts = contracts;
      _isLoading = false;
    });
  }

  String _extractPeriodFromThang(String? thang) {
    if (thang == null || thang.isEmpty) return '';
    
    print("_extractPeriodFromThang: Processing '$thang'");
    
    try {
      // Since thang is now stored as string (YYYY-MM-DD format)
      // Extract YYYY-MM portion
      if (thang.length >= 7 && thang.contains('-')) {
        List<String> parts = thang.split('-');
        if (parts.length >= 2) {
          String result = '${parts[0]}-${parts[1]}';
          print("_extractPeriodFromThang: Extracted from date string: '$result'");
          return result;
        }
      }
      
      // Try parsing as date if it's in full date format
      DateTime date = DateTime.parse(thang);
      String result = DateFormat('yyyy-MM').format(date);
      print("_extractPeriodFromThang: Successfully parsed as DateTime, result: '$result'");
      return result;
    } catch (e) {
      print("_extractPeriodFromThang: DateTime.parse failed: $e");
      
      // Try other common formats
      if (thang.length >= 6) {
        // Check for YYYYMM format
        if (RegExp(r'^\d{6}$').hasMatch(thang)) {
          String result = '${thang.substring(0, 4)}-${thang.substring(4, 6)}';
          print("_extractPeriodFromThang: Converted YYYYMM format: '$result'");
          return result;
        }
        
        // Check for MM/YYYY or MM-YYYY format
        if (thang.contains('/') || thang.contains('-')) {
          List<String> parts = thang.split(RegExp(r'[/-]'));
          if (parts.length == 2) {
            if (parts[1].length == 4) { // MM/YYYY
              String result = '${parts[1]}-${parts[0].padLeft(2, '0')}';
              print("_extractPeriodFromThang: Converted MM/YYYY format: '$result'");
              return result;
            } else if (parts[0].length == 4) { // YYYY/MM
              String result = '${parts[0]}-${parts[1].padLeft(2, '0')}';
              print("_extractPeriodFromThang: Converted YYYY/MM format: '$result'");
              return result;
            }
          }
        }
      }
      
      print("_extractPeriodFromThang: Could not extract period from: '$thang'");
      return '';
    }
  }

  // Helper method to safely convert objects to double (kept for compatibility)
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Helper method to safely convert date strings
  String _safeStringFromDate(String? value) {
    if (value == null || value.isEmpty) return '';
    return value; // Since dates are now stored as strings
  }

  String _formatPeriod(String period) {
    try {
      if (period.contains('-') && period.length >= 7) {
        List<String> parts = period.split('-');
        if (parts.length >= 2) {
          String year = parts[0];
          String month = parts[1];
          return '$month/$year';
        }
      }
      
      DateTime date = DateTime.parse('$period-01'); // Add day for parsing
      return DateFormat('MM/yyyy').format(date);
    } catch (e) {
      return period;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString; // Return as-is if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HD Dashboard'),
        backgroundColor: Color(0xFF024965),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'Tổng quan'),
            Tab(icon: Icon(Icons.description), text: 'Hợp đồng'),
            Tab(icon: Icon(Icons.warning), text: 'Cảnh báo'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildContractsTab(),
                    _buildAlertsTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              _error,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllData,
              child: Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Card
          _buildUserInfoCard(),
          SizedBox(height: 16),
          
          // Current Period Summary Card
          _buildCurrentPeriodCard(),
          SizedBox(height: 16),
          
          // Table Counts Card
          _buildTableCountsCard(),
        ],
      ),
    );
  }

  Widget _buildContractsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildRecentContractsCard(),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildExpiringContractsCard(),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin người dùng',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF024965),
              ),
            ),
            SizedBox(height: 12),
            _buildUserInfoRow('Tên đăng nhập', widget.username),
            _buildUserInfoRow('Vai trò', widget.userRole),
            _buildUserInfoRow('Kỳ hiện tại', _formatPeriod(widget.currentPeriod)),
            _buildUserInfoRow('Kỳ tiếp theo', _formatPeriod(widget.nextPeriod)),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPeriodCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống kê theo kỳ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF024965),
              ),
            ),
            SizedBox(height: 16),
            
            if (_periodStats.isEmpty)
              Center(
                child: Text(
                  'Không có dữ liệu',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Kỳ', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Số HĐ', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _periodStats.map((stat) {
                    return DataRow(
                      cells: [
                        DataCell(Text(_formatPeriod(stat['period']))),
                        DataCell(
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HDThang2Screen(
                                    period: stat['period'],
                                    username: widget.username,
                                    userRole: widget.userRole,
                                    currentPeriod: widget.currentPeriod,
                                    nextPeriod: widget.nextPeriod,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF024965),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size(60, 30),
                            ),
                            child: Text(
                              'Xem',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(Text('${stat['contractCount']}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCountsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng số bản ghi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF024965),
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildCountCard('Hợp đồng', _tableCounts['LinkHopDong'] ?? 0, Icons.description),
                _buildCountCard('Vật tư', _tableCounts['LinkVatTu'] ?? 0, Icons.inventory),
                _buildCountCard('Định kỳ', _tableCounts['LinkDinhKy'] ?? 0, Icons.schedule),
                _buildCountCard('Lễ Tết TC', _tableCounts['LinkLeTetTC'] ?? 0, Icons.celebration),
                _buildCountCard('Phụ cấp', _tableCounts['LinkPhuCap'] ?? 0, Icons.payment),
                _buildCountCard('Ngoại giao', _tableCounts['LinkNgoaiGiao'] ?? 0, Icons.public),
                _buildCountCard('Máy móc', _tableCounts['LinkMayMoc'] ?? 0, Icons.precision_manufacturing),
                _buildCountCard('Lương', _tableCounts['LinkLuong'] ?? 0, Icons.account_balance_wallet),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentContractsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hợp đồng gần đây',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF024965),
              ),
            ),
            SizedBox(height: 16),
            
            if (_recentContracts.isEmpty)
              Center(
                child: Text(
                  'Không có hợp đồng nào',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _recentContracts.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final contract = _recentContracts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFF024965),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      contract.tenHopDong ?? 'Không có tên',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Địa chỉ: ${contract.diaChi ?? 'N/A'}'),
                        Text('Kỳ: ${_formatPeriod(_extractPeriodFromThang(contract.thang))}'),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        contract.trangThai ?? 'N/A',
                        style: TextStyle(fontSize: 12),
                      ),
                      backgroundColor: _getStatusColor(contract.trangThai),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringContractsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Hợp đồng sắp hết hạn',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF024965),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            if (_expiringContracts.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Không có hợp đồng nào sắp hết hạn',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _expiringContracts.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final contract = _expiringContracts[index];
                  final daysLeft = _calculateDaysLeft(contract.thoiHanKetthuc);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: daysLeft <= 7 ? Colors.red : Colors.orange,
                      child: Text(
                        '$daysLeft',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text(
                      contract.tenHopDong ?? 'Không có tên',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Địa chỉ: ${contract.diaChi ?? 'N/A'}'),
                        Text('Hết hạn: ${_formatDate(contract.thoiHanKetthuc)}'),
                        Text(
                          'Còn $daysLeft ngày',
                          style: TextStyle(
                            color: daysLeft <= 7 ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.alarm,
                      color: daysLeft <= 7 ? Colors.red : Colors.orange,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountCard(String title, int count, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF024965).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF024965).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF024965), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF024965),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF024965),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'hoạt động':
      case 'duy trì':
        return Colors.green.withOpacity(0.2);
      case 'pending':
      case 'chờ duyệt':
        return Colors.orange.withOpacity(0.2);
      case 'expired':
      case 'hết hạn':
        return Colors.red.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  int _calculateDaysLeft(String? endDate) {
    if (endDate == null || endDate.isEmpty) return 0;
    
    try {
      DateTime end = DateTime.parse(endDate);
      DateTime now = DateTime.now();
      return end.difference(now).inDays;
    } catch (e) {
      return 0;
    }
  }
}