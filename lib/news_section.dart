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
   if (likeCount >= 22) return PostTier.legendary;
   if (likeCount >= 11) return PostTier.popular;
   return PostTier.normal;
 }

 Map<String, Color> _getTierColors(PostTier tier, String? author) {
   switch (tier) {
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
         'avatar': Colors.transparent,
         'title': Colors.black,
         'accent': Colors.grey,
       };
   }
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
     padding: EdgeInsets.all(4),
     decoration: BoxDecoration(
       gradient: LinearGradient(
         colors: [Colors.amber[400]!, Colors.yellow[600]!, Colors.amber[700]!],
         begin: Alignment.topLeft,
         end: Alignment.bottomRight,
       ),
       borderRadius: BorderRadius.circular(12),
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
             size: 12,
           ),
           SizedBox(width: 2),
           Icon(
             Icons.local_fire_department,
             color: Colors.white,
             size: 12,
           ),
         ],
       ),
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
     
     print('Found ${videoPosts.length} posts with videos to preload');
     
     for (int i = 0; i < videoPosts.length && i < _maxPreloadedVideos; i++) {
       final post = videoPosts[i];
       if (post.newsID != null && post.hinhAnh != null) {
         print('Preloading video for post: ${post.newsID}');
         final controller = VideoPlayerController.networkUrl(Uri.parse(post.hinhAnh!));
         _videoControllers[post.newsID!] = controller;
         _preloadedVideoIds.add(post.newsID!);
         
         await controller.initialize();
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
     await _ensureNewsActivityTableExists();
     
     print('Syncing news comments...');
     
     final response = await http.get(
       Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgroupcomment'),
     );
     
     if (response.statusCode == 200) {
       final data = json.decode(utf8.decode(response.bodyBytes));
       print('Received ${data.length} news activities from server');
       
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
     final tables = await _dbHelper.rawQuery(
       "SELECT name FROM sqlite_master WHERE type='table' AND name='NewsActivity'"
     );
     
     if (tables.isEmpty) {
       print('NewsActivity table does not exist. Creating it...');
       
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
         print('Latest news date found: $latestDate');
       } else {
         print('No existing news records found, using default date: $latestDate');
       }
     } catch (e) {
       print('Error getting latest news date: $e');
     }
     
     print('Calling API with fromDate: $latestDate');
     final response = await http.get(
       Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/hmgroupnews?fromDate=$latestDate'),
     );
     
     if (response.statusCode == 200) {
       final data = json.decode(utf8.decode(response.bodyBytes));
       print('Received ${data.length} news items from server');
       
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
       print('News table does not exist. Creating it...');
       
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
       print('Like submitted successfully');
       if (!isView) {
         setState(() {
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
       print('Comment submitted successfully');
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
       insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
       child: Container(
         width: double.infinity,
         constraints: BoxConstraints(maxWidth: 650, maxHeight: MediaQuery.of(context).size.height * 0.8),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Container(
               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               decoration: BoxDecoration(
                 gradient: postTier == PostTier.legendary 
                   ? LinearGradient(colors: [Colors.amber[600]!, Colors.amber[800]!])
                   : LinearGradient(colors: [colors['accent']!, colors['accent']!.withOpacity(0.8)]),
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
                         backgroundColor: colors['avatar'] != Colors.transparent ? colors['avatar']!.withOpacity(0.3) : null,
                       ),
                       if (postTier == PostTier.legendary) Positioned(
                         right: -2,
                         bottom: -2,
                         child: Container(
                           padding: EdgeInsets.all(2),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             shape: BoxShape.circle,
                           ),
                           child: Icon(Icons.military_tech, color: Colors.amber[700], size: 14),
                         ),
                       ) else if (postTier == PostTier.popular) Positioned(
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
                         postTier == PostTier.legendary 
                           ? _buildGoldShimmerEffect(
                               child: Text(
                                 news.tieuDe ?? 'Không có tiêu đề',
                                 style: TextStyle(
                                   fontSize: 16,
                                   fontWeight: FontWeight.bold,
                                   color: Colors.white,
                                 ),
                                 maxLines: 1,
                                 overflow: TextOverflow.ellipsis,
                               ),
                             )
                           : Text(
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
                             fontSize: 12,color: Colors.white.withOpacity(0.8),
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
                           color: colors['accent']!.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(
                             color: colors['accent']!.withOpacity(0.3)
                           ),
                         ),
                         child: postTier == PostTier.legendary
                           ? _buildGoldShimmerEffect(
                               child: Text(
                                 news.tomTat!,
                                 style: TextStyle(
                                   fontSize: 14,
                                   fontStyle: FontStyle.italic,
                                   color: colors['accent'],
                                 ),
                               ),
                             )
                           : Text(
                               news.tomTat!,
                               style: TextStyle(
                                 fontSize: 14,
                                 fontStyle: FontStyle.italic,
                                 color: colors['accent'],
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
                     
                     if (news.newsID != null)
                       _buildCommentsSection(news.newsID!, commentController),
                   ],
                 ),
               ),
             ),
             
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
                         postTier == PostTier.legendary ? Icons.military_tech : (postTier == PostTier.popular ? Icons.local_fire_department : Icons.star),
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
                         color: colors['accent'],
                       ),
                       _buildActionButton(
                         Icons.comment_outlined,
                         (news.commentCount != null && news.commentCount! > 0)
                           ? '${news.commentCount} Bình luận'
                           : 'Bình luận',
                         () {
                           _showCommentDialog(context, news, commentController);
                         },
                         color: colors['accent'],
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
     margin: EdgeInsets.only(bottom: 16),
     child: Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         CircleAvatar(
           backgroundImage: AssetImage('assets/avatar.png'),
           radius: 18,
         ),
         SizedBox(width: 12),
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
               Text(
                 comment.noiDung ?? '',
                 style: TextStyle(fontSize: 14),
               ),
               SizedBox(height: 8),
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
                   fontSize: 16,
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
        return SizedBox.shrink(); // Don't show loading for preview
      } else if (snapshot.hasData && snapshot.data != null) {
        final comment = snapshot.data!;
        return Container(
          margin: EdgeInsets.fromLTRB(12, 4, 12, 0),
          padding: EdgeInsets.all(8),
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
                radius: 10,
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
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          _formatCommentTime(comment.ngay, comment.gio),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      comment.noiDung ?? '',
                      style: TextStyle(
                        fontSize: 11,
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
        return SizedBox.shrink(); // No comment to show
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
 Widget _buildNewsCard(NewsModel news) {
   bool hasVideo = news.hinhAnh != null && _isVideoUrl(news.hinhAnh!);
   String newsId = news.newsID ?? 'unknown';
   PostTier postTier = _getPostTier(news.likeCount);
   Map<String, Color> colors = _getTierColors(postTier, news.tacGia);
   bool isVideoPreloaded = _preloadedVideoIds.contains(newsId);
   
   Widget mediaWidget = Container();
   
   if (news.hinhAnh != null && news.hinhAnh!.isNotEmpty) {
     if (hasVideo) {
       mediaWidget = VisibilityDetector(
         key: Key('video-$newsId'),
         onVisibilityChanged: (info) {
           if (info.visibleFraction > 0.7) {
             if (!_currentlyVisibleVideoIds.contains(newsId)) {
               setState(() {
                 _currentlyVisibleVideoIds.add(newsId);
                 
                 if (_currentlyVisibleVideoIds.length > 3) {
                   List<String> toRemove = [];
                   _videoControllers.keys.forEach((id) {
                     if (!_currentlyVisibleVideoIds.contains(id)) {
                       toRemove.add(id);
                     }
                   });
                   
                   while (_currentlyVisibleVideoIds.length > 3 && toRemove.isNotEmpty) {
                     String idToRemove = toRemove.removeAt(0);
                     _currentlyVisibleVideoIds.remove(idToRemove);
                     
                     if (_videoControllers.containsKey(idToRemove)) {
                       _videoControllers[idToRemove]!.pause();
                     }
                   }
                 }
               });
             }
             
             if (_videoControllers.containsKey(newsId)) {
               final controller = _videoControllers[newsId]!;
               if (controller.value.isInitialized && !controller.value.isPlaying) {
                 controller.play();
               }
             } else {
               final controller = _getVideoController(news.hinhAnh!, newsId);
             }
           } else if (info.visibleFraction < 0.3) {
             if (_currentlyVisibleVideoIds.contains(newsId)) {
               setState(() {
                 _currentlyVisibleVideoIds.remove(newsId);
               });
             }
             
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
     elevation: postTier == PostTier.legendary ? 4 : (postTier == PostTier.popular ? 3 : 2),
     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
     child: Container(
       decoration: postTier == PostTier.legendary 
         ? BoxDecoration(
             borderRadius: BorderRadius.circular(12),
             border: Border.all(
               color: Colors.amber.withOpacity(0.3),
               width: 1.5,
             ),
             boxShadow: [
               BoxShadow(
                 color: Colors.amber.withOpacity(0.2),
                 blurRadius: 8,
                 spreadRadius: 2,
               ),
             ],
           )
         : null,
       child: InkWell(
         onTap: () {
           _openNewsDetail(news);
           _playVibrationPattern();
         },
         borderRadius: BorderRadius.circular(12),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Padding(
               padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
               child: Row(
                 children: [
                   Container(
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       border: Border.all(
                         color: colors['avatar']!,
                         width: postTier == PostTier.legendary ? 3.0 : 2.0,
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
                   if (postTier == PostTier.legendary)
                     _buildLegendaryIcon()
                   else if (postTier == PostTier.popular)
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
             
             Padding(
               padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
               child: postTier == PostTier.legendary
                 ? _buildGoldShimmerEffect(
                     child: Text(
                       news.tieuDe ?? 'Không có tiêu đề',
                       style: TextStyle(
                         fontSize: 15,
                         fontWeight: FontWeight.bold,
                         color: colors['title'],
                       ),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                   )
                 : Text(
                     news.tieuDe ?? 'Không có tiêu đề',
                     style: TextStyle(
                       fontSize: 15,
                       fontWeight: FontWeight.bold,
                       color: colors['title'],
                     ),
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
             ),
             
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
             
             mediaWidget,
             
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
             if (news.newsID != null)
  _buildCommentPreview(news.newsID!),

             Padding(
               padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   TextButton.icon(
                     icon: Icon(
                       postTier == PostTier.legendary ? Icons.military_tech : (postTier == PostTier.popular ? Icons.local_fire_department : Icons.star), 
                       size: 16,
                       color: colors['accent'],
                     ),
                     label: Text(
                       news.likeCount != null && news.likeCount! > 0 
                         ? '${news.likeCount} Thích' 
                         : '0 Thích',
                       style: TextStyle(
                         color: colors['accent'],
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
                       color: colors['accent'],
                     ),
                     label: Text(
                       news.commentCount != null && news.commentCount! > 0 
                         ? '${news.commentCount}' 
                         : '0',
                       style: TextStyle(
                         color: colors['accent'],
                         fontSize: 12,
                       ),
                     ),
                     onPressed: () {
                       _openNewsDetail(news);
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
     ),
   );
 }
}