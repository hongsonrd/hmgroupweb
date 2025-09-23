//checklist_list.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'checklist_models.dart';
import 'checklist_preview_service.dart';

class ChecklistListScreen extends StatefulWidget {
  final String username;
  const ChecklistListScreen({Key? key, required this.username}) : super(key: key);
  @override
  _ChecklistListScreenState createState() => _ChecklistListScreenState();
}

class _ChecklistListScreenState extends State<ChecklistListScreen> {
  bool _isLoading = false;
  String _syncStatus = '';
  List<ChecklistListModel> _checklists = [];
  List<ChecklistListModel> _filteredChecklists = [];
  List<ChecklistItemModel> _items = [];
  List<ChecklistReportModel> _reports = [];
  final TextEditingController _searchController = TextEditingController();
  final baseUrl = 'https://hmclourdrun1-81200125587.asia-southeast1.run.app';
  static const String _listsKey = 'checklist_lists_v1';
  static const String _itemsKey = 'checklist_items_v1';
  static const String _reportsKey = 'checklist_reports_v1';
  static const String _lastSyncKey = 'checklist_lists_last_sync';
  String? _selectedProject;
  List<String> _projectOptions = [];
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _useBlankDate = false;

  static const Map<String, IconData> _iconMap = {
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

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_filterChecklists);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _checkAndSyncData();
    _extractProjects();
  }

  Future<void> _checkAndSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final today = DateTime.now();
    final isNewDay = lastSync == 0 || lastSyncDate.day != today.day || lastSyncDate.month != today.month || lastSyncDate.year != today.year;
    if (isNewDay) {
      await _syncAllData();
    } else {
      await _loadLocalData();
    }
  }

  Future<void> _syncAllData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang đồng bộ dữ liệu checklist...';
    });
    try {
      await Future.wait([_syncChecklists(), _syncItems(), _syncReports()]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      _showSuccess('Đồng bộ thành công - ${_checklists.length} checklists');
    } catch (e) {
      _showError('Không thể đồng bộ dữ liệu: $e');
      await _loadLocalData();
    } finally {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
      });
    }
  }

  Future<void> _syncChecklists() async {
    final r = await http.get(Uri.parse('$baseUrl/checklistlist/${widget.username}'));
    if (r.statusCode == 200) {
      final List<dynamic> data = json.decode(r.body);
      _checklists = data.map((e) => ChecklistListModel.fromMap(e)).toList();
      await _saveChecklistsLocally();
    }
  }

  Future<void> _syncItems() async {
    final r = await http.get(Uri.parse('$baseUrl/checklistitem/${widget.username}'));
    if (r.statusCode == 200) {
      final List<dynamic> data = json.decode(r.body);
      _items = data.map((e) => ChecklistItemModel.fromMap(e)).toList();
      await _saveItemsLocally();
    }
  }

  Future<void> _syncReports() async {
    final r = await http.get(Uri.parse('$baseUrl/checklistreport/${widget.username}'));
    if (r.statusCode == 200) {
      final List<dynamic> data = json.decode(r.body);
      _reports = data.map((e) => ChecklistReportModel.fromMap(e)).toList();
      await _saveReportsLocally();
    }
  }

  Future<void> _saveChecklistsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_listsKey, _checklists.map((e) => json.encode(e.toMap())).toList());
  }

  Future<void> _saveItemsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_itemsKey, _items.map((e) => json.encode(e.toMap())).toList());
  }

  Future<void> _saveReportsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reportsKey, _reports.map((e) => json.encode(e.toMap())).toList());
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final l = prefs.getStringList(_listsKey) ?? [];
      _checklists = l.map((s) {
        final m = json.decode(s) as Map<String, dynamic>;
        return ChecklistListModel.fromMap(m);
      }).toList();
      final it = prefs.getStringList(_itemsKey) ?? [];
      _items = it.map((s) {
        final m = json.decode(s) as Map<String, dynamic>;
        return ChecklistItemModel.fromMap(m);
      }).toList();
      final rp = prefs.getStringList(_reportsKey) ?? [];
      _reports = rp.map((s) {
        final m = json.decode(s) as Map<String, dynamic>;
        return ChecklistReportModel.fromMap(m);
      }).toList();
      setState(() => _filteredChecklists = _checklists);
    } catch (_) {}
  }

  void _extractProjects() {
    final projects = _checklists.map((c) => c.projectName).where((p) => p != null && p!.isNotEmpty).cast<String>().toSet().toList();
    setState(() {
      _projectOptions = projects;
      if (projects.isNotEmpty) _selectedProject = projects.first;
    });
  }

  void _filterChecklists() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredChecklists = _checklists.where((c) {
        final s = q.isEmpty || (c.checklistTitle?.toLowerCase().contains(q) ?? false) || (c.projectName?.toLowerCase().contains(q) ?? false);
        final p = _selectedProject == null || c.projectName == _selectedProject;
        return s && p;
      }).toList();
    });
  }

  List<ChecklistItemModel> _getItemsForChecklist(ChecklistListModel checklist) {
    if (checklist.checklistTaskList == null || checklist.checklistTaskList!.isEmpty) return [];
    final ids = checklist.checklistTaskList!.split('/');
    return _items.where((it) => ids.contains(it.itemId)).toList();
  }

  List<ChecklistReportModel> _getReportsForChecklist(ChecklistListModel checklist) {
    return _reports.where((r) => r.checklistId == checklist.checklistId).toList();
  }

  void _showChecklistPreview(ChecklistListModel checklist) {
    ChecklistPreviewService.showChecklistPreview(
      context: context,
      checklist: checklist,
      items: _getItemsForChecklist(checklist),
      reports: _getReportsForChecklist(checklist),
      selectedStartDate: _selectedStartDate,
      selectedEndDate: _selectedEndDate,
      useBlankDate: _useBlankDate,
      username: widget.username,
    );
  }

  Future<void> _shareChecklistQr(String id) async {
    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang tạo mã QR...';});

    await ChecklistPreviewService.shareChecklistQr(
      checklistId: id,
      context: context,
    );

    setState(() {
      _isLoading = false;
      _syncStatus = '';
    });
  }

  void _showDateRangePicker(ChecklistListModel checklist) {
    if (_selectedStartDate == null && !_useBlankDate) {
      _selectedStartDate = DateTime.now().subtract(const Duration(days: 2));
    }
    if (_selectedEndDate == null && !_useBlankDate && checklist.checklistDateType == 'Multi') {
      _selectedEndDate = DateTime.now();
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn khoảng thời gian'),
        content: StatefulBuilder(
          builder: (context, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Để trống ngày tháng'),
                value: _useBlankDate,
                onChanged: (v) {
                  setS(() {
                    _useBlankDate = v ?? false;
                    if (_useBlankDate) {
                      _selectedStartDate = null;
                      _selectedEndDate = null;
                    } else {
                      _selectedStartDate = DateTime.now().subtract(const Duration(days: 2));
                      if (checklist.checklistDateType == 'Multi') {
                        _selectedEndDate = DateTime.now();
                      }
                    }
                  });
                },
              ),
              if (!_useBlankDate) ...[
                ListTile(
                  title: const Text('Ngày bắt đầu'),
                  subtitle: Text(_selectedStartDate?.toString().split(' ')[0] ?? 'Chưa chọn'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedStartDate ?? DateTime.now().subtract(const Duration(days: 2)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setS(() => _selectedStartDate = d);
                  },
                ),
                if (checklist.checklistDateType == 'Multi')
                  ListTile(
                    title: const Text('Ngày kết thúc'),
                    subtitle: Text(_selectedEndDate?.toString().split(' ')[0] ?? 'Chưa chọn'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedEndDate ?? DateTime.now(),
                        firstDate: _selectedStartDate ?? DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setS(() => _selectedEndDate = d);
                    },
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showChecklistPreview(checklist);
            },
            child: const Text('Xem trước'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generateAndSharePDF(checklist);
            },
            child: const Text('Tạo PDF'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareChecklistQr(checklist.checklistId);
            },
            icon: const Icon(Icons.qr_code),
            label: const Text('Tải mã QR'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSharePDF(ChecklistListModel checklist) async {
    setState(() {
      _isLoading = true;
      _syncStatus = 'Đang tạo PDF...';
    });

    await ChecklistPreviewService.generateAndSharePDF(
      checklist: checklist,
      items: _getItemsForChecklist(checklist),
      reports: _getReportsForChecklist(checklist),
      username: widget.username,
      selectedStartDate: _selectedStartDate,
      selectedEndDate: _selectedEndDate,
      useBlankDate: _useBlankDate,
      context: context,
    );

    setState(() {
      _isLoading = false;
      _syncStatus = '';
    });
  }

  void _showSuccess(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green));
    }
  }

  void _showError(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
    }
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.fromARGB(255, 156, 39, 176), Color.fromARGB(255, 186, 104, 200), Color.fromARGB(255, 171, 71, 188), Color.fromARGB(255, 206, 147, 216)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: isMobile ? 20 : 24),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(child: Text('Các loại Checklist', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: Colors.white))),
              if (_isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
            ],
          ),
          if (!_isLoading)
            Container(
              margin: EdgeInsets.only(top: isMobile ? 12 : 16),
              height: isMobile ? 36 : 40,
              child: ElevatedButton.icon(
                onPressed: () => _syncAllData(),
                icon: Icon(Icons.sync, size: isMobile ? 16 : 18),
                label: Text('Đồng bộ', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.purple[700], elevation: 2),
              ),
            ),
          if (_isLoading && _syncStatus.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Text(_syncStatus, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isMobile ? 12 : 14), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm checklist...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple[200]!)),
                child: Text('${_filteredChecklists.length} loại', style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w500, color: Colors.purple[700])),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedProject,
            hint: const Text('Chọn dự án'),
            isExpanded: true,
            items: _projectOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedProject = v;
                _filterChecklists();
              });
            },
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 12 : 8)),
          ),
        ],
      ),
    );
  }

  Widget _thumbFor(ChecklistItemModel item, {double size = 16}) {
    final has = (item.itemImage != null && item.itemImage!.isNotEmpty);
    final path = 'assets/checklist/${item.itemImage ?? ''}';
    final child = has ? Image.asset(path, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, e, __) {
      return Icon(_iconMap[item.itemIcon ?? ''] ?? Icons.help_outline, size: size);
    }) : Icon(_iconMap[item.itemIcon ?? ''] ?? Icons.help_outline, size: size);
    return ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(width: size, height: size, child: child));
  }

  Widget _buildChecklistCard(ChecklistListModel checklist) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final items = _getItemsForChecklist(checklist);
    final firstItem = items.isNotEmpty ? items.first : null;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 6),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isMobile ? 32 : 36,
                  height: isMobile ? 32 : 36,
                  decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(8)),
                  child: Center(child: firstItem != null ? _thumbFor(firstItem, size: isMobile ? 22 : 26) : Icon(Icons.list_alt, color: Colors.purple[600], size: isMobile ? 20 : 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(checklist.checklistTitle ?? 'Unnamed Checklist', style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold)),
                      Text('${checklist.projectName ?? ''} - ${checklist.areaName ?? ''}', style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showDateRangePicker(checklist),
                      icon: const Icon(Icons.visibility, size: 14),
                      label: const Text('Xem', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: const Size(0, 32)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showDateRangePicker(checklist),
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('PDF', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: const Size(0, 32)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildChecklistInfo(checklist, items, isMobile),
            const SizedBox(height: 12),
            _buildItemsList(items, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistInfo(ChecklistListModel c, List<ChecklistItemModel> items, bool isMobile) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _chip('ID: ${c.checklistId}', Colors.grey),
        _chip('${c.checklistDateType}', Colors.blue),
        _chip('${c.checklistTimeType}', Colors.green),
        _chip('${c.checklistCompletionType}', Colors.orange),
        _chip('${items.length} items', Colors.purple),
        if (c.versionNumber != null) _chip('v${c.versionNumber}', Colors.teal),
        if (c.checklistNoteEnabled == 'true' || c.checklistNoteEnabled == '1') _chip('Note enabled', Colors.indigo),
      ],
    );
  }

  Widget _chip(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))),
      child: Text(t, style: TextStyle(fontSize: 11, color: Color.fromARGB(255, c.red ~/ 3, c.green ~/ 3, c.blue ~/ 3), fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildItemsList(List<ChecklistItemModel> items, bool isMobile) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: Text('Không có items nào', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items trong checklist:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.purple[700])),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items.map((it) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _thumbFor(it, size: 16),
                const SizedBox(width: 4),
                Text(it.itemName ?? it.itemId, style: TextStyle(fontSize: 11, color: Colors.purple[600])),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            Expanded(
              child: _filteredChecklists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(_isLoading ? 'Đang tải...' : 'Không có checklist nào', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredChecklists.length,
                      itemBuilder: (c, i) => _buildChecklistCard(_filteredChecklists[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}