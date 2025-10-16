import 'package:flutter/material.dart';
import 'dart:math';
import 'db_helper.dart';
import 'table_models.dart';
import 'hd_yeucaumayquanly.dart';
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
  List<String> _uniqueHangMay = ['Tất cả'];
  List<String> _uniqueLoaiMay = ['Tất cả'];
  String _selectedHangMay = 'Tất cả';
  String _selectedLoaiMay = 'Tất cả';
  bool _isLoading = true;
  int _totalRecords = 0;
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
    _loadData();
    _searchController.addListener(_filterData);
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final danhMucMayData = await _dbHelper.getAllLinkDanhMucMays();
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
      setState(() {
        _allDanhMucMay = danhMucMayData;
        _filteredDanhMucMay = danhMucMayData;
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
                          builder: (context) => HDYeuCauMayQuanLyScreen(
                            username: widget.username,
                            userRole: widget.userRole,
                            currentPeriod: widget.currentPeriod,
                            nextPeriod: widget.nextPeriod,
                          ),
                        ),
                      );
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