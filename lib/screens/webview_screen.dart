import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'dart:html' as html;
import 'dart:ui' as ui;
import '../main.dart' show UserState, UserCredentials;

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController controller;
  bool isLoading = true;
  bool showWebView = false;
  String? currentUrl;
  final String viewID = 'appsheet-web-view';

  final List<Map<String, dynamic>> gridData = [
    {
      'icon': 'assets/dblogo.png',
      'name': 'Bán hàng Ly',
      'link': 'https://www.appsheet.com/start/e95d2220-9727-4cac-b4c6-1fa0c4cd116c',
      'userAccess': ['hm.tranly', 'hm.duchuy', 'bpthunghiem', 'hm.tason']
    },
    {
      'icon': 'assets/dblogo.png',
      'name': 'Bán hàng Mạnh',
      'link': 'https://lookerstudio.google.com/s/ohNJVkrnKs8',
      'userAccess': ['hm.lemanh', 'hm.duchuy', 'hm.tason']
    },
    // Add the rest of your grid items here
  ];

  void initWebView(String url) {
    if (kIsWeb) {
      try {
        ui.platformViewRegistry.registerViewFactory(
          viewID,
          (int viewId) => html.IFrameElement()
            ..src = url
            ..style.border = 'none'
            ..style.height = '100%'
            ..style.width = '100%'
            ..style.overflow = 'hidden'
            ..allowFullscreen = true,
        );
      } catch (e) {
        print('View factory already registered: $e');
      }
    } else {
      controller = WebViewController()
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  isLoading = true;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              print('WebView error: ${error.description}');
            },
          ),
        )
        ..enableZoom(true)
        ..loadRequest(
          Uri.parse(url),
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          }
        );
    }
  }

  List<Map<String, dynamic>> _getFilteredGridItems(String username) {
    return gridData.where((item) {
      if (!item.containsKey('userAccess')) return true;
      List<String> allowedUsers = (item['userAccess'] as List).cast<String>();
      return allowedUsers.contains(username.toLowerCase());
    }).toList();
  }

  Future<void> _launchExternalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserCredentials>(
      builder: (context, userCredentials, child) {
        final filteredGridData = _getFilteredGridItems(userCredentials.username);
        
        return WillPopScope(
          onWillPop: () async {
            if (showWebView) {
              setState(() {
                showWebView = false;
                currentUrl = null;
              });
              return false;
            }
            return true;
          },
          child: Scaffold(
            body: showWebView 
              ? Stack(
                  children: [
                    if (kIsWeb)
                      SizedBox.expand(
                        child: HtmlElementView(viewType: viewID),
                      )
                    else
                      WebViewWidget(controller: controller),
                    if (isLoading && !kIsWeb)
                      const Center(child: CircularProgressIndicator()),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/appbackgrid.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10.0,
                            crossAxisSpacing: 10.0,
                            childAspectRatio: 1 / 1.2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return GridItem(
                                itemData: filteredGridData[index],
                                onTap: () {
                                  String url = filteredGridData[index]['link']!;
                                  if (url.contains('appsheet.com') ||
                                      url.contains('accounts.google.com') ||
                                      url.contains('https://yourworldtravel.vn/api/index') ||
                                      url.contains('https://lookerstudio.google.com')) {
                                    setState(() {
                                      currentUrl = url;
                                      showWebView = true;
                                    });
                                    initWebView(url);
                                  } else {
                                    _launchExternalUrl(url);
                                  }
                                },
                              );
                            },
                            childCount: filteredGridData.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        );
      },
    );
  }
}

class GridItem extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final VoidCallback onTap;

  const GridItem({
    Key? key,
    required this.itemData,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isImportant = itemData['important'] == 'true';

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 247, 247, 247).withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(itemData['icon']!, width: 50.0, height: 50.0),
            SizedBox(height: 8.0),
            Text(
              itemData['name']!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.0),
            ),
          ],
        ),
      ),
    );
  }
}