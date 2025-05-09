import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'table_models.dart';
import 'db_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 
import 'hs_kho2tim.dart';

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
  // Use OrientationBuilder to handle orientation changes
  return OrientationBuilder(
    builder: (context, orientation) {
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
    },
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
  return Column(
    children: [
      Container(
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
      ),
      // Add buttons row
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.dashboard_outlined),
                label: Text('Xem tổng thể'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  _showOverviewDialog();
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(Icons.search),
                label: Text('Tìm hàng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFB8860B),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  _openProductSearch();
                },
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// Add this property to the _HSKho2ScreenState class
String? _highlightedPosition;

// Add this method to the _HSKho2ScreenState class
void _openProductSearch() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProductSearchScreen(
        dbHelper: _dbHelper,
        khoHangID: _selectedKhoHangID,
      ),
    ),
  );
  
  // Handle result when returning from product search screen
  if (result != null && result is Map<String, dynamic>) {
    final khuVucKhoID = result['khuVucKhoID'];
    
    if (khuVucKhoID != null) {
      // First check if we need to change warehouse ID
      final khoID = khuVucKhoID.toString().split('-').first;
      if (_selectedKhoHangID != khoID) {
        setState(() {
          _selectedKhoHangID = khoID;
        });
        await _loadFloors(khoID);
      }
      
      // Then set the floor
      if (_selectedKhuVucKhoID != khuVucKhoID) {
        setState(() {
          _selectedKhuVucKhoID = khuVucKhoID;
        });
        await _loadFloorDetails(khuVucKhoID);
      }
      
      // Now, let's try to highlight the specific location
      // First, get all the floor details to find the location
      final floorDetails = await _dbHelper.getKhuVucKhoChiTietByKhuVucKhoID(khuVucKhoID);
      
      // If we have location details, try to highlight a position
      if (floorDetails.isNotEmpty) {
        // Let's find a position that's not empty (this is a simplification)
        KhuVucKhoChiTietModel? locationDetail;
        String? phong;
        
        for (var detail in floorDetails) {
          if (detail.viTri != null && detail.viTri!.isNotEmpty) {
            locationDetail = detail;
            phong = detail.phong;
            break;
          }
        }
        
        if (locationDetail != null) {
          // If we have a room, set it
          if (phong != null && phong != _selectedPhong) {
            setState(() {
              _selectedPhong = phong;
              _filterDetailsByRoom();
            });
          }
          
          // Highlight the position
          _highlightPosition(locationDetail.viTri!);
        }
      }
    }
  }
}

// Add this method to highlight a position
void _highlightPosition(String viTri) {
  // Set the highlighted position
  setState(() {
    _highlightedPosition = viTri;
  });
  
  // Show a message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Vị trí tìm kiếm: $viTri'),
      duration: Duration(seconds: 3),
    ),
  );
  
  // Clear the highlight after 3 seconds
  Future.delayed(Duration(seconds: 3), () {
    if (mounted) {
      setState(() {
        _highlightedPosition = null;
      });
    }
  });
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
  // Determine screen size and orientation
  final screenWidth = MediaQuery.of(context).size.width;
  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  
  // Always use 12 columns for landscape/tablet
  final int columnCount = isLandscape || screenWidth > 600 ? 12 : 4;
  
  // First, find all positions that have items
  final Map<String, List<KhuVucKhoChiTietModel>> positionsWithItems = {};
  final Set<int> usedXCoordinates = {}; // Track unique X values
  final Set<int> usedYCoordinates = {}; // Track unique Y values
  
  // Extract coordinates from all positions
  for (var item in _filteredFloorDetails) {
    if (item.viTri != null) {
      final parts = item.viTri!.split('-');
      if (parts.length == 2) {
        final x = int.tryParse(parts[0]);
        final y = int.tryParse(parts[1]);
        
        if (x != null && y != null) {
          usedXCoordinates.add(x);
          usedYCoordinates.add(y);
          
          // FIX HERE: Initialize the list if it doesn't exist
          positionsWithItems.putIfAbsent(item.viTri!, () => []);
          positionsWithItems[item.viTri!]!.add(item);
        }
      }
    }
  }
  
  // Sort coordinates for mapping
  final sortedX = usedXCoordinates.toList()..sort();
  final sortedY = usedYCoordinates.toList()..sort();
  
  // Create coordinate mappings
  final Map<int, int> xMapping = {};
  for (int i = 0; i < sortedX.length; i++) {
    // Map each original X to a column in our 12-column grid
    // This distributes the X values evenly across the 12 columns
    xMapping[sortedX[i]] = (i * columnCount / sortedX.length).floor();
  }
  
  final Map<int, int> yMapping = {};
  for (int i = 0; i < sortedY.length; i++) {
    // Keep Y ordering but map to row indices
    yMapping[sortedY[i]] = sortedY.length - i - 1; // Reverse to start from bottom
  }
  
  return Stack(
    children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: sortedX.isNotEmpty && sortedY.isNotEmpty ? 
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              childAspectRatio: 1.0,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: columnCount * sortedY.length,
            itemBuilder: (context, index) {
              final col = index % columnCount;
              final row = index ~/ columnCount;
              
              // Find if any of our actual positions map to this grid cell
              String? matchingPosition;
              for (var position in positionsWithItems.keys) {
                final parts = position.split('-');
                if (parts.length == 2) {
                  final x = int.tryParse(parts[0]);
                  final y = int.tryParse(parts[1]);
                  
                  if (x != null && y != null && 
                      xMapping[x] == col && 
                      yMapping[y] == row) {
                    matchingPosition = position;
                    break;
                  }
                }
              }
              
              // If no position maps to this cell, return empty container
              if (matchingPosition == null) {
                return Container();
              }
              
              return _buildGridCell(
                matchingPosition, 
                positionsWithItems[matchingPosition]!
              );
            },
          ) : 
          Center(child: Text('Không có dữ liệu hiển thị')),
      ),
      
      // Wall border and entry arrow
      Positioned.fill(child: CustomPaint(painter: RoomWallPainter())),
      
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Icon(Icons.arrow_upward, color: Colors.white, size: 18),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildGridCell(String position, List<KhuVucKhoChiTietModel> items) {
  final bool isHighlighted = position == _highlightedPosition;
  
  if (items.isEmpty) {
    // Empty cell
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isHighlighted ? Colors.red : Colors.grey.withOpacity(0.3),
          width: isHighlighted ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isHighlighted ? Colors.red.withOpacity(0.1) : null,
      ),
      child: Center(
        child: Text(
          position,
          style: TextStyle(
            color: isHighlighted ? Colors.red : Colors.grey,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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
        border: Border.all(
          color: isHighlighted ? Colors.red : Colors.blue,
          width: isHighlighted ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: isHighlighted ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.1),
            spreadRadius: isHighlighted ? 2 : 1,
            blurRadius: isHighlighted ? 4 : 2,
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
                  color: isHighlighted ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  position,
                  style: TextStyle(
                    fontSize: 10,
                    color: isHighlighted ? Colors.red : Colors.black54,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  ),
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
void _showOverviewDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Tổng thể kho ${_selectedKhoHangID ?? ""}'),
            backgroundColor: Color(0xFFD4AF37),
            leading: IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: FutureBuilder<List<KhuVucKhoChiTietModel>>(
            future: _loadAllWarehouseDetails(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi: ${snapshot.error}'));
              }
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('Không có dữ liệu hiển thị'));
              }
              
              return _buildWarehouseOverview(snapshot.data!);
            },
          ),
        ),
      );
    },
  );
}

Future<List<KhuVucKhoChiTietModel>> _loadAllWarehouseDetails() async {
  List<KhuVucKhoChiTietModel> allDetails = [];
  
  // Load details for all floors in the current warehouse
  try {
    for (var floor in _floors) {
      final floorDetails = await _dbHelper.getKhuVucKhoChiTietByKhuVucKhoID(floor.khuVucKhoID!);
      allDetails.addAll(floorDetails);
    }
  } catch (e) {
    print('Error loading all warehouse details: $e');
  }
  
  return allDetails;
}

Widget _buildWarehouseOverview(List<KhuVucKhoChiTietModel> allDetails) {
  // Group details by floor
  final Map<String, Map<String, List<KhuVucKhoChiTietModel>>> floorRoomGroups = {};
  
  for (var detail in allDetails) {
    if (detail.khuVucKhoID == null || detail.phong == null) continue;
    
    if (!floorRoomGroups.containsKey(detail.khuVucKhoID)) {
      floorRoomGroups[detail.khuVucKhoID!] = {};
    }
    
    if (!floorRoomGroups[detail.khuVucKhoID!]!.containsKey(detail.phong)) {
      floorRoomGroups[detail.khuVucKhoID!]![detail.phong!] = [];
    }
    
    floorRoomGroups[detail.khuVucKhoID!]![detail.phong!]!.add(detail);
  }
  
  // Sort floors in descending order
  final sortedFloors = floorRoomGroups.keys.toList()
    ..sort((a, b) => b.compareTo(a));
  
  return ListView.builder(
    itemCount: sortedFloors.length,
    itemBuilder: (context, floorIndex) {
      final floorID = sortedFloors[floorIndex];
      final roomGroups = floorRoomGroups[floorID]!;
      
      // Sort rooms in descending order within each floor
      final sortedRooms = roomGroups.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // More compact floor header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
            color: Color(0xFFD4AF37).withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tầng $floorID',
                  style: TextStyle(
                    fontSize: 16, // Smaller font
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                  ),
                ),
                _buildCompactFloorCapacity(roomGroups),
              ],
            ),
          ),
          
          // Rooms grid
          _buildRoomsGrid(floorID, sortedRooms, roomGroups),
          
          // Add a small divider between floors
          Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.2)),
        ],
      );
    },
  );
}

Widget _buildCompactFloorCapacity(Map<String, List<KhuVucKhoChiTietModel>> roomGroups) {
  // Calculate floor capacity
  int totalCapacity = 0;
  int maxCapacity = 0;
  
  for (var roomDetails in roomGroups.values) {
    for (var detail in roomDetails) {
      totalCapacity += detail.dungTich ?? 0;
      maxCapacity += 100;
    }
  }
  
  final floorCapacity = maxCapacity > 0 ? (totalCapacity / maxCapacity) * 100 : 0.0;
  
  return Row(
    children: [
      Text(
        '${floorCapacity.toInt()}%',
        style: TextStyle(
          fontSize: 14, // Smaller font
          fontWeight: FontWeight.bold,
          color: _getCapacityColor(floorCapacity.toInt()),
        ),
      ),
      SizedBox(width: 4),
      Container(
        width: 20, height: 20, // Fixed smaller size
        child: _buildCapacityCircle(floorCapacity / 100, mini: true, showText: false),
      ),
    ],
  );
}

Widget _buildRoomsGrid(
  String floorID,
  List<String> sortedRooms,
  Map<String, List<KhuVucKhoChiTietModel>> roomGroups
) {
  // Determine layout based on screen orientation and size
  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  final screenWidth = MediaQuery.of(context).size.width;
  
  // Calculate number of columns based on screen size - increased for more compact layout
  final columns = isLandscape || screenWidth > 600 ? 
                 (screenWidth > 1200 ? 6 : (screenWidth > 800 ? 4 : 3)) : 2;
  
  return Padding(
    padding: EdgeInsets.all(8), // Reduced padding
    child: GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 1.1, // Slightly wider than tall
        crossAxisSpacing: 8,   // Reduced spacing
        mainAxisSpacing: 8,    // Reduced spacing
      ),
      itemCount: sortedRooms.length,
      itemBuilder: (context, roomIndex) {
        final roomName = sortedRooms[roomIndex];
        final roomDetails = roomGroups[roomName]!;
        return _buildRoomCell(floorID, roomName, roomDetails);
      },
    ),
  );
}

Widget _buildRoomCell(
  String floorID, 
  String roomName, 
  List<KhuVucKhoChiTietModel> roomDetails
) {
  // Count aisles in this room
  final aisles = <String>{};
  for (var detail in roomDetails) {
    if (detail.ke != null) aisles.add(detail.ke!);
  }
  
  // Calculate room capacity
  int totalCapacity = 0;
  int maxCapacity = 0;
  
  for (var detail in roomDetails) {
    totalCapacity += detail.dungTich ?? 0;
    maxCapacity += 100;
  }
  
  final roomCapacity = maxCapacity > 0 ? (totalCapacity / maxCapacity) * 100 : 0.0;
  
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: InkWell(
      onTap: () {
        // Changed: Now navigates to product search instead of the room view
        Navigator.of(context).pop(); // Close the overview dialog
        _openProductSearch(); // Open the product search screen
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              _getCapacityColor(roomCapacity.toInt()).withOpacity(0.15),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room header - more compact
              Row(
                children: [
                  Icon(Icons.meeting_room, color: Color(0xFFB8860B), size: 14), // Smaller icon
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'P.$roomName', // Shortened prefix
                      style: TextStyle(
                        fontSize: 12, // Smaller font
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 24, height: 24, // Fixed size
                    child: _buildCapacityCircle(roomCapacity / 100, mini: true, showText: false),
                  ),
                ],
              ),
              
              // Room stats - simplified
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCompactStat(
                        icon: Icons.grid_on,
                        value: '${aisles.length}',
                      ),
                      SizedBox(width: 8),
                      _buildCompactStat(
                        icon: Icons.grid_4x4,
                        value: '${roomDetails.length}',
                      ),
                    ],
                  ),
                ),
              ),
              
              // Capacity indicator
              Container(
                height: 4, // Very compact height
                child: LinearPercentIndicator(
                  lineHeight: 4,
                  percent: roomCapacity / 100,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  progressColor: _getCapacityColor(roomCapacity.toInt()),
                  barRadius: Radius.circular(2),
                  padding: EdgeInsets.zero,
                  center: null, // Remove text for more compact look
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Helper widget for compact stats
Widget _buildCompactStat({
  required IconData icon,
  required String value,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Color(0xFFB8860B), size: 14), // Smaller icon
      SizedBox(width: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 14, // Smaller font
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
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
class RoomWallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    final path = Path();
    
    // Calculate entry width (about 20% of the bottom width)
    final entryWidth = size.width * 0.2;
    final entryStart = (size.width - entryWidth) / 2;
    final entryEnd = entryStart + entryWidth;
    
    // Start from left side of entry at the very bottom
    path.moveTo(entryStart, size.height);
    
    // Draw left wall from bottom to top
    path.lineTo(4, size.height);
    path.lineTo(4, 4);
    
    // Draw top wall from left to right
    path.lineTo(size.width - 4, 4);
    
    // Draw right wall from top to bottom
    path.lineTo(size.width - 4, size.height);
    
    // Draw right side of entry
    path.lineTo(entryEnd, size.height);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}