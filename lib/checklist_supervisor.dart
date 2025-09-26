//checklist_supervisor.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'checklist_models.dart';
import 'checklist_preview_service.dart';
import 'user_state.dart';
import 'checklist_preview_screen.dart';
import 'checklist_network.dart';
import 'coinstat.dart';

class ChecklistSupervisorScreen extends StatefulWidget {
  const ChecklistSupervisorScreen({Key? key}) : super(key: key);

  @override
  State<ChecklistSupervisorScreen> createState() => _ChecklistSupervisorScreenState();
}

class _ChecklistSupervisorScreenState extends State<ChecklistSupervisorScreen> {
  final UserState userState = UserState();
  final String baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  String get username => (userState.currentUser?['username'] ?? '').toString();
  
  bool _loading = false;
  String _status = '';
  List<ChecklistHistoryItem> _historyItems = [];
  final ChecklistNetworkManager _networkManager = ChecklistNetworkManager();
  int _queueLength = 0;
  
  static const String _historyKey = 'checklist_history_supervisor';
  static const String _lastSyncPrefix = 'checklist_history_sync_';

  @override
  void initState() {
    super.initState();
    _networkManager.initialize(baseUrl);
    _networkManager.startPeriodicSync();
    _updateQueueLength();
    _loadLocalHistory();
  }

  @override
  void dispose() {
    _networkManager.stopPeriodicSync();
    super.dispose();
  }

  Future<void> _updateQueueLength() async {
    final length = await _networkManager.getQueueLength();
    if (mounted) setState(() => _queueLength = length);
  }

  Future<void> _loadLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_historyKey) ?? [];
      
      final items = jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChecklistHistoryItem.fromMap(map);
      }).toList();

      items.sort((a, b) => b.lastSyncTime.compareTo(a.lastSyncTime));

      setState(() {
        _historyItems = items;
      });
    } catch (e) {
      print('Error loading local history: $e');
    }
  }

  Future<void> _saveLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _historyItems.map((item) => json.encode(item.toMap())).toList();
      await prefs.setStringList(_historyKey, jsonList);
    } catch (e) {
      print('Error saving local history: $e');
    }
  }

  Future<void> _scanAndPrepare() async {
    setState(() {
      _loading = true;
      _status = 'Khởi động camera...';
    });
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    setState(() {
      _status = 'Đang mở camera...';
    });
    
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QRScannerScreen(),
        fullscreenDialog: true,
      ),
    );
    
    setState(() {
      _loading = false;
      _status = '';
    });
    
    if (result != null && result.isNotEmpty) {
      await _handleQRScanned(result);
    }
  }

  Future<void> _handleQRScanned(String checklistId) async {
    setState(() {
      _loading = true;
      _status = 'Đang đồng bộ dữ liệu checklist...';
    });

    try {
      await _syncChecklistHistory(checklistId).timeout(Duration(seconds: 20));
      await _showChecklistPreview(checklistId);
    } catch (e) {
      _toast('Không thể đồng bộ dữ liệu: ${e.toString()}', false);
    } finally {
      setState(() {
        _loading = false;
        _status = '';
      });
    }
  }

  Future<void> _syncChecklistHistory(String checklistId) async {
    try {
      final reportsResponse = await http.get(
        Uri.parse('$baseUrl/checklisthistory/$checklistId'),
      );

      if (reportsResponse.statusCode != 200) {
        throw Exception('Failed to get reports: ${reportsResponse.statusCode}');
      }

      final responseData = json.decode(reportsResponse.body) as Map<String, dynamic>;
      
      final reports = responseData['reports'] as List? ?? [];
      final checklistConfig = responseData['checklist'] as Map<String, dynamic>? ?? {};
      final items = responseData['items'] as List? ?? [];

      setState(() {
        _status = 'Đang xử lý dữ liệu...';
      });

      final structuredData = {
        'checklist': checklistConfig,
        'items': items,
        'reports': reports,
      };
      
      final existingIndex = _historyItems.indexWhere((item) => item.checklistId == checklistId);
      final historyItem = ChecklistHistoryItem(
        checklistId: checklistId,
        lastSyncTime: DateTime.now(),
        data: structuredData,
      );

      if (existingIndex >= 0) {
        _historyItems[existingIndex] = historyItem;
      } else {
        _historyItems.insert(0, historyItem);
      }

      if (_historyItems.length > 20) {
        _historyItems = _historyItems.take(20).toList();
      }

      await _saveLocalHistory();
      setState(() {});
      
    } catch (e) {
      print('Error syncing checklist history: $e');
      rethrow;
    }
  }

  Future<void> _showChecklistPreview(String checklistId) async {
    try {
      final historyItem = _historyItems.firstWhere((item) => item.checklistId == checklistId);
      final data = historyItem.data;
      
      final checklistData = data['checklist'] as Map<String, dynamic>? ?? {};
      final itemsData = data['items'] as List? ?? [];
      final reportsData = data['reports'] as List? ?? [];
      
      ChecklistListModel checklist;
      if (checklistData.isNotEmpty) {
        checklist = ChecklistListModel.fromMap(checklistData);
      } else {
        checklist = ChecklistListModel(
          checklistId: checklistId,
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          time: DateFormat('HH:mm').format(DateTime.now()),
          checklistTitle: 'Checklist $checklistId',
          projectName: 'Unknown Project',
          areaName: '',
          floorName: '',
          checklistDateType: 'Single',
          checklistTimeType: 'Out',
          checklistCompletionType: 'Check',
        );
      }
      
      List<ChecklistItemModel> relevantItems = [];
      if (checklistData.isNotEmpty && checklistData['checklistTaskList'] != null) {
        final taskList = checklistData['checklistTaskList'].toString();
        final taskIds = taskList.replaceAll(RegExp(r'\s+'), '')
            .split(RegExp(r'[\/,;|]'))
            .where((e) => e.isNotEmpty)
            .toList();
        
        relevantItems = itemsData
            .map((item) => ChecklistItemModel.fromMap(item as Map<String, dynamic>))
            .where((item) => taskIds.contains(item.itemId))
            .toList();
      } else {
        relevantItems = itemsData
            .map((item) => ChecklistItemModel.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      
      final reports = reportsData
          .map((report) => ChecklistReportModel.fromMap(report as Map<String, dynamic>))
          .toList();

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _ChecklistPreviewScreen(
            checklist: checklist,
            items: relevantItems,
            reports: reports,
            username: username,
            networkManager: _networkManager,
            baseUrl: baseUrl,
          ),
        ),
      );

      if (result == true) {
        await _updateQueueLength();
      }
      
    } catch (e) {
      _toast('Không thể hiển thị preview: ${e.toString()}', false);
    }
  }

  Future<bool> _canManualSync(String checklistId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncKey = '$_lastSyncPrefix$checklistId';
    final lastSync = prefs.getInt(lastSyncKey) ?? 0;
    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final now = DateTime.now();
    
    return now.difference(lastSyncTime).inMinutes >= 10;
  }

  Future<void> _manualSync(String checklistId) async {
    if (!await _canManualSync(checklistId)) {
      _toast('Chỉ có thể đồng bộ sau 10 phút kể từ lần đồng bộ cuối', false);
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Đang đồng bộ thủ công...';
    });

    try {
      await _syncChecklistHistory(checklistId);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_lastSyncPrefix$checklistId', DateTime.now().millisecondsSinceEpoch);
      
      _toast('Đồng bộ thành công', true);
    } catch (e) {
      _toast('Đồng bộ thất bại: ${e.toString()}', false);
    } finally {
      setState(() {
        _loading = false;
        _status = '';
      });
    }
  }

  void _navigateToHistoryItem(ChecklistHistoryItem item) async {
    try {
      final data = item.data;
      final checklistData = data['checklist'] as Map<String, dynamic>? ?? {};
      final itemsData = data['items'] as List? ?? [];
      final reportsData = data['reports'] as List? ?? [];
      
      ChecklistListModel checklist;
      if (checklistData.isNotEmpty) {
        checklist = ChecklistListModel.fromMap(checklistData);
      } else {
        checklist = ChecklistListModel(
          checklistId: item.checklistId,
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          time: DateFormat('HH:mm').format(DateTime.now()),
          checklistTitle: 'Checklist ${item.checklistId}',
          projectName: 'Unknown Project',
        );
      }
      
      List<ChecklistItemModel> relevantItems = [];
      if (checklistData.isNotEmpty && checklistData['checklistTaskList'] != null) {
        final taskList = checklistData['checklistTaskList'].toString();
        final taskIds = taskList.replaceAll(RegExp(r'\s+'), '')
            .split(RegExp(r'[\/,;|]'))
            .where((e) => e.isNotEmpty)
            .toList();
        
        relevantItems = itemsData
            .map((item) => ChecklistItemModel.fromMap(item as Map<String, dynamic>))
            .where((item) => taskIds.contains(item.itemId))
            .toList();
      } else {
        relevantItems = itemsData
            .map((item) => ChecklistItemModel.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      
      final reports = reportsData
          .map((report) => ChecklistReportModel.fromMap(report as Map<String, dynamic>))
          .toList();

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _ChecklistPreviewScreen(
            checklist: checklist,
            items: relevantItems,
            reports: reports,
            username: username,
            networkManager: _networkManager,
            baseUrl: baseUrl,
          ),
        ),
      );

      if (result == true) {
        await _updateQueueLength();
      }
    } catch (e) {
      _toast('Không thể mở checklist: ${e.toString()}', false);
    }
  }

  Widget _buildHistoryCard(ChecklistHistoryItem item, bool isMobile) {
    final checklistData = item.data['checklist'] as Map<String, dynamic>? ?? {};
    final title = checklistData['checklistTitle']?.toString() ?? 'Checklist ${item.checklistId}';
    final projectName = checklistData['projectName']?.toString() ?? '';
    final reportsCount = (item.data['reports'] as List?)?.length ?? 0;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToHistoryItem(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              Container(
                width: isMobile ? 32 : 36,
                height: isMobile ? 32 : 36,
                decoration: BoxDecoration(
                  color: Colors.indigo[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.assignment,
                  color: Colors.indigo[600],
                  size: isMobile ? 20 : 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (projectName.isNotEmpty)
                      Text(
                        projectName,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      'Đồng bộ: ${DateFormat('dd/MM/yyyy HH:mm').format(item.lastSyncTime)} • $reportsCount báo cáo',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder<bool>(
                future: _canManualSync(item.checklistId),
                builder: (context, snapshot) {
                  final canSync = snapshot.data ?? false;
                  return IconButton(
                    onPressed: canSync ? () => _manualSync(item.checklistId) : null,
                    icon: Icon(
                      Icons.sync,
                      color: canSync ? Colors.indigo[600] : Colors.grey[400],
                    ),
                    tooltip: canSync ? 'Đồng bộ thủ công' : 'Chờ 10 phút để đồng bộ',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String m, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? Colors.green : Colors.red)
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Kiểm tra Checklist điện tử', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            if (_queueLength > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_queueLength',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.indigo[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_queueLength > 0)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {
                setState(() => _loading = true);
                await _networkManager.processQueue();
                await _updateQueueLength();
                setState(() => _loading = false);
              },
              tooltip: 'Gửi báo cáo đang chờ',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.indigo[600]!,
                  Colors.indigo[600]!.withOpacity(0.8)
                ]
              )
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _scanAndPrepare,
                    icon: const Icon(Icons.qr_code_scanner, size: 28), 
                    label: const Text('Quét QR Checklist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo[600],
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), 
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                if (_loading && _status.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_status, style: const TextStyle(color: Colors.white))
                ],
                if (_queueLength > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$_queueLength báo cáo đang chờ gửi',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ]
            ),
          ),
          Expanded(
            child: _historyItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có lịch sử checklist',
                          style: TextStyle(fontSize: 16, color: Colors.grey)
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Quét mã QR để bắt đầu',
                          style: TextStyle(fontSize: 14, color: Colors.grey)
                        ),
                      ]
                    )
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _historyItems.length,
                    itemBuilder: (_, i) {
                      final item = _historyItems[i];
                      return _buildHistoryCard(item, isMobile);
                    },
                  ),
          ),
        ]
      ),
    );
  }
}

class _ChecklistPreviewScreen extends StatefulWidget {
  final ChecklistListModel checklist;
  final List<ChecklistItemModel> items;
  final List<ChecklistReportModel> reports;
  final String username;
  final ChecklistNetworkManager networkManager;
  final String baseUrl;

  const _ChecklistPreviewScreen({
    Key? key,
    required this.checklist,
    required this.items,
    required this.reports,
    required this.username,
    required this.networkManager,
    required this.baseUrl,
  }) : super(key: key);

  @override
  State<_ChecklistPreviewScreen> createState() => _ChecklistPreviewScreenState();
}

class _ChecklistPreviewScreenState extends State<_ChecklistPreviewScreen> {
  bool _showPreview = true;

  Future<void> _generatePDF() async {
    await ChecklistPreviewService.generateAndSharePDF(
      checklist: widget.checklist,
      items: widget.items,
      reports: widget.reports,
      username: widget.username,
      selectedStartDate: DateTime.now().subtract(Duration(days: 7)),
      selectedEndDate: DateTime.now(),
      useBlankDate: false,
      context: context,
    );
  }
void _generateExcel() async {
  await ChecklistPreviewService.generateAndShareExcel(
    checklist: widget.checklist,
    items: widget.items,
    reports: widget.reports,
    username: 'Current User', 
    selectedStartDate: DateTime.now().subtract(Duration(days: 7)),
    selectedEndDate: DateTime.now(),
    useBlankDate: false,
    context: context,
  );
}
  void _navigateToReportMode() async {
    try {
      final checklistConfig = {
        'projectName': widget.checklist.projectName,
        'areaName': widget.checklist.areaName ?? '',
        'floorName': widget.checklist.floorName ?? '',
        'checklistNoteEnabled': 'true',
        'checklistTimeType': widget.checklist.checklistTimeType ?? 'Out',
        'checklistTaskList': widget.items.map((item) => item.itemId).join(','),
      };

      final itemsDict = <String, dynamic>{};
      for (final item in widget.items) {
        itemsDict[item.itemId] = {
          'itemId': item.itemId,
          'itemName': item.itemName,
          'itemImage': item.itemImage ?? '',
          'itemIcon': item.itemIcon ?? '',
        };
      }

      final submitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _ChecklistSubmitScreen(
            username: widget.username,
            checklistId: widget.checklist.checklistId,
            checklistConfig: checklistConfig,
            itemsDict: itemsDict,
            networkManager: widget.networkManager,
          ),
        ),
      );

      if (submitted == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Báo cáo đã được gửi thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tạo báo cáo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _togglePreview() {
    setState(() {
      _showPreview = !_showPreview;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.checklist.checklistTitle ?? 'Checklist'}'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _generatePDF,
                        icon: Icon(Icons.picture_as_pdf),
                        label: Text('Tạo PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToReportMode,
                        icon: Icon(Icons.edit_note),
                        label: Text('Báo cáo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _togglePreview,
                    icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
                    label: Text(_showPreview ? 'Ẩn kết quả' : 'Xem kết quả'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showPreview)
            Expanded(
              child: ChecklistPreviewScreen(
                checklist: widget.checklist,
                items: widget.items,
                reports: widget.reports,
                selectedStartDate: DateTime.now().subtract(Duration(days: 7)),
                selectedEndDate: DateTime.now(),
                useBlankDate: false,
                iconMap: const {
                  'Icons.wallpaper': Icons.wallpaper,
                  'Icons.receipt_long': Icons.receipt_long,
                  'Icons.blender': Icons.blender,
                  'Icons.ad_units': Icons.ad_units,
                  'Icons.grid_view': Icons.grid_view,
                  'Icons.miscellaneous_services': Icons.miscellaneous_services,
                  'Icons.plumbing': Icons.plumbing,
                  'Icons.inventory_2': Icons.inventory_2,
                  'Icons.countertops': Icons.countertops,
                  'Icons.dry': Icons.dry,
                  'Icons.soap': Icons.soap,
                  'Icons.roofing': Icons.roofing,
                  'Icons.view_week': Icons.view_week,
                  'Icons.lightbulb': Icons.lightbulb,
                  'Icons.label': Icons.label,
                  'Icons.delete': Icons.delete,
                  'Icons.water_damage': Icons.water_damage,
                  'Icons.filter_alt': Icons.filter_alt,
                  'Icons.water_drop': Icons.water_drop,
                  'Icons.meeting_room': Icons.meeting_room,
                  'Icons.shower': Icons.shower,
                  'Icons.water_drop_outlined': Icons.water_drop_outlined,
                  'Icons.texture': Icons.texture,
                  'Icons.airplay': Icons.airplay,
                  'Icons.handyman': Icons.handyman,
                  'Icons.air': Icons.air,
                  'Icons.blur_on': Icons.blur_on,
                  'Icons.verified': Icons.verified,
                  'Icons.build': Icons.build,
                  'Icons.security': Icons.security,
                  'Icons.description': Icons.description,
                  'Icons.assignment': Icons.assignment,
                  'Icons.check_circle': Icons.check_circle,
                  'Icons.warning': Icons.warning,
                  'Icons.info': Icons.info,
                  'Icons.settings': Icons.settings,
                  'Icons.home': Icons.home,
                  'Icons.work': Icons.work,
                  'Icons.cleaning_services': Icons.cleaning_services,
                  'Icons.electrical_services': Icons.electrical_services,
                  'Icons.schedule': Icons.schedule,
                  'Icons.task_alt': Icons.task_alt,
                  'Icons.checklist': Icons.checklist,
                  'Icons.list_alt': Icons.list_alt,
                  'Icons.fact_check': Icons.fact_check,
                  'Icons.rule': Icons.rule,
                  'Icons.inventory': Icons.inventory,
                  'Icons.construction': Icons.construction,
                  'Icons.engineering': Icons.engineering,
                },
                onGeneratePDF: _generatePDF,
                onGenerateExcel: _generateExcel,
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_off, size: 80, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'Nhấn "Xem kết quả" để xem chi tiết',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${widget.reports.length} báo cáo • ${widget.items.length} hạng mục',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),),
            ),
        ],
      ),
    );
  }
}

class _ChecklistSubmitScreen extends StatefulWidget {
  final String username;
  final String checklistId;
  final Map<String, dynamic> checklistConfig;
  final Map<String, dynamic> itemsDict;
  final ChecklistNetworkManager networkManager;

  const _ChecklistSubmitScreen({
    Key? key,
    required this.username,
    required this.checklistId,
    required this.checklistConfig,
    required this.itemsDict,
    required this.networkManager,
  }) : super(key: key);

  @override
  State<_ChecklistSubmitScreen> createState() => _ChecklistSubmitScreenState();
}

class _ChecklistSubmitScreenState extends State<_ChecklistSubmitScreen> {
  late final String projectName;
  late final String areaName;
  late final String floorName;
  late final bool noteEnabled;
  late final String checklistTimeType;
  late List<String> taskIds;
  late Set<String> selected;
  String reportInOut = 'Out';
  final TextEditingController noteCtrl = TextEditingController();
  XFile? picked;
  bool _submitting = false;
  late final DateTime screenEntryTime;
  bool _soundInitialized = false;
  late VideoPlayerController _soundController;

  @override
  void initState() {
    super.initState();
    screenEntryTime = DateTime.now();
    
    projectName = (widget.checklistConfig['projectName'] ?? '').toString();
    areaName = (widget.checklistConfig['areaName'] ?? '').toString();
    floorName = (widget.checklistConfig['floorName'] ?? '').toString();
    
    final noteFlag = (widget.checklistConfig['checklistNoteEnabled'] ?? '').toString().toLowerCase();
    noteEnabled = noteFlag == 'true' || noteFlag == '1';
    
    checklistTimeType = (widget.checklistConfig['checklistTimeType'] ?? 'Out').toString();
    
    final tl = (widget.checklistConfig['checklistTaskList'] ?? '').toString();
    taskIds = tl.replaceAll(RegExp(r'\s+'), '').split(RegExp(r'[\/,;|]')).where((e) => e.isNotEmpty).toList();
    
    if (_reportType() == 'staff') {
      selected = {...taskIds};
    } else {
      selected = {};
    }
    
    if (checklistTimeType == 'In') {
      reportInOut = 'In';
    } else if (checklistTimeType == 'Out') {
      reportInOut = 'Out';
    }

    _soundController = VideoPlayerController.asset('assets/alt/success.mp3')
      ..setVolume(0.6)
      ..initialize().then((_) {
        setState(() {
          _soundInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _soundController.dispose();
    super.dispose();
  }

  String _reportType() {
    final u = widget.username.toLowerCase();
    if (u.startsWith('hm.') || u.startsWith('bp')) return 'sup';
    if (u.startsWith('kh.') ) return 'customer';
    if (u.startsWith('tv') || u.startsWith('tvn') || u.startsWith('hm')) return 'staff';
    return 'sup';
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) setState(() => picked = x);
  }

  Widget _tileFor(String id) {
    final item = widget.itemsDict[id] as Map<String, dynamic>?;
    final img = item?['itemImage']?.toString();
    final ico = item?['itemIcon']?.toString();
    final selectedNow = selected.contains(id);
    
    return GestureDetector(
      onTap: () => setState(() => selectedNow ? selected.remove(id) : selected.add(id)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selectedNow ? Colors.green.withOpacity(.08) : Colors.white,
          border: Border.all(color: selectedNow ? Colors.green : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (img != null && img.isNotEmpty)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/checklist/$img',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(_iconFromString(ico), size: 28, color: Colors.green),
                ),
              ),
            )
          else
            Icon(_iconFromString(ico), size: 28, color: Colors.green),
          const SizedBox(height: 6),
          Text(
            (item?['itemName'] ?? '').toString(), 
            maxLines: 2, 
            overflow: TextOverflow.ellipsis, 
            textAlign: TextAlign.center, 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)
          ),
          const SizedBox(height: 2),
          Icon(
            selectedNow ? Icons.check_circle : Icons.radio_button_unchecked, 
            size: 16, 
            color: selectedNow ? Colors.green : Colors.grey
          ),
        ]),
      ),
    );
  }

  IconData _iconFromString(String? key) {
    const m = {
      'Icons.wallpaper': Icons.wallpaper,
      'Icons.receipt_long': Icons.receipt_long,
      'Icons.blender': Icons.blender,
      'Icons.ad_units': Icons.ad_units,
      'Icons.grid_view': Icons.grid_view,
      'Icons.miscellaneous_services': Icons.miscellaneous_services,
      'Icons.plumbing': Icons.plumbing,
      'Icons.inventory_2': Icons.inventory_2,
      'Icons.countertops': Icons.countertops,
      'Icons.dry': Icons.dry,
      'Icons.soap': Icons.soap,
      'Icons.roofing': Icons.roofing,
      'Icons.view_week': Icons.view_week,
      'Icons.lightbulb': Icons.lightbulb,
      'Icons.label': Icons.label,
      'Icons.delete': Icons.delete,
      'Icons.water_damage': Icons.water_damage,
      'Icons.filter_alt': Icons.filter_alt,
      'Icons.water_drop': Icons.water_drop,
      'Icons.meeting_room': Icons.meeting_room,
      'Icons.shower': Icons.shower,
      'Icons.water_drop_outlined': Icons.water_drop_outlined,
      'Icons.texture': Icons.texture,
      'Icons.airplay': Icons.airplay,
      'Icons.handyman': Icons.handyman,
      'Icons.air': Icons.air,
      'Icons.blur_on': Icons.blur_on,
      'Icons.verified': Icons.verified,
      'Icons.build': Icons.build,
      'Icons.security': Icons.security,
      'Icons.description': Icons.description,
      'Icons.assignment': Icons.assignment,
      'Icons.check_circle': Icons.check_circle,
      'Icons.warning': Icons.warning,
      'Icons.info': Icons.info,
      'Icons.settings': Icons.settings,
      'Icons.home': Icons.home,
      'Icons.work': Icons.work,
      'Icons.cleaning_services': Icons.cleaning_services,
      'Icons.electrical_services': Icons.electrical_services,
      'Icons.schedule': Icons.schedule,
      'Icons.task_alt': Icons.task_alt,
      'Icons.checklist': Icons.checklist,
      'Icons.list_alt': Icons.list_alt,
      'Icons.fact_check': Icons.fact_check,
      'Icons.rule': Icons.rule,
      'Icons.inventory': Icons.inventory,
      'Icons.construction': Icons.construction,
      'Icons.engineering': Icons.engineering,
    };
    return m[key] ?? Icons.check_box_outlined;
  }

  Future<void> _submitSingleReport(String inOut, DateTime submitTime) async {
    await widget.networkManager.queueChecklistReport(
      checklistId: widget.checklistId,
      projectName: projectName,
      reportType: _reportType(),
      reportInOut: inOut,
      taskIds: selected,
      note: noteEnabled ? noteCtrl.text.trim() : '',
      image: picked,
      userId: widget.username,
      customTimestamp: submitTime,
    );
  }

  Future<void> _saveLocalSubmission(String inOut, DateTime submitTime) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('checklist_submissions') ?? [];
    final rec = {
      'ts': submitTime.millisecondsSinceEpoch,
      'projectName': projectName,
      'areaName': areaName,
      'floorName': floorName,
      'inOut': inOut,
      'reportType': _reportType(),
      'count': selected.length,
      'note': noteEnabled ? noteCtrl.text.trim() : '',
      'checklistId': widget.checklistId,
      'tasks': selected.toList(),
      'localImagePath': picked?.path,
    };
    list.insert(0, json.encode(rec));
    if (list.length > 100) list.removeRange(100, list.length);
    await p.setStringList('checklist_submissions', list);
  }

  Future<void> _submit() async {
    if (checklistTimeType != 'InOut' && selected.isEmpty && _reportType() == 'staff') {
      _snack('Chọn ít nhất một hạng mục', false);
      return;
    }
    
    setState(() => _submitting = true);
    
    try {
      if (checklistTimeType == 'InOut') {
        await _submitSingleReport('In', screenEntryTime);
        await _saveLocalSubmission('In', screenEntryTime);
        
        final submitTime = DateTime.now();
        await _submitSingleReport('Out', submitTime);
        await _saveLocalSubmission('Out', submitTime);
        
        _snack('Đã gửi báo cáo (Vào & Ra)', true);
      } else {
        final submitTime = DateTime.now();
        await _submitSingleReport(reportInOut, submitTime);
        await _saveLocalSubmission(reportInOut, submitTime);
        
        _snack('Đã gửi báo cáo', true);
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Lỗi gửi: $e', false);
    } finally {
      _playSuccessSound();
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _playSuccessSound() {
    if (_soundInitialized) {
      _soundController.seekTo(Duration.zero);
      _soundController.play();
      _playVibrationPattern();
      final username = widget.username.toLowerCase();
      print('📢 playSuccessSound: Triggering coin gain for user: $username');
      try {
        triggerCoinGain(username, context).then((result) {
          print('📢 playSuccessSound: Coin gain result: $result');
          if (result == null) {
            print('❌ playSuccessSound: No response from triggerCoinGain');
          }
        });
      } catch (e) {
        print('❌ playSuccessSound: Error triggering coin gain: $e');
      }
    }
  }

  Future<void> _playVibrationPattern() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
        pattern: [
          0, 100, 50, 100,
          50, 100, 50, 150,
          50, 100, 50, 200,
          50, 250, 
        ],
        intensities: [
          0, 200, 0, 200,
          0, 200, 0, 220,
          0, 220, 0, 230,
          0, 255
        ],
      );
    }
  }

  void _snack(String m, bool ok) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: ok ? Colors.green : Colors.red));

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cross = w < 420 ? 3 : w < 640 ? 4 : w < 900 ? 5 : 6;
    final isStaff = _reportType() == 'staff';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gửi báo cáo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green, 
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ElevatedButton.icon(
              onPressed: _pickImage, 
              icon: const Icon(Icons.photo_camera), 
              label: const Text('Chụp ảnh (tuỳ chọn)'), 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                foregroundColor: Colors.white
              )
            ),
            const SizedBox(width: 12),
            if (picked != null) Expanded(child: Text(picked!.name, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: Colors.green.withOpacity(0.2))
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _row('Dự án', projectName),
              if (areaName.isNotEmpty) ...[const SizedBox(height: 6), _row('Khu vực', areaName)],
              if (floorName.isNotEmpty) ...[const SizedBox(height: 6), _row('Tầng', floorName)],
              const SizedBox(height: 6),
              _row('Loại báo cáo', _reportType() == 'sup' ? 'Giám sát' : 'Nhân viên'),
              const SizedBox(height: 8),
              if (checklistTimeType != 'InOut') 
                Row(children: [
                  const Text('Giờ: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (checklistTimeType == 'In')
                    Chip(label: const Text('Báo vào'), backgroundColor: Colors.green.withOpacity(0.1))
                  else if (checklistTimeType == 'Out')
                    Chip(label: const Text('Báo ra'), backgroundColor: Colors.orange.withOpacity(0.1))
                  else ...[
                    ChoiceChip(
                      label: const Text('Báo vào'), 
                      selected: reportInOut == 'In', 
                      onSelected: (_) => setState(() => reportInOut = 'In'),
                      selectedColor: Colors.green.withOpacity(0.2),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Báo ra'), 
                      selected: reportInOut == 'Out', 
                      onSelected: (_) => setState(() => reportInOut = 'Out'),
                      selectedColor: Colors.green.withOpacity(0.2),
                    ),
                  ],
                ])
              else
                Row(children: [
                  const Text('Loại báo cáo: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('Báo vào & Báo ra'),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  ),
                ]),
            ]),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chọn hạng mục', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
                label: Text(_submitting ? 'Đang gửi...' : 'Gửi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isStaff)
            const Text(
              'Chỉ chọn các hạng mục không đạt, mặc định không chọn là đạt',
              style: TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: taskIds.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: .95),
            itemBuilder: (_, i) => _tileFor(taskIds[i]),
          ),
          const SizedBox(height: 16),
          if (noteEnabled) ...[
            const Text('Ghi chú', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nhập ghi chú...')),
          ],
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Row(children: [SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(v))]);
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);
  
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  bool _hasScanned = false;
  MobileScannerController? _controller;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFlashOn = false;
  String _scanStatus = 'Đặt mã QR vào trong khung để quét';

  @override
  void initState() {
    super.initState();
    
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      returnImage: false,
      torchEnabled: false,
    );
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final value = barcodes.first.rawValue ?? '';
      if (value.isNotEmpty) {
        _hasScanned = true;
        
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 100);
        }
        
        setState(() {
          _scanStatus = 'Đã quét thành công!';
        });
        
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          Navigator.pop(context, value);
        }
      }
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _controller?.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowSize = size.width * 0.7;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            scanWindow: Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: scanWindowSize,
              height: scanWindowSize,
            ),
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lỗi camera: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              );
            },
          ),
          
          CustomPaint(
            painter: ScannerOverlayPainter(
              scanAreaSize: scanWindowSize,
              screenSize: size,
            ),
            child: Container(),
          ),
          
          Positioned(
            left: (size.width - scanWindowSize) / 2,
            top: size.height / 2 - scanWindowSize / 2,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: scanWindowSize,
                  height: 2,
                  margin: EdgeInsets.only(top: _animation.value * scanWindowSize),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.indigo,
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Quét mã QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleFlash,
                  ),
                ],
              ),
            ),
          ),
          
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    _scanStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.indigo.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Quét mã QR Checklist',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
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
}

class ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final Size screenSize;
  
  ScannerOverlayPainter({
    required this.scanAreaSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanAreaRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, screenSize.width, screenSize.height))
      ..addRRect(RRect.fromRectAndRadius(
        scanAreaRect,
        const Radius.circular(12),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    final cornerPaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 20.0;
    final corners = [
      [
        Offset(scanAreaRect.left, scanAreaRect.top + cornerLength),
        Offset(scanAreaRect.left, scanAreaRect.top),
        Offset(scanAreaRect.left + cornerLength, scanAreaRect.top),
      ],
      [
        Offset(scanAreaRect.right - cornerLength, scanAreaRect.top),
        Offset(scanAreaRect.right, scanAreaRect.top),
        Offset(scanAreaRect.right, scanAreaRect.top + cornerLength),
      ],
      [
        Offset(scanAreaRect.left, scanAreaRect.bottom - cornerLength),
        Offset(scanAreaRect.left, scanAreaRect.bottom),
        Offset(scanAreaRect.left + cornerLength, scanAreaRect.bottom),
      ],
      [
        Offset(scanAreaRect.right - cornerLength, scanAreaRect.bottom),
        Offset(scanAreaRect.right, scanAreaRect.bottom),
        Offset(scanAreaRect.right, scanAreaRect.bottom - cornerLength),
      ],
    ];

    for (final corner in corners) {
      final path = Path()
        ..moveTo(corner[0].dx, corner[0].dy)
        ..lineTo(corner[1].dx, corner[1].dy)
        ..lineTo(corner[2].dx, corner[2].dy);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ChecklistHistoryItem {
  final String checklistId;
  final DateTime lastSyncTime;
  final Map<String, dynamic> data;

  ChecklistHistoryItem({
    required this.checklistId,
    required this.lastSyncTime,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'checklistId': checklistId,
      'lastSyncTime': lastSyncTime.millisecondsSinceEpoch,
      'data': data,
    };
  }

  factory ChecklistHistoryItem.fromMap(Map<String, dynamic> map) {
    return ChecklistHistoryItem(
      checklistId: map['checklistId'] ?? '',
      lastSyncTime: DateTime.fromMillisecondsSinceEpoch(map['lastSyncTime'] ?? 0),
      data: Map<String, dynamic>.from(map['data'] ?? {}),
    );
  }
}