import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
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

class _ImageSlideshowState extends State<ImageSlideshow>
    with TickerProviderStateMixin {
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
  final Duration _slideDuration = Duration(seconds: 6);
  final Duration _syncInterval = Duration(minutes: 30);

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _explosionController;
  late AnimationController _particleController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _explosionAnimation;
  late Animation<double> _particleAnimation;

  PageController _pageController = PageController();
  bool _isTransitioning = false;

  // Particle effect variables
  List<Particle> _particles = [];
  final int _particleCount = 50;

  bool _shouldFilterProject(String? projectName) {
    if (projectName == null || projectName.trim().isEmpty) return true;
    final name = projectName.toLowerCase();

    if (name.length < 10) return true;
    if (name.startsWith('hm') && RegExp(r'^hm\d+').hasMatch(name)) return true;
    if (name == 'unknown') return true;
    if (projectName == projectName.toUpperCase() && !projectName.contains(' '))
      return true;

    if (name.startsWith('http:') || name.startsWith('https:')) return true;

    return false;
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSlideshow();
  }

  void _initializeAnimations() {
    // Main slide transition controller
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    // Explosion effect controller
    _explosionController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    // Particle effect controller
    _particleController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    // Scale effect controller
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    // Rotation effect controller
    _rotationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    // Create animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.8)
            .chain(CurveTween(curve: Curves.elasticIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_scaleController);

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(1.5, 0.0),
          end: Offset(0.3, 0.0),
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset(0.3, 0.0),
          end: Offset(0.0, 0.0),
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_slideController);

    _explosionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _explosionController,
      curve: Curves.easeOutQuart,
    ));

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    ));

    // Initialize particles
    _generateParticles();
  }

  void _generateParticles() {
    final random = math.Random();
    _particles = List.generate(_particleCount, (index) {
      return Particle(
        x: random.nextDouble() * 400,
        y: random.nextDouble() * 600,
        velocityX: (random.nextDouble() - 0.5) * 400,
        velocityY: (random.nextDouble() - 0.5) * 400,
        color: Color.fromARGB(
          255,
          100 + random.nextInt(155),
          100 + random.nextInt(155),
          100 + random.nextInt(155),
        ),
        size: 2 + random.nextDouble() * 4,
      );
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _syncTimer?.cancel();
    _pageController.dispose();
    _slideController.dispose();
    _explosionController.dispose();
    _particleController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
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
        _nextImageWithExplosion();
      });
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      _checkAndSync();
    });
  }

  void _nextImageWithExplosion() async {
    if (_imagesData.isEmpty || _isTransitioning) return;

    setState(() {
      _isTransitioning = true;
    });

    // Start explosion effect
    _explosionController.forward();
    
    // Start particle effect
    _generateParticles();
    _particleController.reset();
    _particleController.forward();

    // Wait for explosion peak
    await Future.delayed(Duration(milliseconds: 300));

    _currentImageIndex = (_currentImageIndex + 1) % _imagesData.length;

    // Start scale and rotation effects
    _scaleController.reset();
    _rotationController.reset();
    _scaleController.forward();
    _rotationController.forward();

    // Animate to new page with slide effect
    _slideController.reset();
    _slideController.forward();

    await _pageController.animateToPage(
      _currentImageIndex,
      duration: Duration(milliseconds: 1200),
      curve: Curves.easeInOutCubic,
    );

    // Reset all animations
    await Future.delayed(Duration(milliseconds: 200));
    _explosionController.reset();
    _particleController.reset();

    if (mounted) {
      setState(() {
        _isTransitioning = false;
      });
    }
  }

  void _nextImage() {
    _nextImageWithExplosion();
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
      final response = await http
          .get(Uri.parse('$baseUrl/historybaocao2/${widget.username}'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        await dbHelper.clearTable(DatabaseTables.taskHistoryTable);

        final taskHistories = data
            .map((item) => TaskHistoryModel(
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
                ))
            .toList();

        await dbHelper.batchInsertTaskHistory(taskHistories);
        await _updateLastSyncTime();

        final previousCount = _imagesData.length;
        await _loadImagesData();

        if (_imagesData.length > previousCount) {
          _showSuccess(
              'Đã tải ${_imagesData.length - previousCount} hình ảnh mới');
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
    _pageController.animateToPage(0,
        duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    _startSlideshow();
  }

  Future<void> _loadImagesData() async {
    try {
      final db = await dbHelper.database;

      final List<Map<String, dynamic>> allResults = await db.rawQuery('''
        SELECT * FROM ${DatabaseTables.taskHistoryTable}
        ORDER BY Ngay DESC, Gio DESC
      ''');

      _allData = allResults
          .map((item) => TaskHistoryModel(
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
              ))
          .toList();

      final List<Map<String, dynamic>> imageResults = await db.rawQuery('''
        SELECT * FROM ${DatabaseTables.taskHistoryTable}
        WHERE HinhAnh IS NOT NULL AND HinhAnh != ''
        ORDER BY Ngay DESC, Gio DESC
      ''');

      final imagesData = imageResults
          .map((item) => TaskHistoryModel(
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
              ))
          .where((item) =>
              _isValidImage(item) && !_shouldFilterProject(item.boPhan))
          .toList();

      setState(() {
        _imagesData = imagesData;
        if (_imagesData.isNotEmpty &&
            _currentImageIndex >= _imagesData.length) {
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

    final imageUrl = record.hinhAnh!.toLowerCase();
    return imageUrl.startsWith('http') &&
        (imageUrl.contains('.jpg') ||
            imageUrl.contains('.jpeg') ||
            imageUrl.contains('.png') ||
            imageUrl.contains('.gif') ||
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

  Widget _buildImageSlide(TaskHistoryModel record) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Animated main image with multiple effects
          AnimatedBuilder(
            animation: Listenable.merge([
              _fadeAnimation,
              _scaleAnimation,
              _rotationAnimation,
              _slideAnimation
            ]),
            builder: (context, child) {
              return SlideTransition(
                position: _slideAnimation,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(
                        child: Hero(
                          tag: 'image_${record.uid}',
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Đang tải hình ảnh...',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Particle explosion effect
          AnimatedBuilder(
            animation: _particleAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlesPainter(
                  particles: _particles,
                  progress: _particleAnimation.value,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Explosion overlay effect
          AnimatedBuilder(
            animation: _explosionAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: _explosionAnimation.value * 2.0,
                    colors: [
                      Colors.white.withOpacity(0.3 * _explosionAnimation.value),
                      Colors.blue.withOpacity(0.2 * _explosionAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
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
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        Icon(Icons.location_on,
                            color: Colors.white70, size: 16),
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
        },
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (_imagesData.isEmpty) return SizedBox.shrink();

    return Positioned(
      top: 40,
      left: 24,
      right: 24,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
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
                // Animated progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: (_currentImageIndex + 1) / _imagesData.length,
                  ),
                  duration: Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      minHeight: 4,
                    );
                  },
                ),
              ],
            ),
          );
        },
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
              'Tự động đồng bộ mỗi 30 phút',
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
                          _isLoading
                              ? 'Đang tải hình ảnh...'
                              : 'Không có hình ảnh để hiển thị',
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
                              padding: EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ): PageView.builder(
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

// Particle class for explosion effect
class Particle {
 double x;
 double y;
 double velocityX;
 double velocityY;
 Color color;
 double size;

 Particle({
   required this.x,
   required this.y,
   required this.velocityX,
   required this.velocityY,
   required this.color,
   required this.size,
 });

 void update(double progress) {
   x += velocityX * progress * 0.016; // 60fps simulation
   y += velocityY * progress * 0.016;
   
   // Add gravity effect
   velocityY += 500 * progress * 0.016;
   
   // Add air resistance
   velocityX *= 0.98;
   velocityY *= 0.98;
 }
}

// Custom painter for particle effects
class ParticlesPainter extends CustomPainter {
 final List<Particle> particles;
 final double progress;

 ParticlesPainter({
   required this.particles,
   required this.progress,
 });

 @override
 void paint(Canvas canvas, Size size) {
   if (progress == 0) return;

   final paint = Paint()..style = PaintingStyle.fill;

   for (final particle in particles) {
     // Update particle position
     particle.update(progress);

     // Calculate opacity based on progress
     final opacity = math.max(0.0, 1.0 - progress);
     
     paint.color = particle.color.withOpacity(opacity);
     
     // Draw particle with glow effect
     final glowPaint = Paint()
       ..color = particle.color.withOpacity(opacity * 0.3)
       ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size);
     
     canvas.drawCircle(
       Offset(particle.x, particle.y),
       particle.size * 2,
       glowPaint,
     );
     
     canvas.drawCircle(
       Offset(particle.x, particle.y),
       particle.size,
       paint,
     );
   }
 }

 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Shimmer effect widget for loading states
class ShimmerEffect extends StatefulWidget {
 final Widget child;
 final bool enabled;

 const ShimmerEffect({
   Key? key,
   required this.child,
   this.enabled = true,
 }) : super(key: key);

 @override
 _ShimmerEffectState createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
   with SingleTickerProviderStateMixin {
 late AnimationController _shimmerController;
 late Animation<double> _shimmerAnimation;

 @override
 void initState() {
   super.initState();
   _shimmerController = AnimationController(
     duration: Duration(milliseconds: 1500),
     vsync: this,
   );

   _shimmerAnimation = Tween<double>(
     begin: -1.0,
     end: 2.0,
   ).animate(CurvedAnimation(
     parent: _shimmerController,
     curve: Curves.easeInOut,
   ));

   if (widget.enabled) {
     _shimmerController.repeat();
   }
 }

 @override
 void dispose() {
   _shimmerController.dispose();
   super.dispose();
 }

 @override
 Widget build(BuildContext context) {
   if (!widget.enabled) {
     return widget.child;
   }

   return AnimatedBuilder(
     animation: _shimmerAnimation,
     builder: (context, child) {
       return ShaderMask(
         shaderCallback: (bounds) {
           return LinearGradient(
             begin: Alignment.centerLeft,
             end: Alignment.centerRight,
             colors: [
               Colors.transparent,
               Colors.white.withOpacity(0.5),
               Colors.transparent,
             ],
             stops: [
               math.max(0.0, _shimmerAnimation.value - 0.3),
               _shimmerAnimation.value,
               math.min(1.0, _shimmerAnimation.value + 0.3),
             ],
             transform: GradientRotation(0.5),
           ).createShader(bounds);
         },
         blendMode: BlendMode.srcATop,
         child: widget.child,
       );
     },
   );
 }
}

// Enhanced 3D flip transition widget
class FlipTransition extends StatelessWidget {
 final Widget frontChild;
 final Widget backChild;
 final Animation<double> animation;

 const FlipTransition({
   Key? key,
   required this.frontChild,
   required this.backChild,
   required this.animation,
 }) : super(key: key);

 @override
 Widget build(BuildContext context) {
   return AnimatedBuilder(
     animation: animation,
     builder: (context, child) {
       final isShowingFront = animation.value < 0.5;
       return Transform(
         alignment: Alignment.center,
         transform: Matrix4.identity()
           ..setEntry(3, 2, 0.001)
           ..rotateY(animation.value * math.pi),
         child: isShowingFront
             ? frontChild
             : Transform(
                 alignment: Alignment.center,
                 transform: Matrix4.identity()..rotateY(math.pi),
                 child: backChild,
               ),
       );
     },
   );
 }
}

// Ripple effect widget for touch feedback
class RippleEffect extends StatefulWidget {
 final Widget child;
 final VoidCallback? onTap;
 final Color rippleColor;

 const RippleEffect({
   Key? key,
   required this.child,
   this.onTap,
   this.rippleColor = Colors.white,
 }) : super(key: key);

 @override
 _RippleEffectState createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
   with SingleTickerProviderStateMixin {
 late AnimationController _rippleController;
 late Animation<double> _rippleAnimation;
 Offset? _tapPosition;

 @override
 void initState() {
   super.initState();
   _rippleController = AnimationController(
     duration: Duration(milliseconds: 600),
     vsync: this,
   );

   _rippleAnimation = Tween<double>(
     begin: 0.0,
     end: 1.0,
   ).animate(CurvedAnimation(
     parent: _rippleController,
     curve: Curves.easeOut,
   ));
 }

 @override
 void dispose() {
   _rippleController.dispose();
   super.dispose();
 }

 void _handleTap(TapDownDetails details) {
   setState(() {
     _tapPosition = details.localPosition;
   });
   _rippleController.forward().then((_) {
     _rippleController.reset();
   });
   widget.onTap?.call();
 }

 @override
 Widget build(BuildContext context) {
   return GestureDetector(
     onTapDown: _handleTap,
     child: Stack(
       children: [
         widget.child,
         if (_tapPosition != null)
           Positioned.fill(
             child: AnimatedBuilder(
               animation: _rippleAnimation,
               builder: (context, child) {
                 return CustomPaint(
                   painter: RipplePainter(
                     center: _tapPosition!,
                     radius: _rippleAnimation.value * 200,
                     color: widget.rippleColor.withOpacity(
                       (1.0 - _rippleAnimation.value) * 0.3,
                     ),
                   ),
                 );
               },
             ),
           ),
       ],
     ),
   );
 }
}

// Custom painter for ripple effect
class RipplePainter extends CustomPainter {
 final Offset center;
 final double radius;
 final Color color;

 RipplePainter({
   required this.center,
   required this.radius,
   required this.color,
 });

 @override
 void paint(Canvas canvas, Size size) {
   final paint = Paint()
     ..color = color
     ..style = PaintingStyle.fill;

   canvas.drawCircle(center, radius, paint);
 }

 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}