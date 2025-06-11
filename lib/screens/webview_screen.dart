import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import '../user_state.dart';
import '../main.dart' show MainScreen;
import '../floating_draggable_icon.dart';
import '../chamcong.dart';
import '../location_provider.dart';
import '../user_credentials.dart';
import '../hs_page.dart';
import '../news_section.dart'; 
import '../projectmanagement4.dart';
import '../hs_khachhang.dart';
import '../hd_page.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  // Video Player State
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  String _username = '';

  // Tab Controller
  late TabController _tabController;
  
  // Colors from the original GridViewScreen
  final Color appBarTop = Color(0xFF024965);
  final Color appBarBottom = Color(0xFF03a6cf);
  final Color videoOverlayTop = Color(0xFF03a6cf);
  final Color videoOverlayMiddle = Color(0xFF016585);
  final Color videoOverlayBottom = Color(0xFF016585);
  final Color searchBarColor = Color(0xFF35abb5); 
  final Color buttonColor = Color(0xFF33a7ce);
  final Color smallTextColor = Color(0xFFcdc473);
  final Color tabBarColor = Color(0xFF034d58);
  
  final List<Map<String, dynamic>> gridData = [
  {'icon': 'assets/timelogo.png', 'important': 'true', 'name': 'HM Time',
    'link': 'time_link',
    'isDirectNavigation': true,
    'tab': 0,
  },
  {'icon': 'assets/hotellogo.png', 'important': 'true', 'name': 'HM Hotel',
    'link': 'hotel_link',
    'isDirectNavigation': true,
    'tab': 0, 
  },
  {'icon': 'assets/logogoclean.png', 'important': 'true', 'name': 'HM GoClean',
    'link': 'goclean_link',
    'isDirectNavigation': true,
    'tab': 0, 
  },
    {'icon': 'assets/hopdonglogo.png', 'important': 'true', 'name': 'Hợp đồng của tôi',
  'link': 'hopdong_link',
  'isDirectNavigation': true,
  'tab': 0, 
},
  {'icon': 'assets/zaloviplogo.png','important': 'true', 'name': 'OA Kinh Doanh', 'link': 'https://zalo.me/g/rzccet697', 'tab': 0},
  {'icon': 'assets/zaloviplogo.png','important': 'true', 'name': 'OA QLDV', 'link': 'https://zalo.me/g/xbcalx122', 'tab': 0},
  {'icon': 'assets/linklogo.png', 'name': 'HM Link', 'link': 'https://www.appsheet.com/start/28785d83-62f3-4ec6-8ddd-2780d413dfa7', 'tab': 0},
  {'icon': 'assets/logoonline.png', 'name': 'Đào tạo online', 'link': 'https://yourworldtravel.vn/api/index3.html', 'tab': 0},
  {'icon': 'assets/emaillogo.png', 'name': 'Tạo chữ ký email', 'link': 'https://yourworldtravel.vn/api/indexsignature.html', 'tab': 0},
  {'icon': 'assets/dblogo.png', 'important': 'true', 'name': 'Báo cáo hàng ngày', 'link': 'https://yourworldtravel.vn/drive/dailyreport.html', 'tab': 1},
  {'icon': 'assets/logokt.png', 'important': 'true','name': 'HM Kỹ thuật', 'link': 'https://www.appsheet.com/start/f2040b99-7558-4e2c-9e02-df100c83d8ce', 'tab': 0},
  {'icon': 'assets/zalologo.png', 'name': 'Zalo Hoàn Mỹ', 'link': 'https://zalo.me/2746464448500686217', 'tab': 0},
  {'icon': 'assets/fblogo.png','important': 'true', 'name': 'Facebook Hoàn Mỹ', 'link': 'https://www.facebook.com/Hoanmykleanco', 'tab': 0},
  {'icon': 'assets/tiktoklogo.png','important': 'true', 'name': 'Tiktok Hoàn Mỹ', 'link': 'https://www.tiktok.com/@hoanmykleanco', 'tab': 0},
  {'icon': 'assets/weblogo.png','important': 'true', 'name': 'Website Hoàn Mỹ', 'link': 'https://hoanmykleanco.com/', 'tab': 0},
  {'icon': 'assets/iglogo.png','important': 'true', 'name': 'Instagram Hoàn Mỹ', 'link': 'https://www.instagram.com/hoanmykleanco/', 'tab': 0},
  {'icon': 'assets/ytlogo.png','important': 'true', 'name': 'Youtube Hoàn Mỹ', 'link': 'https://www.youtube.com/@hoanmykleanco', 'tab': 0},
];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadUserInfo();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _initializeVideo() {
  if (Platform.isWindows) {
    setState(() {
      _videoInitialized = false;
    });
    return;
  }
  _videoController = VideoPlayerController.asset('assets/appvideogroup.mp4')
    ..initialize().then((_) {
      _videoController.setLooping(true);
      _videoController.setVolume(0.0);
      _videoController.play();
      setState(() {
        _videoInitialized = true;
      });
    }).catchError((error) {
       print("Error initializing video: $error");
       setState(() {
          _videoInitialized = false; 
       });
    });
}

  Future<void> _loadUserInfo() async {
    try {
      final userState = Provider.of<UserState>(context, listen: false);
      final userData = userState.currentUser;
      setState(() {
        _username = userData?['username'] ?? '';
      });
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  @override
  void dispose() {
    if (!Platform.isWindows) {
    _videoController.dispose();
  }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleUrlOpen(String url, String title) async {
    // Special case for HM Time - navigate to ChamCongScreen
    if (title == 'HM Time') {
      final userState = Provider.of<UserState>(context, listen: false);
      final userData = userState.currentUser;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider<LocationProvider>(
                create: (_) => LocationProvider(),
              ),
            ],
            child: ChamCongScreen(userData: userData),
          ),
        ),
      );
      return;
    }
    
    // Special case for HM Hotel - navigate to hs_page.dart
    if (title == 'HM Hotel') {
      final userState = Provider.of<UserState>(context, listen: false);
      final userData = userState.currentUser;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => HSPage(userData: userData),
        ),
      );
      return;
    }

    // Special case for HM GoClean - navigate to ProjectManagement4
    if (title == 'HM GoClean') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProjectManagement4(),
        ),
      );
      return;
    }
if (title == 'Hợp đồng của tôi') {
    final userState = Provider.of<UserState>(context, listen: false);
    final userData = userState.currentUser;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HDPage(),
      ),
    );
    return;
  }
    // External URL handling with desktop_webview_window
    final Uri uri = Uri.parse(url);
    
    final browserDomains = [
      'zalo.me',
      'facebook.com',
      'tiktok.com',
      'instagram.com',
      'hoanmykleanco.com',
      'youtube.com'
    ];

    bool shouldOpenInBrowser = browserDomains.any((domain) => url.contains(domain));

    if (shouldOpenInBrowser) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      showWebViewDialog(context, url, title);
    }
  }

  void showWebViewDialog(BuildContext context, String url, String title) async {
    if (await WebviewWindow.isWebviewAvailable()) {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: title,
          titleBarTopPadding: Platform.isMacOS ? 20 : 0,
          windowWidth: 1024,
          windowHeight: 768,
        ),
      );

      webview.launch(url);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Webview is not available on this system.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredGridItems({String? currentUsername, required int tabIndex}) {
    if (currentUsername == null) return [];

    return gridData.where((item) {
      // Filter by tab index
      if ((item['tab'] ?? 0) != tabIndex) return false;

      // If no userAccess is specified, show to everyone on this tab
      if (!item.containsKey('userAccess')) return true;

      // If userAccess is specified, check if current user has access
      List<String> allowedUsers = (item['userAccess'] as List).cast<String>();
      return allowedUsers.contains(currentUsername.toLowerCase());
    }).toList();
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [appBarTop, appBarBottom],
          stops: [0.0, 1.0],
        ),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: searchBarColor, 
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.refresh, color: Colors.white, size: 14),
              onPressed: () {
                print("Refresh button pressed!");
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildVideoSection() {
  return Container(
    width: double.infinity,
    color: Colors.black,
    child: Platform.isWindows
        ? // Show image on Windows
          Container(
            height: 350, 
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/viddream.png'),
                fit: BoxFit.cover,
              ),
            ),
          )
        : // Show video on other platforms
          _videoInitialized && _videoController.value.isInitialized
            ? AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              )
            : Container(
                height: 200,
                child: Center(
                  child: _videoInitialized == false 
                    ? Text('⚡', style: TextStyle(color: Colors.white)) 
                    : CircularProgressIndicator(color: Colors.white),
                ),
              ),
  );
}
  
  Widget _buildWelcomeSection() {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [videoOverlayTop, videoOverlayMiddle, videoOverlayBottom],
        stops: [0.0, 0.15, 0.4], // Adjusted stops to make the bottom color extend more
      ),
    ),
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: Column(
      children: [
        Text(
          'Chào mừng đến với HM Group',
          style: TextStyle(
            fontSize: 14.0,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3.0, bottom: 6.0),
          child: Text(
            _username.isNotEmpty ? _username : 'Người dùng',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _handleUrlOpen('time_link', 'HM Time');
                },
                icon: Icon(Icons.hourglass_bottom, color: Colors.white, size: 18),
                label: Text('Chấm công', style: TextStyle(color: Colors.white, fontSize: 14.0)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final userState = Provider.of<UserState>(context, listen: false);
                  final userData = userState.currentUser;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HSKhachHangScreen()),
                  );
                },
                icon: Icon(Icons.local_library, color: Colors.white, size: 18),
                label: Text('Khách hàng', style: TextStyle(color: Colors.white, fontSize: 14.0)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: 11),
          child: Text(
              'Chọn Báo/Duyệt khác từ mục Chấm công để báo nghỉ/ vắng',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}
  
  Widget _buildListItem(Map<String, dynamic> itemData, int index, String username) {
    return Container(
      height: 60,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Image.asset(
          itemData['icon']!,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        ),
        title: Text(
          itemData['name']!,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () {
          // Handle tap with proper URL opening implementation
          _handleUrlOpen(itemData['link']!, itemData['name']!);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer<UserState>(
      builder: (context, userState, child) {
        final bool isLoggedIn = userState.currentUser != null;
        final username = userState.currentUser?['username'] ?? '';
        final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final bool isDesktop = MediaQuery.of(context).size.width > 992;
        
        return Scaffold(
          body: Stack(
            children: [
              // Main content with Row layout (split screen)
              Row(
                children: [
                  // Left side - GridViewScreen style layout (70%)
                  Expanded(
                    flex: 70,
                    child: isLandscape || isDesktop
                      ? _buildHorizontalLayout(isLoggedIn, username)
                      : _buildVerticalLayout(isLoggedIn, username),
                  ),
                  
                  // Right side - NewsSection (30%)
                  Expanded(
                    flex: 30,
                    child: NewsSection(),
                  ),
                ],
              ),
              
              // Floating icon
              FloatingDraggableIcon(
                key: FloatingDraggableIcon.globalKey,
              ),
            ],
          ),
        );
      },
    );
  }

  // New method for horizontal/desktop layout (2 columns)
  Widget _buildHorizontalLayout(bool isLoggedIn, String username) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Column 1 (40%): AppBar + Video + Welcome section
      Expanded(
        flex: 60,
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Container(
                // Add this container with decoration to extend the gradient
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, videoOverlayBottom],
                    stops: [0.0, 0.3],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildVideoSection(),
                      _buildWelcomeSection(),
                      // Add some extra space at the bottom with the same background color
                      Container(
                        height: 100,
                        color: videoOverlayBottom,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Column 2 (40%): Tab view with both tabs
      Expanded(
        flex: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            border: Border(
              left: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
          ),
          child: Column(
            children: [
              Container(
                color: tabBarColor,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.6),
                  tabs: [
                    Tab(text: 'Ứng dụng'), 
                    Tab(text: 'Quản trị'), 
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                      // Tab 1 content
                      isLoggedIn
                        ? ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _getFilteredGridItems(currentUsername: username, tabIndex: 0).length,
                            itemBuilder: (context, index) {
                              final itemData = _getFilteredGridItems(currentUsername: username, tabIndex: 0)[index];
                              return _buildListItem(itemData, index, username);
                            },
                            separatorBuilder: (context, index) {
                              return Divider(height: 1, color: Colors.grey[300], indent: 16, endIndent: 16);
                            },
                          )
                        : Center(
                            child: Text(
                              'Bạn cần đăng nhập lại để xem các chức năng',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                      
                      // Tab 2 content
                      isLoggedIn
                        ? ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _getFilteredGridItems(currentUsername: username, tabIndex: 1).length,
                            itemBuilder: (context, index) {
                              final itemData = _getFilteredGridItems(currentUsername: username, tabIndex: 1)[index];
                              return _buildListItem(itemData, index, username);
                            },
                            separatorBuilder: (context, index) {
                              return Divider(height: 1, color: Colors.grey[300], indent: 16, endIndent: 16);
                            },
                          )
                        : Center(
                            child: Text(
                              'Bạn cần đăng nhập lại để xem các chức năng',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Vertical layout for mobile
  Widget _buildVerticalLayout(bool isLoggedIn, String username) {
  return SafeArea(
    child: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildAppBar()),
        SliverToBoxAdapter(
          child: Container(
            color: tabBarColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white, 
              labelColor: Colors.white, 
              unselectedLabelColor: Colors.white.withOpacity(0.6), 
              tabs: [
                Tab(text: 'Ứng dụng'), 
                Tab(text: 'Quản trị'), 
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildVideoSection()),
        // Updated welcome section with minimum height to fill the screen
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.3, // Ensure it takes at least 30% of screen height
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [videoOverlayTop, videoOverlayMiddle, videoOverlayBottom],
                stops: [0.0, 0.15, 0.4], // Adjusted stops to make the bottom color dominant
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        'Chào mừng đến với HM Group',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 3.0, bottom: 6.0),
                        child: Text(
                          _username.isNotEmpty ? _username : 'Người dùng',
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _handleUrlOpen('time_link', 'HM Time');
                              },
                              icon: Icon(Icons.hourglass_bottom, color: Colors.white, size: 18),
                              label: Text('Chấm công', style: TextStyle(color: Colors.white, fontSize: 14.0)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final userState = Provider.of<UserState>(context, listen: false);
                                final userData = userState.currentUser;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => HSKhachHangScreen()),
                                );
                              },
                              icon: Icon(Icons.local_library, color: Colors.white, size: 18),
                              label: Text('Khách hàng', style: TextStyle(color: Colors.white, fontSize: 14.0)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 11),
                        child: Text(
                          'Lượt vào mỗi ngày sẽ tự động chấm nếu hợp lệ',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // The rest of your code remains the same
        SliverFillRemaining(
          // Set hasScrollBody to false to prevent scrolling conflicts
          hasScrollBody: true,
          child: Container(
            // This container extends the gradient background
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [videoOverlayBottom, videoOverlayBottom],
              ),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1 content - wrap in Container with white background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: isLoggedIn
                    ? ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _getFilteredGridItems(currentUsername: username, tabIndex: 0).length,
                        itemBuilder: (context, index) {
                          final itemData = _getFilteredGridItems(currentUsername: username, tabIndex: 0)[index];
                          return _buildListItem(itemData, index, username);
                        },
                        separatorBuilder: (context, index) {
                          return Divider(height: 1, color: Colors.grey[300], indent: 16, endIndent: 16);
                        },
                      )
                    : Center(
                        child: Text(
                          'Bạn cần đăng nhập lại để xem các chức năng',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                ),
                
                // Tab 2 content - wrap in Container with white background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: isLoggedIn
                    ? ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _getFilteredGridItems(currentUsername: username, tabIndex: 1).length,
                        itemBuilder: (context, index) {
                          final itemData = _getFilteredGridItems(currentUsername: username, tabIndex: 1)[index];
                          return _buildListItem(itemData, index, username);
                        },
                        separatorBuilder: (context, index) {
                          return Divider(height: 1, color: Colors.grey[300], indent: 16, endIndent: 16);
                        },
                      )
                    : Center(
                        child: Text(
                          'Bạn cần đăng nhập lại để xem các chức năng',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}