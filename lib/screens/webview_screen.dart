import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import '../main.dart' show UserState, UserCredentials;

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
    {
      'icon': 'assets/dblogo.png',
      'name': 'Bán hàng Ly',
      'link': 'https://yourworldtravel.vn/api/index3.html',
      'userAccess': ['hm.tranly', 'hm.duchuy', 'bpthunghiem', 'hm.tason']
    },
    {
      'icon': 'assets/dblogo.png',
      'name': 'Bán hàng Mạnh',
      'link': 'https://lookerstudio.google.com/embed/reporting/5baa1a38-d2eb-40fa-9316-316dbb9584e0/page/p_omy9wew3md',
      'userAccess': ['bpthunghiem', 'hm.duchuy', 'hm.tason']
    },
  ];

  void showWebViewDialog(BuildContext context, String url, String title) {
    final String uniqueId = 'webview-${DateTime.now().millisecondsSinceEpoch}';
    
    if (kIsWeb) {
      ui.platformViewRegistry.registerViewFactory(
        uniqueId,
        (int id) => html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.height = '100%'
          ..style.width = '100%'
          ..style.overflow = 'hidden'
          ..id = uniqueId
          ..allowFullscreen = true
          ..setAttribute('sandbox', 'allow-same-origin allow-scripts allow-forms allow-popups')
          ..setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          child: Column(
            children: [
              AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                title: Text(title, style: const TextStyle(fontSize: 16)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      if (kIsWeb) {
                        final iframe = html.document.getElementById(uniqueId) as html.IFrameElement?;
                        if (iframe != null) {
                          final currentSrc = iframe.src;
                          iframe.src = '';
                          Future.delayed(const Duration(milliseconds: 100), () {
                            iframe.src = currentSrc;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
              Expanded(
                child: kIsWeb
                    ? HtmlElementView(viewType: uniqueId)
                    : WebViewWidget(
                        controller: WebViewController()
                          ..setJavaScriptMode(JavaScriptMode.unrestricted)
                          ..enableZoom(true)
                          ..loadRequest(Uri.parse(url)),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredGridItems(String username) {
    return gridData.where((item) {
      if (!item.containsKey('userAccess')) return true;
      List<String> allowedUsers = (item['userAccess'] as List).cast<String>();
      return allowedUsers.contains(username.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer<UserCredentials>(
      builder: (context, userCredentials, child) {
        _filteredItems ??= _getFilteredGridItems(userCredentials.username);
        
        return Scaffold(
          body: Container(
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10.0,
                      crossAxisSpacing: 10.0,
                      childAspectRatio: 1 / 1.2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _filteredItems!.length) return null;
                        return GridItem(
                          itemData: _filteredItems![index],
                          onTap: () => showWebViewDialog(
                            context,
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(itemData['icon']!, width: 50.0, height: 50.0, fit: BoxFit.contain),
            const SizedBox(height: 12.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                itemData['name']!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.0, color: Colors.white, fontWeight: FontWeight.w500),
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