import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'table_models.dart';
import 'db_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 

class HSKho2Screen extends StatefulWidget {
    final String? username;
  const HSKho2Screen({Key? key, this.username}) : super(key: key);

  @override
  _HSKho2ScreenState createState() => _HSKho2ScreenState();
}

class _HSKho2ScreenState extends State<HSKho2Screen> {
  final DBHelper _dbHelper = DBHelper();
  String _username = ''; 
  // Selected warehouse and floor
  String? _selectedKhoHangID;
  String? _selectedKhuVucKhoID;
  String? _selectedPhong;
  
  // Lists for dropdowns
  List<KhoModel> _warehouses = [];
  List<KhuVucKhoModel> _floors = [];
  List<String> _rooms = [];
  
  // Data for the current floor
  List<KhuVucKhoChiTietModel> _floorDetails = [];
  List<KhuVucKhoChiTietModel> _filteredFloorDetails = [];
  
  // Grid dimensions
  int _gridWidth = 0;
  int _gridHeight = 0;
  
  // Statistics
  int _totalFloors = 0;
  int _totalRooms = 0;
  int _totalAisles = 0;
  double _warehouseCapacity = 0.0;
  double _floorCapacity = 0.0;
  double _roomCapacity = 0.0;
  
  // Loading state
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadWarehouses();
  }
 Future<void> _loadUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? '';
        print('Loaded username: $_username'); 
      });
    } catch (e) {
      print('Error loading username: $e');
    }
  }
  bool _userHasPermission(String? warehouseId) {
  if (_username.isEmpty || warehouseId == null) return false;
  
  final Map<String, List<String>> warehousePermissions = {
    "HN": ['nvthunghiem', 'hm.tason', 'hm.manhha', 'hm.phiminh', 'hm.lehoa'],
    "ĐN": ['nvthunghiem', 'hm.tason', 'hm.manhha', 'hotel.danang'],
    "NT": ['nvthunghiem', 'hm.tason', 'hm.manhha', 'hotel.nhatrang'],
    "SG": ['nvthunghiem', 'hm.tason', 'hm.manhha', 'hm.damchinh', 'hm.quocchien'],
  };
  
  final allowedUsers = warehousePermissions[warehouseId] ?? [];
  return allowedUsers.contains(_username);
}
  Future<void> _loadWarehouses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Get all warehouses
      final warehouses = await _dbHelper.getAllKho();
      
      setState(() {
        _warehouses = warehouses;
        // Auto-select first warehouse if available
        if (warehouses.isNotEmpty) {
          _selectedKhoHangID = warehouses[0].khoHangID;
          _loadFloors(_selectedKhoHangID!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      print('Error loading warehouses: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải danh sách kho hàng: $e';
      });
    }
  }

  Future<void> _loadFloors(String khoHangID) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _selectedKhuVucKhoID = null; // Reset floor selection
      _selectedPhong = null; // Reset room selection
    });
    
    try {
      // Get floors for selected warehouse
      final floors = await _dbHelper.getKhuVucKhoByKhoID(khoHangID);
      
      setState(() {
        _floors = floors;
        _totalFloors = floors.length;
        
        // Auto-select first floor if available
        if (floors.isNotEmpty) {
          _selectedKhuVucKhoID = floors[0].khuVucKhoID;
          _loadFloorDetails(_selectedKhuVucKhoID!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      print('Error loading floors: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải danh sách tầng: $e';
      });
    }
  }

  Future<void> _loadFloorDetails(String khuVucKhoID) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Get all details for selected floor
      final details = await _dbHelper.getKhuVucKhoChiTietByKhuVucKhoID(khuVucKhoID);
      
      // Extract unique rooms
      final uniqueRooms = <String>{};
      for (var detail in details) {
        if (detail.phong != null && detail.phong!.isNotEmpty) {
          uniqueRooms.add(detail.phong!);
        }
      }
      final rooms = uniqueRooms.toList()..sort();
      
      // Count unique aisles per room
      final uniqueAisles = <String>{};
      for (var detail in details) {
        if (detail.ke != null && detail.phong != null) {
          String aisleKey = '${detail.phong}-${detail.ke}';
          uniqueAisles.add(aisleKey);
        }
      }
      
      // Determine grid size from TangSize of first item
      int gridWidth = 0;
      int gridHeight = 0;
      
      if (details.isNotEmpty && details[0].tangSize != null) {
        final sizeParts = details[0].tangSize!.split('-');
        if (sizeParts.length == 2) {
          gridWidth = int.tryParse(sizeParts[0]) ?? 0;
          gridHeight = int.tryParse(sizeParts[1]) ?? 0;
        }
      }
      
      // Calculate warehouse statistics
      _calculateWarehouseStatistics(details);
      
      setState(() {
        _floorDetails = details;
        _rooms = rooms;
        _totalRooms = rooms.length;
        _totalAisles = uniqueAisles.length;
        
        // Auto-select first room if available
        if (rooms.isNotEmpty) {
          _selectedPhong = rooms[0];
          _filterDetailsByRoom();
        } else {
          _filteredFloorDetails = details;
          _calculateRoomCapacity(details);
        }
        
        _gridWidth = gridWidth;
        _gridHeight = gridHeight;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading floor details: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải chi tiết khu vực kho: $e';
      });
    }
  }
  
  void _filterDetailsByRoom() {
    if (_selectedPhong == null) {
      _filteredFloorDetails = _floorDetails;
    } else {
      _filteredFloorDetails = _floorDetails.where(
        (detail) => detail.phong == _selectedPhong
      ).toList();
      _calculateRoomCapacity(_filteredFloorDetails);
    }
  }
  
  void _calculateWarehouseStatistics(List<KhuVucKhoChiTietModel> details) {
    int totalCapacity = 0;
    int maxCapacity = 0;
    
    for (var detail in details) {
      totalCapacity += detail.dungTich ?? 0;
      maxCapacity += 100; // Assuming max capacity is 100 per item
    }
    
    _warehouseCapacity = maxCapacity > 0 ? (totalCapacity / maxCapacity) * 100 : 0.0;
    
    // Calculate floor capacity
    _calculateFloorCapacity(details);
  }
  
  void _calculateFloorCapacity(List<KhuVucKhoChiTietModel> details) {
    int totalCapacity = 0;
    int maxCapacity = 0;
    
    for (var detail in details) {
      if (detail.khuVucKhoID == _selectedKhuVucKhoID) {
        totalCapacity += detail.dungTich ?? 0;
        maxCapacity += 100; // Assuming max capacity is 100 per item
      }
    }
    
    _floorCapacity = maxCapacity > 0 ? (totalCapacity / maxCapacity) * 100 : 0.0;
  }
  
  void _calculateRoomCapacity(List<KhuVucKhoChiTietModel> details) {
    int totalCapacity = 0;
    int maxCapacity = 0;
    
    for (var detail in details) {
      totalCapacity += detail.dungTich ?? 0;
      maxCapacity += 100; // Assuming max capacity is 100 per item
    }
    
    _roomCapacity = maxCapacity > 0 ? (totalCapacity / maxCapacity) * 100 : 0.0;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quản lý Khu vực kho',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFD4AF37), // Gold
                Color(0xFF8B4513), // Brown
                Color(0xFFB8860B), // Dark gold
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildSelectionArea(),
        _buildStatisticsPanel(),
        Expanded(
          child: _gridWidth > 0 && _gridHeight > 0
              ? _buildFloorGrid()
              : Center(child: Text('Không có dữ liệu hiển thị')),
        ),
      ],
    );
  }

  Widget _buildSelectionArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Color(0xFFF5DEB3).withOpacity(0.3), // Light wheat color
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFD2B48C).withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Warehouse dropdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kho hàng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFD2B48C)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedKhoHangID,
                        hint: Text('Chọn kho', style: TextStyle(fontSize: 12)),
                        style: TextStyle(fontSize: 12, color: Colors.black),
                        items: _warehouses.map((warehouse) {
                          return DropdownMenuItem<String>(
                            value: warehouse.khoHangID,
                            child: Text(warehouse.khoHangID ?? 'Không xác định'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedKhoHangID = value;
                              _selectedKhuVucKhoID = null;
                              _selectedPhong = null;
                            });
                            _loadFloors(value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: 12),
          
          // Floor dropdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tầng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFD2B48C)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedKhuVucKhoID,
                        hint: Text('Chọn tầng', style: TextStyle(fontSize: 12)),
                        style: TextStyle(fontSize: 12, color: Colors.black),
                        items: _floors.map((floor) {
                          return DropdownMenuItem<String>(
                            value: floor.khuVucKhoID,
                            child: Text(floor.khuVucKhoID ?? 'Không xác định'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedKhuVucKhoID = value;
                              _selectedPhong = null;
                            });
                            _loadFloorDetails(value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: 12),
          
          // Room dropdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phòng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFD2B48C)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedPhong,
                        hint: Text('Chọn phòng', style: TextStyle(fontSize: 12)),
                        style: TextStyle(fontSize: 12, color: Colors.black),
                        items: _rooms.map((room) {
                          return DropdownMenuItem<String>(
                            value: room,
                            child: Text(room),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedPhong = value;
                              _filterDetailsByRoom();
                            });
                          }
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
    );
  }
  
  Widget _buildStatisticsPanel() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF5DEB3).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFD2B48C).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.layers,
            label: 'Tầng',
            value: '$_totalFloors',
          ),
          _buildStatItem(
            icon: Icons.meeting_room,
            label: 'Phòng',
            value: '$_totalRooms',
          ),
          _buildStatItem(
            icon: Icons.grid_on,
            label: 'Kệ',
            value: '$_totalAisles',
          ),
          _buildPieCapacityStat(
            label: 'Kho',
            value: _warehouseCapacity / 100,
          ),
          _buildPieCapacityStat(
            label: 'Tầng',
            value: _floorCapacity / 100,
          ),
          _buildPieCapacityStat(
            label: 'Phòng',
            value: _roomCapacity / 100,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFFB8860B), size: 16),
        SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPieCapacityStat({
    required String label,
    required double value,
  }) {
    // Choose color based on capacity percentage
    Color color;
    if (value < 0.5) {
      color = Colors.green;
    } else if (value < 0.8) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 18.0,
          lineWidth: 3.0,
          percent: value,
          center: Text(
            '${(value * 100).toInt()}%',
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
          ),
          progressColor: color,
          backgroundColor: Colors.grey.withOpacity(0.3),
          circularStrokeCap: CircularStrokeCap.round,
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildFloorGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridWidth,
          childAspectRatio: 1.0,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: _gridWidth * _gridHeight,
        itemBuilder: (context, index) {
          // Convert index to x-y coordinates (1-based)
          // Start from bottom up for Y coordinate
          final x = (index % _gridWidth) + 1;
          final y = _gridHeight - (index ~/ _gridWidth); // Flip Y coordinate
          final position = '$x-$y';
          
          // Find items at this position
          final cellItems = _filteredFloorDetails.where(
            (item) => item.viTri == position
          ).toList();
          
          return _buildGridCell(position, cellItems);
        },
      ),
    );
  }

  Widget _buildGridCell(String position, List<KhuVucKhoChiTietModel> items) {
    if (items.isEmpty) {
      // Empty cell
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(position, style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    // Group items by ke (aisle)
    final Map<String, List<KhuVucKhoChiTietModel>> aisleGroups = {};
    
    for (var item in items) {
      final ke = item.ke ?? 'Unknown';
      if (!aisleGroups.containsKey(ke)) {
        aisleGroups[ke] = [];
      }
      aisleGroups[ke]!.add(item);
    }
    
    return InkWell(
      onTap: () {
        _showCellDetailsDialog(position, items);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show position in top-right corner
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    position,
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              ),
              
              // Show aisle name
              Expanded(
                child: aisleGroups.length == 1
                    ? _buildSingleAisleContent(aisleGroups.values.first)
                    : _buildMultipleAislesContent(aisleGroups),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleAisleContent(List<KhuVucKhoChiTietModel> items) {
    final item = items.first;
    final totalCapacity = items.fold<int>(
      0, (sum, item) => sum + (item.dungTich ?? 0)
    );
    final maxCapacity = items.length * 100; // Assuming max capacity is 100 per item
    final capacityPercentage = maxCapacity > 0 ? (totalCapacity / maxCapacity) * 100 : 0.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '🪜 ${item.ke}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4),
        if (item.tangKe == 'Chung' || item.tangKe == null)
          // Show capacity directly if no separate floors
          _buildCapacityIndicator(capacityPercentage)
        else
          // Show floors and their capacity
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final floorItem = items[index];
                final floorCapacity = floorItem.dungTich?.toDouble() ?? 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      floorItem.tangKe ?? 'Tầng ?',
                      style: TextStyle(fontSize: 10),
                    ),
                    SizedBox(height: 2),
                    _buildCapacityIndicator(floorCapacity, mini: true),
                    SizedBox(height: 4),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

   Widget _buildMultipleAislesContent(Map<String, List<KhuVucKhoChiTietModel>> aisleGroups) {
    return ListView(
      shrinkWrap: true,
      children: aisleGroups.entries.map((entry) {
        final aisleName = entry.key;
        final items = entry.value;
        final totalCapacity = items.fold<int>(
          0, (sum, item) => sum + (item.dungTich ?? 0)
        );
        final maxCapacity = items.length * 100;
        final capacityPercentage = maxCapacity > 0 ? (totalCapacity / maxCapacity) * 100 : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🪜 $aisleName',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              _buildCapacityIndicator(capacityPercentage, mini: true),
            ],
          ),
        );
      }).toList(),
    );
  }
Widget _buildCapacityIndicator(double percentValue, {bool mini = false}) {
  // Choose color based on capacity percentage
  Color color = _getCapacityColor(percentValue.toInt());
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${percentValue.toInt()}%',
        style: TextStyle(
          fontSize: mini ? 9 : 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      SizedBox(height: 2),
      Container(
        height: mini ? 4 : 6,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(mini ? 2 : 3),
        ),
        child: FractionallySizedBox(
          widthFactor: percentValue / 100,
          heightFactor: 1.0,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(mini ? 2 : 3),
            ),
          ),
        ),
      ),
    ],
  );
}
  Widget _buildCapacityCircle(double value, {bool mini = false, bool showText = true}) {
    // Choose color based on capacity percentage
    Color color = _getCapacityColor((value * 100).toInt());
    
    double radius = mini ? 12.0 : 18.0;
    double lineWidth = mini ? 2.0 : 3.0;
    double fontSize = mini ? 7.0 : 9.0;
    
    return CircularPercentIndicator(
      radius: radius,
      lineWidth: lineWidth,
      percent: value,
      center: showText ? Text(
        '${(value * 100).toInt()}%',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ) : null,
      progressColor: color,
      backgroundColor: Colors.grey.withOpacity(0.3),
      circularStrokeCap: CircularStrokeCap.round,
    );
  }
    Future<List<LoHangModel>> _fetchBatchesForLocation(String chiTietID) async {
    try {
      // You'd need to add this method to your DBHelper class
      final batches = await _dbHelper.getLoHangByKhuVucKhoID(chiTietID);
      
      // Sort batches by ngayNhap in descending order (latest first)
      batches.sort((a, b) {
        if (a.ngayNhap == null) return 1;
        if (b.ngayNhap == null) return -1;
        return DateTime.parse(b.ngayNhap!).compareTo(DateTime.parse(a.ngayNhap!));
      });
      
      return batches;
    } catch (e) {
      print('Error fetching batches: $e');
      return [];
    }
  }

  // Add a method to fetch product details
  Future<Map<String, dynamic>?> _fetchProductDetails(String? maHangID) async {
    if (maHangID == null) return null;
    
    try {
      // You'd need to add this method to your DBHelper class
      return await _dbHelper.getHangHoaByID(maHangID);
    } catch (e) {
      print('Error fetching product details: $e');
      return null;
    }
  }
   void _showCellDetailsDialog(String position, List<KhuVucKhoChiTietModel> items) {
    if (items.isEmpty) return;
    
    // Check if user has permission for this warehouse
    bool hasPermission = _userHasPermission(_selectedKhoHangID);
    
    // Create a map to track edited values (so we only update changed items)
    Map<String, int> editedValues = {};
    
    // Full screen dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Chi tiết vị trí: $position'),
                  backgroundColor: Color(0xFFD4AF37),
                  leading: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    if (hasPermission && editedValues.isNotEmpty)
                      TextButton.icon(
                        icon: Icon(Icons.save, color: Colors.white),
                        label: Text('Lưu', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          _saveEditedValues(editedValues, items);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
                body: _buildDetailedContent(position, items, editedValues, setState, hasPermission),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildDetailedContent(
    String position, 
    List<KhuVucKhoChiTietModel> items, 
    Map<String, int> editedValues, 
    StateSetter setState,
    bool hasPermission
  ) {
    // Group items by aisle for better organization
    final Map<String, List<KhuVucKhoChiTietModel>> aisleGroups = {};
    
    for (var item in items) {
      final ke = item.ke ?? 'Unknown';
      if (!aisleGroups.containsKey(ke)) {
        aisleGroups[ke] = [];
      }
      aisleGroups[ke]!.add(item);
    }
    
    return DefaultTabController(
      length: aisleGroups.length, 
      child: Column(
        children: [
          Container(
            color: Color(0xFFF5DEB3).withOpacity(0.3),
            child: TabBar(
              isScrollable: true,
              tabs: aisleGroups.keys.map((aisle) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_week),
                      SizedBox(width: 8),
                      Text('Kệ $aisle'),
                    ],
                  ),
                );
              }).toList(),
              labelColor: Colors.brown,
              indicatorColor: Color(0xFFD4AF37),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: aisleGroups.entries.map((entry) {
                final aisleName = entry.key;
                final aisleItems = entry.value;
                
                return _buildAisleTabContent(
                  aisleName, 
                  aisleItems, 
                  editedValues, 
                  setState,
                  hasPermission
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAisleTabContent(
    String aisleName, 
    List<KhuVucKhoChiTietModel> items,
    Map<String, int> editedValues,
    StateSetter setState,
    bool hasPermission
  ) {
    return DefaultTabController(
      length: 2, // Two tabs: Details and Batches
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Thông tin kệ'),
              Tab(text: 'Lô hàng'),
            ],
            labelColor: Colors.brown,
            indicatorColor: Color(0xFFD4AF37),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // First tab: Aisle details
                ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    // Use the edited value if available, otherwise use the original
                    final currentDungTich = editedValues[item.chiTietID] ?? item.dungTich ?? 0;
                    
                    return Card(
                      margin: EdgeInsets.all(8),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tầng kệ: ${item.tangKe ?? "Chung"}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCapacityColor(currentDungTich).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$currentDungTich%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getCapacityColor(currentDungTich),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Divider(),
                            _buildInfoRow('ID', item.chiTietID ?? 'N/A'),
                            _buildInfoRow('Tầng', item.tang ?? 'N/A'),
                            _buildInfoRow('Phòng', item.phong ?? 'N/A'),
                            _buildInfoRow('Giỏ', item.gio ?? 'N/A'),
                            
                            // Add the slider for editing DungTich if user has permission
                            if (hasPermission) ...[
                              SizedBox(height: 16),
                              Text(
                                'Điều chỉnh dung tích:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: currentDungTich.toDouble(),
                                      min: 0,
                                      max: 100,
                                      divisions: 20,
                                      label: currentDungTich.toString(),
                                      activeColor: _getCapacityColor(currentDungTich),
                                      onChanged: (value) {
                                        // Update the edited value
                                        setState(() {
                                          editedValues[item.chiTietID!] = value.toInt();
                                        });
                                      },
                                    ),
                                  ),
                                  Container(
                                    width: 60,
                                    child: Text(
                                      '$currentDungTich%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            
                            if (item.noiDung != null && item.noiDung!.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 16),
                                  Text(
                                    'Nội dung:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(8),
                                    margin: EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(item.noiDung ?? ''),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Second tab: Batches
                _buildBatchesTab(items),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBatchesTab(List<KhuVucKhoChiTietModel> items) {
    // Combine all chiTietIDs to fetch all batches for this position
    final List<String> chiTietIDs = items
        .where((item) => item.chiTietID != null)
        .map((item) => item.chiTietID!)
        .toList();
    
    if (chiTietIDs.isEmpty) {
      return Center(child: Text('Không có dữ liệu lô hàng'));
    }
    
    return FutureBuilder<List<List<LoHangModel>>>(
      future: Future.wait(
        chiTietIDs.map((id) => _fetchBatchesForLocation(id))
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Không có dữ liệu lô hàng'));
        }
        
        // Flatten the list of lists
        final List<LoHangModel> allBatches = snapshot.data!
            .expand((batches) => batches)
            .toList();
        
        // Sort by ngayNhap (newest first)
        allBatches.sort((a, b) {
          final dateA = a.ngayNhap != null 
              ? DateTime.tryParse(a.ngayNhap!) 
              : null;
          final dateB = b.ngayNhap != null 
              ? DateTime.tryParse(b.ngayNhap!)
              : null;
          
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          
          return dateB.compareTo(dateA);
        });
        
        if (allBatches.isEmpty) {
          return Center(child: Text('Không có lô hàng tại vị trí này'));
        }
        
        return ListView.builder(
          itemCount: allBatches.length,
          itemBuilder: (context, index) {
            final batch = allBatches[index];
            return _buildBatchCard(batch);
          },
        );
      },
    );
  }
  
  Widget _buildBatchCard(LoHangModel batch) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final ngayNhap = batch.ngayNhap != null 
      ? dateFormat.format(DateTime.parse(batch.ngayNhap!))
      : 'N/A';
  final ngayCapNhat = batch.ngayCapNhat != null 
      ? dateFormat.format(DateTime.parse(batch.ngayCapNhat!))
      : 'N/A';
  
  // Instead of using FutureBuilder to get product details, just display the maHangID directly
  return Card(
    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // Change here: Use batch.maHangID instead of productName
                  batch.maHangID ?? 'N/A',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(batch.trangThai).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  batch.trangThai ?? 'N/A',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(batch.trangThai),
                  ),
                ),
              ),
            ],
          ),
          Divider(),
          _buildInfoRow('Mã lô hàng', batch.loHangID ?? 'N/A'),
          _buildInfoRow('Số lượng hiện tại', 
              batch.soLuongHienTai != null ? batch.soLuongHienTai.toString() : 'N/A'),
          _buildInfoRow('Số lượng ban đầu', 
              batch.soLuongBanDau != null ? batch.soLuongBanDau.toString() : 'N/A'),
          _buildInfoRow('Ngày nhập', ngayNhap),
          _buildInfoRow('Ngày cập nhật', ngayCapNhat),
          if (batch.hanSuDung != null)
            _buildInfoRow('Hạn sử dụng', '${batch.hanSuDung} ngày'),
        ],
      ),
    ),
  );
}

// Add a helper function to determine status color
Color _getStatusColor(String? status) {
  if (status == null) return Colors.grey;
  
  switch (status.toLowerCase()) {
    case 'còn hàng':
      return Colors.green;
    case 'sắp hết':
      return Colors.orange;
    case 'hết hàng':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
Future<void> _saveEditedValues(Map<String, int> editedValues, List<KhuVucKhoChiTietModel> items) async {
  if (editedValues.isEmpty) return;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    final client = http.Client();
    bool hasError = false;
    
    // Process each edited item
    for (final entry in editedValues.entries) {
      final chiTietID = entry.key;
      final newDungTich = entry.value;
      
      // Find the original item
      final originalItem = items.firstWhere(
        (item) => item.chiTietID == chiTietID,
        orElse: () => throw Exception('Item not found'),
      );
      
      // Create updated item
      final updatedItem = KhuVucKhoChiTietModel(
        chiTietID: chiTietID,
        khuVucKhoID: originalItem.khuVucKhoID,
        tang: originalItem.tang,
        phong: originalItem.phong,
        ke: originalItem.ke,
        tangKe: originalItem.tangKe,
        gio: originalItem.gio,
        viTri: originalItem.viTri,
        noiDung: originalItem.noiDung,
        tangSize: originalItem.tangSize,
        dungTich: newDungTich,
      );
      
      // Send update to server
      try {
        final response = await client.post(
          Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hotelaisle/$chiTietID'),
          body: jsonEncode(updatedItem.toMap()),
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 10));
        
        if (response.statusCode != 200) {
          print('Error updating item $chiTietID: ${response.statusCode}');
          hasError = true;
        } else {
          // Update local data
          for (int i = 0; i < _floorDetails.length; i++) {
            if (_floorDetails[i].chiTietID == chiTietID) {
              _floorDetails[i].dungTich = newDungTich;
              break;
            }
          }
        }
      } catch (e) {
        print('Network error updating item $chiTietID: $e');
        hasError = true;
      }
    }
    
    client.close();
    
    setState(() {
      _isLoading = false;
      // Update the filtered list
      _filterDetailsByRoom();
    });
    
    // Show appropriate message
    if (hasError) {
      _showErrorSnackBar('Một số thay đổi không thể lưu. Vui lòng thử lại.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu thay đổi thành công'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
    // Recalculate capacities
    _calculateWarehouseStatistics(_floorDetails);
    
  } catch (e) {
    print('Error saving values: $e');
    setState(() {
      _isLoading = false;
    });
    _showErrorSnackBar('Lỗi: ${e.toString()}');
  }
}
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCapacityColor(int capacity) {
    if (capacity < 50) {
      return Colors.green;
    } else if (capacity < 80) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}