import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'db_helper.dart';
import 'table_models.dart';

class ImageSlideshow extends StatefulWidget {
  final String username;

  const ImageSlideshow({Key? key, required this.username}) : super(key: key);

  @override
  _ImageSlideshowState createState() => _ImageSlideshowState();
}

class _ImageSlideshowState extends State<ImageSlideshow> {
  bool _isLoading = false;
  List<TaskHistoryModel> _imagesData = [];
  List<TaskHistoryModel> _allData = []; 
  int _currentImageIndex = 0;
  final dbHelper = DBHelper();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  String _syncStatus = '';
  
  // Slideshow configuration
  Timer? _slideTimer;
  Timer? _syncTimer;
  final Duration _slideDuration = Duration(seconds: 5); // 5 seconds per image
  final Duration _syncInterval = Duration(minutes: 30); // Sync every 30 minutes
  
  // Animation
  PageController _pageController = PageController();
  bool _isTransitioning = false;
bool _shouldFilterProject(String? projectName) {
    if (projectName == null || projectName.trim().isEmpty) return true;
    final name = projectName.toLowerCase();
    
    if (name.length < 10) return true;
    if (name.startsWith('hm') && RegExp(r'^hm\d+').hasMatch(name)) return true;
    if (name == 'unknown') return true;
    if (projectName == projectName.toUpperCase() && !projectName.contains(' ')) return true;
    
    // Filter out project names that start with "http:" or "https:"
    if (name.startsWith('http:') || name.startsWith('https:')) return true;
    
    return false;
  }
  @override
  void initState() {
    super.initState();
    _initializeSlideshow();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _syncTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeSlideshow() async {
    await _checkAndSync();
    await _loadImagesData();
    _startSlideshow();
    _startSyncTimer();
  }

  void _startSlideshow() {
    _slideTimer?.cancel();
    if (_imagesData.isNotEmpty) {
      _slideTimer = Timer.periodic(_slideDuration, (timer) {
        _nextImage();
      });
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      _checkAndSync();
    });
  }

  void _nextImage() {
    if (_imagesData.isEmpty || _isTransitioning) return;
    
    setState(() {
      _isTransitioning = true;
    });

    _currentImageIndex = (_currentImageIndex + 1) % _imagesData.length;
    
    _pageController.animateToPage(
      _currentImageIndex,
      duration: Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    ).then((_) {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
      }
    });
  }

  Future<void> _checkAndSync() async {
    if (await _shouldSync()) {
      await _syncData();
    }
  }

  Future<bool> _shouldSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('lastImageSync') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSync) > _syncInterval.inMilliseconds;
  }

  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastImageSync', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _syncData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ hình ảnh mới...';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/historybaocao2/${widget.username}')
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        await dbHelper.clearTable(DatabaseTables.taskHistoryTable);

        final taskHistories = data.map((item) => TaskHistoryModel(
          uid: item['UID'],
          taskId: item['TaskID'],
          ngay: DateTime.parse(item['Ngay']),
          gio: item['Gio'],
          nguoiDung: item['NguoiDung'],
          ketQua: item['KetQua'],
          chiTiet: item['ChiTiet'],
          chiTiet2: item['ChiTiet2'],
          viTri: item['ViTri'],
          boPhan: item['BoPhan'],
          phanLoai: item['PhanLoai'],
          hinhAnh: item['HinhAnh'],
          giaiPhap: item['GiaiPhap'],
        )).toList();

        await dbHelper.batchInsertTaskHistory(taskHistories);
        await _updateLastSyncTime();
        
        final previousCount = _imagesData.length;
        await _loadImagesData();
        
        if (_imagesData.length > previousCount) {
          _showSuccess('Đã tải ${_imagesData.length - previousCount} hình ảnh mới');
          _restartSlideshow();
        } else {
          _showSuccess('Đồng bộ thành công - ${_imagesData.length} hình ảnh');
        }
      } else {
        throw Exception('Failed to sync data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing image data: $e');
      _showError('Không thể đồng bộ: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  void _restartSlideshow() {
    _slideTimer?.cancel();
    _currentImageIndex = 0;
    _pageController.animateToPage(0, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    _startSlideshow();
  }

  Future<void> _loadImagesData() async {
    try {
      final db = await dbHelper.database;
      
      // Load all data for stats
      final List<Map<String, dynamic>> allResults = await db.rawQuery('''
        SELECT * FROM ${DatabaseTables.taskHistoryTable}
        ORDER BY Ngay DESC, Gio DESC
      ''');

      _allData = allResults.map((item) => TaskHistoryModel(
        uid: item['UID'],
        taskId: item['TaskID'],
        ngay: DateTime.parse(item['Ngay']),
        gio: item['Gio'],
        nguoiDung: item['NguoiDung'],
        ketQua: item['KetQua'],
        chiTiet: item['ChiTiet'],
        chiTiet2: item['ChiTiet2'],
        viTri: item['ViTri'],
        boPhan: item['BoPhan'],
        phanLoai: item['PhanLoai'],
        hinhAnh: item['HinhAnh'],
        giaiPhap: item['GiaiPhap'],
      )).toList();

      // Load images data with project filtering
      final List<Map<String, dynamic>> imageResults = await db.rawQuery('''
        SELECT * FROM ${DatabaseTables.taskHistoryTable}
        WHERE HinhAnh IS NOT NULL AND HinhAnh != ''
        ORDER BY Ngay DESC, Gio DESC
      ''');

      final imagesData = imageResults.map((item) => TaskHistoryModel(
        uid: item['UID'],
        taskId: item['TaskID'],
        ngay: DateTime.parse(item['Ngay']),
        gio: item['Gio'],
        nguoiDung: item['NguoiDung'],
        ketQua: item['KetQua'],
        chiTiet: item['ChiTiet'],
        chiTiet2: item['ChiTiet2'],
        viTri: item['ViTri'],
        boPhan: item['BoPhan'],
        phanLoai: item['PhanLoai'],
        hinhAnh: item['HinhAnh'],
        giaiPhap: item['GiaiPhap'],
      )).where((item) => _isValidImage(item) && !_shouldFilterProject(item.boPhan)).toList();

      setState(() {
        _imagesData = imagesData;
        if (_imagesData.isNotEmpty && _currentImageIndex >= _imagesData.length) {
          _currentImageIndex = 0;
        }
      });
    } catch (e) {
      print('Error loading images data: $e');
      _showError('Lỗi tải dữ liệu hình ảnh');
    }
  }

  bool _isValidImage(TaskHistoryModel record) {
    if (record.hinhAnh == null || record.hinhAnh!.trim().isEmpty) return false;
    
    // Check if it's a valid image URL
    final imageUrl = record.hinhAnh!.toLowerCase();
    return imageUrl.startsWith('http') && 
           (imageUrl.contains('.jpg') || imageUrl.contains('.jpeg') || 
            imageUrl.contains('.png') || imageUrl.contains('.gif') ||
            imageUrl.contains('.webp'));
  }

  Color _getStatusColor(String? ketQua) {
    if (ketQua == null) return Colors.grey;
    switch (ketQua) {
      case '✔️':
        return Colors.green;
      case '❌':
        return Colors.red;
      case '⚠️':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatKetQua(String? ketQua) {
    if (ketQua == null) return '';
    switch (ketQua) {
      case '✔️':
        return 'Đạt';
      case '❌':
        return 'Không làm';
      case '⚠️':
        return 'Chưa tốt';
      default:
        return ketQua;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showStatsPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatsPopupWindow(data: _allData);
      },
    );
  }

  Widget _buildImageSlide(TaskHistoryModel record) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Main image
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                record.hinhAnh!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Đang tải hình ảnh...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Image load error: $error');
                  return Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 100,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Không thể tải hình ảnh',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Information overlay
          _buildInfoOverlay(record),
          // Progress indicator
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildInfoOverlay(TaskHistoryModel record) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status and time
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(record.ketQua),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatKetQua(record.ketQua),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(record.ngay)} - ${record.gio ?? ''}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Project and location
            if (record.boPhan?.isNotEmpty == true)
              Text(
                record.boPhan!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (record.viTri?.isNotEmpty == true) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      record.viTri!,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Description
            if (record.chiTiet?.isNotEmpty == true) ...[
              SizedBox(height: 12),
              Text(
                record.chiTiet!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (_imagesData.isEmpty) return SizedBox.shrink();
    
    return Positioned(
      top: 40,
      left: 24,
      right: 24,
      child: Column(
        children: [
          // Image counter
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentImageIndex + 1} / ${_imagesData.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 12),
          // Progress bar
          LinearProgressIndicator(
            value: (_currentImageIndex + 1) / _imagesData.length,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 114, 255, 217),
            Color.fromARGB(255, 201, 255, 236),
            Color.fromARGB(255, 79, 255, 214),
            Color.fromARGB(255, 188, 255, 235),
          ],
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 16),
          Text(
            'Trình chiếu hình ảnh',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Spacer(),
          // Stats button
          ElevatedButton.icon(
            onPressed: _showStatsPopup,
            icon: Icon(Icons.analytics, size: 20),
            label: Text('Thống kê'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          SizedBox(width: 16),
          if (_isLoading)
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Đang đồng bộ...',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          if (!_isLoading)
            Text(
              'Tự động đồng bộ mỗi 35 phút',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildHeader(),
          if (_syncStatus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Colors.blue[900],
              child: Text(
                _syncStatus,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _imagesData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 24),
                        Text(
                          _isLoading ? 'Đang tải hình ảnh...' : 'Không có hình ảnh để hiển thị',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.grey[400],
                          ),
                        ),
                        if (!_isLoading) ...[
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _syncData();
                            },
                            child: Text('Đồng bộ ngay'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _imagesData.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildImageSlide(_imagesData[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// New Stats Popup Window Widget
class StatsPopupWindow extends StatefulWidget {
  final List<TaskHistoryModel> data;

  const StatsPopupWindow({Key? key, required this.data}) : super(key: key);

  @override
  _StatsPopupWindowState createState() => _StatsPopupWindowState();
}

class _StatsPopupWindowState extends State<StatsPopupWindow> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: DraggableResizableWindow(
        title: 'Thống kê báo cáo',
        child: StatsContent(data: widget.data),
      ),
    );
  }
}

class DraggableResizableWindow extends StatefulWidget {
  final String title;
  final Widget child;

  const DraggableResizableWindow({
    Key? key,
    required this.title,
    required this.child,
  }) : super(key: key);

  @override
  _DraggableResizableWindowState createState() => _DraggableResizableWindowState();
}

class _DraggableResizableWindowState extends State<DraggableResizableWindow> {
  double _width = 800;
  double _height = 600;
  double _top = 100;
  double _left = 100;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _top += details.delta.dy;
            _left += details.delta.dx;
          });
        },
        child: Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Title bar
              Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[800]!],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 16),
                    Icon(Icons.analytics, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(child: widget.child),
              // Resize handle
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _width += details.delta.dx;
                    _height += details.delta.dy;
                    _width = _width.clamp(400.0, 1200.0);
                    _height = _height.clamp(300.0, 800.0);
                  });
                },
                child: Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.drag_handle,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsContent extends StatelessWidget {
  final List<TaskHistoryModel> data;

  const StatsContent({Key? key, required this.data}) : super(key: key);

  Map<String, int> _getStaffStats() {
    final stats = <String, int>{};
    for (final record in data) {
      if (record.nguoiDung != null && record.nguoiDung!.trim().isNotEmpty) {
        stats[record.nguoiDung!] = (stats[record.nguoiDung!] ?? 0) + 1;
      }
    }
    return Map.fromEntries(stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, int> _getDepartmentStats() {
    final stats = <String, int>{};
    for (final record in data) {
      if (record.boPhan != null && record.boPhan!.trim().isNotEmpty) {
        stats[record.boPhan!] = (stats[record.boPhan!] ?? 0) + 1;
      }
    }
    return Map.fromEntries(stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, int> _getCategoryStats() {
    final stats = <String, int>{};
    for (final record in data) {
      if (record.phanLoai != null && record.phanLoai!.trim().isNotEmpty) {
        stats[record.phanLoai!] = (stats[record.phanLoai!] ?? 0) + 1;
      }
    }
    return Map.fromEntries(stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, int> _getStatusStats() {
    final stats = <String, int>{};
    for (final record in data) {
      final status = record.ketQua ?? 'Không xác định';
      final displayStatus = _formatKetQua(status);
      stats[displayStatus] = (stats[displayStatus] ?? 0) + 1;
    }
    return stats;
  }

  String _formatKetQua(String? ketQua) {
    if (ketQua == null) return 'Không xác định';
    switch (ketQua) {
      case '✔️':
        return 'Đạt';
      case '❌':
        return 'Không làm';
      case '⚠️':
        return 'Chưa tốt';
      default:
        return ketQua;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Đạt':
        return Colors.green;
      case 'Không làm':
        return Colors.red;
      case 'Chưa tốt':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffStats = _getStaffStats();
    final departmentStats = _getDepartmentStats();
    final categoryStats = _getCategoryStats();
    final statusStats = _getStatusStats();
    final totalReports = data.length;
    final reportsWithImages = data.where((r) => r.hinhAnh?.isNotEmpty == true).length;

    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Tổng báo cáo',
                    totalReports.toString(),
                    Icons.assignment,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Có hình ảnh',
                    reportsWithImages.toString(),
                    Icons.photo_camera,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Tỷ lệ có ảnh',
                    '${((reportsWithImages / totalReports) * 100).toStringAsFixed(1)}%',
                    Icons.pie_chart,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            // Status Statistics
           _buildStatsSection(
             'Thống kê trạng thái',
             statusStats,
             Icons.check_circle,
             (status) => _getStatusColor(status),
           ),
           SizedBox(height: 24),

           // Staff Statistics
           _buildStatsSection(
             'Thống kê nhân viên (Top 10)',
             Map.fromEntries(staffStats.entries.take(10)),
             Icons.person,
             (staff) => Colors.blue[600]!,
           ),
           SizedBox(height: 24),

           // Department Statistics
           _buildStatsSection(
             'Thống kê bộ phận (Top 10)',
             Map.fromEntries(departmentStats.entries.take(10)),
             Icons.business,
             (dept) => Colors.orange[600]!,
           ),
           SizedBox(height: 24),

           // Category Statistics
           _buildStatsSection(
             'Thống kê phân loại báo cáo',
             categoryStats,
             Icons.category,
             (category) => Colors.green[600]!,
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
   return Container(
     padding: EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: color.withOpacity(0.1),
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: color.withOpacity(0.3)),
     ),
     child: Column(
       children: [
         Icon(icon, color: color, size: 32),
         SizedBox(height: 8),
         Text(
           value,
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
             fontSize: 12,
             color: Colors.grey[600],
             fontWeight: FontWeight.w500,
           ),
           textAlign: TextAlign.center,
         ),
       ],
     ),
   );
 }

 Widget _buildStatsSection(
   String title,
   Map<String, int> stats,
   IconData icon,
   Color Function(String) colorProvider,
 ) {
   if (stats.isEmpty) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           children: [
             Icon(icon, color: Colors.grey[600]),
             SizedBox(width: 8),
             Text(
               title,
               style: TextStyle(
                 fontSize: 18,
                 fontWeight: FontWeight.bold,
                 color: Colors.grey[800],
               ),
             ),
           ],
         ),
         SizedBox(height: 16),
         Container(
           padding: EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: Colors.grey[100],
             borderRadius: BorderRadius.circular(8),
           ),
           child: Center(
             child: Text(
               'Không có dữ liệu',
               style: TextStyle(
                 color: Colors.grey[600],
                 fontSize: 14,
               ),
             ),
           ),
         ),
       ],
     );
   }

   final maxValue = stats.values.reduce((a, b) => a > b ? a : b);

   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       Row(
         children: [
           Icon(icon, color: Colors.grey[600]),
           SizedBox(width: 8),
           Text(
             title,
             style: TextStyle(
               fontSize: 18,
               fontWeight: FontWeight.bold,
               color: Colors.grey[800],
             ),
           ),
         ],
       ),
       SizedBox(height: 16),
       Container(
         decoration: BoxDecoration(
           color: Colors.grey[50],
           borderRadius: BorderRadius.circular(8),
           border: Border.all(color: Colors.grey[200]!),
         ),
         child: Column(
           children: [
             // Header
             Container(
               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               decoration: BoxDecoration(
                 color: Colors.grey[100],
                 borderRadius: BorderRadius.only(
                   topLeft: Radius.circular(8),
                   topRight: Radius.circular(8),
                 ),
               ),
               child: Row(
                 children: [
                   Expanded(
                     flex: 3,
                     child: Text(
                       'Tên',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 14,
                         color: Colors.grey[700],
                       ),
                     ),
                   ),
                   Expanded(
                     flex: 2,
                     child: Text(
                       'Biểu đồ',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 14,
                         color: Colors.grey[700],
                       ),
                       textAlign: TextAlign.center,
                     ),
                   ),
                   Expanded(
                     flex: 1,
                     child: Text(
                       'Số lượng',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 14,
                         color: Colors.grey[700],
                       ),
                       textAlign: TextAlign.center,
                     ),
                   ),
                 ],
               ),
             ),
             // Data rows
             ...stats.entries.map((entry) => _buildStatsRow(
                   entry.key,
                   entry.value,
                   maxValue,
                   colorProvider(entry.key),
                 )),
           ],
         ),
       ),
     ],
   );
 }

 Widget _buildStatsRow(String name, int count, int maxValue, Color color) {
   final percentage = (count / maxValue);
   
   return Container(
     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
     decoration: BoxDecoration(
       border: Border(
         bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
       ),
     ),
     child: Row(
       children: [
         // Name
         Expanded(
           flex: 3,
           child: Text(
             name,
             style: TextStyle(
               fontSize: 13,
               color: Colors.grey[800],
             ),
             maxLines: 2,
             overflow: TextOverflow.ellipsis,
           ),
         ),
         // Progress bar
         Expanded(
           flex: 2,
           child: Container(
             margin: EdgeInsets.symmetric(horizontal: 8),
             child: Stack(
               children: [
                 Container(
                   height: 20,
                   decoration: BoxDecoration(
                     color: Colors.grey[200],
                     borderRadius: BorderRadius.circular(10),
                   ),
                 ),
                 Container(
                   height: 20,
                   width: double.infinity,
                   child: FractionallySizedBox(
                     alignment: Alignment.centerLeft,
                     widthFactor: percentage,
                     child: Container(
                       decoration: BoxDecoration(
                         color: color,
                         borderRadius: BorderRadius.circular(10),
                       ),
                     ),
                   ),
                 ),
                 Container(
                   height: 20,
                   child: Center(
                     child: Text(
                       '${(percentage * 100).toStringAsFixed(0)}%',
                       style: TextStyle(
                         fontSize: 10,
                         fontWeight: FontWeight.bold,
                         color: percentage > 0.5 ? Colors.white : Colors.grey[600],
                       ),
                     ),
                   ),
                 ),
               ],
             ),
           ),
         ),
         // Count
         Expanded(
           flex: 1,
           child: Text(
             count.toString(),
             style: TextStyle(
               fontSize: 14,
               fontWeight: FontWeight.bold,
               color: color,
             ),
             textAlign: TextAlign.center,
           ),
         ),
       ],
     ),
   );
 }
}