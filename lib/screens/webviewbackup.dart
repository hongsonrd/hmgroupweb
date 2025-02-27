import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../user_state.dart';
import '../main.dart' show MainScreen;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
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
//{'icon': 'assets/zalologo.png', 'name': 'OA Thành', 'link': 'https://zalo.me/g/bawdga557','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA Nguyễn Huyền', 'link': 'https://zalo.me/g/ewolpl197','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA Lợi', 'link': 'https://zalo.me/g/wwcgsg503','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA Bùi Huyền', 'link': 'https://zalo.me/g/iqwwbf431','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA Thanh', 'link': 'https://zalo.me/g/dfhdid376','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA Hạnh', 'link': 'https://zalo.me/g/xhblsr399','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA Hùng', 'link': 'https://zalo.me/g/pzexka072','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA Miền Trung', 'link': 'https://zalo.me/g/nvrkqe767','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA Miền Nam', 'link': 'https://zalo.me/g/nvrkqe767','userAccess':[]},
//{'icon': 'assets/zalologo.png', 'name': 'OA QLDV', 'link': 'https://zalo.me/g/xbcalx122','userAccess':[]},
{'icon': 'assets/logokt.png', 'name': 'HM Kỹ thuật', 'link': 'https://www.appsheet.com/start/f2040b99-7558-4e2c-9e02-df100c83d8ce','userAccess':[]},
{'icon': 'assets/goodslogo.png', 'name': 'HM Goods', 'link': 'https://www.appsheet.com/start/a97dcdb4-806c-47ac-9277-714e392b2d1b','userAccess':[]},
{'icon': 'assets/hrlogo.png', 'name': 'HM HR', 'link': 'https://www.appsheet.com/start/adc9a180-6992-4dc3-84ee-9a57cfe70013','userAccess':[]},
{'icon': 'assets/officitylogo.png', 'name': 'HM Officity', 'link': 'https://www.appsheet.com/start/b52d2de9-e42f-40eb-ba6e-9fb5b15ba287','userAccess':[]},
{'icon': 'assets/oalogo.png', 'name': 'HM OA', 'link': 'https://www.appsheet.com/start/bbe6a3e9-e704-4fa6-a821-1264bb6e9c11?platform=desktop','userAccess':[]},
//{'icon': 'assets/logo.png', 'name': 'Check lịch', 'link': 'https://www.appsheet.com/start/022337dd-807d-49c7-a1d7-19967617e2c3','userAccess':[]},
{'icon': 'assets/zalologo.png', 'name': 'Zalo Hoàn Mỹ', 'link': 'https://zalo.me/2746464448500686217','userAccess':[]},
{'icon': 'assets/fblogo.png', 'name': 'Facebook Hoàn Mỹ', 'link': 'https://www.facebook.com/Hoanmykleanco','userAccess':[]},
{'icon': 'assets/tiktoklogo.png', 'name': 'Tiktok Hoàn Mỹ', 'link': 'https://www.tiktok.com/@hoanmykleanco','userAccess':[]},
{'icon': 'assets/weblogo.png', 'name': 'Website Hoàn Mỹ', 'link': 'https://hoanmykleanco.com/','userAccess':[]},
{'icon': 'assets/iglogo.png', 'name': 'Instagram Hoàn Mỹ', 'link': 'https://www.instagram.com/hoanmykleanco/','userAccess':[]},
{
'icon': 'assets/dblogo.png',
'name': 'TEST',
'link': 'https://yourworldtravel.vn/api/index3.html',
'userAccess': ['NVHM1398','NVHMXXXX']
},
{
'icon': 'assets/dblogo.png',
'name': 'Giờ GS đi làm',
'link': 'https://lookerstudio.google.com/embed/reporting/9ce42364-9d3a-44ac-911f-444e54c246d2/page/p_imdskw8hjd',
'userAccess': ['NVHM1398','NVHMXXXX']
},
{
'icon': 'assets/zalologo.png',
'name': 'Ảnh OA liên tục',
'link': 'https://yourworldtravel.vn/index.html',
'userAccess': ['NVHM1398','NVHM0004','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
},
{
'icon': 'assets/dblogo.png',
'name': 'Dòng thời gian các việc đã báo cáo',
'link': 'https://yourworldtravel.vn/index2.html',
'userAccess': ['NVHM1398','NVHM0056','NVHM1679','NVHM1689','NVHM0837','NVHM1683','NVHM0837']
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

  bool shouldOpenInBrowser = browserDomains.any((domain) => url.contains(domain));

  if (shouldOpenInBrowser) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } else {
    openDesktopWebView(context, url, title);
  }
}
Future<void> openDesktopWebView(BuildContext context, String url, String title) async {
  if (await WebviewWindow.isWebviewAvailable()) {
    try {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: title,
          windowWidth: 1200,
          windowHeight: 800,
        ),
      );

      // Create a temporary directory for downloads if it doesn't exist
      final downloadsDir = await getApplicationDocumentsDirectory();
      final tempDownloadsPath = '${downloadsDir.path}/temp_downloads';
      
      // Create the directory if it doesn't exist
      final dir = Directory(tempDownloadsPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Configure a download handler script
      webview.addScriptToExecuteOnDocumentCreated('''
        // Function to generate a random filename with extension
        function generateFilename(extension) {
          const timestamp = new Date().getTime();
          const random = Math.floor(Math.random() * 10000);
          return 'download_' + timestamp + '_' + random + '.' + (extension || 'bin');
        }

        // Intercept clicks on download links
        document.addEventListener('click', function(e) {
          const link = e.target.closest('a[href][download]');
          if (link) {
            e.preventDefault();
            console.log('Download link clicked: ' + link.href);
            
            const url = link.href;
            const filename = link.getAttribute('download') || link.download || generateFilename();
            
            // Use browser's native download capability
            const downloadLink = document.createElement('a');
            downloadLink.href = url;
            downloadLink.download = filename;
            downloadLink.style.display = 'none';
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);
          }
        });

        // Special handler for Google's export buttons
        setInterval(() => {
          // For Google Looker Studio "Export" buttons
          document.querySelectorAll('button[aria-label="Export"]').forEach(button => {
            if (!button.__download_handler_added) {
              button.__download_handler_added = true;
              button.addEventListener('click', function() {
                console.log('Export button clicked');
                // Wait for the menu to appear
                setTimeout(() => {
                  // Click on the download options
                  document.querySelectorAll('span[aria-label*="Excel"], span[aria-label*="CSV"]').forEach(item => {
                    console.log('Found export option: ' + item.textContent);
                    item.click();
                  });
                }, 500);
              });
            }
          });
        }, 2000);

        // Debug output
        console.log('Download handlers initialized');
      ''');

      // Launch the URL
      webview.launch(url);
      
      return;
    } catch (e) {
      print("Error creating webview: $e");
      // Fall back to dialog approach if window creation fails
    }
  }
  
  // Fallback approach using InAppWebView in a dialog
  if (context.mounted) {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Container(
          width: 800,
          height: 600,
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
              // Handle downloads here
              final suggestedFilename = path.basename(downloadUrl.toString());
              
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error downloading file: $e')),
                    );
                  }
                }
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
void showWebViewDialog(BuildContext context, String url, String title) async {
  if (await WebviewWindow.isWebviewAvailable()) {
    try {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: title,
          windowWidth: 1200,
          windowHeight: 800,
        ),
      );
      
      // Script specifically targeting Looker Studio's export dialog
      webview.addScriptToExecuteOnDocumentCreated('''
        // Global flag to track when export is in progress
        window.exportInProgress = false;
        
        // Function to monitor for downloads
        function monitorForExport() {
          console.log('Monitoring for Looker Studio export');
          
          // Monitor clicks on the "Export" button (Xuất)
          document.addEventListener('click', function(e) {
            // Look for the export button in the dialog
            if (e.target && (
                e.target.textContent === 'Xuất' || 
                e.target.textContent === 'Export' ||
                (e.target.closest('button') && 
                 (e.target.closest('button').textContent === 'Xuất' || 
                  e.target.closest('button').textContent === 'Export'))
               )) {
              console.log('Export button clicked in dialog');
              window.exportInProgress = true;
              
              // Reset the flag after some time if download doesn't start
              setTimeout(function() {
                window.exportInProgress = false;
              }, 10000);
            }
          }, true);
          
          // Monitor for XHR requests that might be downloads
          const originalXHR = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function() {
            // Add a load event listener
            this.addEventListener('load', function() {
              if (window.exportInProgress) {
                const contentType = this.getResponseHeader('Content-Type');
                const contentDisposition = this.getResponseHeader('Content-Disposition');
                
                // Check if this response looks like a file download
                if (contentType && (
                    contentType.includes('csv') ||
                    contentType.includes('excel') ||
                    contentType.includes('spreadsheet') ||
                    contentType.includes('octet-stream')
                  )) {
                  console.log('Detected file download from XHR:', contentType);
                  
                  // Get filename from content disposition
                  let filename = 'looker_export.csv';
                  if (contentDisposition) {
                    const match = contentDisposition.match(/filename=["']?([^'"]+)["']?/);
                    if (match) filename = match[1];
                  }
                  
                  // Create a blob from the response
                  const blob = new Blob([this.response], {type: contentType});
                  const blobUrl = URL.createObjectURL(blob);
                  
                  // Create a download link
                  const a = document.createElement('a');
                  a.href = blobUrl;
                  a.download = filename;
                  a.style.display = 'none';
                  a.target = '_blank'; // Try to force it to open in a new window
                  
                  // Add to DOM and click
                  document.body.appendChild(a);
                  a.click();
                  document.body.removeChild(a);
                  
                  // Reset export flag
                  window.exportInProgress = false;
                  
                  // Show notification
                  showNotification('File exported: ' + filename);
                }
              }
            });
            
            // Call the original open method
            originalXHR.apply(this, arguments);
          };
          
          // Monitor for fetch requests
          const originalFetch = window.fetch;
          window.fetch = function() {
            const fetchCall = originalFetch.apply(this, arguments);
            
            if (window.exportInProgress) {
              fetchCall.then(response => {
                // Clone the response to examine it
                const clone = response.clone();
                const contentType = clone.headers.get('Content-Type');
                
                if (contentType && (
                    contentType.includes('csv') ||
                    contentType.includes('excel') ||
                    contentType.includes('spreadsheet') ||
                    contentType.includes('octet-stream')
                  )) {
                  console.log('Detected file download from fetch:', contentType);
                  
                  // Get filename
                  let filename = 'looker_export.csv';
                  const contentDisposition = clone.headers.get('Content-Disposition');
                  if (contentDisposition) {
                    const match = contentDisposition.match(/filename=["']?([^'"]+)["']?/);
                    if (match) filename = match[1];
                  }
                  
                  // Process blob
                  clone.blob().then(blob => {
                    const blobUrl = URL.createObjectURL(blob);
                    
                    // Create download link
                    const a = document.createElement('a');
                    a.href = blobUrl;
                    a.download = filename;
                    a.style.display = 'none';
                    a.target = '_blank'; // Try to force it to open in a new window
                    
                    // Add to DOM and click
                    document.body.appendChild(a);
                    a.click();
                    document.body.removeChild(a);
                    
                    // Reset export flag
                    window.exportInProgress = false;
                    
                    // Show notification
                    showNotification('File exported: ' + filename);
                  });
                }
              }).catch(err => {
                console.error('Error in fetch interceptor:', err);
              });
            }
            
            return fetchCall;
          };
          
          // Also monitor for right-clicks specifically on tables
          document.addEventListener('contextmenu', function(e) {
            const table = e.target.closest('table') || 
                          e.target.closest('[role="table"]') || 
                          e.target.closest('.goog-control-table');
            
            if (table) {
              console.log('Right-click detected on table');
              
              // Wait for context menu to appear
              setTimeout(function() {
                // Look for export option in context menu
                const menuItems = document.querySelectorAll('.goog-menuitem, [role="menuitem"]');
                menuItems.forEach(item => {
                  if (item.textContent.includes('Xuất') || item.textContent.includes('Export')) {
                    console.log('Found export option in context menu');
                    
                    // Monitor this item for clicks
                    item.addEventListener('click', function() {
                      console.log('Export option clicked from context menu');
                      
                      // Wait for export dialog to appear
                      setTimeout(function() {
                        console.log('Looking for export dialog buttons');
                        // Look for the export button in the dialog
                        document.querySelectorAll('button').forEach(button => {
                          if (button.textContent === 'Xuất' || button.textContent === 'Export') {
                            console.log('Found export button in dialog');
                            
                            // Set up monitoring for the export button click
                            button.addEventListener('click', function() {
                              console.log('Export button clicked in dialog');
                              window.exportInProgress = true;
                              
                              // Reset the flag after some time if download doesn't start
                              setTimeout(function() {
                                window.exportInProgress = false;
                              }, 10000);
                            });
                          }
                        });
                      }, 500);
                    });
                  }
                });
              }, 300);
            }
          });
        }
        
        // Function to show a notification
        function showNotification(message) {
          const notification = document.createElement('div');
          notification.textContent = message;
          notification.style.position = 'fixed';
          notification.style.bottom = '20px';
          notification.style.left = '50%';
          notification.style.transform = 'translateX(-50%)';
          notification.style.backgroundColor = '#333';
          notification.style.color = 'white';
          notification.style.padding = '10px 20px';
          notification.style.borderRadius = '5px';
          notification.style.zIndex = '10000';
          notification.style.opacity = '0';
          notification.style.transition = 'opacity 0.3s ease';
          
          document.body.appendChild(notification);
          
          // Fade in
          setTimeout(() => {
            notification.style.opacity = '1';
          }, 10);
          
          // Fade out after 3 seconds
          setTimeout(() => {
            notification.style.opacity = '0';
            // Remove after fade out
            setTimeout(() => {
              document.body.removeChild(notification);
            }, 300);
          }, 3000);
        }
        
        // Set up monitoring when the page loads
        window.addEventListener('load', monitorForExport);
        
        // Also run it immediately in case the page is already loaded
        monitorForExport();
        
        console.log('Looker Studio export monitor initialized');
      ''');
      
      webview.launch(url);
    } catch (e) {
      print("Error creating webview window: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
        );
      }
    }
  } else {
    if (context.mounted) {
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
}
// Helper method to handle file saving
Future<void> _saveDownloadedFile(
  BuildContext context, 
  Uint8List? bytes, 
  String suggestedFilename,
  [String? url]
) async {
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
        if (bytes != null) {
          // Save the provided bytes directly
          await File(saveLocation).writeAsBytes(bytes);
        } else if (url != null) {
          // Download from URL
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            await File(saveLocation).writeAsBytes(response.bodyBytes);
          } else {
            throw Exception('Failed to download: HTTP ${response.statusCode}');
          }
        } else {
          throw Exception('No data to save');
        }
        
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
              image: AssetImage('assets/appbackgrid.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
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

class ResizableDialog extends StatefulWidget {
  final double initialWidth;
  final double initialHeight;
  final String title;
  final Widget content;

  const ResizableDialog({
    Key? key,
    required this.initialWidth,
    required this.initialHeight,
    required this.title,
    required this.content,
  }) : super(key: key);

  @override
  _ResizableDialogState createState() => _ResizableDialogState();
}

class _ResizableDialogState extends State<ResizableDialog> {
  late double width;
  late double height;
  Offset? position; // Make this nullable
  bool isDragging = false;

  @override
  void initState() {
    super.initState();
    width = widget.initialWidth;
    height = widget.initialHeight;
    // Don't set position here - we'll do it in build
  }

  @override
  Widget build(BuildContext context) {
    // Initialize position here if it's not set yet
    position ??= Offset(
      (MediaQuery.of(context).size.width - width) / 2,
      (MediaQuery.of(context).size.height - height) / 2,
    );

    return Stack(
      children: [
        // Semi-transparent barrier
        GestureDetector(
          onTap: () {}, // Intercept taps to prevent dismissal
          child: Container(color: Colors.black54),
        ),
        
        // Draggable window
        Positioned(
          left: position!.dx,
          top: position!.dy,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                isDragging = true;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                position = Offset(
                  position!.dx + details.delta.dx,
                  position!.dy + details.delta.dy,
                );
              });
            },
            onPanEnd: (details) {
              setState(() {
                isDragging = false;
              });
            },
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Custom title bar
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content area
                  Expanded(child: widget.content),
                  
                  // Resize handle
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        width = max(400, width + details.delta.dx);
                        height = max(300, height + details.delta.dy);
                      });
                    },
                    child: Container(
                      height: 20,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.drag_handle, size: 20, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}