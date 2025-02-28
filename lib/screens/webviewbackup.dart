import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../user_state.dart';
import '../main.dart' show MainScreen;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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
//{'icon': 'assets/homelogo.png', 'name': 'HM Home', 'link': 'https://www.appsheet.com/start/475f549e-63de-4071-947f-612f4612f377','userAccess':[]},
//{'icon': 'assets/checklogo.png', 'name': 'HM Check', 'link': 'https://www.appsheet.com/start/38c43e28-1170-4234-95b7-3ea57358a3fa','userAccess':[]},
{'icon': 'assets/linklogo.png', 'name': 'HM Link', 'link': 'https://www.appsheet.com/start/28785d83-62f3-4ec6-8ddd-2780d413dfa7','userAccess':[]},
{'icon': 'assets/logokt.png', 'name': 'HM Kỹ thuật', 'link': 'https://www.appsheet.com/start/f2040b99-7558-4e2c-9e02-df100c83d8ce','userAccess':[]},
//{'icon': 'assets/goodslogo.png', 'name': 'HM Goods', 'link': 'https://www.appsheet.com/start/a97dcdb4-806c-47ac-9277-714e392b2d1b','userAccess':[]},
{'icon': 'assets/hrlogo.png', 'name': 'HM HR', 'link': 'https://www.appsheet.com/start/adc9a180-6992-4dc3-84ee-9a57cfe70013','userAccess':[]},
//{'icon': 'assets/officitylogo.png', 'name': 'HM Officity', 'link': 'https://www.appsheet.com/start/b52d2de9-e42f-40eb-ba6e-9fb5b15ba287','userAccess':[]},
//{'icon': 'assets/oalogo.png', 'name': 'HM OA', 'link': 'https://www.appsheet.com/start/bbe6a3e9-e704-4fa6-a821-1264bb6e9c11?platform=desktop','userAccess':[]},
//{'icon': 'assets/logo.png', 'name': 'Check lịch', 'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'Zalo Hoàn Mỹ', 'link': 'https://zalo.me/2746464448500686217','userAccess':[]},
{'icon': 'assets/fblogo.png', 'name': 'Facebook Hoàn Mỹ', 'link': 'https://www.facebook.com/Hoanmykleanco','userAccess':[]},
{'icon': 'assets/tiktoklogo.png', 'name': 'Tiktok Hoàn Mỹ', 'link': 'https://www.tiktok.com/@hoanmykleanco','userAccess':[]},
{'icon': 'assets/weblogo.png', 'name': 'Website Hoàn Mỹ', 'link': 'https://hoanmykleanco.com/','userAccess':[]},
{'icon': 'assets/iglogo.png', 'name': 'Instagram Hoàn Mỹ', 'link': 'https://www.instagram.com/hoanmykleanco/','userAccess':[]},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://lookerstudio.google.com/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_gwubweuhjd',
'userAccess': ['NVHM1398','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
  ];
Future<void> _handleUrlOpen(String url, String title) async {
  final Uri uri = Uri.parse(url);
  
  // List of domains that should open in system browser
  final browserDomains = [
    'zalo.me',
    'facebook.com',
    'tiktok.com',
    'instagram.com',
    'hoanmykleanco.com'
  ];

  // Check if it's a Looker Studio URL
  bool isLookerStudio = url.contains('lookerstudio.google.com');
  bool shouldOpenInBrowser = browserDomains.any((domain) => url.contains(domain));

  if (isLookerStudio) {
    // Show a dialog offering download options for Looker Studio
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title - Download Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This dashboard supports data export.'),
            SizedBox(height: 12),
            Text('How would you like to proceed?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('view'),
            child: Text('View Only'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('download'),
            child: Text('Enable Downloads'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (choice == 'download') {
  bool isLoading = true;
  String errorMessage = '';
  
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              // Title bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                height: 50,
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        // Add a refresh button
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = '';
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content area
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(url),
                        headers: {
                          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                          'Accept-Language': 'en-US,en;q=0.5',
                        }
                      ),
                      initialOptions: InAppWebViewGroupOptions(
                        crossPlatform: InAppWebViewOptions(
                          useShouldOverrideUrlLoading: true,
                          useOnDownloadStart: true,
                          javaScriptEnabled: true,
                          clearCache: true,
                          mediaPlaybackRequiresUserGesture: false,
                          userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36",
                          preferredContentMode: UserPreferredContentMode.MOBILE,
                        ),
                      ),
                      onLoadStart: (controller, url) {
                        print("Started loading: $url");
                        setState(() {
                          isLoading = true;
                          errorMessage = '';
                        });
                      },
                      onLoadStop: (controller, url) {
                        print("Finished loading: $url");
                        setState(() {
                          isLoading = false;
                        });
                        
                        // Execute JavaScript to check if the page loaded content
                        controller.evaluateJavascript(source: 
                          "document.body.innerText.length > 0 ? document.body.innerText.substring(0, 100) : 'Empty page'"
                        ).then((result) {
                          print("Page content check: $result");
                        });
                      },
                      onLoadError: (controller, url, code, message) {
                        print("Error loading $url: $code - $message");
                        setState(() {
                          isLoading = false;
                          errorMessage = "Error: $message ($code)";
                        });
                      },
                      onLoadHttpError: (controller, url, statusCode, description) {
                        print("HTTP Error: $url - $statusCode $description");
                        setState(() {
                          isLoading = false;
                          errorMessage = "HTTP Error: $statusCode $description";
                        });
                      },
                      onConsoleMessage: (controller, consoleMessage) {
                        print("Console: ${consoleMessage.message}");
                      },
                      onDownloadStart: (controller, downloadUrl) async {
                        // Your existing download handling code
                      },
                    ),
                    // Show loading indicator only when isLoading is true
                    if (isLoading)
                      Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Loading dashboard...", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )),
                    // Show error message if there is one
                    if (errorMessage.isNotEmpty)
                      Center(child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                            SizedBox(height: 16),
                            Text(errorMessage, style: TextStyle(color: Colors.red)),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isLoading = true;
                                  errorMessage = '';
                                });
                              },
                              child: Text("Try Again"),
                            ),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
} else {
      // "View Only" mode - use desktop_webview_window
      showWebViewDialog(context, url, title);
    }
  } else if (shouldOpenInBrowser) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } else {
    // Use the original desktop_webview_window for other content
    showWebViewDialog(context, url, title);
  }
}
Future<void> showWebViewDialogWithDownloadSupport(BuildContext context, String url, String title) async {
  // Create a dialog with InAppWebView
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Custom title bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              height: 50,
              color: Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // WebView
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(url)),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    useShouldOverrideUrlLoading: true,
                    useOnDownloadStart: true,
                    javaScriptEnabled: true,
                  ),
                ),
                onDownloadStart: (controller, downloadUrl) async {
                  print("Download started: $downloadUrl");
                  
                  // Extract filename from URL or headers
                  String suggestedFilename = path.basename(downloadUrl.toString());
                  
                  // Show download confirmation dialog
                  final shouldDownload = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Download File'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('File: $suggestedFilename'),
                          SizedBox(height: 8),
                          Text('Would you like to download this file?'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Download'),
                        ),
                      ],
                    ),
                  );
                  
                  if (shouldDownload == true) {
                    // Let user choose where to save the file
                    final saveLocation = await FilePicker.platform.saveFile(
                      dialogTitle: 'Save File',
                      fileName: suggestedFilename,
                    );
                    
                    if (saveLocation != null) {
                      try {
                        // Download the file using http
                        final response = await http.get(Uri.parse(downloadUrl.toString()));
                        await File(saveLocation).writeAsBytes(response.bodyBytes);
                        
                        // Show success message
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('File downloaded successfully to: $saveLocation')),
                          );
                        }
                      } catch (e) {
                        print("Download error: $e");
                        // Show error message
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error downloading file: $e')),
                          );
                        }
                      }
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/appbackgrid.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
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
              width: 65.0,
              height: 65.0,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                itemData['name']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18.0,
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