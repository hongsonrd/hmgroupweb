import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../user_state.dart';
import '../main.dart' show MainScreen;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../floating_draggable_icon.dart';
import '../chamcong.dart';
import '../location_provider.dart';
import '../user_credentials.dart';
import '../hs_page.dart';
import '../news_section.dart'; 
import '../projectmanagement4.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  List<Map<String, dynamic>>? _filteredItems;
  
  final List<Map<String, dynamic>> gridData = [
    {'icon': 'assets/timelogo.png', 'name': 'HM Time', 'link': 'https://www.appsheet.com/start/bd11e9cb-0d5c-423f-bead-3c07f1eae0a3','userAccess':[]},
    {'icon': 'assets/hotellogo.png', 'name': 'HM Hotel', 'link': 'hotel_link','userAccess':[]},
    {'icon': 'assets/logogoclean.png', 'name': 'HM GoClean', 'link': 'goclean_link','userAccess':[]},
    {'icon': 'assets/linklogo.png', 'name': 'HM Link', 'link': 'https://www.appsheet.com/start/28785d83-62f3-4ec6-8ddd-2780d413dfa7','userAccess':[]},
    {'icon': 'assets/logokt.png', 'name': 'HM Kỹ thuật', 'link': 'https://www.appsheet.com/start/f2040b99-7558-4e2c-9e02-df100c83d8ce','userAccess':[]},
    {'icon': 'assets/goodslogo.png', 'name': 'HM Goods', 'link': 'https://www.appsheet.com/start/a97dcdb4-806c-47ac-9277-714e392b2d1b','userAccess':[]},
    {'icon': 'assets/hrlogo.png', 'name': 'HM HR', 'link': 'https://www.appsheet.com/start/adc9a180-6992-4dc3-84ee-9a57cfe70013','userAccess':[]},
    {'icon': 'assets/zalologo.png', 'name': 'Zalo Hoàn Mỹ', 'link': 'https://zalo.me/2746464448500686217','userAccess':[]},
    {'icon': 'assets/fblogo.png', 'name': 'Facebook Hoàn Mỹ', 'link': 'https://www.facebook.com/Hoanmykleanco','userAccess':[]},
    {'icon': 'assets/tiktoklogo.png', 'name': 'Tiktok Hoàn Mỹ', 'link': 'https://www.tiktok.com/@hoanmykleanco','userAccess':[]},
    {'icon': 'assets/weblogo.png', 'name': 'Website Hoàn Mỹ', 'link': 'https://hoanmykleanco.com/','userAccess':[]},
    {'icon': 'assets/iglogo.png', 'name': 'Instagram Hoàn Mỹ', 'link': 'https://www.instagram.com/hoanmykleanco/','userAccess':[]},
  ];

  Future<void> _handleUrlOpen(String url, String title) async {
    // Special case for HM Time - navigate to ChamCongScreen
    if (title == 'HM Time') {
      // Get user data from UserState provider
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
      // Get user data from UserState provider
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
    // Get user data from UserState provider
    final userState = Provider.of<UserState>(context, listen: false);
    final userData = userState.currentUser;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProjectManagement4(),
      ),
    );
    return;
  }
    // Rest of your existing code
    final Uri uri = Uri.parse(url);
    
    final browserDomains = [
      'zalo.me',
      'facebook.com',
      'tiktok.com',
      'instagram.com',
      'hoanmykleanco.com'
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

  List<Map<String, dynamic>> _getFilteredGridItems(String? employeeId) {
    if (employeeId == null) return [];
    
    return gridData.where((item) {
      if (!item.containsKey('userAccess')) return true;
      List<String> allowedUsers = (item['userAccess'] as List).cast<String>();
      return allowedUsers.isEmpty || allowedUsers.contains(employeeId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer<UserState>(
      builder: (context, userState, child) {
        final employeeId = userState.currentUser?['employee_id'];
        _filteredItems ??= _getFilteredGridItems(employeeId);
        
        return Scaffold(
          body: Stack(
            children: [
              // Split screen with Row layout
              Row(
                children: [
                  // Left side - WebViewScreen content (taking 45% of width)
                  Expanded(
                    flex: 70,
                    child: Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/appbackgrid.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: CustomScrollView(
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.all(16.0),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4, // 4 columns for the grid
                                    mainAxisSpacing: 6.0,
                                    crossAxisSpacing: 6.0,
                                    childAspectRatio: 1 / 0.8,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      if (index >= _filteredItems!.length) return null;
                                      return GridItem(
                                        itemData: _filteredItems![index],
                                        onTap: () => _handleUrlOpen(
                                          _filteredItems![index]['link']!,
                                          _filteredItems![index]['name']!,
                                        ),
                                      );
                                    },
                                    childCount: _filteredItems!.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Right side - NewsSection (taking 30% of width)
                  Expanded(
                    flex: 30,
                    child: NewsSection(),
                  ),
                ],
              ),
              
              // Add FloatingDraggableIcon on top
              FloatingDraggableIcon(
                key: FloatingDraggableIcon.globalKey,
              ),
            ],
          ),
        );
      },
    );
  }
}

class GridItem extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final VoidCallback onTap;

  const GridItem({Key? key, required this.itemData, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 247, 247, 247).withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              itemData['icon']!,
              width: 55.0,
              height: 55.0,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                itemData['name']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.0,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}