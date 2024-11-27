import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' as excel;
import 'dart:convert'; 
import '../main.dart' show UserState, MainScreen;
import 'package:shared_preferences/shared_preferences.dart';

class SalaryRecord {
  final String period;
  final String category;
  final String amount;
  SalaryRecord(this.period, this.category, this.amount);
}

class IntroScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  
  const IntroScreen({
    super.key,
    this.userData,
  });

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  final String url = 'https://hongson1.wixstudio.io/demo/groupintro';
  final String viewID = 'tinhte-web-view';
  bool _showSalaryHistory = false;
  bool _showAppLogs = false;
  String _logData = '';
  List<SalaryRecord> _salaryRecords = [];
  bool _isLoadingData = false;
  final Set<String> _expandedPeriods = {};

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _loadData();
  }
  void _initializeWebView() {
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
              if (mounted) setState(() => isLoading = true);
            },
            onPageFinished: (String url) {
              if (mounted) setState(() => isLoading = false);
            },
            onWebResourceError: (WebResourceError error) {
              print('WebView error: ${error.description}');
            },
          ),
        )
        ..enableZoom(true)
        ..loadRequest(Uri.parse(url));
    }
  }
Future<void> _loadData() async {
  setState(() => _isLoadingData = true);
  
  try {
    // Load salary data
    final salaryResponse = await http.get(
      Uri.parse('https://storage.googleapis.com/times1/DocumentApp/staff_data.xlsx'),
    );
    if (salaryResponse.statusCode == 200) {
      final bytes = salaryResponse.bodyBytes;
      final excel.Excel excelFile = excel.Excel.decodeBytes(bytes);
      final sheet = excelFile.tables[excelFile.tables.keys.first];
      
      if (sheet != null) {
        for (var row = 1; row < sheet.maxRows; row++) {
          final userCode = sheet.cell(excel.CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: row)).value?.toString();
            
          if (userCode == widget.userData?['username']) {
            final period = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: 1, rowIndex: row)).value?.toString() ?? '';
            final category = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: 2, rowIndex: row)).value?.toString() ?? '';
            final amount = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: 3, rowIndex: row)).value?.toString() ?? '';
              
            _salaryRecords.add(SalaryRecord(period, category, amount));
          }
        }
      }
    }

    // Load log data with UTF-8 decoding
    final logResponse = await http.get(
      Uri.parse('https://storage.googleapis.com/times1/DocumentApp/log_data.txt'),
    );
    if (logResponse.statusCode == 200) {
      // Properly decode UTF-8
      _logData = utf8.decode(logResponse.bodyBytes);
    }
  } catch (e) {
    print('Error loading data: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }
}
 Widget _buildHistoryContent() {
  if (_showAppLogs) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          _logData,
          style: TextStyle(fontSize: 13),
        ),
      ),
    );
  } else if (_showSalaryHistory) {
    if (_salaryRecords.isEmpty) {
      return const Center(child: Text('Không có thông tin lương'));
    }
    
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
            trailing: Text(
              NumberFormat('#,###').format(
                double.tryParse(record.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0
              ),
            ),
          )).toList(),
        );
      },
    );
  } else {
    // Chấm công history
    final userState = UserState();
    final chamCong = userState.chamCong;
    
    if (chamCong == null || chamCong.isEmpty) {
      return const Center(child: Text('Không có thông tin chấm công'));
    }
    
    final chamCongEntries = chamCong.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
        
    return ListView.builder(
      itemCount: chamCongEntries.length,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: ListTile(
            title: Text(
              chamCongEntries[index],
              style: TextStyle(fontSize: 13),
            ),
          ),
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
          // Header section with minimal height
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info with logout button
                if (widget.userData != null) 
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              widget.userData!['name'].toString().toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Mã NV: ${widget.userData!['employee_id']}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color.fromARGB(255, 185, 0, 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
  onPressed: () async {
    // Get the UserState instance
    final userState = UserState();
    
    // Clear UserState
    await userState.clearUser();
    
    // Clear SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    await prefs.remove('is_authenticated');
    await prefs.remove('current_user');
    await prefs.remove('login_response');
    await prefs.remove('update_response1');
    await prefs.remove('update_response2');
    await prefs.remove('update_response3');
    await prefs.remove('update_response4');
    await prefs.remove('cham_cong');
    
    // Navigate back to login screen
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainScreen(),
        ),
        (route) => false,
      );
    }
  },
  icon: const Icon(Icons.logout, size: 20),
  label: const Text(
    'Đăng xuất',
    style: TextStyle(fontSize: 16),
  ),
  style: TextButton.styleFrom(
    foregroundColor: Colors.red,
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
  ),
),
                    ],
                  ),
                const SizedBox(height: 4),
                // Segmented button
                _buildSegmentedButton(),
              ],
            ),
          ),
          // Content split view
          Expanded(
            child: Row(
              children: [
                // Left side: Embedded page (60% width)
                Expanded(
                  flex: 6,
                  child: Stack(
                    children: [
                      kIsWeb
                        ? HtmlElementView(viewType: viewID)
                        : WebViewWidget(controller: controller),
                      // Add a white bar over the left side embed
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: MediaQuery.of(context).size.height * 0.03,
                        child: Container(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side: History content (40% width)
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: _isLoadingData
                      ? const Center(child: CircularProgressIndicator())
                      : _buildHistoryContent(),
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
    return SegmentedButton<String>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: MaterialStateProperty.all(EdgeInsets.symmetric(horizontal: 16)),
      ),
      segments: [
        ButtonSegment(
          value: 'chamcong',
          label: Text('Chấm công', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: 'luong',
          label: Text('Lương', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: 'app',
          label: Text('App', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: {_showAppLogs ? 'app' : (_showSalaryHistory ? 'luong' : 'chamcong')},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          String selected = newSelection.first;
          _showSalaryHistory = selected == 'luong';
          _showAppLogs = selected == 'app';
        });
      },
    );
  }
}