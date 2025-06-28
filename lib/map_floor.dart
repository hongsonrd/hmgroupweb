import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'table_models.dart';
import 'db_helper.dart';

class MapFloorScreen extends StatefulWidget {
  final String mapUID;
  final String mapName;
  
  const MapFloorScreen({
    Key? key, 
    required this.mapUID,
    required this.mapName
  }) : super(key: key);

  @override
  _MapFloorScreenState createState() => _MapFloorScreenState();
}

class _MapFloorScreenState extends State<MapFloorScreen> with SingleTickerProviderStateMixin {
  final ValueNotifier<String?> hoveredZoneNotifier = ValueNotifier<String?>(null);
  final DBHelper dbHelper = DBHelper();
  final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  late TabController _tabController;
  MapListModel? mapData;
  List<MapFloorModel> floors = [];
  String? selectedFloorUID;
  
  bool isLoading = false;
  String statusMessage = '';
  Set<String> visibleFloors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu bản đồ'))
      );
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
      // Initialize visible floors with all floor UIDs
      visibleFloors = Set.from(loadedFloors.map((f) => f.floorUID!));
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sửa bản đồ: ${widget.mapName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Tầng', icon: Icon(Icons.layers)),
            Tab(text: 'Khu vực', icon: Icon(Icons.grid_on)),
          ],
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
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFloorsTab(),
                    _buildFloorPreview(),
                  ],
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddFloorDialog();
          } else {
            _showAddZoneDialog();
          }
        },
        child: Icon(Icons.add),
        tooltip: _tabController.index == 0 ? 'Thêm tầng mới' : 'Thêm khu vực mới',
      ),
    );
  }
  
  Widget _buildFloorsTab() {
    if (floors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_clear, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có tầng nào. Hãy thêm tầng mới!'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: floors.length,
      itemBuilder: (context, index) {
        final floor = floors[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(
              floor.tenTang ?? 'Tầng không tên',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kích thước: ${floor.chieuDaiMet ?? 0}m x ${floor.chieuCaoMet ?? 0}m'),
                Text('Vị trí: Offset X:${floor.offsetX ?? 0}, Y:${floor.offsetY ?? 0}'),
              ],
            ),
            leading: floor.hinhAnhTang != null && floor.hinhAnhTang!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    floor.hinhAnhTang!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[300],
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[300],
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditFloorDialog(floor),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteFloor(floor),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                selectedFloorUID = floor.floorUID;
                _tabController.animateTo(1); // Switch to preview tab
              });
            },
          ),
        );
      },
    );
  }
  
  Widget _buildFloorPreview() {
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
              'Xem trước bản đồ ${widget.mapName}',
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
                              opacity: 0.5,
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
      // Parse color (unchanged)
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
      
      return Positioned.fill(
  child: ClipPath(
    clipper: ZoneClipper(points: scaledPoints),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _showZoneDetails(zone);
      },
      child: CustomPaint(
        painter: ZoneAreaPainter(
          points: scaledPoints,
          color: zoneColor,
          isHighlighted: zone.zoneUID == selectedZoneUID,
        ),
        size: Size(
          widthPercent * width / 100,
          heightPercent * height / 100,
        ),
      ),
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
void _showZoneDetails(MapZoneModel zone) {
  setState(() {
    selectedZoneUID = zone.zoneUID;
  });
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(zone.tenKhuVuc ?? 'Khu vực không tên'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display zone properties
            Text('Thông tin khu vực:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            
            // Display color
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
            
            // Display points count
            Text('Số điểm: ${_getPointsCount(zone.cacDiemMoc)}'),
            
            // Display zone ID
            SizedBox(height: 8),
            Text('Zone UID: ${zone.zoneUID ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey)),
            
            // Display floor ID
            Text('Floor UID: ${zone.floorUID ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey)),
            
            // Show points data if not empty
            if (zone.cacDiemMoc != null && zone.cacDiemMoc!.isNotEmpty) 
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Text('Dữ liệu điểm:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatPointsData(zone.cacDiemMoc!),
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Đóng'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Add your edit logic here or show a message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Chức năng chỉnh sửa đang được phát triển'))
            );
          },
          style: TextButton.styleFrom(foregroundColor: Colors.blue),
          child: Text('Sửa'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _confirmDeleteZone(zone);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text('Xóa'),
        ),
      ],
    ),
  ).then((_) {
    setState(() {
      selectedZoneUID = null;
    });
  });
}
String _formatPointsData(String pointsJson) {
  try {
    final jsonData = json.decode(pointsJson);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonData);
    return prettyJson.length > 200 ? prettyJson.substring(0, 200) + '...' : prettyJson;
  } catch (e) {
    print('Error formatting points data: $e');
    return 'Invalid JSON data';
  }
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

int _getPointsCount(String? pointsJson) {
  try {
    if (pointsJson == null || pointsJson.isEmpty) return 0;
    final points = json.decode(pointsJson) as List;
    return points.length;
  } catch (e) {
    print('Error parsing points: $e');
    return 0;
  }
}
bool _isPointInPolygon(Offset point, List<Offset> polygon) {
  bool isInside = false;
  int i = 0, j = polygon.length - 1;
  
  for (i = 0; i < polygon.length; i++) {
    if (((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy)) &&
        (point.dx < (polygon[j].dx - polygon[i].dx) * (point.dy - polygon[i].dy) / 
        (polygon[j].dy - polygon[i].dy) + polygon[i].dx)) {
      isInside = !isInside;
    }
    j = i;
  }
  
  return isInside;
}
String? selectedZoneUID;
  String? hoveredZoneUID;
  void _showAddFloorDialog() {
    final formKey = GlobalKey<FormState>();
    final tenTangController = TextEditingController();
    final chieuDaiController = TextEditingController();
    final chieuCaoController = TextEditingController();
    final offsetXController = TextEditingController(text: '0');
    final offsetYController = TextEditingController(text: '0');
    
    File? selectedImage;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final maxDai = mapData?.chieuDaiMet ?? 100.0;
          final maxCao = mapData?.chieuCaoMet ?? 100.0;
          final maxOffset = maxDai < 50 || maxCao < 50 ? 
              (maxDai < maxCao ? maxDai : maxCao) : 50.0;
              
          Future<void> pickImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
            
            if (pickedFile != null) {
              setDialogState(() {
                selectedImage = File(pickedFile.path);
              });
            }
          }
          
          return AlertDialog(
            title: Text('Thêm tầng mới'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: tenTangController,
                      decoration: InputDecoration(labelText: 'Tên tầng'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập tên tầng';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: selectedImage != null
                          ? Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Chọn hình ảnh tầng'),
                              ],
                            ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: chieuDaiController,
                            decoration: InputDecoration(
                              labelText: 'Chiều dài (m)',
                              helperText: 'Tối đa: ${maxDai}m',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Yêu cầu';
                              }
                              final dai = double.tryParse(value);
                              if (dai == null) {
                                return 'Số không hợp lệ';
                              }
                              if (dai <= 0) {
                                return 'Phải > 0';
                              }
                              if (dai > maxDai) {
                                return 'Tối đa ${maxDai}m';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: chieuCaoController,
                            decoration: InputDecoration(
                              labelText: 'Chiều cao (m)',
                              helperText: 'Tối đa: ${maxCao}m',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Yêu cầu';
                              }
                              final cao = double.tryParse(value);
                              if (cao == null) {
                                return 'Số không hợp lệ';
                              }
                              if (cao <= 0) {
                                return 'Phải > 0';
                              }
                              if (cao > maxCao) {
                                return 'Tối đa ${maxCao}m';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    Text('Vị trí offset (từ -$maxOffset đến $maxOffset):'),
                    SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: offsetXController,
                            decoration: InputDecoration(labelText: 'Offset X'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Yêu cầu';
                              }
                              final x = double.tryParse(value);
                              if (x == null) {
                                return 'Số không hợp lệ';
                              }
                              if (x < -maxOffset || x > maxOffset) {
                                return 'Từ -$maxOffset đến $maxOffset';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: offsetYController,
                            decoration: InputDecoration(labelText: 'Offset Y'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Yêu cầu';
                              }
                              final y = double.tryParse(value);
                              if (y == null) {
                                return 'Số không hợp lệ';
                              }
                              if (y < -maxOffset || y > maxOffset) {
                                return 'Từ -$maxOffset đến $maxOffset';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    
                    // Create new floor with unique ID
                    String floorUID = DateTime.now().millisecondsSinceEpoch.toString();
                    String? imageUrl;
                    
                    setState(() {
                      isLoading = true;
                      statusMessage = 'Đang tạo tầng mới...';
                    });
                    
                    try {
                      // Upload image if selected
                      if (selectedImage != null) {
                        imageUrl = await _uploadImage(selectedImage!, floorUID);
                      }
                      
                      // Create floor model
                      final newFloor = MapFloorModel(
                        floorUID: floorUID,
                        mapUID: widget.mapUID,
                        tenTang: tenTangController.text,
                        hinhAnhTang: imageUrl,
                        chieuDaiMet: double.tryParse(chieuDaiController.text),
                        chieuCaoMet: double.tryParse(chieuCaoController.text),
                        offsetX: double.tryParse(offsetXController.text),
                        offsetY: double.tryParse(offsetYController.text),
                      );
                      
                      // Save to server
                      await _saveFloorToServer(newFloor);
                      
                      // Save to local database
                      await dbHelper.insertMapFloor(newFloor);
                      
                      // Reload floors
                      await _loadFloors();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tầng mới đã được tạo thành công'))
                      );
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                        statusMessage = 'Lỗi: $e';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi khi tạo tầng mới: $e'))
                      );
                    }
                  }
                },
                child: Text('Tạo'),
              ),
            ],
          );
        }
      ),
    );
  }
  Future<String> _uploadImage(File image, String floorUID) async {
  setState(() {
    statusMessage = 'Đang tải hình ảnh lên máy chủ...';
  });
  
  try {
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    
    final fileStream = http.ByteStream(image.openRead());
    final fileLength = await image.length();
    
    final multipartFile = http.MultipartFile(
      'file',
      fileStream,
      fileLength,
      filename: path.basename(image.path),
      contentType: MediaType('image', path.extension(image.path).replaceAll('.', '')),
    );
    
    request.files.add(multipartFile);
    request.fields['floorUID'] = floorUID;
    
    final response = await request.send();
    
    if (response.statusCode != 200) {
      throw Exception('Failed to upload image: ${response.statusCode}');
    }
    
    final responseBody = await response.stream.bytesToString();
    final jsonResponse = json.decode(responseBody);
    
    if (jsonResponse['url'] == null) {
      throw Exception('No image URL returned from server');
    }
    
    return jsonResponse['url'];
  } catch (e) {
    print('Error uploading image: $e');
    throw e;
  }
}
  void _showEditFloorDialog(MapFloorModel floor) {
    final formKey = GlobalKey<FormState>();
    final tenTangController = TextEditingController(text: floor.tenTang);
    final chieuDaiController = TextEditingController(text: floor.chieuDaiMet?.toString());
    final chieuCaoController = TextEditingController(text: floor.chieuCaoMet?.toString());
    final offsetXController = TextEditingController(text: floor.offsetX?.toString() ?? '0');
    final offsetYController = TextEditingController(text: floor.offsetY?.toString() ?? '0');
    
    File? selectedImage;
    String? existingImageUrl = floor.hinhAnhTang;
    bool keepExistingImage = existingImageUrl != null && existingImageUrl.isNotEmpty;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final maxDai = mapData?.chieuDaiMet ?? 100.0;
          final maxCao = mapData?.chieuCaoMet ?? 100.0;
          final maxOffset = maxDai < 1550 || maxCao < 1550 ? 
              (maxDai < maxCao ? maxDai : maxCao) : 1550.0;
              
          Future<void> pickImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
            
            if (pickedFile != null) {
              setDialogState(() {
                selectedImage = File(pickedFile.path);
                keepExistingImage = false;
              });
            }
          }
          
          return AlertDialog(
            title: Text('Sửa tầng'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: tenTangController,
                      decoration: InputDecoration(labelText: 'Tên tầng'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập tên tầng';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: selectedImage != null
                          ? Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                            )
                          : keepExistingImage && existingImageUrl != null
                            ? Image.network(
    existingImageUrl!, 
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('Không thể tải hình ảnh hiện tại'),
        ],
      );
    },
  )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Chọn hình ảnh tầng'),
                                ],
                              ),
                      ),
                    ),
                    if (keepExistingImage)
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            keepExistingImage = false;
                            existingImageUrl = null;
                          });
                        },
                        child: Text('Xóa hình ảnh hiện tại'),
                      ),
                    SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: chieuDaiController,
                            decoration: InputDecoration(
                              labelText: 'Chiều dài (m)',
                              helperText: 'Tối đa: ${maxDai}m',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Yêu cầu';
                              }
                              final dai = double.tryParse(value);
                              if (dai == null) {
                                return 'Số không hợp lệ';
                              }
                              if (dai <= 0) {
                                return 'Phải > 0';
                              }
                              if (dai > maxDai) {
                                return 'Tối đa ${maxDai}m';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: chieuCaoController,
                            decoration: InputDecoration(
                              labelText: 'Chiều cao (m)',
                              helperText: 'Tối đa: ${maxCao}m',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Yêu cầu';
                              }
                              final cao = double.tryParse(value);
                              if (cao == null) {
                                return 'Số không hợp lệ';
                              }
                              if (cao <= 0) {
                                return 'Phải > 0';
                              }
                              if (cao > maxCao) {
                                return 'Tối đa ${maxCao}m';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    Text('Vị trí offset (từ -$maxOffset đến $maxOffset):'),
                    SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: offsetXController,
                            decoration: InputDecoration(labelText: 'Offset X'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Yêu cầu';
                              }
                              final x = double.tryParse(value);
                              if (x == null) {
                                return 'Số không hợp lệ';
                              }
                              if (x < -maxOffset || x > maxOffset) {
                                return 'Từ -$maxOffset đến $maxOffset';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: offsetYController,
                            decoration: InputDecoration(labelText: 'Offset Y'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Yêu cầu';
                              }
                              final y = double.tryParse(value);
                              if (y == null) {
                                return 'Số không hợp lệ';
                              }
                              if (y < -maxOffset || y > maxOffset) {
                                return 'Từ -$maxOffset đến $maxOffset';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
  TextButton(
    onPressed: () => Navigator.pop(context),  // Changed from dialogContext to context
    child: Text('Hủy'),
  ),
  ElevatedButton(
    onPressed: () {
      if (formKey.currentState!.validate()) {
        // Capture all values we need BEFORE dismissing the dialog
        final String tenTangValue = tenTangController.text;
        final String? chieuDaiValue = chieuDaiController.text;
        final String? chieuCaoValue = chieuCaoController.text;
        final String? offsetXValue = offsetXController.text;
        final String? offsetYValue = offsetYController.text;
        final String? imageUrlValue = keepExistingImage ? existingImageUrl : null;
        final File? selectedImageValue = selectedImage;
        
        // Close dialog first
        Navigator.pop(context);  // Changed from dialogContext to context
        
        // Start a completely new function that doesn't rely on dialog state
        _processFloorUpdate(
          floor,
          tenTangValue,
          chieuDaiValue,
          chieuCaoValue,
          offsetXValue,
          offsetYValue,
          imageUrlValue,
          selectedImageValue
        );
      }
    },
    child: Text('Lưu'),
  ),
],
        );
      }
    ),
  );
}
  Future<void> _processFloorUpdate(
  MapFloorModel floor,
  String tenTang,
  String? chieuDaiText,
  String? chieuCaoText,
  String? offsetXText,
  String? offsetYText,
  String? existingImageUrl,
  File? selectedImage
) async {
  if (!mounted) return;
  
  setState(() {
    isLoading = true;
    statusMessage = 'Đang cập nhật tầng...';
  });
  
  try {
    // Determine image URL
    String? imageUrl = existingImageUrl;
    
    // Upload new image if selected
    if (selectedImage != null) {
      imageUrl = await _uploadImage(selectedImage, floor.floorUID!);
    }
    
    // Create updated floor model
    final updatedFloor = MapFloorModel(
      floorUID: floor.floorUID,
      mapUID: floor.mapUID,
      tenTang: tenTang,
      hinhAnhTang: imageUrl,
      chieuDaiMet: chieuDaiText != null ? double.tryParse(chieuDaiText) : null,
      chieuCaoMet: chieuCaoText != null ? double.tryParse(chieuCaoText) : null,
      offsetX: offsetXText != null ? double.tryParse(offsetXText) : null,
      offsetY: offsetYText != null ? double.tryParse(offsetYText) : null,
    );
    
    // Save to server
    await _saveFloorToServer(updatedFloor);
    
    // Update local database
    await dbHelper.updateMapFloor(updatedFloor);
    
    // Reload floors
    if (mounted) {
      await _loadFloors();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tầng đã được cập nhật thành công'))
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        isLoading = false;
        statusMessage = 'Lỗi: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật tầng: $e'))
      );
    }
  }
}
  void _confirmDeleteFloor(MapFloorModel floor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa tầng "${floor.tenTang ?? 'Không tên'}"? Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                isLoading = true;
                statusMessage = 'Đang xóa tầng...';
              });
              
              try {
                // Delete from server
                await _deleteFloorFromServer(floor.floorUID!);
                
                // Delete from local database
                await dbHelper.deleteMapFloor(floor.floorUID!);
                
                // Reload floors
                await _loadFloors();
                
                if (selectedFloorUID == floor.floorUID) {
                  setState(() {
                    selectedFloorUID = null;
                  });
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tầng đã được xóa thành công'))
                );
              } catch (e) {
                setState(() {
                  isLoading = false;
                  statusMessage = 'Lỗi: $e';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi khi xóa tầng: $e'))
                );
              }
            },
            child: Text('Xóa'),
          ),
        ],
      ),
    );
  }
  
  void _showAddZoneDialog() {
  if (selectedFloorUID == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vui lòng chọn tầng trước khi thêm khu vực mới'))
    );
    return;
  }
  
  // Get the selected floor
  final selectedFloor = floors.firstWhere(
    (floor) => floor.floorUID == selectedFloorUID,
    orElse: () => throw Exception('Không tìm thấy tầng đã chọn'),
  );
  
  final formKey = GlobalKey<FormState>();
  final zoneNameController = TextEditingController();
  Color selectedColor = Colors.blue.withOpacity(0.5);
  List<Offset> selectedPoints = [];
  bool isDrawingMode = false;
  final drawingContainerKey = GlobalKey();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Thêm khu vực mới cho ${selectedFloor.tenTang}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(),
                
                // Dialog content
                Expanded(
                  child: Form(
                    key: formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Controls panel - left side
                        Container(
                          width: 300,
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: zoneNameController,
                                decoration: InputDecoration(labelText: 'Tên khu vực'),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng nhập tên khu vực';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 24),
                              
                              Text('Chọn màu cho khu vực:'),
                              SizedBox(height: 8),
                              
                              // Color selector
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Colors.red,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.yellow,
                                  Colors.purple,
                                  Colors.orange,
                                  Colors.pink,
                                  Colors.teal,
                                ].map((color) {
                                  return GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedColor = color.withOpacity(0.3);
                                      });
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.3),
                                        border: Border.all(
                                          color: selectedColor.value == color.withOpacity(0.3).value 
                                            ? Colors.black 
                                            : Colors.transparent,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              
                              SizedBox(height: 24),
                              Text(
                                'Số điểm đã chọn: ${selectedPoints.length}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              
                              // Drawing controls
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: Icon(
                                        isDrawingMode ? Icons.edit_off : Icons.edit,
                                        size: 18,
                                      ),
                                      label: Text(isDrawingMode ? 'Dừng vẽ' : 'Bắt đầu vẽ'),
                                      onPressed: () {
                                        setDialogState(() {
                                          isDrawingMode = !isDrawingMode;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: Icon(Icons.clear, size: 18),
                                label: Text('Xóa điểm cuối'),
                                onPressed: selectedPoints.isNotEmpty ? () {
                                  setDialogState(() {
                                    if (selectedPoints.isNotEmpty) {
                                      selectedPoints.removeLast();
                                    }
                                  });
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: Icon(Icons.delete_sweep, size: 18),
                                label: Text('Xóa tất cả điểm'),
                                onPressed: selectedPoints.isNotEmpty ? () {
                                  setDialogState(() {
                                    selectedPoints.clear();
                                  });
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              
                              Spacer(),
                              // Submit button at bottom of left panel
                              ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState!.validate() && selectedPoints.length >= 3) {
                                    Navigator.pop(context);
                                    
                                    // Create new zone with unique ID
                                    String zoneUID = 'zone_${DateTime.now().millisecondsSinceEpoch}';
                                    
                                    setState(() {
                                      isLoading = true;
                                      statusMessage = 'Đang tạo khu vực mới...';
                                    });
                                    
                                    try {
                                      // Convert the points to JSON
                                      final realPoints = selectedPoints.map((point) {
                                        // Convert from 0-1 values to real-world coordinates
                                        final xReal = (point.dx * selectedFloor.chieuDaiMet!) + (selectedFloor.offsetX ?? 0);
                                        final yReal = (point.dy * selectedFloor.chieuCaoMet!) + (selectedFloor.offsetY ?? 0);
                                        
                                        return Offset(xReal, yReal);
                                      }).toList();

                                      final pointsJson = json.encode(realPoints.map((point) {
                                        return {'x': point.dx, 'y': point.dy};
                                      }).toList());
                                      
                                      // Convert color to hex string
                                      final colorHex = '#${selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

                                      // Create zone model
                                      final newZone = MapZoneModel(
                                        zoneUID: zoneUID,
                                        floorUID: selectedFloorUID!,
                                        tenKhuVuc: zoneNameController.text,
                                        cacDiemMoc: pointsJson,
                                        mauSac: colorHex,
                                      );
                                      
                                      // Save to server
                                      await _saveZoneToServer(newZone);
                                      
                                      // Save to local database
                                      await dbHelper.insertMapZone(newZone);
                                      
                                      setState(() {
                                        isLoading = false;
                                        statusMessage = '';
                                      });
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Khu vực mới đã được tạo thành công'))
                                      );
                                    } catch (e) {
                                      setState(() {
                                        isLoading = false;
                                        statusMessage = 'Lỗi: $e';
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Lỗi khi tạo khu vực mới: $e'))
                                      );
                                    }
                                  } else if (selectedPoints.length < 3) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Cần ít nhất 3 điểm để tạo khu vực'))
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('TẠO KHU VỰC', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        
                        VerticalDivider(),
                        
                        // Drawing area - right side (expanded to fill remaining space)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vẽ khu vực trên bản đồ: ${isDrawingMode ? "ĐANG VẼ" : "CHỌN BẮT ĐẦU VẼ"}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDrawingMode ? Colors.green : Colors.black,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // This gives us the actual constraints of the container,
                                      // which we can use for scaling
                                      final containerWidth = constraints.maxWidth;
                                      final containerHeight = constraints.maxHeight;
                                      
                                      return Container(
                                        key: drawingContainerKey,
                                        width: containerWidth,
                                        height: containerHeight,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isDrawingMode ? Colors.green : Colors.grey,
                                            width: isDrawingMode ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Stack(
                                          children: [
                                            // Floor image
                                            if (selectedFloor.hinhAnhTang != null && selectedFloor.hinhAnhTang!.isNotEmpty)
                                              Positioned.fill(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(3),
                                                  child: Image.network(
                                                    selectedFloor.hinhAnhTang!,
                                                    fit: BoxFit.fill,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(color: Colors.grey[200]);
                                                    },
                                                  ),
                                                ),
                                              ),
                                            
                                            // Zone drawing area
                                            Positioned.fill(
                                              child: GestureDetector(
                                                onTapDown: isDrawingMode ? (details) {
                                                  final localPosition = details.localPosition;
                                                  
                                                  // Add point, normalized to 0-1 range
                                                  setDialogState(() {
                                                    selectedPoints.add(Offset(
                                                      localPosition.dx / containerWidth,
                                                      localPosition.dy / containerHeight,
                                                    ));
                                                  });
                                                } : null,
                                                child: CustomPaint(
                                                  size: Size(containerWidth, containerHeight),
                                                  painter: ZoneAreaPainter(
                                                    points: selectedPoints.map((point) => Offset(
                                                      point.dx * containerWidth,
                                                      point.dy * containerHeight,
                                                    )).toList(),
                                                    color: selectedColor,
                                                    isDrawingMode: true,  
                                                  ),
                                                ),
                                              ),
                                            ),
                                            
                                            // Instructions overlay when not in drawing mode
                                            if (!isDrawingMode)
                                              Positioned.fill(
                                                child: Container(
                                                  color: Colors.black.withOpacity(0.1),
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.touch_app, size: 48, color: Colors.white),
                                                        SizedBox(height: 16),
                                                        Text(
                                                          'Nhấn BẮT ĐẦU VẼ để bắt đầu vẽ khu vực',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                            shadows: [
                                                              Shadow(
                                                                blurRadius: 3.0,
                                                                color: Colors.black,
                                                                offset: Offset(1.0, 1.0),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: 8),
                                if (isDrawingMode)
                                  Text(
                                    'Nhấn vào bản đồ để tạo các điểm. Cần tối thiểu 3 điểm để tạo khu vực.',
                                    style: TextStyle(fontStyle: FontStyle.italic),
                                  ),
                              ],
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
      },
    ),
  );
}
Future<void> _saveZoneToServer(MapZoneModel zone) async {
  setState(() {
    statusMessage = 'Đang lưu dữ liệu khu vực lên máy chủ...';
  });
  
  try {
    final uri = Uri.parse('$baseUrl/mapzone/${zone.zoneUID}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(zone.toMap()),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to save zone: ${response.statusCode}');
    }
  } catch (e) {
    print('Error saving zone to server: $e');
    throw e;
  }
}
  Future<void> _deleteZoneFromServer(String zoneUID) async {
  setState(() {
    statusMessage = 'Đang xóa khu vực từ máy chủ...';
  });
  
  try {
    final uri = Uri.parse('$baseUrl/mapzone/$zoneUID');
    final response = await http.delete(uri);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete zone: ${response.statusCode}');
    }
  } catch (e) {
    print('Error deleting zone from server: $e');
    throw e;
  }
}

void _confirmDeleteZone(MapZoneModel zone) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Xác nhận xóa'),
      content: Text('Bạn có chắc muốn xóa khu vực "${zone.tenKhuVuc ?? 'Không tên'}"? Thao tác này không thể hoàn tác.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(context);
            
            setState(() {
              isLoading = true;
              statusMessage = 'Đang xóa khu vực...';
              selectedZoneUID = null; // Clear selected zone immediately
            });
            
            try {
              // Delete from server
              await _deleteZoneFromServer(zone.zoneUID!);
              
              // Delete from local database
              await dbHelper.deleteMapZone(zone.zoneUID!);
              
              // Force UI refresh by toggling visibility
              if (mounted) {
                setState(() {
                  // This will force the FutureBuilder to rebuild
                  selectedFloorUID = null;
                  setState(() {
                    selectedFloorUID = zone.floorUID;
                  });
                  
                  isLoading = false;
                  statusMessage = '';
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Khu vực đã được xóa thành công'))
                );
              }
            } catch (e) {
              if (mounted) {
                setState(() {
                  isLoading = false;
                  statusMessage = 'Lỗi: $e';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi khi xóa khu vực: $e'))
                );
              }
            }
          },
          child: Text('Xóa'),
        ),
      ],
    ),
  );
}
  Future<void> _saveFloorToServer(MapFloorModel floor) async {
    setState(() {
      statusMessage = 'Đang lưu dữ liệu tầng lên máy chủ...';
    });
    
    try {
      final uri = Uri.parse('$baseUrl/mapfloor/${floor.floorUID}');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(floor.toMap()),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to save floor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving floor to server: $e');
      throw e;
    }
  }
  
  Future<void> _deleteFloorFromServer(String floorUID) async {
    setState(() {
      statusMessage = 'Đang xóa tầng từ máy chủ...';
    });
    
    try {
      final uri = Uri.parse('$baseUrl/mapfloor/$floorUID');
      final response = await http.delete(uri);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete floor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting floor from server: $e');
      throw e;
    }
  }
}
class ZoneAreaPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final bool isHighlighted;
  final bool isDrawingMode; // Add this parameter
  
  ZoneAreaPainter({
    required this.points, 
    required this.color, 
    this.isHighlighted = false,
    this.isDrawingMode = false, // Default to false
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
    
    // Close the path only if we have 3+ points or we're not in drawing mode
    if (points.length >= 3 || !isDrawingMode) {
      path.close();
    }
    
    // Draw the filled path
    canvas.drawPath(path, paint);
    
    // Add highlight border if hovered
    if (isHighlighted) {
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawPath(path, borderPaint);
    }
    
    // Draw the points if in editing mode or highlighted
    if (isHighlighted || isDrawingMode) {
      final pointPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      
      for (var point in points) {
        canvas.drawCircle(point, 5, pointPaint);
      }
      
      // Draw lines connecting the points
      final linePaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      for (int i = 0; i < points.length; i++) {
        final current = points[i];
        // Only connect to next point if there is one
        if (i < points.length - 1) {
          final next = points[i + 1];
          canvas.drawLine(current, next, linePaint);
        } 
        // Connect last point to first only if we're not in drawing mode or have enough points
        else if (!isDrawingMode || points.length >= 3) {
          canvas.drawLine(current, points[0], linePaint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant ZoneAreaPainter oldDelegate) {
    return oldDelegate.points != points || 
           oldDelegate.color != color || 
           oldDelegate.isHighlighted != isHighlighted ||
           oldDelegate.isDrawingMode != isDrawingMode;
  }
}
class ZoneClipper extends CustomClipper<Path> {
  final List<Offset> points;
  
  ZoneClipper({required this.points});
  
  @override
  Path getClip(Size size) {
    final path = Path();
    if (points.isEmpty) return path;
    
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(ZoneClipper oldClipper) => oldClipper.points != points;
}