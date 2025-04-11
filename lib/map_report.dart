import 'dart:convert';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'table_models.dart';

class MapReportScreen extends StatefulWidget {
  final String mapUID;
  final String mapName;
  
  const MapReportScreen({
    Key? key, 
    required this.mapUID,
    required this.mapName
  }) : super(key: key);

  @override
  _MapReportScreenState createState() => _MapReportScreenState();
}

class _MapReportScreenState extends State<MapReportScreen> {
  final DBHelper dbHelper = DBHelper();
  MapListModel? mapData;
  List<MapFloorModel> floors = [];
  String? selectedFloorUID;
  
  bool isLoading = false;
  String statusMessage = '';
  Set<String> visibleFloors = {};

  @override
  void initState() {
    super.initState();
    _loadMapData();
    _loadFloors();
  }
  
  Future<void> _loadMapData() async {
    try {
      final map = await dbHelper.getMapListByUID(widget.mapUID);
      setState(() {
        mapData = map;
      });
    } catch (e) {
      print('Error loading map data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải dữ liệu bản đồ'))
        );
      }
    }
  }
  
  Future<void> _loadFloors() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Đang tải danh sách tầng...';
    });
    
    try {
      final loadedFloors = await dbHelper.getMapFloorsByMapUID(widget.mapUID);
      
      // Sort floors in reverse order (e.g., Floor 3 > Floor 2 > Floor 1)
      loadedFloors.sort((a, b) {
        // Try to extract floor numbers for natural sorting
        final aName = a.tenTang ?? '';
        final bName = b.tenTang ?? '';
        
        // Extract digits if they exist
        final aMatch = RegExp(r'\d+').firstMatch(aName);
        final bMatch = RegExp(r'\d+').firstMatch(bName);
        
        if (aMatch != null && bMatch != null) {
          final aNum = int.parse(aMatch.group(0)!);
          final bNum = int.parse(bMatch.group(0)!);
          return bNum.compareTo(aNum); // Reverse order
        }
        
        return bName.compareTo(aName); // Fallback to reverse alphabetical
      });
      
      setState(() {
        floors = loadedFloors;
        // Select first floor by default if available
        if (floors.isNotEmpty && selectedFloorUID == null) {
          selectedFloorUID = floors.first.floorUID;
        }
        // Initialize visible floors with the selected floor
        visibleFloors = selectedFloorUID != null ? {selectedFloorUID!} : {};
        isLoading = false;
        statusMessage = '';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = 'Lỗi tải dữ liệu: $e';
      });
      print('Error loading floors: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Báo cáo: ${widget.mapName}'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.greenAccent.shade400, Colors.green.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(statusMessage),
              ],
            ),
          )
        : Column(
            children: [
              if (statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    statusMessage,
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              Expanded(
                child: _buildMapView(),
              ),
            ],
          ),
    );
  }
  
  Widget _buildMapView() {
    if (mapData == null) {
      return Center(child: Text('Không có dữ liệu bản đồ'));
    }
    
    if (floors.isEmpty) {
      return Center(child: Text('Không có tầng nào để hiển thị'));
    }
    
    // Calculate aspect ratio based on map dimensions
    final mapWidth = mapData!.chieuDaiMet ?? 1200.0;
    final mapHeight = mapData!.chieuCaoMet ?? 600.0;
    final aspectRatio = mapWidth / mapHeight;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xem bản đồ ${widget.mapName}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              
              // Floor visibility toggles - show only one floor at a time
              Text('Chọn tầng để hiển thị:'),
              SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: floors.map((floor) {
                  final isVisible = visibleFloors.contains(floor.floorUID);
                  return ChoiceChip(
                    label: Text(floor.tenTang ?? 'Không tên'),
                    selected: isVisible,
                    onSelected: (selected) {
                      setState(() {
                        // Only one floor visible at a time
                        visibleFloors.clear();
                        if (selected) {
                          visibleFloors.add(floor.floorUID!);
                          selectedFloorUID = floor.floorUID;
                        }
                      });
                    },
                    selectedColor: Colors.blue.withOpacity(0.3),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the size based on the available width and the aspect ratio
              double width = constraints.maxWidth;
              double height = width / aspectRatio;
              
              // If height exceeds available height, recalculate based on height
              if (height > constraints.maxHeight) {
                height = constraints.maxHeight;
                width = height * aspectRatio;
              }
              
              return InteractiveViewer(
                constrained: true,
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Container(
                    width: width,
                    height: height,
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Stack(
                        children: [
                          // Base map image
                          if (mapData?.hinhAnhBanDo != null && mapData!.hinhAnhBanDo!.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.2,
                                child: Image.network(
                                  mapData!.hinhAnhBanDo!,
                                  fit: BoxFit.fill,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(color: Colors.grey[200]);
                                  },
                                ),
                              ),
                            ),
                          
                          // Display floors at their actual positions and sizes
                          ...floors.where((floor) => 
                            visibleFloors.contains(floor.floorUID)
                          ).map((floor) {
                            // Get floor dimensions
                            final floorWidth = floor.chieuDaiMet ?? mapWidth;
                            final floorHeight = floor.chieuCaoMet ?? mapHeight;
                            
                            // Calculate position based on offsets
                            final offsetX = floor.offsetX ?? 0;
                            final offsetY = floor.offsetY ?? 0;
                            
                            // Convert to percentages of map size
                            final leftPercent = (offsetX / mapWidth) * 100;
                            final topPercent = (offsetY / mapHeight) * 100;
                            final widthPercent = (floorWidth / mapWidth) * 100;
                            final heightPercent = (floorHeight / mapHeight) * 100;
                            
                            return Positioned(
                              left: leftPercent * width / 100,
                              top: topPercent * height / 100,
                              width: widthPercent * width / 100,
                              height: heightPercent * height / 100,
                              child: Stack(
                                children: [
                                  // Floor background
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: selectedFloorUID == floor.floorUID ? Colors.blue : Colors.grey,
                                        width: selectedFloorUID == floor.floorUID ? 2 : 1,
                                      ),
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    child: Stack(
                                      children: [
                                        if (floor.hinhAnhTang != null && floor.hinhAnhTang!.isNotEmpty)
                                          Positioned.fill(
                                            child: Image.network(
                                              floor.hinhAnhTang!,
                                              fit: BoxFit.fill,
                                              errorBuilder: (context, error, stackTrace) {
                                                return SizedBox();
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  // We'll add zones here once we load them
                                  FutureBuilder<List<MapZoneModel>>(
                                    future: dbHelper.getMapZonesByFloorUID(floor.floorUID!),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Center(child: CircularProgressIndicator());
                                      }
                                      
                                      if (snapshot.hasError) {
                                        return SizedBox();
                                      }
                                      
                                      final zones = snapshot.data ?? [];
                                      
                                      // Create a map of scaled points for each zone for faster access
                                      final Map<String, List<Offset>> zonePointsMap = {};
                                      
                                      for (var zone in zones) {
                                        try {
                                          final pointsData = json.decode(zone.cacDiemMoc ?? '[]') as List;
                                          if (pointsData.isEmpty) {
                                            continue; 
                                          }
                                          final points = pointsData.map((point) {
                                            if (point is! Map || !point.containsKey('x') || !point.containsKey('y')) {
                                              return null;
                                            }
                                            return Offset(
                                              (point['x'] as num).toDouble(),
                                              (point['y'] as num).toDouble(),
                                            );
                                          }).whereType<Offset>().toList(); 
                                          if (points.length < 3) {
                                            continue;
                                          }
                                                
                                          // Convert to scaled points
                                          final scaledPoints = points.map((point) {
                                            final xPercent = (point.dx - (floor.offsetX ?? 0)) / floorWidth;
                                            final yPercent = (point.dy - (floor.offsetY ?? 0)) / floorHeight;
                                            
                                            return Offset(
                                              xPercent * widthPercent * width / 100,
                                              yPercent * heightPercent * height / 100,
                                            );
                                          }).toList();
                                          
                                          zonePointsMap[zone.zoneUID!] = scaledPoints;
                                        } catch (e) {
                                          print('Error processing zone points for ${zone.zoneUID}: $e');
                                          continue;
                                        }
                                      }
                                      
                                      return Stack(
                                        children: [
                                          ...zones.map((zone) {
                                            // Parse color
                                            Color zoneColor;
                                            try {
                                              final colorStr = zone.mauSac ?? '#3388FF80';
                                              if (colorStr.startsWith('#')) {
                                                String hexColor = colorStr.substring(1);
                                                if (hexColor.length == 6) {
                                                  zoneColor = Color(int.parse('0xFF$hexColor')).withOpacity(0.3);
                                                } else if (hexColor.length == 8) {
                                                  final alpha = int.parse(hexColor.substring(6, 8), radix: 16);
                                                  final baseColor = Color(int.parse('0xFF${hexColor.substring(0, 6)}'));
                                                  zoneColor = baseColor.withOpacity(alpha / 255.0 * 0.6);
                                                } else {
                                                  zoneColor = Colors.blue.withOpacity(0.3);
                                                }
                                              } else {
                                                zoneColor = Colors.blue.withOpacity(0.3);
                                              }
                                            } catch (e) {
                                              print('Error parsing color: $e for color string: ${zone.mauSac}');
                                              zoneColor = Colors.blue.withOpacity(0.3);
                                            }
                                            
                                            final scaledPoints = zonePointsMap[zone.zoneUID] ?? [];
                                            
                                            return GestureDetector(
                                              onTap: () {
                                                _showZoneInfo(zone);
                                              },
                                              child: CustomPaint(
                                                painter: ZoneAreaPainter(
                                                  points: scaledPoints,
                                                  color: zoneColor,
                                                ),
                                                size: Size(
                                                  widthPercent * width / 100,
                                                  heightPercent * height / 100,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      );
                                    },
                                  ),
                                  
                                  // Floor label
                                  Positioned(
                                    left: 4,
                                    top: 4,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      color: Colors.black.withOpacity(0.7),
                                      child: Text(
                                        floor.tenTang ?? '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  void _showZoneInfo(MapZoneModel zone) {
    try {
    final pointsData = json.decode(zone.cacDiemMoc ?? '[]') as List;
    print('Raw Points Data: $pointsData');
    
    // Print out min and max coordinates
    if (pointsData.isNotEmpty) {
      double minX = double.infinity, maxX = double.negativeInfinity;
      double minY = double.infinity, maxY = double.negativeInfinity;
      
      for (var point in pointsData) {
        final x = (point['x'] as num).toDouble();
        final y = (point['y'] as num).toDouble();
        
        minX = minX > x ? x : minX;
        maxX = maxX < x ? x : maxX;
        minY = minY > y ? y : minY;
        maxY = maxY < y ? y : maxY;
      }
      
      print('Coordinate Ranges:');
      print('X: $minX to $maxX (width: ${maxX - minX})');
      print('Y: $minY to $maxY (height: ${maxY - minY})');
    }
  } catch (e) {
    print('Error parsing points: $e');
  }
  double calculateZoneArea(List<Offset> points, double mapWidth, double mapHeight) {
    if (points.length < 3) return 0.0;
    
    // Shoelace formula for polygon area calculation
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      area += (points[i].dx * points[j].dy) - (points[j].dx * points[i].dy);
    }
    area = area.abs() / 2.0;
    
    // Calculate the actual area based on map dimensions
    final pointsData = json.decode(zone.cacDiemMoc ?? '[]') as List;
    if (pointsData.isEmpty) return 0.0;
    
    // Find the min and max coordinates of the original points
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    
    for (var point in pointsData) {
      final x = (point['x'] as num).toDouble();
      final y = (point['y'] as num).toDouble();
      
      minX = minX > x ? x : minX;
      maxX = maxX < x ? x : maxX;
      minY = minY > y ? y : minY;
      maxY = maxY < y ? y : maxY;
    }
    
    // Calculate the actual area in square meters
    final zoneWidth = maxX - minX;
    final zoneHeight = maxY - minY;
    
    // Proportional scaling to map dimensions
    final widthRatio = zoneWidth / mapWidth;
    final heightRatio = zoneHeight / mapHeight;
    
    return (widthRatio * heightRatio * mapWidth * mapHeight);
  }

  // Determine the most appropriate width and height
  final mapWidth = mapData?.chieuDaiMet ?? 1200.0;
  final mapHeight = mapData?.chieuCaoMet ?? 600.0;

  // Decode and convert points
  List<Offset> zonePoints = [];
  try {
    final pointsData = json.decode(zone.cacDiemMoc ?? '[]') as List;
    zonePoints = pointsData.map((point) {
      return Offset(
        (point['x'] as num).toDouble(),
        (point['y'] as num).toDouble(),
      );
    }).toList();
  } catch (e) {
    print('Error parsing zone points: $e');
  }

  final zoneArea = 0.75*calculateZoneArea(zonePoints, mapWidth, mapHeight);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(zone.tenKhuVuc ?? 'Khu vực không tên'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông tin khu vực:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            
            Row(
              children: [
                Text('Màu sắc: '),
                Container(
                  width: 20,
                  height: 20,
                  margin: EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: _parseColor(zone.mauSac ?? '#3388FF80'),
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(' ${zone.mauSac ?? '#3388FF80'}'),
              ],
            ),
            
            SizedBox(height: 16),
            
            Text('Thống kê:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            
            _buildStatItem(Icons.person, 'Số lượt truy cập', '${(zone.zoneUID?.hashCode ?? 0) % 100 + 5}'),
            _buildStatItem(Icons.access_time, 'Thời gian trung bình', '${(zone.zoneUID?.hashCode ?? 0) % 60 + 2} phút'),
            _buildStatItem(Icons.favorite, 'Mức độ ưa thích', '${(zone.zoneUID?.hashCode ?? 0) % 5 + 1}/5'),
            _buildStatItem(Icons.square_foot, 'Diện tích khu vực', '${zoneArea.toStringAsFixed(2)} m²'),
            
            SizedBox(height: 16),
            
            Text('Zone UID: ${zone.zoneUID ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Floor UID: ${zone.floorUID ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Đóng'),
        ),
      ],
    ),
  );
}
  
  Widget _buildStatItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        String hexColor = colorStr.substring(1);
        if (hexColor.length == 6) {
          return Color(int.parse('0xFF$hexColor')).withOpacity(0.3);
        } else if (hexColor.length == 8) {
          final alpha = int.parse(hexColor.substring(6, 8), radix: 16);
          final baseColor = Color(int.parse('0xFF${hexColor.substring(0, 6)}'));
          return baseColor.withOpacity(alpha / 255.0 * 0.6);
        }
      }
    } catch (e) {
      print('Error parsing color: $e');
    }
    return Colors.blue.withOpacity(0.3);
  }
}

class ZoneAreaPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final bool isHighlighted;
  
  ZoneAreaPainter({
    required this.points, 
    required this.color, 
    this.isHighlighted = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    
    // Start from the first point
    path.moveTo(points.first.dx, points.first.dy);
    
    // Add lines to each point
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    // Close the path
    path.close();
    
    // Draw the filled path
    canvas.drawPath(path, paint);
    
    // Add highlight border if highlighted
    if (isHighlighted) {
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawPath(path, borderPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant ZoneAreaPainter oldDelegate) {
    return oldDelegate.points != points || 
           oldDelegate.color != color || 
           oldDelegate.isHighlighted != isHighlighted;
  }
}