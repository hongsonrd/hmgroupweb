import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' as excel;
import 'dart:convert';
import '../user_state.dart';
import '../main.dart' show MainScreen;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import '../http_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
class SalaryRecord {
  final String period;
  final String category;
  final String amount;
  SalaryRecord(this.period, this.category, this.amount);
}

class IntroScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const IntroScreen({super.key, this.userData});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  String _currentVersion = '';

  final TextEditingController resetUsernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  late InAppWebViewController _webViewController;
  bool isLoading = true;
  final String url = 'https://hongson1.wixstudio.io/demo/groupintro';
  bool _showSalaryHistory = false;
  bool _showAppLogs = false;
  String _logData = '';
  List<SalaryRecord> _salaryRecords = [];
  bool _isLoadingData = false;
  final Set<String> _expandedPeriods = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _getAppVersion();
  }
Future<void> _getAppVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentVersion = packageInfo.version;
      });
    }
  } catch (e) {
    print('Error getting app version: $e');
    _currentVersion = 'unknown';
  }
}
  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final salaryResponse = await http.get(Uri.parse('https://storage.googleapis.com/times1/DocumentApp/staff_data.xlsx'));
      if (salaryResponse.statusCode == 200) {
        final bytes = salaryResponse.bodyBytes;
        final excel.Excel excelFile = excel.Excel.decodeBytes(bytes);
        final sheet = excelFile.tables[excelFile.tables.keys.first];
        if (sheet != null) {
          for (var row = 1; row < sheet.maxRows; row++) {
            final userCode = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value?.toString();
            if (userCode == widget.userData?['username']) {
              final period = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value?.toString() ?? '';
              final category = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value?.toString() ?? '';
              final amount = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value?.toString() ?? '';
              _salaryRecords.add(SalaryRecord(period, category, amount));
            }
          }
        }
      }
      final logResponse = await http.get(Uri.parse('https://storage.googleapis.com/times1/DocumentApp/log_data.txt'));
      if (logResponse.statusCode == 200) {
        _logData = utf8.decode(logResponse.bodyBytes);
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Widget _buildHistoryContent() {
    if (_showAppLogs) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(_logData, style: TextStyle(fontSize: 13)),
        ),
      );
    } else if (_showSalaryHistory) {
      if (_salaryRecords.isEmpty) return const Center(child: Text('Không có thông tin lương'));
      final groupedRecords = <String, List<SalaryRecord>>{};
      for (var record in _salaryRecords) {
        groupedRecords.putIfAbsent(record.period, () => []).add(record);
      }
      return ListView.builder(
        itemCount: groupedRecords.length,
        itemBuilder: (context, index) {
          final period = groupedRecords.keys.elementAt(index);
          final records = groupedRecords[period]!;
          return ExpansionTile(
            title: Text('Kỳ lương: $period'),
            children: records.map((record) => ListTile(
              title: Text(record.category),
              trailing: Text(NumberFormat('#,###').format(double.tryParse(record.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0)),
            )).toList(),
          );
        },
      );
    } else {
      final userState = Provider.of<UserState>(context, listen: false);
      final chamCong = userState.chamCong;
      if (chamCong == null || chamCong.isEmpty) return const Center(child: Text('Không có thông tin chấm công'));
      final chamCongEntries = chamCong.split('\n').where((line) => line.trim().isNotEmpty).toList();
      return ListView.builder(
        itemCount: chamCongEntries.length,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ListTile(title: Text(chamCongEntries[index], style: TextStyle(fontSize: 13))),
          );
        },
      );
    }
  }
@override
Widget build(BuildContext context) {
 return Scaffold(
   body: Column(
     children: [
       Container(
         color: Colors.white,
         padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             if (widget.userData != null) 
               Row(
                 children: [
                   const SizedBox(width: 16),
                   Expanded(
                     child: Row(
                       children: [
                         Text(widget.userData!['name'].toString().toUpperCase(),
                           style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                         const SizedBox(width: 16),
                         Text('Mã NV: ${widget.userData!['employee_id']}',
                           style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 185, 0, 0))),
                       ],
                     ),
                   ),
                   TextButton.icon(
                     onPressed: () async {
                       try {
                         SharedPreferences prefs = await SharedPreferences.getInstance();
                         await prefs.clear();
                         final userState = Provider.of<UserState>(context, listen: false);
                         await userState.clearUser();
                         await prefs.setBool('is_authenticated', false);
                         Navigator.of(context).pushAndRemoveUntil(
                           MaterialPageRoute(builder: (context) => MainScreen()),
                           (route) => false
                         );
                       } catch (e) {
                         print('Reset error: $e');
                         if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                               content: Text('Có lỗi khi đăng xuất'),
                               backgroundColor: Colors.red,
                             ),
                           );
                         }
                       }
                     },
                     icon: const Icon(Icons.logout, size: 20),
                     label: const Text('Đăng xuất', style: TextStyle(fontSize: 16)),
                     style: TextButton.styleFrom(
                       foregroundColor: Colors.red,
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     ),
                   ),
                 ],
               ),
             const SizedBox(height: 4),
             _buildSegmentedButton(),
           ],
         ),
       ),
       Expanded(
  child: Row(
    children: [
      Expanded(
        flex: 6,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Platform.isWindows
                ? Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Company long image (like a screenshot of the website)
                          Image.network(
                            'https://storage.googleapis.com/times1/DocumentApp/appguide.jpg',
                            fit: BoxFit.fitWidth,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 500,
                                color: Colors.grey[200],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        "Không thể tải hình ảnh",
                                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(url)),
                    onLoadStart: (controller, url) => setState(() => isLoading = true),
                    onLoadStop: (controller, url) => setState(() => isLoading = false),
                    onWebViewCreated: (controller) {
                      try {
                        _webViewController = controller;
                        print("WebView controller initialized successfully");
                      } catch (e) {
                        print("Error initializing WebView controller: $e");
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      print("WebView error: ${error.description}");
                    },
                  ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.02,
                color: Colors.white,
              ),
            ),
            if (isLoading && !Platform.isWindows)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
      Expanded(
        flex: 4,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.grey.shade300, width: 1)),
          ),
          child: _isLoadingData ? const Center(child: CircularProgressIndicator()) : _buildHistoryContent(),
        ),
      ),
    ],
  ),
),
     ],
   ),
 );
}

 Widget _buildSegmentedButton() {
  return Row(
    children: [
      SizedBox(
        width: 360, // Fixed width for the segment group
        child: SegmentedButton<String>(
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: MaterialStateProperty.all(EdgeInsets.zero),
          ),
          segments: [
            ButtonSegment(value: 'chamcong', label: Text('Chấm công', style: TextStyle(fontSize: 13))),
            ButtonSegment(value: 'luong', label: Text('Lương', style: TextStyle(fontSize: 13))),
            ButtonSegment(value: 'app', label: Text('App', style: TextStyle(fontSize: 13))),
          ],
          selected: {_showAppLogs ? 'app' : (_showSalaryHistory ? 'luong' : 'chamcong')},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              String selected = newSelection.first;
              _showSalaryHistory = selected == 'luong';
              _showAppLogs = selected == 'app';
            });
          },
        ),
      ),
      const SizedBox(width: 16),
      SizedBox(
        width: 120,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
         ),
         onPressed: () {
           showDialog(
             context: context,
             builder: (context) {
               bool isLoading = false;
               return StatefulBuilder(
                 builder: (context, dialogSetState) {
                   return AlertDialog(
                     title: Text('Đổi mật khẩu'),
                     content: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         TextField(
                           controller: passwordController,
                           decoration: InputDecoration(
                             labelText: 'Mật khẩu mới',
                             border: OutlineInputBorder(),
                           ),
                           obscureText: true,
                         ),
                         if (isLoading)
                           Padding(
                             padding: const EdgeInsets.only(top: 16),
                             child: CircularProgressIndicator(),
                           ),
                       ],
                     ),
                     actions: [
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.stretch,
                         children: [
                           ElevatedButton(
                             onPressed: () async {
                               final newPassword = passwordController.text.trim();
                               if (newPassword.length < 6 || newPassword.length > 16) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text('Mật khẩu phải từ 6-16 ký tự'), backgroundColor: Colors.red)
                                 );
                                 return;
                               }
                               
                               if (!RegExp(r'^[a-zA-Z0-9!@#$%^&*(),.?":{}|<>]+$').hasMatch(newPassword)) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text('Mật khẩu chỉ được chứa chữ, số và ký tự đặc biệt'), backgroundColor: Colors.red)
                                 );
                                 return;
                               }

                               dialogSetState(() => isLoading = true);
                               try {
                                 final response = await AuthenticatedHttpClient.post(
                                   Uri.parse('https://hmclourdrun1-81200125587.asia-southeast1.run.app/matkhaudoi/${widget.userData!['username']}/$newPassword'),
                                 );
                                 
                                 await Future.delayed(Duration(seconds: 3));
                                 
                                 if (response.statusCode == 200) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text('Đổi mật khẩu thành công'), backgroundColor: Colors.green)
                                   );
                                   Navigator.pop(context);
                                 } else {
                                   throw Exception('Failed to change password');
                                 }
                               } catch (e) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text('Có lỗi xảy ra khi đổi mật khẩu'), backgroundColor: Colors.red)
                                 );
                               } finally {
                                 dialogSetState(() => isLoading = false);
                               }
                             },
                             child: Text('Xác nhận', style: TextStyle(fontSize: 16, color: const Color.fromARGB(255, 11, 166, 0))),
                           ),
                           SizedBox(height: 12),
                           TextButton(
                             onPressed: () => Navigator.pop(context),
                             child: Text('Huỷ', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                           ),
                         ],
                       ),
                     ],
                   );
                 },
               );
             },
           );
         },
         child: Text(
           'Đổi mật khẩu',
           style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
           textAlign: TextAlign.center,
         ),
       ),
     ),
const SizedBox(width: 16),
SizedBox(
  width: 120,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color.fromARGB(255, 24, 144, 0),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    ),
    onPressed: () async {
  final url = 'https://storage.googleapis.com/times1/DocumentApp/HMGROUPmac.zip';
  try {
    // Remove platform check to let it work on all platforms
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {  // Check if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link tải đã được copy vào clipboard'), backgroundColor: Colors.green)
      );
    }
  } catch (e) {
    print('Copy link error: $e');  // Log the error for debugging
    if (mounted) {  // Check if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể copy link tải: $e'), backgroundColor: Colors.red)
      );
    }
  }
},
    child: Text(
      'Tải macOS',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
      textAlign: TextAlign.center,
    ),
  ),
),
const SizedBox(width: 8),
SizedBox(
  width: 120,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    ),
    onPressed: () async {
  final url = 'https://storage.googleapis.com/times1/DocumentApp/HMGROUPwin.zip';
  try {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link tải đã được copy vào clipboard'), backgroundColor: Colors.green)
      );
    }
  } catch (e) {
    print('Copy link error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể copy link tải: $e'), backgroundColor: Colors.red)
      );
    }
  }
},
    child: Text(
      'Tải Windows',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
      textAlign: TextAlign.center,
    ),
  ),
),
 const SizedBox(width: 16),
Text('v$_currentVersion', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
   ],
 );
}

@override
void dispose() {
 resetUsernameController.dispose();
 super.dispose();
}
}