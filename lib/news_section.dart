import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:math';
import 'db_helper.dart';
import 'table_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:vibration/vibration.dart';
import 'package:shimmer/shimmer.dart';
import 'coinstat.dart';

enum PostTier {
  normal,
  popular,
  legendary,
  legendaryPlus, 
}

class NewsSection extends StatefulWidget {
  @override
  _NewsSectionState createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  bool _isSyncingNews = false;
  DateTime? _lastNewsSyncDate;
  final Random _random = Random();
  final DBHelper _dbHelper = DBHelper();
  Map<String, VideoPlayerController> _videoControllers = {};
  String username = 'anonymous';
  final ScrollController _scrollController = ScrollController();
  Color avatarBorderColor = Colors.transparent;
  Color titleColor = Colors.black;
  bool _isPreloadingVideos = false;
  List<String> _preloadedVideoIds = [];
  final int _maxPreloadedVideos = 5;
  Set<String> _currentlyVisibleVideoIds = {};
  late AnimationController _goldAnimationController;
  late Animation<double> _goldAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _goldAnimationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _goldAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _goldAnimationController,
      curve: Curves.easeInOut,
    ));
    _goldAnimationController.repeat(reverse: true);
    _ensureNewsTableExists().then((_) {
      _loadLastNewsSyncDate();
      _checkAndSyncNews();
      _preloadVideosForLatestPosts();
    });
    _syncNewsComments();
    _loadUsername();
  }

  @override
  void dispose() {
    _goldAnimationController.dispose();
    _scrollController.dispose();
    _videoControllers.forEach((_, controller) {
      try {
        controller.pause();
        controller.dispose();
      } catch (e) {
        print('Error disposing video controller: $e');
      }
    });
    _videoControllers.clear();
    _currentlyVisibleVideoIds.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(NewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndSyncNews();
  }

  PostTier _getPostTier(int? likeCount) {
    if (likeCount == null) return PostTier.normal;
    if (likeCount >= 93) return PostTier.legendaryPlus;
    if (likeCount >= 33) return PostTier.legendary;
    if (likeCount >= 13) return PostTier.popular;
    return PostTier.normal;
  }

  Map<String, Color> _getTierColors(PostTier tier, String? author) {
    switch (tier) {
      case PostTier.legendaryPlus:
      return {
        'avatar': Colors.purple[700]!,
        'title': Colors.purple[900]!,
        'accent': Colors.purple[800]!,
      };
      case PostTier.legendary:
        return {
          'avatar': Colors.amber[400]!,
          'title': Colors.amber[700]!,
          'accent': Colors.amber[600]!,
        };
      case PostTier.popular:
        return {
          'avatar': Colors.orange,
          'title': Colors.deepOrange,
          'accent': Colors.orange,
        };
      case PostTier.normal:
        return _getAuthorColors(author);
    }
  }
Widget _buildLegendaryPlusIcon() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.purple[700]!, Colors.pink[400]!, Colors.purple[900]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.purple.withOpacity(0.5),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    ),
    child: _buildGoldShimmerEffect(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond,
            color: Colors.white,
            size: 9,
          ),
          SizedBox(width: 3),
          Text(
            'HOÀN MỸ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}
  Map<String, Color> _getAuthorColors(String? author) {
    switch (author) {
      case 'VP Hoàn Mỹ':
        return {
          'avatar': Colors.red,
          'title': Colors.red,
          'accent': Colors.red,
        };
      case 'Lychee Hotel':
        return {
          'avatar': Colors.blue,
          'title': Colors.blue,
          'accent': Colors.blue,
        };
      case 'Officity Coworking Space':
        return {
          'avatar': Colors.amber[700]!,
          'title': Colors.amber[700]!,
          'accent': Colors.amber[700]!,
        };
      case 'Hoàn Mỹ Hotel Supply':
        return {
          'avatar': Colors.green,
          'title': Colors.green,
          'accent': Colors.green,
        };
      default:
        return {
          'avatar': Colors.blue[600]!,
          'title': Colors.grey[800]!,
          'accent': Colors.blue[600]!,
        };
    }
  }

  Widget _buildModernHeader() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[700]!,
            Colors.blue[600]!,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.article,
              color: Colors.white,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tin tức mới nhất',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: _isSyncingNews 
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 1.5,
                    ),
                  )
                : Icon(Icons.refresh, color: Colors.white, size: 14),
              onPressed: _isSyncingNews ? null : _syncNews,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldShimmerEffect({required Widget child}) {
    return AnimatedBuilder(
      animation: _goldAnimation,
      builder: (context, child) {
        return Shimmer.fromColors(
          baseColor: Colors.amber[700]!,
          highlightColor: Colors.yellow[300]!,
          period: Duration(milliseconds: 1500),
          direction: ShimmerDirection.ltr,
          child: child!,
        );
      },
      child: child,
    );
  }

  Widget _buildLegendaryIcon() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[400]!, Colors.yellow[600]!, Colors.amber[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: _buildGoldShimmerEffect(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.military_tech,
              color: Colors.white,
              size: 9,
            ),
            SizedBox(width: 3),
            Text(
              'TUYỆT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularIcon() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.red],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 9,
          ),
          SizedBox(width: 3),
          Text(
            'HOT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'anonymous';
    });
  }

  Future<void> _playVibrationPattern() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
        pattern: [0, 100, 50, 100,],
        intensities: [0, 200, 0, 200,],
      );
    }
  }

  Future<void> _preloadVideosForLatestPosts() async {
    if (_isPreloadingVideos) return;
    setState(() {
      _isPreloadingVideos = true;
    });
    try {
      final latestPosts = await _loadNewsFromDb(limit: 30);
      final videoPosts = latestPosts.where((post) => 
        post.hinhAnh != null && _isVideoUrl(post.hinhAnh!)).toList();
      for (int i = 0; i < videoPosts.length && i < _maxPreloadedVideos; i++) {
        final post = videoPosts[i];
        if (post.newsID != null && post.hinhAnh != null) {
          final controller = VideoPlayerController.networkUrl(Uri.parse(post.hinhAnh!));
          _videoControllers[post.newsID!] = controller;
          _preloadedVideoIds.add(post.newsID!);
          await controller.initialize();
          controller.setVolume(0);
          controller.play();
          await Future.delayed(Duration(milliseconds: 300));
          controller.pause();
          controller.setVolume(1);
        }
      }
    } catch (e) {
      print('Error preloading videos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPreloadingVideos = false;
        });
      }
    }
  }

  Future<void> _syncNewsComments() async {
    try {
      await _ensureNewsActivityTableExists();
      final response = await http.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgroupcomment'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List && data.isNotEmpty) {
          int successCount = 0;
          for (var item in data) {
            try {
              final activity = NewsActivityModel.fromMap(item);
              final Map<String, dynamic> activityData = {
                'LikeID': activity.likeID,
                'NewsID': activity.newsID,
                'Ngay': activity.ngay,
                'Gio': activity.gio,
                'PhanLoai': activity.phanLoai,
                'NoiDung': activity.noiDung,
                'NguoiDung': activity.nguoiDung,
              };
              final existingActivity = await _dbHelper.rawQuery(
                "SELECT * FROM NewsActivity WHERE LikeID = ?",
                [activity.likeID]
              );
              if (existingActivity.isEmpty) {
                await _dbHelper.insert('NewsActivity', activityData);
                successCount++;
              }
            } catch (insertError) {
              print('Error processing activity: $insertError');
            }
          }
        }
      }
    } catch (e) {
      print('Error syncing news comments: $e');
    }
  }

  Future<void> _ensureNewsActivityTableExists() async {
    try {
      final tables = await _dbHelper.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='NewsActivity'"
      );
      if (tables.isEmpty) {
        await _dbHelper.rawQuery('''
          CREATE TABLE IF NOT EXISTS NewsActivity (
            LikeID VARCHAR(100),
            NewsID VARCHAR(100),
            Ngay DATE,
            Gio TIME,
            PhanLoai VARCHAR(100),
            NoiDung TEXT,
            NguoiDung VARCHAR(100)
          )
        ''');
      }
    } catch (e) {
      print('Error ensuring NewsActivity table exists: $e');
    }
  }

  Future<List<NewsActivityModel>> _loadCommentsForNews(String newsId) async {
    try {
      final results = await _dbHelper.rawQuery(
        "SELECT * FROM NewsActivity WHERE NewsID = ? AND PhanLoai = 'Comment' ORDER BY Ngay DESC, Gio DESC",
        [newsId]
      );
      return results.map((item) => NewsActivityModel.fromMap({
        'likeID': item['LikeID'],
        'newsID': item['NewsID'],
        'ngay': item['Ngay'],
        'gio': item['Gio'],
        'phanLoai': item['PhanLoai'],
        'noiDung': item['NoiDung'],
        'nguoiDung': item['NguoiDung'],
      })).toList();
    } catch (e) {
      print('Error loading comments from database: $e');
      return [];
    }
  }

  Future<void> _loadLastNewsSyncDate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? timestamp = prefs.getInt('lastNewsSyncDate');
    if (timestamp != null) {
      setState(() {
        _lastNewsSyncDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      });
    }
  }

  Future<void> _saveLastNewsSyncDate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_lastNewsSyncDate != null) {
      await prefs.setInt('lastNewsSyncDate', _lastNewsSyncDate!.millisecondsSinceEpoch);
    }
  }

  void _checkAndSyncNews() {
    bool shouldSync = false;
    final now = DateTime.now();
    if (_lastNewsSyncDate == null || 
        _lastNewsSyncDate!.year != now.year || 
        _lastNewsSyncDate!.month != now.month || 
        _lastNewsSyncDate!.day != now.day) {
      shouldSync = true;
    }
    else if (_random.nextDouble() < 0.5) {
      shouldSync = true;
    }
    if (shouldSync) {
      _syncNews();
    }
  }

  Future<void> _syncNews() async {
    if (_isSyncingNews) return;
    setState(() {
      _isSyncingNews = true;
    });
    try {
      String latestDate = "2022-01-01";
      try {
        final result = await _dbHelper.rawQuery(
          "SELECT Ngay FROM News ORDER BY Ngay DESC LIMIT 1"
        );
        if (result.isNotEmpty && result.first['Ngay'] != null) {
          latestDate = result.first['Ngay'].toString();
        }
      } catch (e) {
        print('Error getting latest news date: $e');
      }
      final response = await http.get(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgroupnews?fromDate=$latestDate'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List && data.isNotEmpty) {
          int successCount = 0;
          int updatedCount = 0;
          for (var item in data) {
            try {
              final news = NewsModel.fromMap(item);
              final Map<String, dynamic> newsData = {
                'NewsID': news.newsID,
                'TieuDe': news.tieuDe,
                'SocialURL': news.socialURL,
                'HinhAnh': news.hinhAnh,
                'BaiViet': news.baiViet,
                'Ngay': news.ngay,
                'Logo': news.logo,
                'TomTat': news.tomTat,
                'TacGia': news.tacGia,
                'LikeCount': news.likeCount,
                'CommentCount': news.commentCount,
              };
              final existingNews = await _dbHelper.rawQuery(
                "SELECT * FROM News WHERE NewsID = ?",
                [news.newsID]
              );
              if (existingNews.isNotEmpty) {
                await _dbHelper.update(
                  'News', 
                  newsData, 
                  where: 'NewsID = ?', 
                  whereArgs: [news.newsID]
                );
                updatedCount++;
              } else {
                await _dbHelper.insert('News', newsData);
                successCount++;
              }
            } catch (insertError) {
              print('Error processing news item: $insertError');
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã cập nhật $successCount tin tức mới, $updatedCount tin tức được cập nhật'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không có tin tức mới'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        await _syncNewsComments();
        _lastNewsSyncDate = DateTime.now();
        await _saveLastNewsSyncDate();
        await _preloadVideosForLatestPosts();
        setState(() {});
      } else {
        throw Exception('Failed to sync news: API returned ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing news: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật tin tức: ${e.toString().substring(0, 50)}...'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncingNews = false;
      });
    }
  }

  Future<List<NewsModel>> _loadNewsFromDb({int? limit}) async {
    try {
      String query = "SELECT * FROM News ORDER BY Ngay DESC";
      if (limit != null) {
        query += " LIMIT $limit";
      }
      final results = await _dbHelper.rawQuery(query);
      return results
        .where((item) => item['TomTat'] != '❌')
        .map((item) => NewsModel.fromMap({
          'newsID': item['NewsID'],
          'tieuDe': item['TieuDe'],
          'socialURL': item['SocialURL'],
          'hinhAnh': item['HinhAnh'],
          'baiViet': item['BaiViet'],
          'ngay': item['Ngay'],
          'logo': item['Logo'],
          'tomTat': item['TomTat'],
          'tacGia': item['TacGia'],
          'likeCount': item['LikeCount'],
          'commentCount': item['CommentCount'],
        }))
        .toList();
    } catch (e) {
      print('Error loading news from database: $e');
      return [];
    }
  }

  Future<void> _ensureNewsTableExists() async {
    try {
      final tables = await _dbHelper.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='News'"
      );
      if (tables.isEmpty) {
        await _dbHelper.rawQuery('''
          CREATE TABLE IF NOT EXISTS News (
            NewsID VARCHAR(100),
            TieuDe TEXT,
            SocialURL TEXT,
            HinhAnh TEXT,
            BaiViet TEXT,
            Ngay DATE,
            Logo TEXT,
            TomTat TEXT,
            TacGia VARCHAR(100),
            LikeCount INT,
            CommentCount INT
          )
        ''');
      }
    } catch (e) {
      print('Error ensuring News table exists: $e');
    }
  }

  bool _isVideoUrl(String? url) {
    if (url == null) return false;
    final videoExtensions = ['.mp4', '.mov', '.avi', '.wmv', '.flv', '.webm', '.mkv'];
    return videoExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  VideoPlayerController _getVideoController(String url, String newsId) {
    if (!_videoControllers.containsKey(newsId)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoControllers[newsId] = controller;
      controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    return _videoControllers[newsId]!;
  }

  Future<void> _submitLike(String newsId, bool isView) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String username = prefs.getString('username') ?? 'anonymous';
      final likeId = 'like_${DateTime.now().millisecondsSinceEpoch}_${newsId}_$username';
      final now = DateTime.now();
      final currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      final Map<String, dynamic> likeData = {
        'LikeID': likeId,
        'NewsID': newsId,
        'Ngay': currentDate,
        'Gio': currentTime,
        'PhanLoai': 'Like',
        'NoiDung': '',
        'NguoiDung': username
      };
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgrouplike'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(likeData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!isView) {
          setState(() {
            _refreshNewsItem(newsId, incrementLike: true);
          });
        }
      }
    } catch (e) {
      print('Error submitting like: $e');
    }
  }

  Future<bool> _submitComment(String newsId, String commentText) async {
    if (commentText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bình luận không thể trống'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String username = prefs.getString('username') ?? 'anonymous';
      final commentId = 'comment_${DateTime.now().millisecondsSinceEpoch}_${newsId}_$username';
      final now = DateTime.now();
      final currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      final Map<String, dynamic> commentData = {
        'LikeID': commentId,
        'NewsID': newsId,
        'Ngay': currentDate,
        'Gio': currentTime,
        'PhanLoai': 'Comment',
        'NoiDung': commentText,
        'NguoiDung': username
      };
      final response = await http.post(
        Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgrouplike'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(commentData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _refreshNewsItem(newsId, incrementComment: true);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bình luận đã được gửi'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gửi bình luận'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      print('Error submitting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<void> _refreshNewsItem(String newsId, {bool incrementLike = false, bool incrementComment = false}) async {
    try {
      final results = await _dbHelper.rawQuery(
        "SELECT * FROM News WHERE NewsID = ?",
        [newsId]
      );
      if (results.isNotEmpty) {
        final newsItem = results.first;
        Map<String, dynamic> updates = {};
        if (incrementLike) {
          int currentLikes = newsItem['LikeCount'] ?? 0;
          updates['LikeCount'] = currentLikes + 1;
        }
        if (incrementComment) {
          int currentComments = newsItem['CommentCount'] ?? 0;
          updates['CommentCount'] = currentComments + 1;
        }
        if (updates.isNotEmpty) {
          await _dbHelper.update('News', updates, where: 'NewsID = ?', whereArgs: [newsId]);
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      print('Error refreshing news item: $e');
    }
  }

  void _openNewsDetail(NewsModel news) {
    if (news.newsID != null) {
      _submitLike(news.newsID!, true);
    }
    PostTier postTier = _getPostTier(news.likeCount);
    Map<String, Color> colors = _getTierColors(postTier, news.tacGia);
    VideoPlayerController? videoController;
    if (news.hinhAnh != null && _isVideoUrl(news.hinhAnh)) {
      videoController = _getVideoController(news.hinhAnh!, news.newsID ?? 'unknown');
    }
    final TextEditingController commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: postTier == PostTier.legendary 
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.amber[50]!, Colors.white],
                )
              : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: postTier == PostTier.legendary 
                      ? [Colors.purple[800]!, Colors.indigo[700]!]
                      : [colors['accent']!, colors['accent']!.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: CircleAvatar(
                        backgroundImage: news.logo != null && news.logo!.isNotEmpty 
                          ? CachedNetworkImageProvider(news.logo!) 
                          : AssetImage('assets/logo3.png') as ImageProvider,
                        radius: 16,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          postTier == PostTier.legendary 
                            ? _buildGoldShimmerEffect(
                                child: Text(
                                  news.tieuDe ?? 'Không có tiêu đề',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : Text(
                                news.tieuDe ?? 'Không có tiêu đề',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          SizedBox(height: 3),
                          Text(
                            'Tác giả: ${news.tacGia ?? 'Không có tác giả'} - ${news.ngay ?? 'Không có ngày'}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (postTier == PostTier.legendary)
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.military_tech, color: Colors.white, size: 12),
                      )
                    else if (postTier == PostTier.popular)
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                      ),
                    SizedBox(width: 6),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () {
                        if (videoController != null) {
                          videoController.pause();
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (news.tomTat != null && news.tomTat!.isNotEmpty && news.tomTat != '❌')
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors['accent']!.withOpacity(0.1), colors['accent']!.withOpacity(0.05)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors['accent']!.withOpacity(0.3)),
                          ),
                          child: postTier == PostTier.legendary
                            ? _buildGoldShimmerEffect(
                                child: Text(
                                  news.tomTat!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: colors['accent'],
                                    height: 1.3,
                                  ),
                                ),
                              )
                            : Text(
                                news.tomTat!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: colors['accent'],
                                  height: 1.3,
                                ),
                              ),
                        ),
                      if (news.hinhAnh != null && news.hinhAnh!.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _isVideoUrl(news.hinhAnh) 
                                ? _buildVideoPlayer(videoController!, true)
                                : CachedNetworkImage(
                                    imageUrl: news.hinhAnh!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (context, url) => Container(
                                      height: 150,
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      height: 150,
                                      color: Colors.grey[200],
                                      child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                                    ),
                                  ),
                          ),
                        ),
                      Text(
                        news.baiViet ?? 'Không có nội dung',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 18),
                      if (news.newsID != null)
                        _buildCommentsSection(news.newsID!, commentController),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          postTier == PostTier.legendary ? Icons.thumb_up : (postTier == PostTier.popular ? Icons.local_fire_department : Icons.favorite),
                          size: 14,
                        ),
                        label: Text(
                          (news.likeCount != null && news.likeCount! > 0) 
                            ? '${news.likeCount} Thích' 
                            : 'Thích',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                        onPressed: () {
                          if (news.newsID != null) {
                            _submitLike(news.newsID!, false);
                            _playVibrationPattern();
                            triggerCoinGain(username, context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors['accent'],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.comment_outlined, size: 14),
                        label: Text(
                          (news.commentCount != null && news.commentCount! > 0)
                            ? '${news.commentCount} Bình luận'
                            : 'Bình luận',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                        onPressed: () {
                          _showCommentDialog(context, news, commentController);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors['accent'],
                          side: BorderSide(color: colors['accent']!),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsSection(String newsId, TextEditingController commentController) {
    return FutureBuilder<List<NewsActivityModel>>(
      future: _loadCommentsForNews(newsId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Không thể tải bình luận: ${snapshot.error}', style: TextStyle(fontSize: 11)),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(thickness: 1),
              SizedBox(height: 12),
              Text(
                'Bình luận',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 36, color: Colors.grey[400]),
                    SizedBox(height: 10),
                    Text(
                      'Chưa có bình luận nào',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Hãy là người đầu tiên bình luận',
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(thickness: 1),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bình luận (${snapshot.data!.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.add_comment, size: 12),
                    label: Text('Thêm bình luận', style: TextStyle(fontSize: 10)),
                    onPressed: () => _showCommentDialog(context, NewsModel(newsID: newsId), commentController),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ...snapshot.data!.map((comment) => _buildCommentItem(comment)).toList(),
            ],
          );
        }
      },
    );
  }

  Widget _buildCommentItem(NewsActivityModel comment) {
    String formattedDate = '';
    if (comment.ngay != null && comment.gio != null) {
      try {
        DateTime commentDate = DateTime.parse('${comment.ngay} ${comment.gio}');
        final now = DateTime.now();
        final difference = now.difference(commentDate);
        if (difference.inDays > 0) {
          formattedDate = '${difference.inDays} ngày trước';
        } else if (difference.inHours > 0) {
          formattedDate = '${difference.inHours} giờ trước';
        } else if (difference.inMinutes > 0) {
          formattedDate = '${difference.inMinutes} phút trước';
        } else {
          formattedDate = 'Vừa xong';
        }
      } catch (e) {
        formattedDate = '${comment.ngay} ${comment.gio}';
      }
    }
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: AssetImage('assets/avatar.png'),
            radius: 15,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      comment.nguoiDung ?? 'Ẩn danh',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  comment.noiDung ?? '',
                  style: TextStyle(fontSize: 10, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentDialog(BuildContext context, NewsModel news, TextEditingController commentController) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.chat_bubble, color: Colors.blue[600], size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Viết bình luận',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'Nhập bình luận của bạn...',
                  hintStyle: TextStyle(fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: EdgeInsets.all(12),
                ),
                style: TextStyle(fontSize: 11),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: Text('Hủy', style: TextStyle(fontSize: 11)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    child: Text('Gửi', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (news.newsID != null) {
                        bool success = await _submitComment(news.newsID!, commentController.text);
                        if (success) {
                          commentController.clear();
                          Navigator.of(context).pop();
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(VideoPlayerController controller, bool autoPlay) {
    if (autoPlay && !controller.value.isPlaying && controller.value.isInitialized) {
      controller.play();
    }
    return AspectRatio(
      aspectRatio: controller.value.isInitialized 
          ? controller.value.aspectRatio 
          : 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(controller),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Colors.blue,
              bufferedColor: Colors.grey.withOpacity(0.5),
              backgroundColor: Colors.grey.withOpacity(0.2),
            ),
          ),
          if (!controller.value.isInitialized)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 6),
                    Text(
                      'Đang tải video...',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    )
                  ],
                ),
              ),
            ),
          if (controller.value.isInitialized && !controller.value.isPlaying)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: 45,
                  icon: Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: () {
                    controller.play();
                    setState(() {});
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      margin: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue[700]!,
            Colors.blue[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 1,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildModernHeader(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: _isSyncingNews
                  ? _buildLoadingState()
                  : _buildNewsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitFadingCircle(
            color: Colors.blue[600],
            size: 38.0,
          ),
          SizedBox(height: 16),
          Text(
            'Đang cập nhật tin tức...',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Vui lòng chờ trong giây lát',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsList() {
    return FutureBuilder<List<NewsModel>>(
      future: _loadNewsFromDb(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        } else if (snapshot.hasError) {
          return _buildErrorState();
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        } else {
          return ListView.builder(
            controller: _scrollController,
            key: PageStorageKey('newsListView'),
            padding: EdgeInsets.all(12),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final newsItem = snapshot.data![index];
              return _buildModernNewsCard(newsItem, index);
            },
          );
        }
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 36,
                color: Colors.red[400],
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Không thể tải tin tức',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Vui lòng kiểm tra kết nối và thử lại',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh, size: 16),
              label: Text('Thử lại', style: TextStyle(fontSize: 11)),
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.article_outlined,
                size: 36,
                color: Colors.blue[400],
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Chưa có tin tức',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Hãy cập nhật để nhận tin tức mới nhất',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.sync, size: 16),
              label: Text('Cập nhật ngay', style: TextStyle(fontSize: 11)),
              onPressed: _syncNews,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
Widget _buildModernNewsCard(NewsModel news, int index) {
  bool hasVideo = news.hinhAnh != null && _isVideoUrl(news.hinhAnh!);
  String newsId = news.newsID ?? 'unknown';
  PostTier postTier = _getPostTier(news.likeCount);
  Map<String, Color> colors = _getTierColors(postTier, news.tacGia);
  
  return Container(
    margin: EdgeInsets.only(bottom: 12),
    child: Card(
      elevation: postTier == PostTier.legendaryPlus ? 8 : (postTier == PostTier.legendary ? 6 : 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: postTier == PostTier.legendaryPlus
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple[50]!,
                  Colors.pink[50]!,
                  Colors.white,
                ],
              )
            : postTier == PostTier.legendary 
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber[50]!,
                    Colors.white,
                  ],
                )
              : null,
          border: postTier == PostTier.legendaryPlus
            ? Border.all(
                color: Colors.purple.withOpacity(0.5),
                width: 2,
              )
            : postTier == PostTier.legendary 
              ? Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1.5,
                )
              : null,
        ),
        child: InkWell(
          onTap: () {
            _openNewsDetail(news);
            _playVibrationPattern();
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(news, postTier, colors),
              _buildCardContent(news, hasVideo, newsId),
              _buildCardFooter(news, colors, postTier),
            ],
          ),
        ),
      ),
    ),
  );
}
Widget _buildCardHeader(NewsModel news, PostTier postTier, Map<String, Color> colors) {
  return Container(
    padding: EdgeInsets.all(12),
    child: Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors['avatar']!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors['avatar']!.withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundImage: news.logo != null && news.logo!.isNotEmpty 
              ? CachedNetworkImageProvider(news.logo!) 
              : AssetImage('assets/logo3.png') as ImageProvider,
            radius: 15,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                news.tacGia ?? 'Không có tác giả',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: colors['accent'],
                ),
              ),
              SizedBox(height: 2),
              Text(
                news.ngay ?? 'Không có ngày',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        if (postTier == PostTier.legendaryPlus)
          _buildLegendaryPlusIcon()
        else if (postTier == PostTier.legendary)
          _buildLegendaryIcon()
        else if (postTier == PostTier.popular)
          _buildPopularIcon(),
      ],
    ),
  );
}

  Widget _buildCardContent(NewsModel news, bool hasVideo, String newsId) {
  PostTier postTier = _getPostTier(news.likeCount);
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (news.tieuDe != null)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            news.tieuDe!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (news.tomTat != null && news.tomTat!.isNotEmpty && news.tomTat != '❌')
        Container(
          margin: EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Text(
            news.tomTat!,
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue[700],
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (news.hinhAnh != null && news.hinhAnh!.isNotEmpty)
        Container(
          margin: EdgeInsets.fromLTRB(12, 9, 12, 0),
          child: postTier == PostTier.legendaryPlus
              ? _buildDiamondBorderedMedia(news, hasVideo, newsId)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: hasVideo 
                    ? _buildVideoThumbnail(news.hinhAnh!, newsId)
                    : CachedNetworkImage(
                        imageUrl: news.hinhAnh!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 150,
                          color: Colors.grey[100],
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                        ),
                      ),
                ),
        ),
      if (news.baiViet != null && news.baiViet!.isNotEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(12, 6, 12, 0), 
          child: Text(
            news.baiViet!,
            style: TextStyle(fontSize: 10, height: 1.3),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}
Widget _buildDiamondBorderedMedia(NewsModel news, bool hasVideo, String newsId) {
  return Stack(
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [Colors.purple[700]!, Colors.pink[400]!, Colors.purple[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: hasVideo 
            ? _buildVideoThumbnail(news.hinhAnh!, newsId)
            : CachedNetworkImage(
                imageUrl: news.hinhAnh!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 150,
                  color: Colors.grey[100],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                ),
              ),
        ),
      ),
      // Top-left diamond
      Positioned(
        top: 0,
        left: 0,
        child: Transform.rotate(
          angle: 0.785398, // 45 degrees in radians
          child: Icon(Icons.diamond, color: Colors.white, size: 23),
        ),
      ),
      // Top-right diamond
      Positioned(
        top: 0,
        right: 0,
        child: Transform.rotate(
          angle: 0.785398,
          child: Icon(Icons.diamond, color: Colors.white, size: 23),
        ),
      ),
      // Bottom-left diamond
      Positioned(
        bottom: 0,
        left: 0,
        child: Transform.rotate(
          angle: 0.785398,
          child: Icon(Icons.diamond, color: Colors.white, size: 23),
        ),
      ),
      // Bottom-right diamond
      Positioned(
        bottom: 0,
        right: 0,
        child: Transform.rotate(
          angle: 0.785398,
          child: Icon(Icons.diamond, color: Colors.white, size: 23),
        ),
      ),
    ],
  );
}
Widget _buildVideoThumbnail(String videoUrl, String newsId) {
    return Container(
      height: 150,
      color: Colors.black12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_videoControllers.containsKey(newsId) && _videoControllers[newsId]!.value.isInitialized)
            VideoPlayer(_videoControllers[newsId]!)
          else
            Icon(Icons.video_library, size: 36, color: Colors.grey[400]),
          Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.play_arrow, color: Colors.white, size: 24),
              onPressed: () {
                _loadNewsFromDb().then((newsList) {
                  final newsItem = newsList.firstWhere((n) => n.newsID == newsId);
                  _openNewsDetail(newsItem);
                });
              },
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 9),
                  SizedBox(width: 3),
                  Text(
                    'Video',
                    style: TextStyle(color: Colors.white, fontSize: 7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter(NewsModel news, Map<String, Color> colors, PostTier postTier) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        children: [
          if (news.newsID != null)
            _buildCommentPreview(news.newsID!),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    postTier == PostTier.legendary ? Icons.thumb_up_outlined : (postTier == PostTier.popular ? Icons.local_fire_department : Icons.favorite_border), 
                    size: 12,
                  ),
                  label: Text(
                    news.likeCount != null && news.likeCount! > 0 
                      ? '${news.likeCount}' 
                      : '0',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    if (news.newsID != null) {
                      _submitLike(news.newsID!, false);
                      _playVibrationPattern();
                      triggerCoinGain(username, context);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors['accent'],
                    side: BorderSide(color: colors['accent']!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.comment_outlined, size: 12),
                  label: Text(
                    news.commentCount != null && news.commentCount! > 0 
                      ? '${news.commentCount}' 
                      : '0',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    final TextEditingController commentController = TextEditingController();
                    _showCommentDialog(context, news, commentController);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors['accent'],
                    side: BorderSide(color: colors['accent']!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.open_in_new, size: 12),
                  label: Text(
                    'Xem',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    _openNewsDetail(news);
                    _playVibrationPattern();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors['accent'],
                    side: BorderSide(color: colors['accent']!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<NewsActivityModel?> _loadLatestCommentForNews(String newsId) async {
    try {
      final results = await _dbHelper.rawQuery(
        "SELECT * FROM NewsActivity WHERE NewsID = ? AND PhanLoai = 'Comment' ORDER BY Ngay DESC, Gio DESC LIMIT 1",
        [newsId]
      );
      if (results.isNotEmpty) {
        return NewsActivityModel.fromMap({
          'likeID': results.first['LikeID'],
          'newsID': results.first['NewsID'],
          'ngay': results.first['Ngay'],
          'gio': results.first['Gio'],
          'phanLoai': results.first['PhanLoai'],
          'noiDung': results.first['NoiDung'],
          'nguoiDung': results.first['NguoiDung'],
        });
      }
      return null;
    } catch (e) {
      print('Error loading latest comment from database: $e');
      return null;
    }
  }

  Widget _buildCommentPreview(String newsId) {
    return FutureBuilder<NewsActivityModel?>(
      future: _loadLatestCommentForNews(newsId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox.shrink();
        } else if (snapshot.hasData && snapshot.data != null) {
          final comment = snapshot.data!;
          return Container(
            padding: EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage('assets/avatar.png'),
                  radius: 9,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.nguoiDung ?? 'Ẩn danh',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '•',
                            style: TextStyle(color: Colors.grey[400], fontSize: 9),
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatCommentTime(comment.ngay, comment.gio),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        comment.noiDung ?? '',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }

  String _formatCommentTime(String? ngay, String? gio) {
    if (ngay == null || gio == null) return '';
    try {
      DateTime commentDate = DateTime.parse('$ngay $gio');
      final now = DateTime.now();
      final difference = now.difference(commentDate);
      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (e) {
      return '$ngay';
    }
  }
}