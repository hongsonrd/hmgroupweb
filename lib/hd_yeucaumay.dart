import 'package:flutter/material.dart';
import 'dart:math';
import 'db_helper.dart';
import 'table_models.dart';
import 'hd_yeucaumayquanly.dart';
import 'hd_yeucaumaymoi.dart';

class HDYeuCauMayScreen extends StatefulWidget {
  final String username;
  final String userRole;
  final String currentPeriod;
  final String nextPeriod;

  const HDYeuCauMayScreen({
    Key? key,
    required this.username,
    required this.userRole,
    required this.currentPeriod,
    required this.nextPeriod,
  }) : super(key: key);

  @override
  _HDYeuCauMayScreenState createState() => _HDYeuCauMayScreenState();
}

class _HDYeuCauMayScreenState extends State<HDYeuCauMayScreen> {
  final DBHelper _dbHelper = DBHelper();
  final TextEditingController _searchController = TextEditingController();
  
  List<LinkDanhMucMayModel> _allDanhMucMay = [];
  List<LinkDanhMucMayModel> _filteredDanhMucMay = [];
  List<LinkYeuCauMayModel> _allRequests = [];
  
  List<String> _uniqueHangMay = ['Tất cả'];
  List<String> _uniqueLoaiMay = ['Tất cả'];
  String _selectedHangMay = 'Tất cả';
  String _selectedLoaiMay = 'Tất cả';
  bool _isLoading = true;
  int _totalRecords = 0;

  // Dashboard stats
  int _totalRequests = 0;
  int _draftRequests = 0;
  int _pendingManagerApproval = 0;
  int _pendingFinanceApproval = 0;
  int _approvedRequests = 0;
  int _rejectedRequests = 0;
  
  // Approval permissions
  final List<String> _managerApprovers = ['hm.tason', 'hm.tranminh'];
  final List<String> _financeApprovers = ['hm.tason', 'hm.nguyenyen'];
  
  bool _isManagerApprover = false;
  bool _isFinanceApprover = false;
  int _needsMyApproval = 0;

  final List<IconData> _machineIcons = [
    Icons.precision_manufacturing,
    Icons.build,
    Icons.construction,
    Icons.engineering,
    Icons.settings,
    Icons.handyman,
    Icons.hardware,
    Icons.home_repair_service,
    Icons.plumbing,
    Icons.electrical_services,
    Icons.carpenter,
    Icons.cleaning_services,
    Icons.miscellaneous_services,
    Icons.design_services,
    Icons.hvac,
    Icons.power,
    Icons.power_settings_new,
    Icons.settings_applications,
    Icons.settings_power,
    Icons.build_circle,
  ];

  final List<Color> _iconColors = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFE53935),
    Color(0xFFFF6F00),
    Color(0xFF6A1B9A),
    Color(0xFF00ACC1),
    Color(0xFFD81B60),
    Color(0xFF546E7A),
    Color(0xFF3949AB),
    Color(0xFF00897B),
  ];

  final Random _random = Random();
  final Map<String, IconData> _iconCache = {};
  final Map<String, Color> _colorCache = {};

  @override
  void initState() {
    super.initState();
    _checkApprovalPermissions();
    _loadData();
    _searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _checkApprovalPermissions() {
    _isManagerApprover = _managerApprovers.contains(widget.username.toLowerCase());
    _isFinanceApprover = _financeApprovers.contains(widget.username.toLowerCase());
  }

  IconData _getIconForItem(String itemId) {
    if (!_iconCache.containsKey(itemId)) {
      _iconCache[itemId] = _machineIcons[_random.nextInt(_machineIcons.length)];
    }
    return _iconCache[itemId]!;
  }

  Color _getColorForLoaiMay(String? loaiMay) {
    if (loaiMay == null) return Colors.grey;
    if (!_colorCache.containsKey(loaiMay)) {
      _colorCache[loaiMay] = _iconColors[loaiMay.hashCode.abs() % _iconColors.length];
    }
    return _colorCache[loaiMay]!;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load machine catalog
      final danhMucMayData = await _dbHelper.getAllLinkDanhMucMays();
      
      // Load requests for dashboard
      final requestsData = await _dbHelper.getAllLinkYeuCauMays();
      
      final uniqueHangMaySet = <String>{};
      final uniqueLoaiMaySet = <String>{};

      for (var item in danhMucMayData) {
        if (item.hangMay != null && item.hangMay!.isNotEmpty) {
          uniqueHangMaySet.add(item.hangMay!);
        }
        if (item.loaiMay != null && item.loaiMay!.isNotEmpty) {
          uniqueLoaiMaySet.add(item.loaiMay!);
        }
      }

      // Calculate dashboard stats
      _calculateDashboardStats(requestsData);

      setState(() {
        _allDanhMucMay = danhMucMayData;
        _filteredDanhMucMay = danhMucMayData;
        _allRequests = requestsData;
        _totalRecords = danhMucMayData.length;
        _uniqueHangMay = ['Tất cả', ...uniqueHangMaySet.toList()..sort()];
        _uniqueLoaiMay = ['Tất cả', ...uniqueLoaiMaySet.toList()..sort()];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải dữ liệu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _calculateDashboardStats(List<LinkYeuCauMayModel> requests) {
    _totalRequests = requests.length;
    _draftRequests = 0;
    _pendingManagerApproval = 0;
    _pendingFinanceApproval = 0;
    _approvedRequests = 0;
    _rejectedRequests = 0;
    _needsMyApproval = 0;

    for (var request in requests) {
      switch (request.trangThai) {
        case 'Nháp':
          _draftRequests++;
          break;
        case 'Gửi':
          _pendingManagerApproval++;
          if (_isManagerApprover) _needsMyApproval++;
          break;
        case 'TPKD Duyệt':
          _pendingFinanceApproval++;
          if (_isFinanceApprover) _needsMyApproval++;
          break;
        case 'TPKD Từ chối':
        case 'Kế toán từ chối':
          _rejectedRequests++;
          break;
        case 'Kế toán duyệt':
          _approvedRequests++;
          break;
      }
    }
  }

  void _filterData() {
    final searchText = _searchController.text.toLowerCase();
    setState(() {
      _filteredDanhMucMay = _allDanhMucMay.where((item) {
        final matchesSearch = searchText.isEmpty ||
            (item.loaiMay?.toLowerCase().contains(searchText) ?? false) ||
            (item.maMay?.toLowerCase().contains(searchText) ?? false) ||
            (item.hangMay?.toLowerCase().contains(searchText) ?? false);

        final matchesHangMay = _selectedHangMay == 'Tất cả' ||
            item.hangMay == _selectedHangMay;

        final matchesLoaiMay = _selectedLoaiMay == 'Tất cả' ||
            item.loaiMay == _selectedLoaiMay;

        return matchesSearch && matchesHangMay && matchesLoaiMay;
      }).toList();
    });
  }

  Widget _buildDashboardCard(String title, int count, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalNotification() {
    if (!_isManagerApprover && !_isFinanceApprover) {
      return SizedBox.shrink();
    }

    if (_needsMyApproval == 0) {
      return SizedBox.shrink();
    }

    String approvalType = _isManagerApprover ? 'TPKD' : 'Kế toán';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFFF6F00), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.notification_important, color: Color(0xFFFF6F00)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bạn có $_needsMyApproval yêu cầu cần duyệt ($approvalType)',
              style: TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFFF6F00)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Danh mục máy móc'),
            Text(
              'Tổng số: $_totalRecords bản ghi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1976D2),
                Color(0xFF42A5F5),
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Dashboard Stats Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF42A5F5).withOpacity(0.05),
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng quan yêu cầu máy móc',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    _buildDashboardCard(
                      'Tổng số',
                      _totalRequests,
                      Color(0xFF1976D2),
                      Icons.summarize,
                    ),
                    SizedBox(width: 8),
                    _buildDashboardCard(
                      'Nháp',
                      _draftRequests,
                      Color(0xFF757575),
                      Icons.edit_note,
                    ),
                    SizedBox(width: 8),
                    _buildDashboardCard(
                      'Chờ TPKD',
                      _pendingManagerApproval,
                      Color(0xFFFF9800),
                      Icons.pending_actions,
                    ),
                    SizedBox(width: 8),
                    _buildDashboardCard(
                      'Chờ KT',
                      _pendingFinanceApproval,
                      Color(0xFFFFA726),
                      Icons.account_balance,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildDashboardCard(
                      'Đã duyệt',
                      _approvedRequests,
                      Color(0xFF4CAF50),
                      Icons.check_circle,
                    ),
                    SizedBox(width: 8),
                    _buildDashboardCard(
                      'Từ chối',
                      _rejectedRequests,
                      Color(0xFFE53935),
                      Icons.cancel,
                    ),
                    Expanded(child: SizedBox()),
                    Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),

          // Approval Notification Bar
          _buildApprovalNotification(),

          // Action Buttons Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF42A5F5).withOpacity(0.1),
                  Colors.white,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HDYeuCauMayMoiScreen(
                            username: widget.username,
                            userRole: widget.userRole,
                            currentPeriod: widget.currentPeriod,
                            nextPeriod: widget.nextPeriod,
                          ),
                        ),
                      ).then((_) => _loadData()); // Refresh after creating
                    },
                    icon: Icon(Icons.add_circle),
                    label: Text('Tạo yêu cầu mới'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 3,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HDYeuCauMayQuanLyScreen(
                            username: widget.username,
                            userRole: widget.userRole,
                            currentPeriod: widget.currentPeriod,
                            nextPeriod: widget.nextPeriod,
                          ),
                        ),
                      ).then((_) => _loadData()); // Refresh after managing
                    },
                    icon: Icon(Icons.manage_accounts),
                    label: Text('Quản lý yêu cầu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search and Filter Section
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm',
                    hintText: 'Nhập loại máy, mã máy hoặc hãng máy...',
                    prefixIcon: Icon(Icons.search, color: Color(0xFF1976D2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterData();
                            },
                          )
                        : null,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Loại máy: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedLoaiMay,
                                  isExpanded: true,
                                  items: _uniqueLoaiMay.map((loaiMay) {
                                    return DropdownMenuItem<String>(
                                      value: loaiMay,
                                      child: Text(loaiMay),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedLoaiMay = value!;
                                      _filterData();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Hãng: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedHangMay,
                                  isExpanded: true,
                                  items: _uniqueHangMay.map((hangMay) {
                                    return DropdownMenuItem<String>(
                                      value: hangMay,
                                      child: Text(hangMay),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedHangMay = value!;
                                      _filterData();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Machine List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredDanhMucMay.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Không tìm thấy kết quả',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = constraints.maxWidth > 1200 ? 4 : 
                                              constraints.maxWidth > 800 ? 3 : 
                                              constraints.maxWidth > 600 ? 2 : 1;
                          return GridView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 4.5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _filteredDanhMucMay.length,
                            itemBuilder: (context, index) {
                              final item = _filteredDanhMucMay[index];
                              final icon = _getIconForItem(item.danhMucId);
                              final color = _getColorForLoaiMay(item.loaiMay);
                              return Card(
                                margin: EdgeInsets.zero,
                                elevation: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.grey[100]!,
                                        Colors.grey[50]!,
                                      ],
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {},
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              icon,
                                              color: color,
                                              size: 24,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  item.loaiMay ?? 'N/A',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Mã: ${item.maMay ?? 'N/A'} • Hãng: ${item.hangMay ?? 'N/A'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey[400],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}