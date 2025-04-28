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
import 'coinstat.dart';

class NewsSection extends StatefulWidget {
  @override
  _NewsSectionState createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> with AutomaticKeepAliveClientMixin {
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

  @override
  bool get wantKeepAlive => true;
  @override
@override
void initState() {
  super.initState();
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
  _scrollController.dispose();
  // Clean up all video controllers
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
  Future<void> _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'anonymous';
    });
  }
Future<void> _playVibrationPattern() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
  pattern: [
    0, 100, 50, 100,
  ],
  intensities: [
    0, 200, 0, 200,
  ],
); }}
Future<void> _preloadVideosForLatestPosts() async {
    if (_isPreloadingVideos) return;
    
    setState(() {
      _isPreloadingVideos = true;
    });
    
    try {
      // Get the latest 30 posts
      final latestPosts = await _loadNewsFromDb(limit: 30);
      
      // Filter only posts with videos
      final videoPosts = latestPosts.where((post) => 
        post.hinhAnh != null && _isVideoUrl(post.hinhAnh!)).toList();
      
      print('Found ${videoPosts.length} posts with videos to preload');
      
      // Preload up to _maxPreloadedVideos videos to avoid excessive memory usage
      for (int i = 0; i < videoPosts.length && i < _maxPreloadedVideos; i++) {
        final post = videoPosts[i];
        if (post.newsID != null && post.hinhAnh != null) {
          // Initialize video controller
          print('Preloading video for post: ${post.newsID}');
          final controller = VideoPlayerController.networkUrl(Uri.parse(post.hinhAnh!));
          _videoControllers[post.newsID!] = controller;
          _preloadedVideoIds.add(post.newsID!);
          
          // Initialize but don't play yet
          await controller.initialize();
          // Pre-buffer some video content
          controller.setVolume(0);
          controller.play();
          await Future.delayed(Duration(milliseconds: 300));
          controller.pause();
          controller.setVolume(1);
          
          print('Successfully preloaded video for post: ${post.newsID}');
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
    // First ensure the NewsActivity table exists
    await _ensureNewsActivityTableExists();
    
    print('Syncing news comments...');
    
    // Call API to get comments
    final response = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgroupcomment'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      print('Received ${data.length} news activities from server');
      
      if (data is List && data.isNotEmpty) {
        // Insert activities into the database
        int successCount = 0;
        
        for (var item in data) {
          try {
            // Convert to a NewsActivityModel object
            final activity = NewsActivityModel.fromMap(item);
            
            // Prepare data for database
            final Map<String, dynamic> activityData = {
              'LikeID': activity.likeID,
              'NewsID': activity.newsID,
              'Ngay': activity.ngay,
              'Gio': activity.gio,
              'PhanLoai': activity.phanLoai,
              'NoiDung': activity.noiDung,
              'NguoiDung': activity.nguoiDung,
            };
            
            // Check if it already exists
            final existingActivity = await _dbHelper.rawQuery(
              "SELECT * FROM NewsActivity WHERE LikeID = ?",
              [activity.likeID]
            );
            
            if (existingActivity.isEmpty) {
              // Only insert if it doesn't exist
              await _dbHelper.insert('NewsActivity', activityData);
              successCount++;
            }
          } catch (insertError) {
            print('Error processing activity: $insertError');
          }
        }
        
        print('Synced $successCount new news activities');
      }
    } else {
      print('API error - Status code: ${response.statusCode}, Body: ${response.body}');
    }
  } catch (e) {
    print('Error syncing news comments: $e');
  }
}
Future<void> _ensureNewsActivityTableExists() async {
  try {
    // Check if the NewsActivity table exists
    final tables = await _dbHelper.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='NewsActivity'"
    );
    
    if (tables.isEmpty) {
      print('NewsActivity table does not exist. Creating it...');
      
      // Create the NewsActivity table
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
      
      print('NewsActivity table created successfully');
    } else {
      print('NewsActivity table already exists');
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
    // Check if we should sync based on these conditions:
    // 1. First time today
    // 2. Random chance (50%)
    bool shouldSync = false;
    
    // First time today
    final now = DateTime.now();
    if (_lastNewsSyncDate == null || 
        _lastNewsSyncDate!.year != now.year || 
        _lastNewsSyncDate!.month != now.month || 
        _lastNewsSyncDate!.day != now.day) {
      shouldSync = true;
    }
    // Random chance (50%)
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
    // Get the latest date from the local database
    String latestDate = "2022-01-01";
    
    // Try to get the latest news date from database
    try {
      final result = await _dbHelper.rawQuery(
        "SELECT Ngay FROM News ORDER BY Ngay DESC LIMIT 1"
      );
      
      if (result.isNotEmpty && result.first['Ngay'] != null) {
        latestDate = result.first['Ngay'].toString();
        print('Latest news date found: $latestDate');
      } else {
        print('No existing news records found, using default date: $latestDate');
      }
    } catch (e) {
      print('Error getting latest news date: $e');
      // Continue with default date
    }
    
    // Call API to sync data with the correct parameter name
    print('Calling API with fromDate: $latestDate');
    final response = await http.get(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgroupnews?fromDate=$latestDate'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      print('Received ${data.length} news items from server');
      
      if (data is List && data.isNotEmpty) {
        // Insert or update news items one by one
        int successCount = 0;
        int updatedCount = 0;
        for (var item in data) {
          try {
            // Convert the data to a NewsModel object
            final news = NewsModel.fromMap(item);
            
            // Convert to a format that matches the database table
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
            
            // Check if the news item already exists
            final existingNews = await _dbHelper.rawQuery(
              "SELECT * FROM News WHERE NewsID = ?",
              [news.newsID]
            );
            
            if (existingNews.isNotEmpty) {
              // Update existing record
              await _dbHelper.update(
                'News', 
                newsData, 
                where: 'NewsID = ?', 
                whereArgs: [news.newsID]
              );
              updatedCount++;
            } else {
              // Insert new record
              await _dbHelper.insert('News', newsData);
              successCount++;
            }
          } catch (insertError) {
            print('Error processing news item: $insertError');
            // Continue with next item
          }
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật $successCount tin tức mới, $updatedCount tin tức được cập nhật'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // No new data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không có tin tức mới'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      await _syncNewsComments();
      // Update last sync date
      _lastNewsSyncDate = DateTime.now();
      await _saveLastNewsSyncDate();
      await _preloadVideosForLatestPosts();
      setState(() {});
    } else {
      print('API error - Status code: ${response.statusCode}, Body: ${response.body}');
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
      // Using rawQuery instead of query with orderBy parameter
      String query = "SELECT * FROM News ORDER BY Ngay DESC";
      if (limit != null) {
        query += " LIMIT $limit";
      }
      
      final results = await _dbHelper.rawQuery(query);
      
      // Filter out hidden news (TomTat = '❌') and map to models
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
    // Check if the News table exists
    final tables = await _dbHelper.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='News'"
    );
    
    if (tables.isEmpty) {
      print('News table does not exist. Creating it...');
      
      // Create the News table
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
      
      print('News table created successfully');
    } else {
      print('News table already exists');
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
    // Create controller without triggering a full rebuild
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoControllers[newsId] = controller;
    
    // Initialize without setState or with a more targeted approach
    controller.initialize().then((_) {
      if (mounted) {
        // Use a key-based approach to only rebuild the specific video
        setState(() {
          // Empty setState but it's now minimized in scope
        });
      }
    });
  }
  return _videoControllers[newsId]!;
}
// Function to handle like submission
Future<void> _submitLike(String newsId, bool isView) async {
  try {
    // Get current user credentials
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String username = prefs.getString('username') ?? 'anonymous';

    // Generate a unique ID for the like
    final likeId = 'like_${DateTime.now().millisecondsSinceEpoch}_${newsId}_$username';
    
    // Get current date and time
    final now = DateTime.now();
    final currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    
    // Prepare the request body
    final Map<String, dynamic> likeData = {
      'LikeID': likeId,
      'NewsID': newsId,
      'Ngay': currentDate,
      'Gio': currentTime,
      'PhanLoai': 'Like', // Changed to always be "Like" even for views
      'NoiDung': '',
      'NguoiDung': username
    };
    
    // Send the request to the server
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgrouplike'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(likeData),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Like submitted successfully');
      // Increment the like count locally if it was an actual like (not a view)
      if (!isView) {
        setState(() {
          // Find the news item in our cached data and increment its like count
          _refreshNewsItem(newsId, incrementLike: true);
        });
      }
    } else {
      print('Failed to submit like: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('Error submitting like: $e');
  }
}
// Function to handle comment submission
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
    // Get current user credentials
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String username = prefs.getString('username') ?? 'anonymous';
    
    // Generate a unique ID for the comment
    final commentId = 'comment_${DateTime.now().millisecondsSinceEpoch}_${newsId}_$username';
    
    // Get current date and time
    final now = DateTime.now();
    final currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    
    // Prepare the request body
    final Map<String, dynamic> commentData = {
      'LikeID': commentId,
      'NewsID': newsId,
      'Ngay': currentDate,
      'Gio': currentTime,
      'PhanLoai': 'Comment',
      'NoiDung': commentText,
      'NguoiDung': username
    };
    
    // Send the request to the server
    final response = await http.post(
      Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgrouplike'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(commentData),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Comment submitted successfully');
      // Increment the comment count locally
      setState(() {
        _refreshNewsItem(newsId, incrementComment: true);
      });
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bình luận đã được gửi'),
          backgroundColor: Colors.green,
        ),
      );
      return true; // Return success to close comment dialog if needed
    } else {
      print('Failed to submit comment: ${response.statusCode}');
      print('Response: ${response.body}');
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

// Helper method to refresh a news item in the local data
Future<void> _refreshNewsItem(String newsId, {bool incrementLike = false, bool incrementComment = false}) async {
  try {
    // Get the news item from database
    final results = await _dbHelper.rawQuery(
      "SELECT * FROM News WHERE NewsID = ?",
      [newsId]
    );
    
    if (results.isNotEmpty) {
      final newsItem = results.first;
      
      // Update like or comment count
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
        // Update the database
        await _dbHelper.update('News', updates, where: 'NewsID = ?', whereArgs: [newsId]);
        
        // More targeted refresh - only update if widget is still mounted
        if (mounted) {
          setState(() {
            // The state update is still needed but we've minimized other 
            // unnecessary state changes elsewhere in the code
          });
        }
      }
    }
  } catch (e) {
    print('Error refreshing news item: $e');
  }
}
  void _openNewsDetail(NewsModel news) {
  // Register view event when opening news detail
  if (news.newsID != null) {
    _submitLike(news.newsID!, true); // true means it's a view, not a like
  }
  
  bool isPopular = (news.likeCount ?? 0) > 5;
  Color avatarBorderColor;
  Color titleColor;

  // Set colors based on author name
  switch (news.tacGia) {
    case 'VP Hoàn Mỹ':
      avatarBorderColor = Colors.red;
      titleColor = Colors.red;
      break;
    case 'Lychee Hotel':
      avatarBorderColor = Colors.blue;
      titleColor = Colors.blue;
      break;
    case 'Officity Coworking Space':
      avatarBorderColor = Colors.amber[700]!;
      titleColor = Colors.amber[700]!;
      break;
    case 'Hoàn Mỹ Hotel Supply':
      avatarBorderColor = Colors.green;
      titleColor = Colors.green;
      break;
    default:
      avatarBorderColor = Colors.transparent;
      titleColor = Colors.white;
      break;
  }
  
  // Use popular post styling if applicable
  if (isPopular) {
    avatarBorderColor = Colors.orange;
    titleColor = Colors.deepOrange;
  }
  
  // Prepare video controller if needed
  VideoPlayerController? videoController;
  if (news.hinhAnh != null && _isVideoUrl(news.hinhAnh)) {
    videoController = _getVideoController(news.hinhAnh!, news.newsID ?? 'unknown');
  }

  // Comment text controller
  final TextEditingController commentController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 650, maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and close button
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isPopular ? Colors.deepOrange : Colors.blue[700],
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        backgroundImage: news.logo != null && news.logo!.isNotEmpty 
                          ? CachedNetworkImageProvider(news.logo!) 
                          : AssetImage('assets/logo3.png') as ImageProvider,
                        radius: 20,
                        backgroundColor: avatarBorderColor != Colors.transparent ? avatarBorderColor.withOpacity(0.3) : null,
                      ),
                      if (isPopular) Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 14),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          news.tieuDe ?? 'Không có tiêu đề',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Tác giả: ${news.tacGia ?? 'Không có tác giả'} - ${news.ngay ?? 'Không có ngày'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
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
            
            // Content
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
                          color: isPopular 
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPopular 
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.blue.withOpacity(0.3)
                          ),
                        ),
                        child: Text(
                          news.tomTat!,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: isPopular ? Colors.deepOrange : Colors.blue[700],
                          ),
                        ),
                      ),
                      
                    if (news.hinhAnh != null && news.hinhAnh!.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: _isVideoUrl(news.hinhAnh) 
                            ? _buildVideoPlayer(videoController!, true)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: news.hinhAnh!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                                  ),
                                ),
                              ),
                      ),
                      
                    Text(
                      news.baiViet ?? 'Không có nội dung',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Comments section
                    if (news.newsID != null)
                      _buildCommentsSection(news.newsID!, commentController),
                  ],
                ),
              ),
            ),
            
            // Footer with like and comment buttons
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        isPopular ? Icons.local_fire_department : Icons.star,
                        (news.likeCount != null && news.likeCount! > 0) 
                          ? '${news.likeCount} Thích' 
                          : '0 Thích',
                        () {
                          if (news.newsID != null) {
                            _submitLike(news.newsID!, false);
                            _playVibrationPattern();

                            triggerCoinGain(username, context).then((result) {
                              print('📢 playSuccessSound: Coin gain result: $result');
                              if (result == null) {
                                print('❌ playSuccessSound: No response from triggerCoinGain');
                              }
                            }); 
                          }
                        },
                        color: isPopular ? Colors.deepOrange : Colors.blue[700],
                      ),
                      _buildActionButton(
                        Icons.comment_outlined,
                        (news.commentCount != null && news.commentCount! > 0)
                          ? '${news.commentCount} Bình luận'
                          : 'Bình luận',
                        () {
                          // Show comment dialog
                          _showCommentDialog(context, news, commentController);
                        },
                        color: isPopular ? Colors.deepOrange : Colors.blue[700],
                      ),
                    ],
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
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        );
      } else if (snapshot.hasError) {
        return Center(
          child: Text('Không thể tải bình luận: ${snapshot.error}'),
        );
      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(thickness: 1),
            SizedBox(height: 8),
            Text(
              'Bình luận',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[400]),
                  SizedBox(height: 8),
                  Text(
                    'Chưa có bình luận nào',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  OutlinedButton(
                    child: Text('Viết bình luận đầu tiên'),
                    onPressed: () => _showCommentDialog(context, NewsModel(newsID: newsId), commentController),
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
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bình luận (${snapshot.data!.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: Icon(Icons.add_comment, size: 16),
                  label: Text('Thêm bình luận'),
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

// Add this widget to display individual comments
Widget _buildCommentItem(NewsActivityModel comment) {
  // Format date and time
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
    margin: EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User avatar
        CircleAvatar(
          backgroundImage: AssetImage('assets/avatar.png'),
          radius: 18,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Comment header (username and date)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    comment.nguoiDung ?? 'Ẩn danh',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              // Comment content
              Text(
                comment.noiDung ?? '',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              // Action buttons
              Row(
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.star, size: 14),
                    label: Text('Thích', style: TextStyle(fontSize: 12)),
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.reply, size: 14),
                    label: Text('Trả lời', style: TextStyle(fontSize: 12)),
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
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
    builder: (context) => AlertDialog(
      title: Text('Viết bình luận 🔥'),
      content: TextField(
        controller: commentController,
        decoration: InputDecoration(
          hintText: 'Nhập bình luận của bạn...',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          child: Text('Hủy'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: Text('Gửi'),
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
  );
}
Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, {Color? color}) {
  return TextButton.icon(
    icon: Icon(icon, size: 20, color: color ?? Colors.blue[700]),
    label: Text(
      label,
      style: TextStyle(color: color ?? Colors.blue[700]),
    ),
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    SizedBox(height: 8),
                    Text(
                      'Đang tải video...',
                      style: TextStyle(color: Colors.white),
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
                  iconSize: 60,
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
    margin: EdgeInsets.only(top: 4, bottom: 8, left: 16, right: 16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 2,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thông tin mới',
                style: TextStyle(
                  fontSize: 16, // Smaller font
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              IconButton(
                icon: Icon(Icons.sync, color: Colors.blue[800], size: 20), 
                padding: EdgeInsets.zero, 
                constraints: BoxConstraints(), 
                onPressed: _isSyncingNews ? null : _syncNews,
              ),
            ],
          ),
        ),
        Divider(thickness: 1, height: 1),
        // News content
        Expanded(
          child: _isSyncingNews
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitFadingCircle(
                        color: Colors.blue,
                        size: 40.0,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Đang cập nhật tin tức...',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildNewsList(),
        ),
      ],
    ),
  );
}

  // News list widget
  Widget _buildNewsList() {
    return FutureBuilder<List<NewsModel>>(
      future: _loadNewsFromDb(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                SizedBox(height: 16),
                Text(
                  'Có lỗi xảy ra khi tải tin tức',
                  style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Vui lòng thử lại sau',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Tải lại'),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'Chưa có tin tức',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Bấm nút cập nhật để tải tin mới nhất',
                  style: TextStyle(color: Colors.grey[500]),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.sync),
                  label: Text('Cập nhật ngay'),
                  onPressed: _syncNews,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        } else {
          return ListView.builder(
  controller: _scrollController,
  key: PageStorageKey('newsListView'), 
  padding: EdgeInsets.all(16),
  itemCount: snapshot.data!.length,
  itemBuilder: (context, index) {
    final newsItem = snapshot.data![index];
    return _buildNewsCard(newsItem);
  },
);
      }
    },
  );
}
Widget _buildNewsCard(NewsModel news) {
  bool hasVideo = news.hinhAnh != null && _isVideoUrl(news.hinhAnh!);
  String newsId = news.newsID ?? 'unknown';
  bool isPopular = (news.likeCount ?? 0) > 5;
  bool isVideoPreloaded = _preloadedVideoIds.contains(newsId);
  
  // Define author-based colors
  Color avatarBorderColor;
  Color titleColor;
  
  // Set colors based on author name
  switch (news.tacGia) {
    case 'VP Hoàn Mỹ':
      avatarBorderColor = Colors.red;
      titleColor = Colors.red;
      break;
    case 'Lychee Hotel':
      avatarBorderColor = Colors.blue;
      titleColor = Colors.blue;
      break;
    case 'Officity Coworking Space':
      avatarBorderColor = Colors.amber[700]!;
      titleColor = Colors.amber[700]!;
      break;
    case 'Hoàn Mỹ Hotel Supply':
      avatarBorderColor = Colors.green;
      titleColor = Colors.green;
      break;
    default:
      avatarBorderColor = Colors.transparent;
      titleColor = Colors.black;
      break;
  }
  
  // Create the video widget
  Widget mediaWidget = Container(); // Empty default
  
  if (news.hinhAnh != null && news.hinhAnh!.isNotEmpty) {
    if (hasVideo) {
      mediaWidget = VisibilityDetector(
        key: Key('video-$newsId'),
        onVisibilityChanged: (info) {
          // More conservative approach to when videos should play
          if (info.visibleFraction > 0.7) {
            // Only keep a limited number of controllers active at once
            if (!_currentlyVisibleVideoIds.contains(newsId)) {
              setState(() {
                _currentlyVisibleVideoIds.add(newsId);
                
                // If we have too many visible videos, dispose the ones that are no longer visible
                if (_currentlyVisibleVideoIds.length > 3) {
                  // Find videos to remove - the ones not currently visible according to our tracking
                  List<String> toRemove = [];
                  _videoControllers.keys.forEach((id) {
                    if (!_currentlyVisibleVideoIds.contains(id)) {
                      toRemove.add(id);
                    }
                  });
                  
                  // Remove oldest videos beyond our limit
                  while (_currentlyVisibleVideoIds.length > 3 && toRemove.isNotEmpty) {
                    String idToRemove = toRemove.removeAt(0);
                    _currentlyVisibleVideoIds.remove(idToRemove);
                    
                    // Pause and reset video
                    if (_videoControllers.containsKey(idToRemove)) {
                      _videoControllers[idToRemove]!.pause();
                    }
                  }
                }
              });
            }
            
            // Play the video if initialized
            if (_videoControllers.containsKey(newsId)) {
              final controller = _videoControllers[newsId]!;
              if (controller.value.isInitialized && !controller.value.isPlaying) {
                controller.play();
              }
            } else {
              // Only initialize if it's visible
              final controller = _getVideoController(news.hinhAnh!, newsId);
            }
          } else if (info.visibleFraction < 0.3) {
            // Video is not very visible anymore
            if (_currentlyVisibleVideoIds.contains(newsId)) {
              setState(() {
                _currentlyVisibleVideoIds.remove(newsId);
              });
            }
            
            // Pause video when not visible
            if (_videoControllers.containsKey(newsId)) {
              final controller = _videoControllers[newsId]!;
              if (controller.value.isPlaying) {
                controller.pause();
              }
            }
          }
        },
        child: Container(
          height: 180,
          width: double.infinity,
          // Use ClipRRect to ensure the video stays within bounds
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _videoControllers.containsKey(newsId) && 
                   _videoControllers[newsId]!.value.isInitialized
                ? _buildVideoPlayer(_videoControllers[newsId]!, false)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        color: Colors.black12,
                        height: 180,
                        width: double.infinity,
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          isVideoPreloaded 
                            ? CircularProgressIndicator()
                            : Icon(Icons.video_library, size: 40, color: Colors.grey[400]),
                          SizedBox(height: 8),
                          Text(
                            isVideoPreloaded ? 'Đang tải video...' : 'Video sẽ tải khi hiển thị',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      );
    } else {
      mediaWidget = CachedNetworkImage(
        imageUrl: news.hinhAnh!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 180,
          color: Colors.grey[200],
          child: Center(child: Icon(Icons.image_not_supported, size: 30, color: Colors.grey)),
        ),
      );
    }
  }
  
  return Card(
    margin: EdgeInsets.only(bottom: 10),
    elevation: isPopular ? 3 : 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: () {
        _openNewsDetail(news);
        _playVibrationPattern();
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with author and date
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                // Avatar with colored border
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPopular ? Colors.orange : avatarBorderColor,
                      width: isPopular ? 2.5 : 2.0,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: news.logo != null && news.logo!.isNotEmpty 
                      ? CachedNetworkImageProvider(news.logo!) 
                      : AssetImage('assets/logo3.png') as ImageProvider,
                    radius: 16,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        news.tacGia ?? 'Không có tác giả',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        news.ngay ?? 'Không có ngày',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Flame icon for popular posts
                if (isPopular)
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.red],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              news.tieuDe ?? 'Không có tiêu đề',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isPopular ? Colors.deepOrange : titleColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Summary
          if (news.tomTat != null && news.tomTat!.isNotEmpty && news.tomTat != '❌')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(
                news.tomTat!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          // Media content (image or video)
          mediaWidget,
          
          // Preview of content text
          if (news.baiViet != null && news.baiViet!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Text(
                news.baiViet!,
                style: TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          // Footer with action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: Icon(
                    isPopular ? Icons.local_fire_department : Icons.star, 
                    size: 16,
                    color: isPopular ? Colors.deepOrange : Colors.blue[700],
                  ),
                  label: Text(
                    news.likeCount != null && news.likeCount! > 0 
                      ? '${news.likeCount} Thích' 
                      : '0 Thích',
                    style: TextStyle(
                      color: isPopular ? Colors.deepOrange : Colors.blue[700],
                      fontSize: 12, 
                    ),
                  ),
                  onPressed: () {
                    if (news.newsID != null) {
                      _submitLike(news.newsID!, false);
                    }

                    _playVibrationPattern();
                    triggerCoinGain(username, context).then((result) {
                      print('📢 playSuccessSound: Coin gain result: $result');
                      if (result == null) {
                        print('❌ playSuccessSound: No response from triggerCoinGain');
                      }
                    }); 
                  },
                ),
                TextButton.icon(
                  icon: Icon(
                    Icons.comment_outlined,
                    size: 16,
                    color: isPopular ? Colors.deepOrange : Colors.blue[700],
                  ),
                  label: Text(
                    news.commentCount != null && news.commentCount! > 0 
                      ? '${news.commentCount}' 
                      : '0',
                    style: TextStyle(
                      color: isPopular ? Colors.deepOrange : Colors.blue[700],
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () {
                    _openNewsDetail(news);
                    // Create a controller that will be destroyed when dialog closes
                    final TextEditingController commentController = TextEditingController();
                    _showCommentDialog(context, news, commentController);
                  },
                ),
                TextButton.icon(
                  icon: Icon(Icons.more_horiz, size: 16),
                  label: Text(
                    'Xem',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () { 
                    _openNewsDetail(news);
                    _playVibrationPattern();
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}