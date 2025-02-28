import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'table_models.dart';

class ProjectImageScreen extends StatefulWidget {
  final String? boPhan;
  final String? username;

  const ProjectImageScreen({Key? key, this.boPhan, this.username}) : super(key: key);

  @override
  _ProjectImageScreenState createState() => _ProjectImageScreenState();
}

class _ProjectImageScreenState extends State<ProjectImageScreen> {
  final DBHelper _dbHelper = DBHelper();
  bool _isLoading = true;
  bool _isSyncing = false;
  String _username = '';
  List<HinhAnhZaloModel> _imageList = [];
  Map<String, List<HinhAnhZaloModel>> _groupedByProject = {};
  
  @override
  void initState() {
    super.initState();
    _loadUsername().then((_) {
      _loadData();
    });
  }
  
  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Use username from widget if provided, otherwise get from SharedPreferences
      _username = widget.username ?? prefs.getString('username') ?? '';
    });
    
    // Check if initial sync has been done
    bool hasSynced = prefs.getBool('hinhanh_synced') ?? false;
    if (!hasSynced) {
      // Auto trigger sync on first load
      _syncImagesFromServer();
    }
  }
  
  Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Always load all images from the database regardless of boPhan parameter
    final images = await _dbHelper.getAllHinhAnhZalo();
    
    // Group images by project (bophan) and then by date
    final grouped = <String, Map<String, List<HinhAnhZaloModel>>>{};
    
    for (var image in images) {
      final project = image.boPhan ?? 'Unknown';
      final dateStr = image.ngay != null 
          ? DateFormat('yyyy-MM-dd').format(image.ngay!)
          : 'Unknown Date';
          
      if (!grouped.containsKey(project)) {
        grouped[project] = {}; 
      }
      
      if (!grouped[project]!.containsKey(dateStr)) {
        grouped[project]![dateStr] = [];
      }
      
      grouped[project]![dateStr]!.add(image);
    }
    
    // Sort by date (most recent first)
    for (var project in grouped.keys) {
      for (var date in grouped[project]!.keys) {
        grouped[project]![date]!.sort((a, b) {
          if (a.ngay == null) return 1;
          if (b.ngay == null) return -1;
          return b.ngay!.compareTo(a.ngay!);
        });
      }
    }
    
    setState(() {
      _imageList = images;
      _isLoading = false;
      
      // Flatten the grouped structure for rendering
      _groupedByProject = {};
      for (var project in grouped.keys) {
        _groupedByProject[project] = [];
        
        // Sort dates newest first
        final sortedDates = grouped[project]!.keys.toList()
          ..sort((a, b) => b.compareTo(a));
          
        for (var date in sortedDates) {
          _groupedByProject[project]!.addAll(grouped[project]![date]!);
        }
      }
    });
  } catch (e) {
    print('Error loading data: $e');
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi tải ảnh: $e')),
    );
  }
}
  
  Future<void> _syncImagesFromServer() async {
  if (_username.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chưa đăng nhập.')),
    );
    return;
  }
  
  setState(() {
    _isSyncing = true;
  });
  
  try {
    final response = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hinhanhzalo/$_username'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data is List) {
        final images = data.map((item) {
          // Handle date parsing properly
          DateTime? ngayDate;
          if (item['Ngay'] != null) {
            try {
              // Try parsing as ISO string
              ngayDate = DateTime.parse(item['Ngay']);
            } catch (e) {
              // If it fails, try handling MySQL date format
              try {
                final parts = item['Ngay'].toString().split('T')[0].split('-');
                if (parts.length == 3) {
                  ngayDate = DateTime(
                    int.parse(parts[0]), 
                    int.parse(parts[1]), 
                    int.parse(parts[2])
                  );
                }
              } catch (e) {
                print('Error parsing date: ${item['Ngay']}');
              }
            }
          }
          
          return HinhAnhZaloModel(
            uid: item['UID'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            ngay: ngayDate,
            gio: item['Gio']?.toString(),
            boPhan: item['BoPhan']?.toString(),
            giamSat: item['GiamSat']?.toString(),
            nguoiDung: item['NguoiDung']?.toString(),
            hinhAnh: item['HinhAnh']?.toString(),
            khuVuc: item['KhuVuc']?.toString() ?? '',
            quanTrong: item['QuanTrong']?.toString() ?? '0',
          );
        }).toList();
        
        // Save to database
        await _dbHelper.batchInsertHinhAnhZalo(images);
        
        // Mark as synced
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hinhanh_synced', true);
        
        // Reload data
        await _loadData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đồng bộ thành công ${images.length} ảnh')),
        );
      }
    } else {
      throw Exception('Failed to load data from server: ${response.statusCode}');
    }
  } catch (e) {
    print('Error syncing with server: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi đồng bộ với server: $e')),
    );
  } finally {
    setState(() {
      _isSyncing = false;
    });
  }
}
  
  Future<void> _updateImageRecord(HinhAnhZaloModel image) async {
    try {
      // Limit input length instead of using RegExp
      final sanitizedKhuVuc = (image.khuVuc ?? '').substring(0, 
          image.khuVuc != null && image.khuVuc!.length > 60 ? 60 : image.khuVuc?.length ?? 0);
      
      // Prepare update data
      final updates = {
        'KhuVuc': sanitizedKhuVuc,
        'QuanTrong': image.quanTrong,
      };
      
      // Update local database
      await _dbHelper.updateHinhAnhZalo(image.uid, updates);
      
      // Send update to server
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hinhanhzaloupdate/${image.uid}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update on server: ${response.statusCode}');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công')),
      );
      
      // Reload data to reflect changes
      _loadData();
      
    } catch (e) {
      print('Error updating record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text(
    'Hình ảnh dự án',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  actions: [
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: IconButton(
        key: ValueKey<bool>(_isSyncing),
        icon: Icon(_isSyncing ? Icons.sync : Icons.sync_outlined),
        onPressed: _isSyncing ? null : _syncImagesFromServer,
        tooltip: 'Đồng bộ dữ liệu',
      ),
    ),
    const SizedBox(width: 8),
  ],
  elevation: 4,
  backgroundColor: const Color.fromARGB(255, 220, 233, 255),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
  ),
),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _imageList.isEmpty
              ? const Center(child: Text('Không có hình ảnh'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: _buildProjectGroups(),
                    ),
                  ),
                ),
    );
  }
  
  List<Widget> _buildProjectGroups() {
    final List<Widget> projectWidgets = [];
    
    // Sort projects alphabetically
    final sortedProjects = _groupedByProject.keys.toList()..sort();
    
    for (var project in sortedProjects) {
      projectWidgets.add(
        ExpansionTile(
          title: Text(project, style: TextStyle(fontWeight: FontWeight.bold)),
          children: _buildDateGroups(project),
        ),
      );
    }
    
    return projectWidgets;
  }
  
  List<Widget> _buildDateGroups(String project) {
    final List<Widget> dateGroups = [];
    final images = _groupedByProject[project]!;
    
    // Group by date
    final Map<String, List<HinhAnhZaloModel>> byDate = {};
    for (var image in images) {
      final dateStr = image.ngay != null 
          ? DateFormat('yyyy-MM-dd').format(image.ngay!)
          : 'Unknown Date';
          
      if (!byDate.containsKey(dateStr)) {
        byDate[dateStr] = [];
      }
      
      byDate[dateStr]!.add(image);
    }
    
    // Sort dates newest first
    final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    
    for (var dateStr in sortedDates) {
      dateGroups.add(
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: ExpansionTile(
            title: Text(dateStr),
            children: byDate[dateStr]!.map((image) => _buildImageCard(image)).toList(),
          ),
        ),
      );
    }
    
    return dateGroups;
  }
  
  Widget _buildImageCard(HinhAnhZaloModel image) {
  // Controllers for editable fields
  final khuVucController = TextEditingController(text: image.khuVuc ?? '');
  
  // Create a stateful variable to track toggle state
  bool quanTrongValue = image.quanTrong == '1';
  
  // Create a copy of the image for editing
  var editedImage = HinhAnhZaloModel(
    uid: image.uid,
    ngay: image.ngay,
    gio: image.gio,
    boPhan: image.boPhan,
    giamSat: image.giamSat,
    nguoiDung: image.nguoiDung,
    hinhAnh: image.hinhAnh,
    khuVuc: image.khuVuc,
    quanTrong: image.quanTrong,
  );
  
  // Set card color based on quanTrong value
  Color cardColor;
  if (image.quanTrong == '1') {
    cardColor = const Color.fromARGB(255, 214, 255, 249); // Gold for important
  } else if (image.quanTrong == '0') {
    cardColor = const Color.fromARGB(255, 230, 229, 200); // Green for not important
  } else {
    cardColor = Colors.grey.shade200; // Gray for undefined
  }
  
  return StatefulBuilder(
    builder: (context, setCardState) {
      return Card(
        margin: const EdgeInsets.all(8.0),
        color: cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            image.hinhAnh != null && image.hinhAnh!.isNotEmpty
                ? Image.network(
                    image.hinhAnh!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.error)),
                      );
                    },
                  )
                : Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(child: Text('Không có ảnh')),
                  ),
                  
            // Image details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time
                  Text(
                    'Giờ: ${image.gio ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Important (QuanTrong) field - now with StatefulBuilder
                  Row(
                    children: [
                      const Text('Quan trọng: '),
                      Switch(
                        value: quanTrongValue,
                        onChanged: (value) {
                          setCardState(() {
                            quanTrongValue = value;
                            editedImage.quanTrong = value ? '1' : '0';
                            
                            // Update card color immediately
                            if (value) {
                              cardColor = Colors.amber.shade100;
                            } else {
                              cardColor = Colors.green.shade100;
                            }
                          });
                        },
                      ),
                      Text(quanTrongValue ? 'Có' : 'Không'),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Area (KhuVuc) field
                  TextField(
                    controller: khuVucController,
                    decoration: const InputDecoration(
                      labelText: 'Tên khu vực',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 60,
                    onChanged: (value) {
                      editedImage.khuVuc = value;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Submit button
                  ElevatedButton(
                    onPressed: () {
                      _updateImageRecord(editedImage);
                    },
                    child: const Text('Cập nhật'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  );
}}