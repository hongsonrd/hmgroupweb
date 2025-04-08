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
            
            // Floor visibility toggles
            Wrap(
              spacing: 8,
              children: floors.map((floor) {
                final isVisible = visibleFloors.contains(floor.floorUID);
                return FilterChip(
                  label: Text(floor.tenTang ?? 'Không tên'),
                  selected: isVisible,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        visibleFloors.add(floor.floorUID!);
                      } else {
                        visibleFloors.remove(floor.floorUID!);
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
        child: InteractiveViewer(
          constrained: false,
          boundaryMargin: EdgeInsets.all(8),
          minScale: 0.5,
          maxScale: 5.0,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
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
                            fit: BoxFit.contain,
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
                        left: leftPercent,
                        top: topPercent,
                        width: widthPercent,
                        height: heightPercent,
                        child: Container(
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
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return SizedBox();
                                    },
                                  ),
                                ),
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
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
  
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
    
    // Implementation for zone creation will go here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thêm khu vực mới'),
        content: Text('Chức năng đang được phát triển'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }
  
  // API methods
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